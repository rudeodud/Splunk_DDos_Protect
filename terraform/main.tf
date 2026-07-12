locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_ami" "amazon_linux_2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  selected_ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023[0].id
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[1].id

  tags = {
    Name = "${local.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_instance" "bastion" {
  ami                         = local.selected_ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  tags = {
    Name = "${local.name_prefix}-bastion"
  }
}

resource "aws_instance" "app" {
  count                       = 2
  ami                         = local.selected_ami_id
  instance_type               = var.app_instance_type
  subnet_id                   = aws_subnet.private[count.index].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_pair_name
  iam_instance_profile        = aws_iam_instance_profile.app.name
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    dnf update -y
    dnf install -y git nodejs npm awscli

    APP_DIR="/opt/splunk-ddos-protect"
    APP_USER="splunkstore"

    if ! id "$${APP_USER}" >/dev/null 2>&1; then
      useradd --system --home-dir "$${APP_DIR}" --shell /sbin/nologin "$${APP_USER}"
    fi

    rm -rf "$${APP_DIR}"
    git clone --depth 1 --branch ${jsonencode(var.app_source_ref)} ${jsonencode(var.app_source_repo)} "$${APP_DIR}"

    SPLUNK_HEC_TOKEN=${jsonencode(var.splunk_hec_token)}
    if [ -n "${var.splunk_hec_token_ssm_parameter_name}" ]; then
      SPLUNK_HEC_TOKEN="$(aws ssm get-parameter \
        --name ${jsonencode(var.splunk_hec_token_ssm_parameter_name)} \
        --with-decryption \
        --query Parameter.Value \
        --output text \
        --region ${jsonencode(var.aws_region)})"
    fi

    printf '%s\n' \
      'HOST=0.0.0.0' \
      'PORT=${var.app_port}' \
      'SPLUNK_HEC_URL=${jsonencode(var.splunk_hec_url)}' \
      "SPLUNK_HEC_TOKEN=$${SPLUNK_HEC_TOKEN}" \
      'SPLUNK_HEC_INDEX=${jsonencode(var.splunk_hec_index)}' \
      'SPLUNK_HEC_SOURCE=${jsonencode(var.splunk_hec_source)}' \
      'SPLUNK_HEC_SOURCETYPE=${jsonencode(var.splunk_hec_sourcetype)}' \
      'SPLUNK_HEC_INSECURE=${var.splunk_hec_insecure}' \
      > "$${APP_DIR}/.env"

    chown -R "$${APP_USER}:$${APP_USER}" "$${APP_DIR}"

    printf '%s\n' \
      '[Unit]' \
      'Description=Splunk DDoS Protect Virtual Store' \
      'After=network-online.target' \
      'Wants=network-online.target' \
      '' \
      '[Service]' \
      'Type=simple' \
      "WorkingDirectory=$${APP_DIR}" \
      'ExecStart=/usr/bin/npm start' \
      'Restart=always' \
      'RestartSec=5' \
      "User=$${APP_USER}" \
      'Environment=NODE_ENV=production' \
      '' \
      '[Install]' \
      'WantedBy=multi-user.target' \
      > /etc/systemd/system/virtual-store.service

    systemctl daemon-reload
    systemctl enable --now virtual-store.service
  EOF

  tags = {
    Name = "${local.name_prefix}-app-${count.index + 1}"
  }
}

resource "aws_lb" "app" {
  name               = substr("${local.name_prefix}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = substr("${local.name_prefix}-tg", 0, 32)
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = length(aws_instance.app)
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = var.app_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

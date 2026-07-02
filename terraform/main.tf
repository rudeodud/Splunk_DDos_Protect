# ============================================================
# Data Sources
# ============================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================
# VPC
# ============================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
  }
}

# ============================================================
# Internet Gateway
# ============================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw-${var.environment}"
  }
}

# ============================================================
# Public Subnets
# ============================================================
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}-${var.environment}"
    Tier = "Public"
  }
}

# ============================================================
# Private Subnets
# ============================================================
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}-${var.environment}"
    Tier = "Private"
  }
}

# ============================================================
# Elastic IP & NAT Gateway (프라이빗 서브넷 → 인터넷)
# ============================================================
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${var.environment}"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat-gw-${var.environment}"
  }
}

# ============================================================
# Route Tables
# ============================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt-${var.environment}"
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
    Name = "${var.project_name}-private-rt-${var.environment}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================================
# Security Groups
# ============================================================

# Splunk 서버 SG
resource "aws_security_group" "splunk" {
  name        = "${var.project_name}-splunk-sg-${var.environment}"
  description = "Splunk 서버 보안 그룹"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Splunk Web UI"
    from_port   = var.splunk_web_port
    to_port     = var.splunk_web_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Splunk HEC"
    from_port   = var.splunk_hec_port
    to_port     = var.splunk_hec_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-splunk-sg-${var.environment}"
  }
}

# ALB SG
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "ALB 보안 그룹"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg-${var.environment}"
  }
}

# ============================================================
# IAM Role for EC2 (Splunk → S3/CloudWatch 접근)
# ============================================================
resource "aws_iam_role" "splunk_ec2" {
  name = "${var.project_name}-splunk-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-splunk-ec2-role-${var.environment}"
  }
}

resource "aws_iam_role_policy_attachment" "splunk_ssm" {
  role       = aws_iam_role.splunk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "splunk_cloudwatch" {
  role       = aws_iam_role.splunk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "splunk_s3_access" {
  name = "${var.project_name}-splunk-s3-policy-${var.environment}"
  role = aws_iam_role.splunk_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.logs.arn,
        "${aws_s3_bucket.logs.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "splunk_ec2" {
  name = "${var.project_name}-splunk-instance-profile-${var.environment}"
  role = aws_iam_role.splunk_ec2.name
}

# ============================================================
# EC2 – Splunk 서버
# ============================================================
resource "aws_instance" "splunk" {
  ami                    = var.splunk_ami_id
  instance_type          = var.splunk_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.splunk.id]
  iam_instance_profile   = aws_iam_instance_profile.splunk_ec2.name
  key_name               = var.key_pair_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 100
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/splunk_install.sh", {
    splunk_web_port = var.splunk_web_port
    splunk_hec_port = var.splunk_hec_port
  }))

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = "${var.project_name}-splunk-server-${var.environment}"
    Role = "Splunk"
  }
}

# ============================================================
# S3 – 로그 저장소
# ============================================================
resource "aws_s3_bucket" "logs" {
  bucket        = var.log_bucket_name
  force_destroy = var.environment != "prod"

  tags = {
    Name    = var.log_bucket_name
    Purpose = "DDoS-WAF-Logs"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.log_retention_days
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

# ============================================================
# WAF v2 – DDoS/봇 차단
# ============================================================
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-waf-${var.environment}"
  description = "DDoS 방어 WAF ACL"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-${var.environment}"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-waf-${var.environment}"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_s3_bucket.logs.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}

# ============================================================
# SNS – DDoS 알람
# ============================================================
resource "aws_sns_topic" "ddos_alarm" {
  name = "${var.project_name}-ddos-alarm-${var.environment}"

  tags = {
    Name = "${var.project_name}-ddos-alarm-${var.environment}"
  }
}

resource "aws_sns_topic_subscription" "ddos_email" {
  topic_arn = aws_sns_topic.ddos_alarm.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ============================================================
# CloudWatch – DDoS 감지 알람
# ============================================================
resource "aws_cloudwatch_metric_alarm" "ddos_detected" {
  alarm_name          = "${var.project_name}-ddos-detected-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DDoSDetected"
  namespace           = "AWS/DDoSProtection"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "AWS Shield가 DDoS 공격을 감지했습니다"
  alarm_actions       = [aws_sns_topic.ddos_alarm.arn]
  ok_actions          = [aws_sns_topic.ddos_alarm.arn]

  dimensions = {
    ResourceArn = aws_vpc.main.arn
  }

  tags = {
    Name = "${var.project_name}-ddos-detected-alarm-${var.environment}"
  }
}

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${var.project_name}-waf-blocked-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 60
  statistic           = "Sum"
  threshold           = var.ddos_threshold_requests
  alarm_description   = "WAF 차단 요청 수가 임계값을 초과했습니다 (DDoS 의심)"
  alarm_actions       = [aws_sns_topic.ddos_alarm.arn]

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = var.aws_region
    Rule   = "ALL"
  }

  tags = {
    Name = "${var.project_name}-waf-blocked-alarm-${var.environment}"
  }
}

# ============================================================
# CloudWatch Log Group
# ============================================================
resource "aws_cloudwatch_log_group" "splunk_ddos" {
  name              = "/aws/${var.project_name}/${var.environment}/ddos-events"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-log-group-${var.environment}"
  }
}

# ============================================================
# AWS Shield Advanced (선택적)
# ============================================================
resource "aws_shield_protection" "vpc" {
  count        = var.enable_aws_shield_advanced ? 1 : 0
  name         = "${var.project_name}-shield-vpc-${var.environment}"
  resource_arn = aws_vpc.main.arn

  tags = {
    Name = "${var.project_name}-shield-vpc-${var.environment}"
  }
}

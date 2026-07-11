resource "random_password" "splunk_admin" {
  length           = 18
  special          = true
  override_special = "!@#%*-_+="
}

resource "random_uuid" "splunk_hec_token" {}

locals {
  effective_splunk_admin_password = var.splunk_admin_password != "" ? var.splunk_admin_password : random_password.splunk_admin.result
  effective_splunk_hec_token      = var.splunk_hec_token != "" ? var.splunk_hec_token : random_uuid.splunk_hec_token.result
  effective_splunk_hec_url        = var.splunk_hec_url != "" ? var.splunk_hec_url : "http://${aws_instance.splunk.private_ip}:${var.splunk_hec_port}/services/collector/event"
}

resource "aws_instance" "splunk" {
  ami                         = local.selected_ami_id
  instance_type               = var.splunk_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.splunk.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.splunk_root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    dnf update -y
    dnf install -y wget

    SPLUNK_HOME="/opt/splunk"
    SPLUNK_ADMIN_PASS=${jsonencode(local.effective_splunk_admin_password)}
    SPLUNK_HEC_TOKEN=${jsonencode(local.effective_splunk_hec_token)}

    wget -O /tmp/splunk.rpm ${jsonencode(var.splunk_download_url)}
    dnf install -y /tmp/splunk.rpm
    rm -f /tmp/splunk.rpm

    "$${SPLUNK_HOME}/bin/splunk" start --accept-license --answer-yes --no-prompt --seed-passwd "$${SPLUNK_ADMIN_PASS}"

    "$${SPLUNK_HOME}/bin/splunk" set web-port ${var.splunk_web_port} -auth "admin:$${SPLUNK_ADMIN_PASS}"

    mkdir -p "$${SPLUNK_HOME}/etc/system/local"
    printf '%s\n' \
      '[http]' \
      'disabled = 0' \
      'port = ${var.splunk_hec_port}' \
      'enableSSL = 0' \
      '' \
      '[http://virtual-store-click-events]' \
      'disabled = 0' \
      "token = $${SPLUNK_HEC_TOKEN}" \
      'index = ${var.splunk_hec_index}' \
      'sourcetype = ${var.splunk_hec_sourcetype}' \
      'source = ${var.splunk_hec_source}' \
      'useACK = 0' \
      > "$${SPLUNK_HOME}/etc/system/local/inputs.conf"

    "$${SPLUNK_HOME}/bin/splunk" restart
    "$${SPLUNK_HOME}/bin/splunk" enable boot-start -systemd-managed 1 || true
  EOF

  tags = {
    Name = "${local.name_prefix}-splunk"
  }
}

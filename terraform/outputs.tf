# ============================================================
# Network Outputs
# ============================================================
output "vpc_id" {
  description = "생성된 VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "NAT Gateway 공인 IP"
  value       = aws_eip.nat.public_ip
}

# ============================================================
# Splunk Outputs
# ============================================================
output "splunk_instance_id" {
  description = "Splunk EC2 인스턴스 ID"
  value       = aws_instance.splunk.id
}

output "splunk_private_ip" {
  description = "Splunk 서버 프라이빗 IP"
  value       = aws_instance.splunk.private_ip
}

# ============================================================
# S3 Outputs
# ============================================================
output "log_bucket_name" {
  description = "로그 S3 버킷 이름"
  value       = aws_s3_bucket.logs.bucket
}

output "log_bucket_arn" {
  description = "로그 S3 버킷 ARN"
  value       = aws_s3_bucket.logs.arn
}

# ============================================================
# WAF Outputs
# ============================================================
output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.main.id
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN (ALB 연결에 사용)"
  value       = aws_wafv2_web_acl.main.arn
}

# ============================================================
# SNS / Alarm Outputs
# ============================================================
output "sns_alarm_topic_arn" {
  description = "DDoS 알람 SNS 토픽 ARN"
  value       = aws_sns_topic.ddos_alarm.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.splunk_ddos.name
}

# ============================================================
# Account Info
# ============================================================
output "aws_account_id" {
  description = "현재 AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "배포 리전"
  value       = data.aws_region.current.name
}

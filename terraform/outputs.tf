output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP"
  value       = aws_eip.nat.public_ip
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = aws_instance.bastion.public_ip
}

output "splunk_web_url" {
  description = "Splunk Web UI URL"
  value       = "http://${aws_instance.splunk.public_ip}:${var.splunk_web_port}"
}

output "splunk_private_ip" {
  description = "Splunk EC2 private IP"
  value       = aws_instance.splunk.private_ip
}

output "splunk_hec_url" {
  description = "App EC2에서 사용하는 Splunk HEC URL"
  value       = local.effective_splunk_hec_url
}

output "splunk_admin_password" {
  description = "Splunk admin password"
  value       = local.effective_splunk_admin_password
  sensitive   = true
}

output "splunk_hec_token" {
  description = "Splunk HEC token"
  value       = local.effective_splunk_hec_token
  sensitive   = true
}

output "app_private_ips" {
  description = "Private application EC2 IPs"
  value       = aws_instance.app[*].private_ip
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.app.dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.app.domain_name
}

output "log_bucket_name" {
  description = "S3 log bucket name"
  value       = aws_s3_bucket.logs.bucket
}

output "cloudfront_firehose_name" {
  description = "CloudFront log Firehose name"
  value       = aws_kinesis_firehose_delivery_stream.cloudfront_logs.name
}

output "waf_firehose_name" {
  description = "WAF log Firehose name"
  value       = aws_kinesis_firehose_delivery_stream.waf_logs.name
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.cloudfront.arn
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

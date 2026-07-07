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

output "route53_record_fqdn" {
  description = "Route 53 record FQDN"
  value       = try(aws_route53_record.app[0].fqdn, null)
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

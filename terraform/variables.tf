variable "aws_region" {
  description = "주 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "splunk-ddos-protect"
}

variable "environment" {
  description = "배포 환경"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "사용할 가용 영역"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR 목록"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.10.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR 목록"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.11.0/24"]
}

variable "key_pair_name" {
  description = "EC2 SSH key pair 이름"
  type        = string
}

variable "admin_cidr" {
  description = "Bastion SSH 접근 허용 CIDR"
  type        = string
  default     = "203.0.113.10/32"
}

variable "bastion_instance_type" {
  description = "Bastion EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "Private application EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "EC2 AMI ID. 비워두면 Amazon Linux 2023 최신 AMI를 사용"
  type        = string
  default     = ""
}

variable "app_port" {
  description = "애플리케이션 포트"
  type        = number
  default     = 80
}

variable "log_bucket_name" {
  description = "CloudFront/WAF 로그 저장 S3 버킷 이름. 비우면 자동 생성"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "S3 로그 보존 기간"
  type        = number
  default     = 90
}

variable "waf_rate_limit" {
  description = "WAF rate-based rule 제한값. 5분 기준 IP별 요청 수"
  type        = number
  default     = 2000
}

variable "domain_name" {
  description = "CloudFront에 연결할 FQDN. 비우면 CloudFront 기본 도메인만 사용"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID. domain_name 설정 시 필요"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "CloudFront용 ACM 인증서 ARN. us-east-1 인증서 필요. 비우면 기본 인증서 사용"
  type        = string
  default     = ""
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"
}

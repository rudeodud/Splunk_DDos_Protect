# ============================================================
# General Settings
# ============================================================
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2" # 서울 리전
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍에 사용)"
  type        = string
  default     = "splunk-ddos-protect"
}

variable "environment" {
  description = "배포 환경 (dev / staging / prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment 값은 dev, staging, prod 중 하나여야 합니다."
  }
}

# ============================================================
# VPC / Network
# ============================================================
variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록 (AZ 수만큼)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록 (AZ 수만큼)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "사용할 가용 영역 목록"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

# ============================================================
# EC2 / Splunk
# ============================================================
variable "splunk_instance_type" {
  description = "Splunk EC2 인스턴스 타입"
  type        = string
  default     = "t3.large"
}

variable "splunk_ami_id" {
  description = "Splunk 서버 AMI ID (Amazon Linux 2023)"
  type        = string
  default     = "ami-0c9c942bd7bf113a2" # Amazon Linux 2023 (ap-northeast-2)
}

variable "key_pair_name" {
  description = "EC2 접속용 키 페어 이름"
  type        = string
}

variable "splunk_web_port" {
  description = "Splunk Web UI 포트"
  type        = number
  default     = 8000
}

variable "splunk_hec_port" {
  description = "Splunk HEC (HTTP Event Collector) 포트"
  type        = number
  default     = 8088
}

# ============================================================
# S3 (로그 저장소)
# ============================================================
variable "log_bucket_name" {
  description = "DDoS/WAF 로그를 저장할 S3 버킷 이름 (전역 고유)"
  type        = string
}

variable "log_retention_days" {
  description = "S3 로그 보존 기간 (일)"
  type        = number
  default     = 90
}

# ============================================================
# WAF / Shield
# ============================================================
variable "enable_aws_shield_advanced" {
  description = "AWS Shield Advanced 활성화 여부 (월 $3,000 과금 주의)"
  type        = bool
  default     = false
}

variable "waf_rate_limit" {
  description = "WAF 속도 제한 규칙 – 5분당 최대 요청 수"
  type        = number
  default     = 2000
}

# ============================================================
# CloudWatch / Alerting
# ============================================================
variable "alarm_email" {
  description = "DDoS 알람 수신 이메일 주소"
  type        = string
}

variable "ddos_threshold_requests" {
  description = "DDoS 감지 임계값 – 분당 요청 수"
  type        = number
  default     = 10000
}

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

variable "splunk_instance_type" {
  description = "Splunk Enterprise EC2 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "splunk_root_volume_size" {
  description = "Splunk Enterprise EC2 루트 EBS 볼륨 크기(GB)"
  type        = number
  default     = 30
}

variable "ami_id" {
  description = "EC2 AMI ID. 비워두면 Amazon Linux 2023 최신 AMI를 사용"
  type        = string
  default     = ""
}

variable "app_port" {
  description = "애플리케이션 포트"
  type        = number
  default     = 3000
}

variable "app_source_repo" {
  description = "App EC2가 부팅 시 clone할 frontend/backend Git 저장소 URL"
  type        = string
  default     = "https://github.com/rudeodud/Splunk_DDos_Protect.git"
}

variable "app_source_ref" {
  description = "App EC2가 clone할 Git branch 또는 tag"
  type        = string
  default     = "main"
}

variable "splunk_hec_url" {
  description = "외부 Splunk HEC URL. 비우면 Terraform이 생성한 Splunk EC2 private IP를 사용"
  type        = string
  default     = ""
}

variable "splunk_hec_token" {
  description = "실습용 Splunk HEC token. 운영에서는 splunk_hec_token_ssm_parameter_name 사용 권장"
  type        = string
  default     = ""
  sensitive   = true
}

variable "splunk_hec_token_ssm_parameter_name" {
  description = "Splunk HEC token을 저장한 SSM SecureString parameter 이름. 예: /splunk-ddos/hec-token"
  type        = string
  default     = ""
}

variable "splunk_hec_index" {
  description = "Splunk HEC index"
  type        = string
  default     = "main"
}

variable "splunk_hec_source" {
  description = "Splunk HEC source"
  type        = string
  default     = "virtual-store"
}

variable "splunk_hec_sourcetype" {
  description = "Splunk HEC sourcetype"
  type        = string
  default     = "ddos:store:click"
}

variable "splunk_hec_insecure" {
  description = "Self-signed HTTPS 인증서 실습용 검증 비활성화 여부"
  type        = bool
  default     = false
}

variable "splunk_web_port" {
  description = "Splunk Web UI 포트"
  type        = number
  default     = 8000
}

variable "splunk_hec_port" {
  description = "Splunk HEC 포트"
  type        = number
  default     = 8088
}

variable "splunk_admin_password" {
  description = "Splunk admin 비밀번호. 비우면 Terraform이 임의 생성"
  type        = string
  default     = ""
  sensitive   = true
}

variable "splunk_download_url" {
  description = "Splunk Enterprise Linux RPM 다운로드 URL"
  type        = string
  default     = "https://download.splunk.com/products/splunk/releases/9.2.1/linux/splunk-9.2.1-78803f08aabb.x86_64.rpm"
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

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"
}

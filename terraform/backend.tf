# 기본값은 local state입니다.
# 원격 state를 사용하려면 아래 예시를 환경에 맞게 수정한 뒤 주석을 해제하세요.
#
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "splunk-ddos-protect/terraform.tfstate"
#     region         = "ap-northeast-2"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

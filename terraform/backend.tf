terraform {
  backend "s3" {
    bucket         = "splunk-ddos-tfstate-843578292124"
    key            = "splunk-ddos-protect/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

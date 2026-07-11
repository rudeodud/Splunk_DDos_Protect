# 구축 가이드

## 1. 사전 준비

- Terraform `>= 1.5.0`
- AWS CLI 인증 설정
- EC2 Key Pair
- Terraform이 생성하는 Splunk Enterprise EC2
- Splunk Add-on for AWS

AWS 인증은 환경 변수, AWS SSO, profile, IAM Role 등으로 설정합니다. Access Key와 Secret Key를 Terraform 코드에 넣지 않습니다.

## 2. Terraform 변수 설정

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

필수로 수정할 값은 다음과 같습니다.

```hcl
key_pair_name   = "your-ec2-keypair"
admin_cidr      = "203.0.113.10/32"
log_bucket_name = "your-unique-splunk-ddos-logs-bucket"
```

이 아키텍처는 Route 53을 사용하지 않고 CloudFront 기본 도메인으로 접근합니다.
Splunk Enterprise EC2도 같이 생성되며, `admin_cidr`에서만 Splunk Web UI 8000 포트에 접근할 수 있습니다.

## 3. 배포

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

배포 후 `cloudfront_domain_name`, `splunk_web_url`, `log_bucket_name`, `bastion_public_ip` 출력을 확인합니다. 접속 테스트는 `cloudfront_domain_name` 출력값을 사용합니다.

Splunk admin 비밀번호와 HEC 토큰 확인:

```bash
terraform output -raw splunk_admin_password
terraform output -raw splunk_hec_token
```

## 4. Splunk 수집 설정

Splunk Add-on for AWS에서 S3 input을 생성합니다.

- CloudFront 로그 prefix: `cloudfront/`
- WAF 로그 prefix: `waf/`
- CloudFront sourcetype: `aws:cloudfront:accesslogs`
- WAF sourcetype: `aws:waf`

예시 설정은 `splunk/inputs.conf.example`과 `splunk/props.conf.example`을 참고합니다.

## 5. 탐지 룰 적용

`splunk/ddos_detection_queries.spl`의 SPL을 Splunk Search에서 검증한 뒤 saved search 또는 alert로 등록합니다. 운영 임계값은 정상 트래픽 기준선을 먼저 측정한 뒤 조정해야 합니다.

## 6. 테스트

샘플 로그 생성:

```bash
python3 scripts/generate_test_logs.py --output /tmp/ddos-test-logs --count 1000
```

승인된 테스트 대상에 요청 시뮬레이션:

```bash
python3 scripts/simulate_ddos_requests.py --url https://example.cloudfront.net --requests 500 --concurrency 20
```

## 7. 정리

테스트 리소스를 제거합니다.

```bash
terraform destroy
```

S3 버킷에 로그 객체가 남아 있으면 destroy가 실패할 수 있습니다. 운영 로그는 보존 정책에 따라 별도 백업 또는 삭제 절차를 수행하세요.

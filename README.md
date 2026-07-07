# Splunk 기반 AWS DDoS 탐지/대응 시스템

이 프로젝트는 AWS 엣지/애플리케이션 계층에서 발생하는 대량 요청, 비정상 봇 트래픽, 403/429 급증 같은 DDoS 의심 이벤트를 수집하고 Splunk에서 탐지/분석하기 위한 예제 인프라입니다.

기준 아키텍처 이미지는 루트 폴더의 `Splunk_DDos_Protect.jpg`입니다.

## 아키텍처 개요

요청 흐름은 다음과 같습니다.

```text
User
  -> Route 53
  -> CloudFront
  -> AWS WAF
  -> Application Load Balancer
  -> Private Subnet EC2 2대
```

로그 수집 흐름은 다음과 같습니다.

```text
CloudFront Real-time Logs
  -> Kinesis Data Stream
  -> Kinesis Data Firehose
  -> S3
  -> Splunk

AWS WAF Logs
  -> Kinesis Data Firehose
  -> S3
  -> Splunk
```

## 네트워크 CIDR

| 구분 | AZ | CIDR |
| --- | --- | --- |
| VPC | - | `10.0.0.0/16` |
| Public Subnet | `ap-northeast-2a` | `10.0.0.0/24` |
| Private Subnet | `ap-northeast-2a` | `10.0.1.0/24` |
| Public Subnet | `ap-northeast-2c` | `10.0.10.0/24` |
| Private Subnet | `ap-northeast-2c` | `10.0.11.0/24` |

## 주요 구성 요소

- **Route 53**: 사용자 도메인을 CloudFront 배포로 라우팅합니다. `domain_name`과 `route53_zone_id`를 설정하면 Alias 레코드를 생성합니다.
- **CloudFront**: 전 세계 엣지에서 요청을 수신하고 ALB를 origin으로 사용합니다. 실시간 로그를 Kinesis Data Stream으로 전달합니다.
- **AWS WAF**: CloudFront에 연결되어 rate-based rule로 과도한 요청을 차단합니다. WAF 로그는 Firehose로 전달됩니다.
- **ALB**: Public subnet에 위치하며 Private subnet의 EC2 2대로 트래픽을 분산합니다.
- **Private EC2 2대**: 실제 웹 애플리케이션 서버 역할입니다. 외부에서 직접 접근하지 않고 ALB를 통해서만 접근합니다.
- **Bastion Host**: 운영자가 Private EC2에 SSH 접근할 때 사용하는 점프 서버입니다. `admin_cidr`로 SSH 접근 대역을 제한합니다.
- **NAT Gateway**: AZ c Public subnet(`10.0.10.0/24`)에 위치하며, Private subnet EC2가 패키지 업데이트 등 외부 인터넷으로 나갈 수 있게 합니다.
- **S3**: CloudFront/WAF 로그를 저장합니다. Splunk는 이 버킷을 대상으로 로그를 수집합니다.
- **Splunk**: S3에 적재된 CloudFront/WAF 로그를 수집하고 SPL 탐지 쿼리로 이상 트래픽을 분석합니다.

## 프로젝트 구조

```text
.
├── README.md
├── architecture.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── security_groups.tf
│   ├── waf.tf
│   ├── cloudfront.tf
│   └── firehose.tf
├── splunk/
│   ├── inputs.conf.example
│   ├── props.conf.example
│   ├── savedsearches.conf.example
│   └── ddos_detection_queries.spl
├── scripts/
│   ├── generate_test_logs.py
│   └── simulate_ddos_requests.py
└── docs/
    ├── setup_guide.md
    └── incident_response.md
```

## 실행 방법

1. Terraform 변수 파일을 준비합니다.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

2. `terraform.tfvars`에서 환경에 맞게 값을 수정합니다.

```hcl
key_pair_name = "your-ec2-keypair"
admin_cidr    = "203.0.113.10/32"
log_bucket_name = "your-unique-splunk-ddos-logs-bucket"

# 도메인을 연결할 때만 설정
domain_name     = "app.example.com"
route53_zone_id = "Z1234567890ABCDE"
```

3. Terraform을 초기화하고 배포 계획을 확인합니다.

```bash
terraform init
terraform fmt
terraform validate
terraform plan
```

4. 배포합니다.

```bash
terraform apply
```

5. Splunk에서 S3 수집을 설정합니다.

- `splunk/inputs.conf.example`
- `splunk/props.conf.example`
- `splunk/savedsearches.conf.example`
- `splunk/ddos_detection_queries.spl`

Splunk Add-on for AWS를 사용하는 경우 S3 input에서 로그 버킷과 prefix를 각각 `cloudfront/`, `waf/`로 지정합니다.

## 테스트 로그 생성

샘플 CloudFront/WAF 형태의 테스트 로그를 생성합니다.

```bash
python3 scripts/generate_test_logs.py --output /tmp/ddos-test-logs --count 1000
```

ALB 또는 CloudFront 도메인으로 요청을 보내 DDoS 유사 트래픽을 시뮬레이션합니다.

```bash
python3 scripts/simulate_ddos_requests.py --url https://example.cloudfront.net --requests 500 --concurrency 20
```

운영 환경에서는 승인된 테스트 대상에서만 실행하세요.

## 보안 주의사항

- AWS Access Key와 Secret Key는 코드에 절대 하드코딩하지 않습니다.
- Terraform 실행은 AWS CLI profile, SSO, IAM Role, OIDC 등 안전한 인증 방식을 사용합니다.
- `admin_cidr`는 반드시 본인 또는 운영망의 고정 IP 대역으로 제한합니다.
- WAF rate limit은 서비스 정상 트래픽 기준에 맞게 조정합니다.
- CloudFront/WAF는 전역 서비스 특성상 일부 리소스가 `us-east-1` provider alias로 생성됩니다.

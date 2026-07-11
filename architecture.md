# 아키텍처 상세 설명

이 문서는 루트 폴더의 `Splunk_Protect_DDos.png`를 기준으로 정리했습니다.

## 1. 사용자 요청 처리 흐름

```text
User -> CloudFront -> AWS WAF -> ALB -> Private EC2 2대
```

사용자는 CloudFront 배포 도메인으로 서비스에 접근합니다. CloudFront는 엣지 캐시와 TLS 종단 역할을 수행하며, AWS WAF는 CloudFront에 연결되어 비정상 요청을 필터링합니다.

정상 요청은 ALB로 전달되고, ALB는 Private subnet에 있는 EC2 2대에 트래픽을 분산합니다. EC2는 Public IP 없이 내부 네트워크에만 위치하므로 직접 인터넷 노출을 줄일 수 있습니다.

## 2. 로그 수집 및 분석 흐름

```text
CloudFront Real-time Logs -> Kinesis Data Stream -> Firehose -> S3 -> Splunk
AWS WAF Logs              -> Firehose             -> S3 -> Splunk
```

CloudFront 실시간 로그는 Kinesis Data Stream으로 전달되고, Firehose가 이를 S3에 적재합니다. AWS WAF 로그는 WAF logging configuration을 통해 Firehose로 직접 전달됩니다. Splunk는 S3에 저장된 로그를 주기적으로 수집하여 인덱싱합니다.

Splunk에서는 다음과 같은 탐지 시나리오를 운영할 수 있습니다.

- 특정 IP의 요청 급증
- 403/429 응답 급증
- 자동화 도구 또는 봇 User-Agent 탐지
- 국가/지역별 트래픽 이상
- 동일 URI 반복 요청

## 3. 네트워크 설계

VPC CIDR는 `10.0.0.0/16`입니다.

| AZ | Public Subnet | Private Subnet |
| --- | --- | --- |
| `ap-northeast-2a` | `10.0.0.0/24` | `10.0.1.0/24` |
| `ap-northeast-2c` | `10.0.10.0/24` | `10.0.11.0/24` |

이미지 기준으로 Bastion Host는 AZ a Public subnet에, NAT Gateway는 AZ c Public subnet에 위치합니다. ALB는 VPC 내부에서 두 AZ의 Private EC2로 트래픽을 분산하는 진입점으로 표현되어 있습니다. Private subnet에는 애플리케이션 EC2가 각각 1대씩 위치합니다.

## 4. 구성 요소 역할

- **Bastion Host**: 운영자의 SSH 진입점입니다. Private EC2로 직접 접근하지 않고 Bastion을 거칩니다.
- **NAT Gateway**: Private EC2가 인터넷으로 패키지 다운로드, 보안 업데이트 등을 수행할 수 있게 합니다.
- **ALB**: HTTP/HTTPS 요청을 Private EC2로 분산합니다.
- **EC2**: 보호 대상 웹 애플리케이션 서버입니다.
- **S3**: CloudFront/WAF 로그의 중앙 저장소입니다.
- **Splunk**: 로그 분석, 대시보드, 경보, 사고 대응 조사를 담당합니다.
- **WAF**: rate-based rule과 managed rule을 통해 L7 공격을 완화합니다.
- **CloudFront**: 엣지 계층에서 트래픽을 받아 origin 보호와 로그 생성을 담당합니다.

## 5. 운영 관점

WAF 차단 이벤트와 CloudFront 상태 코드를 함께 분석하면, 단순 트래픽 증가와 실제 공격성 트래픽을 구분하는 데 도움이 됩니다. Splunk 알림은 SOC 또는 운영 채널과 연동하여 임계값 초과 시 대응 절차를 시작하도록 구성합니다.

# DDoS 사고 대응 가이드

## 1. 탐지

Splunk 알림 또는 WAF CloudWatch 지표에서 비정상 트래픽을 확인합니다.

우선 확인할 항목:

- 요청 수 급증 시점
- 상위 source IP
- 403/429 응답 비율
- WAF BLOCK 이벤트
- 특정 URI 집중 여부
- User-Agent 패턴
- 국가/지역별 편중

## 2. 초기 분류

다음 기준으로 단순 트래픽 증가와 공격성 트래픽을 구분합니다.

- 정상 사용자 경로와 다른 URI 반복 요청
- 짧은 시간 내 동일 IP 또는 동일 ASN의 요청 집중
- 비정상 User-Agent 사용
- 로그인, 검색, 결제 같은 비용 높은 엔드포인트 집중
- WAF managed rule 또는 rate-based rule 차단 증가

## 3. 즉시 대응

- WAF rate limit을 임시로 낮춥니다.
- 공격 URI가 명확하면 WAF rule로 해당 경로를 제한합니다.
- 특정 국가/지역에서만 공격이 발생하면 geo match rule을 검토합니다.
- 봇 User-Agent가 명확하면 header match rule을 추가합니다.
- ALB target health와 EC2 CPU/Network 지표를 확인합니다.

## 4. Splunk 조사 쿼리

상위 공격 IP:

```spl
index=aws sourcetype=aws:cloudfront:accesslogs
| stats count as request_count by c_ip
| sort - request_count
| head 20
```

상위 공격 URI:

```spl
index=aws sourcetype=aws:cloudfront:accesslogs
| stats count as request_count by cs_uri_stem
| sort - request_count
| head 20
```

WAF 차단 사유:

```spl
index=aws sourcetype=aws:waf action=BLOCK
| spath
| stats count by terminatingRuleId
| sort - count
```

## 5. 안정화

- 정상 사용자 영향도를 확인합니다.
- WAF rule 변경 사항을 기록합니다.
- 임시 차단 룰은 만료 기준을 정합니다.
- 공격 종료 후 rate limit을 정상 값으로 복구할지 검토합니다.

## 6. 사후 분석

- 공격 시작/종료 시각
- 최대 RPS
- 주요 IP, 국가, ASN
- 주요 URI와 User-Agent
- WAF 차단량
- origin 영향도
- 대응 조치와 효과
- 추가 개선 항목

사후 분석 결과는 WAF 룰, CloudFront 캐시 정책, 애플리케이션 rate limiting, Splunk alert 임계값 개선에 반영합니다.

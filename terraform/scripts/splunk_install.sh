#!/bin/bash
# =============================================================
# Splunk Enterprise 설치 스크립트 (Amazon Linux 2023)
# 템플릿 변수: splunk_web_port, splunk_hec_port
# =============================================================
set -euo pipefail

SPLUNK_VERSION="9.2.1"
SPLUNK_BUILD="78803f08aabb"
SPLUNK_PKG="splunk-$${SPLUNK_VERSION}-$${SPLUNK_BUILD}.x86_64.rpm"
SPLUNK_URL="https://download.splunk.com/products/splunk/releases/$${SPLUNK_VERSION}/linux/$${SPLUNK_PKG}"
SPLUNK_HOME="/opt/splunk"
SPLUNK_ADMIN_PASS="Splunk@Admin2024!" # 운영 환경에서는 Secrets Manager로 교체

# 시스템 업데이트
dnf update -y

# Splunk 다운로드 및 설치
wget -O /tmp/$${SPLUNK_PKG} $${SPLUNK_URL}
rpm -ivh /tmp/$${SPLUNK_PKG}
rm -f /tmp/$${SPLUNK_PKG}

# 초기 실행 (라이선스 동의 자동 처리)
$${SPLUNK_HOME}/bin/splunk start --accept-license --answer-yes \
  --no-prompt --seed-passwd "$${SPLUNK_ADMIN_PASS}"

# 시스템 부팅 시 자동 시작 등록
$${SPLUNK_HOME}/bin/splunk enable boot-start -systemd-managed 1

# Web 포트 변경 (기본 8000)
$${SPLUNK_HOME}/bin/splunk set web-port ${splunk_web_port} \
  -auth admin:$${SPLUNK_ADMIN_PASS}

# HEC 활성화
$${SPLUNK_HOME}/bin/splunk http-event-collector enable \
  -auth admin:$${SPLUNK_ADMIN_PASS}

# HEC 포트 설정
cat >> $${SPLUNK_HOME}/etc/system/local/inputs.conf << EOF
[http]
disabled = 0
port = ${splunk_hec_port}
enableSSL = 0

[http://ddos_events]
index = main
sourcetype = ddos_event
token = $(uuidgen)
EOF

# Splunk 재시작
systemctl restart SplunkForwarder 2>/dev/null || \
  $${SPLUNK_HOME}/bin/splunk restart

# CloudWatch Agent 설치 및 시작
dnf install -y amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

echo "✅ Splunk 설치 완료 – 포트: ${splunk_web_port} (Web), ${splunk_hec_port} (HEC)"

#!/usr/bin/env bash
set -euo pipefail

BUCKET="${BUCKET:-splunk-ddos-logs-843578292124}"
PREFIX="${PREFIX:-cloudfront/}"
REGION="${REGION:-us-east-1}"
DEST="${DEST:-runtime/cloudfront-fast}"

mkdir -p "$DEST"

aws s3 sync "s3://${BUCKET}/${PREFIX}" "$DEST/" \
  --region "$REGION" \
  --exclude "*" \
  --include "*.gz" \
  --only-show-errors

echo "Synced CloudFront logs to $DEST"

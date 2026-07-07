#!/usr/bin/env python3
import argparse
import gzip
import json
import random
from datetime import datetime, timezone
from pathlib import Path


USER_AGENTS = [
    "Mozilla/5.0",
    "curl/8.1.2",
    "python-requests/2.31.0",
    "Googlebot/2.1",
    "HeadlessChrome",
]

URIS = ["/", "/login", "/api/items", "/search", "/checkout", "/wp-login.php"]
COUNTRIES = ["KR", "US", "CN", "RU", "JP", "DE"]


def ip_for(index: int) -> str:
    if index % 10 == 0:
        return "198.51.100.10"
    return f"203.0.113.{random.randint(1, 240)}"


def write_cloudfront_logs(output_dir: Path, count: int) -> None:
    path = output_dir / "cloudfront-test.log.gz"
    with gzip.open(path, "wt", encoding="utf-8") as file:
        for i in range(count):
            status = random.choices([200, 301, 403, 429, 500], weights=[80, 5, 8, 5, 2])[0]
            row = [
                datetime.now(timezone.utc).isoformat(),
                ip_for(i),
                str(round(random.random(), 3)),
                str(status),
                random.choice(["GET", "POST", "HEAD"]),
                random.choice(URIS),
                "-",
                "-",
                random.choice(USER_AGENTS),
                "example.cloudfront.net",
            ]
            file.write("\t".join(row) + "\n")


def write_waf_logs(output_dir: Path, count: int) -> None:
    path = output_dir / "waf-test.json.gz"
    with gzip.open(path, "wt", encoding="utf-8") as file:
        for i in range(count):
            action = random.choices(["ALLOW", "BLOCK"], weights=[85, 15])[0]
            event = {
                "timestamp": int(datetime.now(timezone.utc).timestamp() * 1000),
                "formatVersion": 1,
                "webaclId": "splunk-ddos-protect-web-acl",
                "terminatingRuleId": "rate-limit-by-ip" if action == "BLOCK" else "Default_Action",
                "action": action,
                "httpRequest": {
                    "clientIp": ip_for(i),
                    "country": random.choice(COUNTRIES),
                    "uri": random.choice(URIS),
                    "httpMethod": random.choice(["GET", "POST"]),
                    "headers": [{"name": "User-Agent", "value": random.choice(USER_AGENTS)}],
                },
            }
            file.write(json.dumps(event, separators=(",", ":")) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="CloudFront/WAF 테스트 로그 생성")
    parser.add_argument("--output", default="./test-logs", help="로그 출력 디렉터리")
    parser.add_argument("--count", type=int, default=1000, help="로그 건수")
    args = parser.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    write_cloudfront_logs(output_dir, args.count)
    write_waf_logs(output_dir, args.count)
    print(f"generated logs in {output_dir}")


if __name__ == "__main__":
    main()

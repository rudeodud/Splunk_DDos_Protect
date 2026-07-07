#!/usr/bin/env python3
import argparse
import concurrent.futures
import random
import time
import urllib.error
import urllib.request


USER_AGENTS = [
    "Mozilla/5.0",
    "curl/8.1.2",
    "python-requests/2.31.0",
    "HeadlessChrome",
]

PATHS = ["/", "/login", "/api/items", "/search?q=test", "/wp-login.php"]


def request_once(base_url: str, timeout: float) -> int:
    url = base_url.rstrip("/") + random.choice(PATHS)
    request = urllib.request.Request(url, headers={"User-Agent": random.choice(USER_AGENTS)})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
    except Exception:
        return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="승인된 테스트 대상에 DDoS 유사 요청을 보냅니다.")
    parser.add_argument("--url", required=True, help="테스트 대상 URL")
    parser.add_argument("--requests", type=int, default=100, help="총 요청 수")
    parser.add_argument("--concurrency", type=int, default=10, help="동시 요청 수")
    parser.add_argument("--timeout", type=float, default=5.0, help="요청 타임아웃")
    args = parser.parse_args()

    start = time.time()
    status_counts = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as executor:
        futures = [executor.submit(request_once, args.url, args.timeout) for _ in range(args.requests)]
        for future in concurrent.futures.as_completed(futures):
            status = future.result()
            status_counts[status] = status_counts.get(status, 0) + 1

    elapsed = time.time() - start
    print(f"sent={args.requests} elapsed={elapsed:.2f}s rps={args.requests / elapsed:.2f}")
    for status, count in sorted(status_counts.items()):
        print(f"status={status} count={count}")


if __name__ == "__main__":
    main()

#!/usr/bin/env bash
set -euo pipefail

# Only retry failures that are recognizably caused by HTTP, DNS, socket,
# or native-asset dependency downloads. Do not match generic "timed out":
# Flutter's own test timeout can contain that phrase after a real assertion
# failure and must not be retried as if it were a network problem.
retry_pattern='Received status code 5[0-9]{2}|HTTP/[0-9.]+ 5[0-9]{2}|HTTP response code: 5[0-9]{2}|Gateway Time[- ]out|Connection reset|Connection timed out|Connection refused|Temporary failure|Failed host lookup|Could not resolve host|Name or service not known|Network is unreachable|Failed to establish a new connection|Building native assets failed|Building assets for package:sqlite3 failed|sqlite3.*(download|failed)'

if [[ "${1:-}" == "--self-test" ]]; then
  test_timeout='TimeoutException after 0:10:00.000000: Test timed out after 10 minutes.'
  network_timeout='SocketException: Connection timed out'
  http_503='Received status code 503 from package host'

  if printf '%s\n' "$test_timeout" | grep -Eiq "$retry_pattern"; then
    echo "ERROR: Flutter test timeout was incorrectly classified as transient."
    exit 1
  fi
  if ! printf '%s\n' "$network_timeout" | grep -Eiq "$retry_pattern"; then
    echo "ERROR: Socket connection timeout was not classified as transient."
    exit 1
  fi
  if ! printf '%s\n' "$http_503" | grep -Eiq "$retry_pattern"; then
    echo "ERROR: HTTP 503 was not classified as transient."
    exit 1
  fi

  echo "Flutter test retry classifier self-test passed."
  exit 0
fi

if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo "Usage: $0 <flutter-test-log>" >&2
  exit 2
fi

grep -Eiq "$retry_pattern" "$1"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(dirname "$0")/validate_android_release_tag.sh"

expect_success() {
  local expected="$1"
  shift
  local actual
  actual="$(bash "$SCRIPT" "$@")"
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected '$expected', got '$actual'." >&2
    exit 1
  fi
}

expect_failure() {
  if bash "$SCRIPT" "$@" >/dev/null 2>&1; then
    echo "Expected validation failure for: $*" >&2
    exit 1
  fi
}

expect_success $'1.0.1\t123\tv1.0.1+123' \
  "1.0.1+1" "v1.0.1+123" "v1.0.0+122" "abc123" "abc123"
expect_success $'1.0.0\t123\tv1.0.0+123' \
  "1.0.0+1" "v1.0.0+123" "v1.0.0+122" "abc123" "abc123"

expect_failure "1.0.1+1" "v1.0.1" "v1.0.0+122" "abc123" "abc123"
expect_failure "1.0.1+1" "v1.0.2+123" "v1.0.0+122" "abc123" "abc123"
expect_failure "1.0.1+1" "v1.0.1+123" "v1.0.0+122" "abc123" "different"
expect_failure "1.0.1+1" "v1.0.1+122" "v1.0.0+122" "abc123" "abc123"
expect_failure "1.0.0+1" "v0.9.9+123" "v1.0.0+122" "abc123" "abc123"
expect_failure "1.0.1+1" "v1.0.1+123" "not-a-release" "abc123" "abc123"
expect_failure "1.0.1+1" "v1.0.1+0123" "v1.0.0+122" "abc123" "abc123"

echo "Android release-tag validation tests passed."

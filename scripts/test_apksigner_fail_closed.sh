#!/usr/bin/env bash
set -euo pipefail

WORKFLOW=".github/workflows/ci.yml"

for invocation in \
  'if ! "$APKSIGNER" verify --print-certs "$PREVIOUS_APK"' \
  'if ! "$APKSIGNER" verify --print-certs "$APK"'
do
  if ! grep -Fq "$invocation" "$WORKFLOW"; then
    echo "Missing fail-closed apksigner verification: $invocation" >&2
    exit 1
  fi
done

if grep -E 'apksigner" verify --print-certs.*\|\|[[:space:]]*true' "$WORKFLOW"; then
  echo "apksigner verification must never ignore a non-zero exit status." >&2
  exit 1
fi

echo "APK signature verification is fail-closed for both published and candidate APKs."

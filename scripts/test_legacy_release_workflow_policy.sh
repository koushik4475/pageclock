#!/usr/bin/env bash
set -euo pipefail

workflow=".github/workflows/ci.yml"
if [[ ! -f "$workflow" ]]; then
  echo "ERROR: legacy release workflow is missing."
  exit 1
fi

if grep -Eq 'secrets\.|^  (android-apk|publish-release):|tags:.*v\*|contents: write' "$workflow"; then
  echo "ERROR: legacy release workflow still contains production signing or publishing capability."
  exit 1
fi

echo "Legacy release workflow is validation-only: no signing secrets, production jobs, tag trigger, or write permission."

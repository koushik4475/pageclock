#!/usr/bin/env bash
set -euo pipefail

WORKFLOW=".github/workflows/ci.yml"
if [[ ! -f "$WORKFLOW" ]]; then
  echo "Workflow file not found: $WORKFLOW" >&2
  exit 1
fi

grep -Fq "tags: [ 'v*' ]" "$WORKFLOW" || {
  echo "Version-tag pushes must trigger the release workflow." >&2
  exit 1
}

TAG_ONLY_CONDITIONS="$(grep -Fc "if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')" "$WORKFLOW")"
if [[ "$TAG_ONLY_CONDITIONS" -ne 2 ]]; then
  echo "Both production APK build and publisher must be restricted to v* tag pushes." >&2
  exit 1
fi

if grep -Fq "github.ref == 'refs/heads/main'" "$WORKFLOW"; then
  echo "Production jobs must not be gated to main branch pushes." >&2
  exit 1
fi

if grep -Fq 'GITHUB_RUN_NUMBER' "$WORKFLOW"; then
  echo "Release versionCode must come from the version tag, not the workflow run number." >&2
  exit 1
fi

awk '
  /^  android-apk:/ { in_android = 1; next }
  /^  [A-Za-z0-9_-]+:/ && in_android { in_android = 0 }
  /secrets\.ANDROID_/ {
    if (!in_android) {
      print "Production Android signing secrets are referenced outside android-apk." > "/dev/stderr"
      exit 1
    }
    found = 1
  }
  END {
    if (!found) {
      print "No production Android signing secrets found in android-apk." > "/dev/stderr"
      exit 1
    }
  }
' "$WORKFLOW"

echo "Release workflow policy tests passed: production signing is tag-only."

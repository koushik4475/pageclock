#!/usr/bin/env bash
# Exercise the release comparator with disposable copies of the PR debug build.
set -euo pipefail
apk="$1"
build_tools="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
compare() {
  java --class-path "$build_tools/lib/apksigner.jar" scripts/CompareApkSigners.java "$apk" "$1"
}
compare "$apk"
keytool -genkeypair -alias fixture -keyalg RSA -keystore "$tmp/fixture.jks" \
  -storepass fixturepass -keypass fixturepass -dname CN=Test -validity 2
"$build_tools/apksigner" sign --ks "$tmp/fixture.jks" --ks-pass pass:fixturepass \
  --out "$tmp/different.apk" "$apk"
"$build_tools/apksigner" verify "$tmp/different.apk"
if compare "$tmp/different.apk"; then
  echo "Accepted APK signed by a different key" >&2
  exit 1
fi
head -c 4096 "$apk" > "$tmp/truncated.apk"
if compare "$tmp/truncated.apk"; then
  echo "Accepted truncated APK" >&2
  exit 1
fi

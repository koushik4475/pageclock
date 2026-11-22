#!/usr/bin/env bash
set -euo pipefail

APK="${GITHUB_WORKSPACE:?}/build/app/outputs/flutter-apk/app-debug.apk"
OUTPUT="${RUNNER_TEMP:?}/pageclock-android-smoke.png"
LOG="${RUNNER_TEMP}/pageclock-android-logcat.txt"

if [[ ! -s "$APK" ]]; then
  echo "::error::Android debug APK is missing from the GitHub workspace: $APK"
  find "$GITHUB_WORKSPACE/build/app/outputs/flutter-apk" -maxdepth 2 -type f -ls 2>/dev/null || true
  exit 1
fi

adb logcat -c
adb install -r "$APK"
adb shell monkey -p com.example.pageclock 1

started=false
for attempt in $(seq 1 30); do
  if adb shell pidof com.example.pageclock >/dev/null 2>&1; then
    started=true
    break
  fi
  sleep 1
done
if [[ "$started" != true ]]; then
  echo "::error::PageClock process did not start on the Android 16 emulator."
  exit 1
fi

sleep 8
if ! adb shell pidof com.example.pageclock; then
  echo "::error::PageClock process exited shortly after launch."
  exit 1
fi

ACTIVITY_DUMP=$(adb shell dumpsys activity activities)
echo "$ACTIVITY_DUMP" | grep -F 'com.example.pageclock' >/dev/null || { echo '::error::PageClock is not present in Android activity stack.'; exit 1; }
echo 'PageClock is present in activity stack.'
adb logcat -d -v brief > "$LOG"
if grep -A 12 -F "FATAL EXCEPTION" "$LOG" | grep -qF "com.example.pageclock"; then
  echo "::error::PageClock crashed during Android emulator launch."
  exit 1
fi

adb shell screencap -p /sdcard/pageclock-android-smoke.png
adb pull /sdcard/pageclock-android-smoke.png "$OUTPUT"
test -s "$OUTPUT"
echo "Android 16 emulator install, foreground launch, process-liveness, crash-log and screenshot checks passed."

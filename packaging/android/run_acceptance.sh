#!/usr/bin/env bash
set -euo pipefail
# Retrieve synthetic app-only captures before Gradle tears down the test device.
mkdir -p dist/android-emulator
collect() {
  while true; do
    for name in home-en-light.png home-ru-dark.png; do
      local_file="dist/android-emulator/$name"
      if [[ ! -f "$local_file" ]] && adb pull "/data/local/tmp/odibo-$name" "$local_file.part" >/dev/null 2>&1; then
        mv "$local_file.part" "$local_file"
        adb shell touch "/data/local/tmp/odibo-captured-$name" >/dev/null
      fi
    done
    sleep 0.2
  done
}
collect &
collector=$!
cleanup() {
  kill "$collector" 2>/dev/null || true
  wait "$collector" 2>/dev/null || true
}
trap cleanup EXIT
"${ODIBO_GRADLE:?}" -p android --no-daemon -PodiboAbi=x86_64 :app:connectedDebugAndroidTest
python3 packaging/android/verify_screenshots.py

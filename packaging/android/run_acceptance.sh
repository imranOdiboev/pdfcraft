#!/usr/bin/env bash
set -euo pipefail
# Retrieve synthetic app-only captures before Gradle tears down the test device.
mkdir -p dist/android-emulator
collect() {
  while true; do
    for name in home-en-light.png home-ru-dark.png tools-combine-en-light.png tools-split-en-light.png tools-reorder-ru-dark.png; do
      local_file="dist/android-emulator/$name"
      if [[ ! -f "$local_file" ]] && adb shell run-as com.odibo.pdf test -f "files/screenshots/$name.ready" >/dev/null 2>&1 &&
        adb exec-out run-as com.odibo.pdf cat "files/screenshots/$name" > "$local_file.part" 2>/dev/null; then
        mv "$local_file.part" "$local_file"
        adb shell run-as com.odibo.pdf touch "files/screenshots/$name.collected" >/dev/null
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

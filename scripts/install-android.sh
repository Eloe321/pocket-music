#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sdk_root=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}

if [ -z "$sdk_root" ] || [ ! -x "$sdk_root/platform-tools/adb" ]; then
  printf '%s\n' 'Set ANDROID_SDK_ROOT (or ANDROID_HOME) to an Android SDK that contains platform-tools/adb.' >&2
  exit 1
fi

adb="$sdk_root/platform-tools/adb"
apk="$project_root/app/build/app/outputs/flutter-apk/app-release.apk"

if [ ! -f "$apk" ]; then
  printf '%s\n' 'Build the APK first: ./scripts/build-android-release.sh' >&2
  exit 1
fi

device_count=$("$adb" devices | awk '$2 == "device" { count++ } END { print count + 0 }')
if [ "$device_count" -ne 1 ]; then
  printf '%s\n' 'Connect exactly one unlocked Android phone with USB debugging authorized.' >&2
  "$adb" devices -l >&2
  exit 1
fi

"$adb" install -r "$apk"

#!/bin/sh
set -eu

if [ -z "${IPHONE_UDID:-}" ]; then
  printf '%s\n' 'Set IPHONE_UDID to the connected iPhone identifier shown by: xcrun devicectl list devices' >&2
  exit 1
fi

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
flutter_bin=${FLUTTER_BIN:-flutter}

cd "$project_root/app"
"$flutter_bin" pub get
cd ios
pod install
cd ..
"$flutter_bin" build ios --release
xcrun devicectl device install app --device "$IPHONE_UDID" build/ios/iphoneos/Runner.app

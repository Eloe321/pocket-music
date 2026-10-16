#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
flutter_bin=${FLUTTER_BIN:-flutter}

cd "$project_root/app"
"$flutter_bin" pub get
"$flutter_bin" build apk --release --no-tree-shake-icons

printf '%s\n' "APK ready: $project_root/app/build/app/outputs/flutter-apk/app-release.apk"

#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${1:-emulator-5554}"
PACKAGE_NAME="com.lokus.app"
LEGACY_PACKAGE_NAMES=("com.example.lokus" "com.example.lm_playground")
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
APK="$ROOT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

if [[ ! -x "$ADB" ]]; then
  echo "adb not found at $ADB" >&2
  exit 1
fi

cd "$ROOT_DIR"
flutter build apk --debug --target-platform android-arm64

"$ADB" -s "$DEVICE_ID" shell pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1 || true
"$ADB" -s "$DEVICE_ID" shell rm -rf "/data/local/tmp/${PACKAGE_NAME}" >/dev/null 2>&1 || true
for legacy_package in "${LEGACY_PACKAGE_NAMES[@]}"; do
  "$ADB" -s "$DEVICE_ID" shell pm uninstall "$legacy_package" >/dev/null 2>&1 || true
  "$ADB" -s "$DEVICE_ID" shell rm -rf "/data/local/tmp/${legacy_package}" >/dev/null 2>&1 || true
done
"$ADB" -s "$DEVICE_ID" shell pm trim-caches 1G >/dev/null 2>&1 || true

echo "Device /data space before install:"
"$ADB" -s "$DEVICE_ID" shell df -h /data || true

if "$ADB" -s "$DEVICE_ID" install -r -d "$APK"; then
  echo "Installed $APK on $DEVICE_ID"
else
  echo "Debug APK install failed." >&2
  echo "Free emulator storage or run with a wiped AVD before retrying." >&2
  exit 1
fi

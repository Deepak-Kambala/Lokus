#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${1:-emulator-5554}"
PACKAGE_NAME="com.example.lokus"
LEGACY_PACKAGE_NAME="com.example.lm_playground"
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
"$ADB" -s "$DEVICE_ID" shell pm uninstall "$LEGACY_PACKAGE_NAME" >/dev/null 2>&1 || true
"$ADB" -s "$DEVICE_ID" shell rm -rf "/data/local/tmp/${PACKAGE_NAME}" >/dev/null 2>&1 || true
"$ADB" -s "$DEVICE_ID" shell rm -rf "/data/local/tmp/${LEGACY_PACKAGE_NAME}" >/dev/null 2>&1 || true

echo "Device /data space before install:"
"$ADB" -s "$DEVICE_ID" shell df -h /data || true

"$ADB" -s "$DEVICE_ID" install -r -d "$APK"

echo "Installed $APK on $DEVICE_ID"

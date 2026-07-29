#!/usr/bin/env bash
# Build Record Seconds for the iOS Simulator, install it and launch with any args.
# Usage:
#   ./build-run.sh
#   RS_DEVICE="iPhone 16" ./build-run.sh
set -euo pipefail

DEV="${RS_DEVICE:-iPhone 17 Pro}"
PROJ="$(cd "$(dirname "$0")" && pwd)"
APP="$PROJ/build/Debug-iphonesimulator/RecordSeconds.app"

echo "▶︎ Generating project…"
python3 "$PROJ/gen_pbxproj.py"

echo "▶︎ Building…"
xcodebuild -project "$PROJ/RecordSeconds.xcodeproj" -target RecordSeconds \
  -sdk iphonesimulator -configuration Debug \
  CODE_SIGNING_ALLOWED=NO SYMROOT="$PROJ/build" build \
  | grep -E "error:|warning: [A-Z]|BUILD (SUCCEEDED|FAILED)" || true

echo "▶︎ Booting $DEV…"
xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" >/dev/null 2>&1 || true
open -a Simulator || true

echo "▶︎ Installing…"
xcrun simctl install "$DEV" "$APP"
xcrun simctl terminate "$DEV" company.lno.videoonesec 2>/dev/null || true

echo "▶︎ Launching with: $*"
xcrun simctl launch "$DEV" company.lno.videoonesec "$@"

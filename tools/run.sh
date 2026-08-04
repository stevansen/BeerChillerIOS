#!/bin/bash
# Rebuild the iOS app and reinstall it on a booted simulator.
#   tools/run.sh <simulator-udid> [scheme] [device-name]
set -e
cd "$(dirname "$0")/.."
UDID="${1:?usage: run.sh <udid> [scheme] [device-name]}"
SCHEME="${2:-BeerCHILLER}"
DEVICE="${3:-iPhone 17}"

xcodebuild -project BeerCHILLER.xcodeproj -scheme "$SCHEME" -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" -derivedDataPath build build \
  2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | sort -u

APP="build/Build/Products/Debug-iphonesimulator/BeerCHILLER.app"
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" com.bierchiller.app 2>/dev/null || true
xcrun simctl launch "$UDID" com.bierchiller.app

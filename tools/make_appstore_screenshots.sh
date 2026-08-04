#!/bin/bash
#
# Captures the App Store screenshots into AppStore/screenshots/.
#
# The scenes live in UITests/AppStoreScreenshots.swift — driven from a UI test
# because two of them need the app driven (the calculation-model page sits behind
# the ⋯ menu) and because the visual style lives in the App Group, which
# `-key value` launch arguments cannot reach.
#
# Apple requires one iPhone size and, since the app supports iPad, one iPad size.
# Smaller sizes are scaled from those, so there is no reason to capture more.
#
# The watch is handled separately: XCUITest does not run on watchOS, so those
# frames come from `simctl` against a booted watch simulator.
#
# Usage: bash tools/make_appstore_screenshots.sh [--skip-watch]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/AppStore/screenshots"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# device name : output directory
DEVICES=(
  "iPhone 17 Pro Max:iphone-6.9"
  "iPad Pro 13-inch (M5):ipad-13"
)
WATCH_DEVICE="Apple Watch Series 11 (46mm)"

collect() {
  local bundle="$1" dest="$2"
  # Wiped rather than merged: leftovers from an earlier run are indistinguishable
  # from this run's output once the names are cleaned up, and uploading a stale
  # frame is exactly the mistake this script exists to prevent.
  rm -rf "$dest"
  mkdir -p "$dest"
  rm -rf "$WORK/att"
  xcrun xcresulttool export attachments \
    --path "$bundle" --output-path "$WORK/att" >/dev/null

  python3 - "$WORK/att" "$dest" <<'PY'
import json, re, shutil, sys
from pathlib import Path

source, destination = Path(sys.argv[1]), Path(sys.argv[2])
manifest = json.loads((source / "manifest.json").read_text())

count = 0
for entry in manifest:
    for attachment in entry.get("attachments", []):
        name = attachment.get("suggestedHumanReadableName", "")
        exported = source / attachment.get("exportedFileName", "")
        # The scene captures are the only attachments named "NN-...".
        if not name[:2].isdigit() or not exported.is_file():
            continue
        # xcresulttool appends "_0_<UUID>" and sometimes ".png" to the name given
        # in the test. Strip both so the files sort and read cleanly.
        clean = re.sub(r"_\d+_[0-9A-Fa-f-]{36}", "", name)
        clean = re.sub(r"\.png$", "", clean, flags=re.IGNORECASE)
        shutil.copy(exported, destination / f"{clean}.png")
        count += 1
print(f"  {count} screenshots -> {destination}")
if count == 0:
    raise SystemExit("no screenshots were exported — did the scenes run?")
PY
}

for entry in "${DEVICES[@]}"; do
  name="${entry%%:*}"
  directory="${entry##*:}"
  echo "==> $name"

  xcodebuild test \
    -project "$ROOT/BeerCHILLER.xcodeproj" \
    -scheme BeerCHILLER \
    -destination "platform=iOS Simulator,name=$name" \
    -derivedDataPath "$ROOT/build" \
    -only-testing:BeerCHILLERUITests/AppStoreScreenshots \
    -resultBundlePath "$WORK/$directory.xcresult" \
    >"$WORK/$directory.log" 2>&1 || {
      echo "  FAILED — last lines of the log:"
      grep -E "error:|failed" "$WORK/$directory.log" | tail -5
      exit 1
    }

  collect "$WORK/$directory.xcresult" "$OUT/$directory"

  # XCUIScreen hands back the frame in the device's *physical* orientation, so a
  # landscape scene arrives with portrait dimensions and the content turned on its
  # side. App Store Connect wants landscape shots at landscape dimensions, and
  # would otherwise display a sideways image. Rotate 90° anticlockwise, which is
  # the direction that puts the header back at the top.
  for shot in "$OUT/$directory"/*landscape*.png; do
    [[ -f "$shot" ]] || continue
    width="$(sips -g pixelWidth "$shot" | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "$shot" | awk '/pixelHeight/ {print $2}')"
    if (( width < height )); then
      sips --rotate 270 "$shot" >/dev/null
      echo "  rotated $(basename "$shot") to landscape"
    fi
  done
done

if [[ "${1:-}" == "--skip-watch" ]]; then
  echo "==> watch skipped"
  exit 0
fi

# --- watch ---
#
# No XCUITest on watchOS, so this drives the app directly. The state comes from
# the same DEBUG launch arguments the UI tests use.
echo "==> $WATCH_DEVICE"
mkdir -p "$OUT/watch"

udid="$(xcrun simctl list devices available -j \
  | python3 -c "
import json,sys
data = json.load(sys.stdin)['devices']
for runtime, devices in data.items():
    for device in devices:
        if device['name'] == '''$WATCH_DEVICE''':
            print(device['udid']); raise SystemExit
raise SystemExit('watch simulator not found')
")"

xcodebuild build \
  -project "$ROOT/BeerCHILLER.xcodeproj" \
  -scheme BeerCHILLERWatch \
  -configuration Debug \
  -destination "platform=watchOS Simulator,id=$udid" \
  -derivedDataPath "$ROOT/build" >"$WORK/watch-build.log" 2>&1

app="$(find "$ROOT/build/Build/Products" -name "*.app" -path "*watchsimulator*" \
       -maxdepth 2 | head -1)"
[[ -n "$app" ]] || { echo "watch app not built"; exit 1; }

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$app"

capture_watch() {
  local scene="$1"; shift
  xcrun simctl terminate "$udid" com.bierchiller.app.watchkitapp 2>/dev/null || true
  xcrun simctl launch "$udid" com.bierchiller.app.watchkitapp "$@" >/dev/null
  python3 -c "import time; time.sleep(4)"
  xcrun simctl io "$udid" screenshot "$OUT/watch/$scene.png" >/dev/null 2>&1
  echo "  $scene"
}

capture_watch "01-running" -seedStyle beer -seedRunningSession
capture_watch "02-idle" -seedStyle classic -seedNoSession

echo
echo "done — review the frames before uploading:"
find "$OUT" -name "*.png" | sort

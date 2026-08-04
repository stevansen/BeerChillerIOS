#!/usr/bin/env python3
"""Writes a ChillSession straight into the simulator's App Group store.

Lets the running / nearly-done / finished UI states be exercised without waiting
out a real cooling time.

    python3 tools/inject_session.py <udid> running   --progress 0.35
    python3 tools/inject_session.py <udid> finished
    python3 tools/inject_session.py <udid> clear

The encoding must match Swift's JSONEncoder defaults: dates are Doubles counted
from 2001-01-01 (timeIntervalSinceReferenceDate) and RawRepresentable enums
encode as their raw Int.
"""
import argparse
import base64
import glob
import json
import os
import plistlib
import subprocess
import time

APP_GROUP = "group.com.bierchiller.app.shared"
REFERENCE_EPOCH = 978307200.0  # 2001-01-01T00:00:00Z in Unix time


def plist_path(udid):
    pattern = os.path.expanduser(
        f"~/Library/Developer/CoreSimulator/Devices/{udid}"
        f"/data/Containers/Shared/AppGroup/*/Library/Preferences/{APP_GROUP}.plist")
    matches = glob.glob(pattern)
    if not matches:
        raise SystemExit("App Group plist not found — launch the app once first.")
    return matches[0]


def swift_date(unix_time):
    return unix_time - REFERENCE_EPOCH


def build_session(total_minutes, progress, start_c, target_c, device_c):
    now = time.time()
    total_seconds = total_minutes * 60
    elapsed = total_seconds * progress
    start = now - elapsed
    return {
        "startDate": swift_date(start),
        "endDate": swift_date(start + total_seconds),
        "startTempC": start_c,
        "targetTempC": target_c,
        "deviceTempC": device_c,
        "containerType": 0,   # bottle
        "volume": 0,          # 0.33 l
        "deviceMode": 0,      # freezer
        "orientation": 1,     # standing
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("udid")
    parser.add_argument("state", choices=["running", "finished", "clear"])
    parser.add_argument("--progress", type=float, default=0.4)
    parser.add_argument("--minutes", type=float, default=34)
    args = parser.parse_args()

    path = plist_path(args.udid)
    with open(path, "rb") as handle:
        store = plistlib.load(handle)

    if args.state == "clear":
        store.pop("chillSession", None)
        summary = "cleared"
    else:
        progress = 1.0 if args.state == "finished" else args.progress
        session = build_session(args.minutes, progress, 22.0, 8.0, -18.0)
        if args.state == "finished":
            # Ended a minute ago, so the app opens straight into the alarm state.
            session["endDate"] -= 60
            session["startDate"] -= 60
        payload = json.dumps(session, separators=(",", ":")).encode()
        store["chillSession"] = payload
        summary = (f"{args.state} progress={progress:.2f} "
                   f"total={args.minutes:g}min")

    with open(path, "wb") as handle:
        plistlib.dump(store, handle)

    # cfprefsd caches the file; make it re-read.
    subprocess.run(["xcrun", "simctl", "spawn", args.udid,
                    "launchctl", "stop", "com.apple.cfprefsd.xpc.daemon"],
                   check=False, capture_output=True)
    print(f"{summary} -> {path}")


if __name__ == "__main__":
    main()

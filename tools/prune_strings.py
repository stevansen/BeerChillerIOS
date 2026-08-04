#!/usr/bin/env python3
"""Normalises the brand name and drops the Android-only strings.

Two clean-ups, both one-off but kept as a script so the result is reproducible
after re-running make_xcstrings.py against the Android source:

1. The German translations call the app "BierCHILLER" while every other language
   and the bundle display name say "BeerCHILLER". Standardise on BeerCHILLER.
2. Roughly a third of the imported keys describe Android concepts that do not
   exist on iOS — notification channels, Google Play in-app updates, the
   Android 14 full-screen-intent permission — or duplicate a key we already use.
   Two of them ("version_alarm", "info_text") even state "Android alarm" in
   their text, which would be plainly wrong in an iOS build.
"""
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

# Derived from this file's location, so the script works in any clone.
SOURCE_ROOT = Path(__file__).resolve().parent.parent
CATALOG = SOURCE_ROOT / "BeerChiller/Localizable.xcstrings"

# Android platform concepts with no iOS counterpart.
ANDROID_ONLY = [
    "alarm_channel_name", "alarm_channel_description",       # notification channels
    "timer_channel_name", "timer_channel_description",
    "full_screen_intent_title", "full_screen_intent_message",  # Android 14 permission
    "open_settings",
    "update_ready_title", "update_ready_message",             # Play in-app updates
    "update_restart", "update_later",
    "version_alarm", "info_text",                            # say "Android alarm"
]

# Duplicates of a key already in use, or leftovers the iOS UI never shows.
REDUNDANT = [
    "app_info_message",        # composed in SwiftUI instead
    "app_name",                # display name comes from CFBundleDisplayName
    "app_version",             # superseded by version_display
    "back",                    # NavigationStack provides the back button
    "calculated_cooling_time", # duplicate of cooling_time
    "check_inputs",            # long form; the dial uses check_inputs_short
    "current_temperature",     # long form; the dial uses current_temperature_short
    "end_time_placeholder",
    "header_subtitle",         # "Freezer timer" — the app also does fridges
    "language_system", "menu_language", "menu_temperature_unit",
    "ready", "running", "status_ready",
    "alarm_start", "stop_timer",
    "widget_open_app",
    "menu_classic_ui", "menu_beer_ui",   # replaced by style_classic / style_beer
]

REMOVE = ANDROID_ONLY + REDUNDANT

# Languages held back from the first release.
#
# Their help pages arrived from upstream fully transliterated to ASCII — a Polish
# document of 207 lines without one Polish character. Only the titles, the
# introduction and the section headings were repaired; the body text is still
# ASCII. Shipping a localization whose longest document reads as broken is worse
# for a Czech, Croatian or Polish user than shipping English, which is what the
# help viewer falls back to. iOS also advertises the language in the App Store
# listing, so a half-finished localization is a promise the app does not keep.
#
# Re-add a code here once its help page has had a native-speaker pass: drop the
# entry, restore BeerChiller/Help/cooling_model_<code>.md, add the code back to
# KNOWN_REGIONS in generate_project.py, and re-run this script.
DROPPED_LANGUAGES = ["cs", "hr", "pl"]


def swift_referenced_keys():
    """Every key the Swift sources look up, so nothing in use gets deleted."""
    keys = set()
    patterns = [
        r'LocalizedStringKey\("([a-z0-9_]+)"\)',
        r'localized\("([a-z0-9_]+)"\)',
        # The watch rows pass their key through differently named parameters;
        # without these the report calls watch_temp_start/target unused, which
        # invites someone to delete a key the UI is actually showing.
        r'(?:titleKey|shortKey|spokenKey): "([a-z0-9_]+)"',
        r'return "([a-z0-9_]+)"',
    ]
    for path in SOURCE_ROOT.rglob("*.swift"):
        if "build/" in str(path):
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in patterns:
            keys |= set(re.findall(pattern, text))
    return keys


def main():
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"),
                         object_pairs_hook=OrderedDict)
    strings = catalog["strings"]

    # --- 1. brand name ---
    renamed = 0
    for key, entry in strings.items():
        for lang, localization in entry.get("localizations", {}).items():
            unit = localization.get("stringUnit", {})
            value = unit.get("value", "")
            if "BierCHILLER" in value:
                unit["value"] = value.replace("BierCHILLER", "BeerCHILLER")
                renamed += 1

    # --- 2. prune, but never something the code still uses ---
    in_use = swift_referenced_keys()
    conflicts = sorted(set(REMOVE) & in_use)
    if conflicts:
        raise SystemExit("refusing to delete keys still referenced in Swift: "
                         + ", ".join(conflicts))

    removed, missing = [], []
    for key in REMOVE:
        if strings.pop(key, None) is not None:
            removed.append(key)
        else:
            missing.append(key)

    # --- 3. drop the languages held back from the release ---
    dropped = 0
    for entry in strings.values():
        for lang in DROPPED_LANGUAGES:
            if entry.get("localizations", {}).pop(lang, None) is not None:
                dropped += 1

    catalog["strings"] = OrderedDict(sorted(strings.items()))
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
                       encoding="utf-8")

    languages = sorted({lang for entry in catalog["strings"].values()
                        for lang in entry.get("localizations", {})})
    print(f"brand-name values rewritten : {renamed}")
    print(f"localizations dropped       : {dropped}"
          f" ({', '.join(DROPPED_LANGUAGES)})")
    print(f"languages remaining         : {len(languages)}"
          f" ({', '.join(languages)})")
    print(f"keys removed                : {len(removed)}")
    print(f"keys already absent         : {len(missing)}"
          + (f" ({', '.join(missing)})" if missing else ""))
    print(f"keys remaining              : {len(catalog['strings'])}")

    unused = sorted(set(catalog["strings"]) - in_use)
    print(f"still unused                : {len(unused)}"
          + (f" -> {', '.join(unused)}" if unused else ""))
    leftover = [k for k, v in catalog["strings"].items()
                for loc in v["localizations"].values()
                if "BierCHILLER" in loc.get("stringUnit", {}).get("value", "")]
    print(f"remaining 'BierCHILLER'     : {len(leftover)}")


if __name__ == "__main__":
    sys.exit(main())

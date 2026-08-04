#!/usr/bin/env python3
"""Convert Android string resources into an Xcode String Catalog (.xcstrings).

Usage:
    python3 make_xcstrings.py <android-res-dir> <output.xcstrings>

Reads `values/strings.xml` (base) plus every `values-<lang>/strings.xml` and
emits a String Catalog version "1.0" with sourceLanguage "en".

Conversions applied:
  * XML entities / numeric char refs are decoded by the XML parser.
  * Android backslash escapes (\\n, \\t, \\', \\", \\\\, \\@, \\?) are decoded.
  * Positional format specifiers are translated to the ObjC/Swift flavour:
        %1$s   -> %1$@      (Android String arg -> ObjC object arg)
        %1$d   -> %1$d      (unchanged)
        %1$.1f -> %1$.1f    (unchanged)
    Bare `%s` is likewise rewritten to `%@`.
Everything else is preserved byte-for-byte, including embedded newlines.
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SOURCE_LANGUAGE = "en"

# %<index>$[flags/width/precision]s  ->  ...$@
POSITIONAL_STRING_SPEC = re.compile(r"%(\d+)\$([-+ #0]*[\d.]*)s")
# bare %s (not %%s, not positional) -> %@
BARE_STRING_SPEC = re.compile(r"(?<!%)%([-+ #0]*[\d.]*)s")

# Any format specifier, for the consistency check.
ANY_SPEC = re.compile(r"%(?:(\d+)\$)?[-+ #0]*[\d.]*[@dioufeEgGxXsc%]")

# Android backslash escapes, in a single pass so that `\\n` stays literal.
ANDROID_ESCAPES = {
    "n": "\n",
    "t": "\t",
    "'": "'",
    '"': '"',
    "\\": "\\",
    "@": "@",
    "?": "?",
    " ": " ",
}
ESCAPE_RE = re.compile(r"\\(.)", re.DOTALL)


def unescape_android(text: str) -> str:
    """Decode Android's backslash escape sequences."""
    return ESCAPE_RE.sub(lambda m: ANDROID_ESCAPES.get(m.group(1), m.group(0)), text)


def convert_specifiers(text: str) -> str:
    """Translate Android string format specifiers into iOS ones."""
    text = POSITIONAL_STRING_SPEC.sub(r"%\1$\2@", text)
    return BARE_STRING_SPEC.sub(r"%\1@", text)


def parse_strings(path: Path) -> dict[str, str]:
    """Return {name: value} for every translatable <string> in an XML file."""
    root = ET.parse(path).getroot()
    out: dict[str, str] = {}
    for node in root.findall("string"):
        name = node.get("name")
        if name is None:
            continue
        if node.get("translatable") == "false":
            continue
        raw = "".join(node.itertext())
        out[name] = convert_specifiers(unescape_android(raw))
    return out


def discover(res_dir: Path) -> tuple[dict[str, str], dict[str, dict[str, str]]]:
    """Return (base strings, {lang: strings}) found under an Android res dir."""
    base_file = res_dir / "values" / "strings.xml"
    if not base_file.is_file():
        raise SystemExit(f"missing base resource file: {base_file}")
    base = parse_strings(base_file)

    langs: dict[str, dict[str, str]] = {}
    for d in sorted(res_dir.glob("values-*")):
        f = d / "strings.xml"
        if not f.is_file():
            continue
        lang = d.name[len("values-") :]
        # Android qualifier dirs may be region-tagged (values-pt-rBR) or be
        # non-locale qualifiers (values-night); keep only locale-ish ones.
        if not re.fullmatch(r"[a-z]{2,3}(-r[A-Z]{2})?", lang):
            continue
        langs[lang.replace("-r", "-")] = parse_strings(f)
    return base, langs


def build_catalog(base: dict[str, str], langs: dict[str, dict[str, str]]) -> dict:
    keys = sorted(base)
    strings: dict[str, dict] = {}
    for key in keys:
        localizations: dict[str, dict] = {}
        for lang in sorted(langs):
            value = langs[lang].get(key)
            if value is None:
                # Fall back to the base (English) resource.
                value = base.get(key)
            if value is None:
                continue
            localizations[lang] = {
                "stringUnit": {"state": "translated", "value": value}
            }
        strings[key] = {
            "extractionState": "manual",
            "localizations": localizations,
        }
    return {
        "sourceLanguage": SOURCE_LANGUAGE,
        "strings": strings,
        "version": "1.0",
    }


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    res_dir = Path(argv[1]).expanduser().resolve()
    out_path = Path(argv[2]).expanduser().resolve()

    base, langs = discover(res_dir)
    if SOURCE_LANGUAGE not in langs:
        # Guarantee an "en" localization even without a values-en dir.
        langs[SOURCE_LANGUAGE] = dict(base)

    catalog = build_catalog(base, langs)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(
        catalog, indent=2, separators=(",", " : "), ensure_ascii=False, sort_keys=True
    )
    out_path.write_text(text + "\n", encoding="utf-8")

    print(f"wrote {out_path}")
    print(f"  keys      : {len(catalog['strings'])}")
    print(f"  languages : {len(langs)} ({', '.join(sorted(langs))})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

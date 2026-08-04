#!/usr/bin/env python3
"""Audits the string catalog and the localized help pages.

Reports the things that are mechanically checkable across ten languages:
missing diacritics, format-specifier mismatches, untranslated leftovers,
leftover platform references, and length outliers that risk truncation.
Judgement calls are left to a human read-through.
"""
import json
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

# Derived from this file's location, so the script works in any clone.
ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "BeerChiller/Localizable.xcstrings"
HELP = ROOT / "BeerChiller/Help"

LANGS = ["cs", "de", "en", "es", "fr", "hr", "it", "nl", "pl", "pt"]

# Characters each language is expected to use. A file that needs them and has
# none has probably been transliterated to ASCII.
EXPECTED_DIACRITICS = {
    "cs": "áčďéěíňóřšťúůýž",
    "de": "äöüß",
    "es": "áéíóúñ¿¡",
    "fr": "àâçèéêëîïôùûü",
    "hr": "čćđšž",
    "it": "àèéìòù",
    "nl": "ëïéêáó",
    "pl": "ąćęłńóśźż",
    "pt": "ãõáâàéêíóôúç",
    "en": "",
}

# ASCII stand-ins for German umlauts. The whitelist holds words where the
# digraph is genuinely part of the spelling.
GERMAN_LEGIT = {
    "aktuelle", "aktuellen", "neue", "neuen", "neuer", "genaue", "genauen",
    "Aufbau", "Dauer", "auer", "Feuer", "heute", "Leute", "treue",
    "Steuerung", "eue",
}

PLATFORM_WORDS = ["Android", "Google", "Play Store", "Play-Store", "APK"]


def load_catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]


def specifiers(text):
    return sorted(re.findall(r"%\d+\$[@dfs]|%[@dfs]", text))


def audit_catalog(strings):
    problems = defaultdict(list)

    for key, entry in sorted(strings.items()):
        locs = entry.get("localizations", {})
        values = {lang: locs.get(lang, {}).get("stringUnit", {}).get("value")
                  for lang in LANGS}

        missing = [l for l, v in values.items() if v is None]
        if missing:
            problems["missing language"].append(f"{key}: {missing}")

        # Format specifiers must match across every language or the app crashes.
        reference = specifiers(values["en"] or "")
        for lang, value in values.items():
            if value is None:
                continue
            if specifiers(value) != reference:
                problems["specifier mismatch"].append(
                    f"{key} [{lang}]: {specifiers(value)} vs en {reference}")

        # Untranslated: identical to English while English has real words.
        english = (values["en"] or "").strip()
        if len(english.split()) >= 2:
            for lang, value in values.items():
                if lang == "en" or value is None:
                    continue
                if value.strip() == english:
                    problems["identical to English"].append(f"{key} [{lang}]: {value!r}")

        # Leftover platform references.
        for lang, value in values.items():
            if value is None:
                continue
            for word in PLATFORM_WORDS:
                if word.lower() in value.lower():
                    problems["platform reference"].append(
                        f"{key} [{lang}]: {value!r}")

        # Length outliers: a control label three times the English width is a
        # truncation risk in segmented controls and menus.
        if english and len(english) >= 3:
            for lang, value in values.items():
                if value is None or lang == "en":
                    continue
                if len(value) > max(3 * len(english), len(english) + 18):
                    problems["much longer than English"].append(
                        f"{key} [{lang}]: {len(value)} vs {len(english)} chars: {value!r}")

    return problems


def audit_diacritics(strings):
    """Per language: do the translations use the script's own characters?"""
    report = {}
    for lang in LANGS:
        expected = EXPECTED_DIACRITICS[lang]
        if not expected:
            continue
        text = " ".join(
            entry["localizations"].get(lang, {}).get("stringUnit", {}).get("value", "")
            for entry in strings.values())
        used = {c for c in text.lower() if c in expected}
        report[lang] = (len(used), len(expected), "".join(sorted(used)))
    return report


def audit_help():
    problems = defaultdict(list)
    for path in sorted(HELP.glob("cooling_model_*.md")):
        lang = path.stem.split("_")[-1]
        text = path.read_text(encoding="utf-8")

        # German ASCII transliterations.
        if lang == "de":
            for word in re.findall(r"\b\w*(?:ae|oe|ue)\w*\b", text):
                if word not in GERMAN_LEGIT:
                    problems[f"{lang}: umlaut written as digraph"].append(word)

        # Any language: expected diacritics entirely absent from a long document.
        expected = EXPECTED_DIACRITICS.get(lang, "")
        if expected:
            used = {c for c in text.lower() if c in expected}
            if len(used) < 2:
                problems[f"{lang}: looks transliterated"].append(
                    f"only {sorted(used)} of {expected} present")

        # Portuguese/Spanish cedilla and tilde often lost in transliteration.
        if lang == "pt":
            for word in re.findall(r"\b\w*(?:coes|cao|acao)\b", text):
                problems[f"{lang}: missing tilde/cedilla"].append(word)

        for word in PLATFORM_WORDS:
            if word.lower() in text.lower():
                problems[f"{lang}: platform reference"].append(word)

        # Structure: every file should have the same number of formulas so no
        # translation silently dropped one.
        problems["_structure"].append(
            f"{lang}: {text.count(chr(92) + '[')} display formulas, "
            f"{len(text.splitlines())} lines")

    return problems


def main():
    strings = load_catalog()
    print(f"catalog: {len(strings)} keys x {len(LANGS)} languages\n")

    print("=" * 72)
    print("CATALOG PROBLEMS")
    print("=" * 72)
    problems = audit_catalog(strings)
    if not problems:
        print("none")
    for kind, items in sorted(problems.items()):
        print(f"\n[{kind}] {len(items)}")
        for item in items[:25]:
            print("   ", item)

    print()
    print("=" * 72)
    print("DIACRITIC COVERAGE IN THE CATALOG")
    print("=" * 72)
    for lang, (used, total, chars) in sorted(audit_diacritics(strings).items()):
        flag = "  <-- suspicious" if used == 0 else ""
        print(f"  {lang}: {used}/{total} distinct expected chars used [{chars}]{flag}")

    print()
    print("=" * 72)
    print("HELP PAGES")
    print("=" * 72)
    help_problems = audit_help()
    for kind in sorted(help_problems):
        items = help_problems[kind]
        if kind == "_structure":
            continue
        uniq = sorted(set(items))
        print(f"\n[{kind}] {len(items)} occurrences, {len(uniq)} distinct")
        print("   ", ", ".join(uniq[:20]))
    print("\n[structure]")
    for line in help_problems["_structure"]:
        print("   ", line)


if __name__ == "__main__":
    sys.exit(main())

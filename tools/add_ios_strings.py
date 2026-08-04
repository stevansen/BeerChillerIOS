#!/usr/bin/env python3
"""Adds the iOS-only strings to Localizable.xcstrings.

The Android app has no light/dark override and no in-app pointer to the system
language screen, so these keys have no counterpart in values-*/strings.xml.
Idempotent: re-running only fills in what is missing.
"""
import json
import sys
from collections import OrderedDict
from pathlib import Path

LANGS = ["de", "en", "es", "fr", "it", "nl", "pt"]

NEW = {
    "appearance_title": {
        "de": "Erscheinungsbild", "en": "Appearance",
        "es": "Apariencia", "fr": "Apparence", "it": "Aspetto", "nl": "Weergave", "pt": "Aparência",
    },
    "appearance_system": {
        "de": "Systemeinstellung", "en": "System setting",
        "es": "Ajuste del sistema", "fr": "Réglage système", "it": "Impostazione di sistema", "nl": "Systeeminstelling",
        "pt": "Definição do sistema",
    },
    "appearance_light": {
        "de": "Hell", "en": "Light", "es": "Claro",
        "fr": "Clair", "it": "Chiaro", "nl": "Licht",
        "pt": "Claro",
    },
    "appearance_dark": {
        "de": "Dunkel", "en": "Dark", "es": "Oscuro",
        "fr": "Sombre", "it": "Scuro", "nl": "Donker",
        "pt": "Escuro",
    },
    "language_footer": {
        "de": "Die App-Sprache wird in den Systemeinstellungen gewählt.",
        "en": "Choose the app language in the system settings.",
        "es": "Elige el idioma de la app en los ajustes del sistema.",
        "fr": "Choisissez la langue de l’app dans les réglages du système.",
        "it": "Scegli la lingua dell’app nelle impostazioni di sistema.",
        "nl": "Kies de taal van de app in de systeeminstellingen.",
        "pt": "Escolha o idioma da app nas definições do sistema.",
    },
    # Watch-specific: the phone UI has room for the full label, the watch does not.
    "watch_start": {
        "de": "Start", "en": "Start", "es": "Iniciar",
        "fr": "Démarrer", "it": "Avvia", "nl": "Start",
        "pt": "Iniciar",
    },
    # The Android UI labels these groups only by their options (segmented
    # controls), so there are no source strings for the row titles the watch's
    # list-style pickers need.
    "picker_container": {
        "de": "Gebinde", "en": "Container", "es": "Envase",
        "fr": "Récipient", "it": "Contenitore",
        "nl": "Verpakking", "pt": "Recipiente",
    },
    "picker_appliance": {
        "de": "Gerät", "en": "Appliance", "es": "Aparato",
        "fr": "Appareil", "it": "Apparecchio",
        "nl": "Apparaat", "pt": "Aparelho",
    },
    # The Android labels are "Classic UI" / "Beer UI". Inside a menu section
    # already titled "Appearance", the "UI" is both redundant and jargon that
    # Apple's own UI never uses, so the styles get plain names.
    "style_classic": {
        "de": "Klassisch", "en": "Classic", "es": "Clásico",
        "fr": "Classique", "it": "Classico",
        "nl": "Klassiek", "pt": "Clássico",
    },
    "style_beer": {
        "de": "Bier", "en": "Beer", "es": "Cerveza",
        "fr": "Bière", "it": "Birra", "nl": "Bier",
        "pt": "Cerveja",
    },
    # Spoken forms so VoiceOver reads a formula as words instead of spelling out
    # symbols. Padded with spaces because they are concatenated into a sentence.
    "math_to_the_power_of": {
        "de": " hoch ", "en": " to the power of ",
        "es": " elevado a ", "fr": " puissance ", "it": " elevato a ", "nl": " tot de macht ", "pt": " elevado a ",
    },
    "math_sub": {
        "de": "Index", "en": "sub", "es": "índice",
        "fr": "indice", "it": "indice", "nl": "index",
        "pt": "índice",
    },
    "math_divided_by": {
        "de": " geteilt durch ", "en": " divided by ",
        "es": " dividido por ", "fr": " divisé par ", "it": " diviso ", "nl": " gedeeld door ", "pt": " dividido por ",
    },
    # "bottle size" is wrong as soon as a can is selected, which is plainly
    # visible on the watch where the label sits next to the value.
    "picker_volume": {
        "de": "Volumen", "en": "Volume", "es": "Volumen",
        "fr": "Volume", "it": "Volume", "nl": "Volume",
        "pt": "Volume",
    },
    # VoiceOver hint for the watch rows that cycle their value on tap.
    "watch_toggle_hint": {
        "de": "Zum Wechseln doppeltippen",
        "en": "Double tap to change", "es": "Toca dos veces para cambiar",
        "fr": "Touchez deux fois pour changer", "it": "Tocca due volte per cambiare", "nl": "Dubbeltik om te wijzigen",
        "pt": "Toque duas vezes para alterar",
    },
    # Short forms for the watch temperature rows. The full compounds
    # ("Gerätetemperatur", "Apparaattemperatuur") truncate next to the ± buttons,
    # and beside a value of "22 °C" the word "temperature" is redundant anyway.
    "watch_temp_start": {
        "de": "Start", "en": "Start", "es": "Inicial",
        "fr": "Initiale", "it": "Iniziale", "nl": "Start",
        "pt": "Inicial",
    },
    "watch_temp_target": {
        "de": "Ziel", "en": "Target", "es": "Objetivo",
        "fr": "Cible", "it": "Obiettivo", "nl": "Doel",
        "pt": "Objetivo",
    },
    "picker_position": {
        "de": "Lage", "en": "Position", "es": "Posición",
        "fr": "Position", "it": "Posizione",
        "nl": "Positie", "pt": "Posição",
    },
}


def main(path):
    with open(path, encoding="utf-8") as handle:
        catalog = json.load(handle, object_pairs_hook=OrderedDict)

    added = []
    for key, translations in NEW.items():
        missing = [lang for lang in LANGS if lang not in translations]
        if missing:
            raise SystemExit(f"{key}: missing translations for {missing}")
        if key in catalog["strings"]:
            continue
        catalog["strings"][key] = OrderedDict([
            ("extractionState", "manual"),
            ("localizations", OrderedDict(
                (lang, {"stringUnit": {"state": "translated", "value": translations[lang]}})
                for lang in sorted(LANGS)
            )),
        ])
        added.append(key)

    catalog["strings"] = OrderedDict(sorted(catalog["strings"].items()))

    with open(path, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    print(f"added {len(added)}: {', '.join(added) if added else '(nothing new)'}")
    print(f"total keys: {len(catalog['strings'])}")
    counts = {len(v["localizations"]) for v in catalog["strings"].values()}
    print(f"localizations per key: {sorted(counts)}")


if __name__ == "__main__":
    default = Path(__file__).resolve().parent.parent / "BeerChiller/Localizable.xcstrings"
    main(sys.argv[1] if len(sys.argv) > 1 else default)

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

LANGS = ["cs", "de", "en", "es", "fr", "hr", "it", "nl", "pl", "pt"]

NEW = {
    "appearance_title": {
        "cs": "Vzhled", "de": "Erscheinungsbild", "en": "Appearance",
        "es": "Apariencia", "fr": "Apparence", "hr": "Izgled",
        "it": "Aspetto", "nl": "Weergave", "pl": "Wygląd", "pt": "Aparência",
    },
    "appearance_system": {
        "cs": "Nastavení systému", "de": "Systemeinstellung", "en": "System setting",
        "es": "Ajuste del sistema", "fr": "Réglage système", "hr": "Postavka sustava",
        "it": "Impostazione di sistema", "nl": "Systeeminstelling",
        "pl": "Ustawienie systemowe", "pt": "Definição do sistema",
    },
    "appearance_light": {
        "cs": "Světlý", "de": "Hell", "en": "Light", "es": "Claro",
        "fr": "Clair", "hr": "Svijetlo", "it": "Chiaro", "nl": "Licht",
        "pl": "Jasny", "pt": "Claro",
    },
    "appearance_dark": {
        "cs": "Tmavý", "de": "Dunkel", "en": "Dark", "es": "Oscuro",
        "fr": "Sombre", "hr": "Tamno", "it": "Scuro", "nl": "Donker",
        "pl": "Ciemny", "pt": "Escuro",
    },
    "language_footer": {
        "cs": "Jazyk aplikace vyberte v nastavení systému.",
        "de": "Die App-Sprache wird in den Systemeinstellungen gewählt.",
        "en": "Choose the app language in the system settings.",
        "es": "Elige el idioma de la app en los ajustes del sistema.",
        "fr": "Choisissez la langue de l’app dans les réglages du système.",
        "hr": "Jezik aplikacije odaberite u postavkama sustava.",
        "it": "Scegli la lingua dell’app nelle impostazioni di sistema.",
        "nl": "Kies de taal van de app in de systeeminstellingen.",
        "pl": "Wybierz język aplikacji w ustawieniach systemu.",
        "pt": "Escolha o idioma da app nas definições do sistema.",
    },
    # Watch-specific: the phone UI has room for the full label, the watch does not.
    "watch_start": {
        "cs": "Start", "de": "Start", "en": "Start", "es": "Iniciar",
        "fr": "Démarrer", "hr": "Start", "it": "Avvia", "nl": "Start",
        "pl": "Start", "pt": "Iniciar",
    },
    # The Android UI labels these groups only by their options (segmented
    # controls), so there are no source strings for the row titles the watch's
    # list-style pickers need.
    "picker_container": {
        "cs": "Obal", "de": "Gebinde", "en": "Container", "es": "Envase",
        "fr": "Récipient", "hr": "Ambalaža", "it": "Contenitore",
        "nl": "Verpakking", "pl": "Opakowanie", "pt": "Recipiente",
    },
    "picker_appliance": {
        "cs": "Zařízení", "de": "Gerät", "en": "Appliance", "es": "Aparato",
        "fr": "Appareil", "hr": "Uređaj", "it": "Apparecchio",
        "nl": "Apparaat", "pl": "Urządzenie", "pt": "Aparelho",
    },
    # The Android labels are "Classic UI" / "Beer UI". Inside a menu section
    # already titled "Appearance", the "UI" is both redundant and jargon that
    # Apple's own UI never uses, so the styles get plain names.
    "style_classic": {
        "cs": "Klasický", "de": "Klassisch", "en": "Classic", "es": "Clásico",
        "fr": "Classique", "hr": "Klasično", "it": "Classico",
        "nl": "Klassiek", "pl": "Klasyczny", "pt": "Clássico",
    },
    "style_beer": {
        "cs": "Pivo", "de": "Bier", "en": "Beer", "es": "Cerveza",
        "fr": "Bière", "hr": "Pivo", "it": "Birra", "nl": "Bier",
        "pl": "Piwo", "pt": "Cerveja",
    },
    # Spoken forms so VoiceOver reads a formula as words instead of spelling out
    # symbols. Padded with spaces because they are concatenated into a sentence.
    "math_to_the_power_of": {
        "cs": " na ", "de": " hoch ", "en": " to the power of ",
        "es": " elevado a ", "fr": " puissance ", "hr": " na ",
        "it": " elevato a ", "nl": " tot de macht ", "pl": " do potęgi ",
        "pt": " elevado a ",
    },
    "math_sub": {
        "cs": "index", "de": "Index", "en": "sub", "es": "índice",
        "fr": "indice", "hr": "indeks", "it": "indice", "nl": "index",
        "pl": "indeks", "pt": "índice",
    },
    "math_divided_by": {
        "cs": " děleno ", "de": " geteilt durch ", "en": " divided by ",
        "es": " dividido por ", "fr": " divisé par ", "hr": " podijeljeno s ",
        "it": " diviso ", "nl": " gedeeld door ", "pl": " podzielone przez ",
        "pt": " dividido por ",
    },
    # "bottle size" is wrong as soon as a can is selected, which is plainly
    # visible on the watch where the label sits next to the value.
    "picker_volume": {
        "cs": "Objem", "de": "Volumen", "en": "Volume", "es": "Volumen",
        "fr": "Volume", "hr": "Volumen", "it": "Volume", "nl": "Volume",
        "pl": "Objętość", "pt": "Volume",
    },
    # VoiceOver hint for the watch rows that cycle their value on tap.
    "watch_toggle_hint": {
        "cs": "Dvojitým tapnutím změníte", "de": "Zum Wechseln doppeltippen",
        "en": "Double tap to change", "es": "Toca dos veces para cambiar",
        "fr": "Touchez deux fois pour changer", "hr": "Dvaput dodirnite za promjenu",
        "it": "Tocca due volte per cambiare", "nl": "Dubbeltik om te wijzigen",
        "pl": "Dotknij dwukrotnie, aby zmienić", "pt": "Toque duas vezes para alterar",
    },
    # Short forms for the watch temperature rows. The full compounds
    # ("Gerätetemperatur", "Apparaattemperatuur") truncate next to the ± buttons,
    # and beside a value of "22 °C" the word "temperature" is redundant anyway.
    "watch_temp_start": {
        "cs": "Start", "de": "Start", "en": "Start", "es": "Inicial",
        "fr": "Initiale", "hr": "Start", "it": "Iniziale", "nl": "Start",
        "pl": "Start", "pt": "Inicial",
    },
    "watch_temp_target": {
        "cs": "Cíl", "de": "Ziel", "en": "Target", "es": "Objetivo",
        "fr": "Cible", "hr": "Cilj", "it": "Obiettivo", "nl": "Doel",
        "pl": "Cel", "pt": "Objetivo",
    },
    "picker_position": {
        "cs": "Poloha", "de": "Lage", "en": "Position", "es": "Posición",
        "fr": "Position", "hr": "Položaj", "it": "Posizione",
        "nl": "Positie", "pl": "Pozycja", "pt": "Posição",
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

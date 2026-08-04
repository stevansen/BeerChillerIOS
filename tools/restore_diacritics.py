#!/usr/bin/env python3
"""Restores diacritics in the headings and the introduction of the Czech,
Croatian and Polish help pages.

Those three documents arrived from upstream fully transliterated to ASCII — a
Polish text of 207 lines with not one Polish character. Restoring all of it means
rewriting ~260 distinct words per language, which is more machine translation than
proof-reading. This script therefore fixes only the most visible surface: the
document title, the two introductory paragraphs and the twelve section headings.
The body paragraphs are deliberately left as upstream wrote them.

Every replacement is a whole line and must match exactly once, so a change in the
upstream text turns into a loud failure rather than a silent no-op.
"""
import sys
from pathlib import Path

HELP = Path("/Users/shell/BeerChilleriOS/BeerChiller/Help")

FIXES = {
    "cs": [
        ("# Vypocetni model",
         "# Výpočetní model"),
        ("Aplikace pocita dobu chlazeni piva v lednici nebo mrazaku pomoci modelu **BeerCHILLER Calibrated V2**.",
         "Aplikace počítá dobu chlazení piva v lednici nebo mrazáku pomocí modelu **BeerCHILLER Calibrated V2**."),
        ("Model je prakticke priblizeni. Pouziva pocatecni teplotu, cilovou teplotu, teplotu zarizeni, obal, objem a polohu. Skutecne spotrebice mohou chladit rychleji nebo pomaleji kvuli proudění vzduchu, kontaktnim plocham, naplneni a otevirani dveri.",
         "Model je praktické přiblížení. Používá počáteční teplotu, cílovou teplotu, teplotu zařízení, obal, objem a polohu. Skutečné spotřebiče mohou chladit rychleji nebo pomaleji kvůli proudění vzduchu, kontaktním plochám, naplnění a otevírání dveří."),
        ("## 1. Teplotni rozdil",
         "## 1. Teplotní rozdíl"),
        ("## 2. Teplotne zavisly prenos tepla",
         "## 2. Teplotně závislý přenos tepla"),
        ("## 3. Casovy vzorec",
         "## 3. Časový vzorec"),
        ("## 4. Konecny vzorec aplikace",
         "## 4. Konečný vzorec aplikace"),
        ("## 6. Korekce studeneho startu pro sklenene lahve v mrazaku",
         "## 6. Korekce studeného startu pro skleněné lahve v mrazáku"),
        ("## 7. Teplota behem timeru",
         "## 7. Teplota během timeru"),
        ("## 10. Omezeni modelu",
         "## 10. Omezení modelu"),
        ("## Priklad",
         "## Příklad"),
    ],
    "hr": [
        ("# Model izracuna",
         "# Model izračuna"),
        ("Aplikacija izracunava vrijeme hladenja piva u hladnjaku ili zamrzivacu pomocu modela **BeerCHILLER Calibrated V2**.",
         "Aplikacija izračunava vrijeme hlađenja piva u hladnjaku ili zamrzivaču pomoću modela **BeerCHILLER Calibrated V2**."),
        ("Model je prakticna aproksimacija. Koristi pocetnu temperaturu, ciljnu temperaturu, temperaturu uredaja, ambalazu, volumen i polozaj. U stvarnim uvjetima uredaji mogu hladiti brze ili sporije zbog protoka zraka, kontaktnih povrsina, napunjenosti i otvaranja vrata.",
         "Model je praktična aproksimacija. Koristi početnu temperaturu, ciljnu temperaturu, temperaturu uređaja, ambalažu, volumen i položaj. U stvarnim uvjetima uređaji mogu hladiti brže ili sporije zbog protoka zraka, kontaktnih površina, napunjenosti i otvaranja vrata."),
        ("## 4. Konacna formula aplikacije",
         "## 4. Konačna formula aplikacije"),
        ("## 6. Korekcija hladnog starta za staklene boce u zamrzivacu",
         "## 6. Korekcija hladnog starta za staklene boce u zamrzivaču"),
        ("## 10. Ogranicenja modela",
         "## 10. Ograničenja modela"),
    ],
    "pl": [
        ("Aplikacja oblicza czas chlodzenia piwa w lodowce lub zamrazarce za pomoca modelu **BeerCHILLER Calibrated V2**.",
         "Aplikacja oblicza czas chłodzenia piwa w lodówce lub zamrażarce za pomocą modelu **BeerCHILLER Calibrated V2**."),
        ("Model jest praktycznym przyblizeniem. Uwzglednia temperature poczatkowa, temperature docelowa, temperature urzadzenia, pojemnik, objetosc i polozenie. W praktyce urzadzenia moga chlodzic szybciej lub wolniej z powodu przeplywu powietrza, powierzchni kontaktu, zaladowania i otwierania drzwi.",
         "Model jest praktycznym przybliżeniem. Uwzględnia temperaturę początkową, temperaturę docelową, temperaturę urządzenia, pojemnik, objętość i położenie. W praktyce urządzenia mogą chłodzić szybciej lub wolniej z powodu przepływu powietrza, powierzchni kontaktu, załadowania i otwierania drzwi."),
        ("## 1. Roznica temperatur",
         "## 1. Różnica temperatur"),
        ("## 2. Przenoszenie ciepla zalezne od temperatury",
         "## 2. Przenoszenie ciepła zależne od temperatury"),
        ("## 3. Wzor czasu",
         "## 3. Wzór czasu"),
        ("## 4. Koncowy wzor aplikacji",
         "## 4. Końcowy wzór aplikacji"),
        ("## 5. Stale",
         "## 5. Stałe"),
        ("## 6. Korekta zimnego startu dla szklanych butelek w zamrazarce",
         "## 6. Korekta zimnego startu dla szklanych butelek w zamrażarce"),
        ("## 8. Reguly poprawnosci",
         "## 8. Reguły poprawności"),
        ("## Przyklad",
         "## Przykład"),
    ],
}


def main():
    total = 0
    for lang, replacements in FIXES.items():
        path = HELP / f"cooling_model_{lang}.md"
        text = path.read_text(encoding="utf-8")
        before = len([c for c in text if ord(c) > 127 and c.isalpha()])

        for old, new in replacements:
            count = text.count(old)
            if count != 1:
                raise SystemExit(
                    f"{lang}: expected exactly one match, found {count}:\n  {old[:80]}")
            text = text.replace(old, new)

        path.write_text(text, encoding="utf-8")
        after = len([c for c in text if ord(c) > 127 and c.isalpha()])
        total += len(replacements)
        print(f"{lang}: {len(replacements)} lines fixed, "
              f"accented letters {before} -> {after}")

    print(f"\n{total} lines rewritten in total")
    print("Body paragraphs are still transliterated — see README, "
          "'Known limitations'.")


if __name__ == "__main__":
    sys.exit(main())

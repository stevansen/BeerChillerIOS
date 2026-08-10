# Prompt: revise the App Store texts

Paste the block below into a fresh session at `/Users/shell/BeerChilleriOS`. The
rest of this file is the reference the prompt points at — read it if something is
unclear, but the prompt alone should be enough.

---

## The prompt

> Überarbeite die App-Store-Texte von BeerCHILLER.
>
> **Zeig mir jede Änderung vollständig, bevor du irgendetwas veröffentlichst, und
> warte auf mein OK.** Zeig alt und neu nebeneinander, mit Zeichenzahl gegen
> Apples Grenze.
>
> Die Sprachen dürfen voneinander abweichen — es sind Lokalisierungen, keine
> Übersetzungen. Was im Deutschen gut klingt, muss im Italienischen nicht Wort
> für Wort so stehen. Gleich bleiben müssen nur die Aussagen: keine Sprache darf
> etwas versprechen, das eine andere nicht verspricht oder die App nicht hält.
>
> Halte dich an `AppStore/REVISE-TEXTS.md`: Feldgrenzen, was gerade überhaupt
> änderbar ist, die Vorgaben aus zwei App-Review-Ablehnungen, und wie
> veröffentlicht und nachgeprüft wird.
>
> [hier sagen, was du willst — z. B. „mach die Beschreibungen kürzer",
>  „en und it neu, de behalten", „nur den Werbetext, spielerischer"]

---

## What can be changed, and when

Measured against the live app, not assumed — a PATCH with the value unchanged
either succeeds or names the field it refuses:

| Field | On a released version | Needs a new version |
|---|---|---|
| `promotionalText` | **editable, takes effect at once** | no |
| `description` | blocked | yes |
| `keywords` | blocked | yes |
| `supportUrl`, `marketingUrl` | blocked | yes |
| `subtitle`, `name` (on `appInfo`) | blocked | yes |
| `whatsNew` | n/a on a first release | set it on the update |

So: **the promotional text is the only lever on a live release.** It is also the
line most people actually read — it sits above the description, before the *more*
fold. Spend it on why someone should care, not on how the app works.

Everything else waits for the next version. Prepare it in the repo, publish it
when that version is editable.

Re-run the probe if in doubt:

```bash
export ASC_KEY_ID=… ASC_ISSUER_ID=…
python3 - <<'EOF'
import sys; sys.path.insert(0, "tools")
from asc import get, request
V = "a0665d57-2308-4c01-8c83-d527d2d6f7fb"
l = [x for x in get(f"/appStoreVersions/{V}/appStoreVersionLocalizations",
                    **{"limit": 50})["data"] if x["attributes"]["locale"] == "en-US"][0]
for field in ("promotionalText", "description", "keywords"):
    try:
        request("PATCH", f"/appStoreVersionLocalizations/{l['id']}",
                {"data": {"id": l["id"], "type": "appStoreVersionLocalizations",
                          "attributes": {field: l["attributes"][field]}}})
        print(f"{field}: editable")
    except SystemExit as e:
        print(f"{field}: blocked")
EOF
```

## Limits

| Field | Maximum |
|---|---|
| name | 30 |
| subtitle | 30 |
| promotional text | 170 |
| keywords | 100 total, comma-separated, **no space after the comma** |
| description | 4000 |

`tools/make_appstore_metadata.py` enforces these and exits non-zero on a
violation. It has caught a French promotional text at 188. Never hand-edit the
files under `AppStore/metadata/` — they are generated; edit the script.

## Languages

Shipped: **de-DE, en-US, es-ES, fr-FR, it, nl-NL, pt-PT.** Note Apple's codes —
Italian is `it`, not `it-IT`.

German, English and Italian are original copy. Spanish, French, Dutch and
Portuguese have never had a native-speaker pass; the README says so under *Known
limitations*. Treat a rewrite of those four as new machine translation unless a
native speaker is involved — and say so rather than implying they were reviewed.

Divergence between languages is fine and often better. The German promotional
text opens with a question and reads naturally; the English and Italian ones open
with a scene because the same question read stiff in translation. What must not
diverge is the substance.

## Rules learned from two rejections

**No references to other platforms** — guideline 2.3.10. The descriptions once
closed with "a port of the Android app by C. Auer" and were rejected. So was the
support URL's target: the repository README used to lead with the same sentence.
After editing, check the whole directory, not the file you touched:

```bash
grep -rniE "android|google|play store|windows|samsung|huawei" AppStore/metadata/
```

**Keep the attribution to C. Auer.** The design is licensed CC BY 4.0 and
attribution is a licence condition, not a courtesy. Remove the platform, never
the credit.

**Rate for the highest level of content** — guideline 2.3.6. Unrelated to the
texts, but the same instinct applies to copy: do not soften what the app is.

**Do not over-claim the alarm.** It rings through the silent switch from the
app's own sound, and through Focus on iOS 26.1 and later via AlarmKit — but a
background notification on older versions is silenced like any other. "Rings even
when your phone is silent" is therefore true for some users and not others. Say
"raises an alarm" and leave it there.

## Publishing

Credentials come from the environment; the `.p8` lives in
`~/.appstoreconnect/private_keys/` and is never printed.

```bash
export ASC_KEY_ID=… ASC_ISSUER_ID=…
python3 tools/make_appstore_metadata.py    # regenerate + check the limits
```

Then push the changed fields with `tools/asc.py`. For the promotional text:

```python
import sys; sys.path.insert(0, "tools")
from asc import get, request
V = "a0665d57-2308-4c01-8c83-d527d2d6f7fb"
locs = {l["attributes"]["locale"]: l["id"]
        for l in get(f"/appStoreVersions/{V}/appStoreVersionLocalizations",
                     **{"limit": 50})["data"]}
request("PATCH", f"/appStoreVersionLocalizations/{locs['en-US']}",
        {"data": {"id": locs["en-US"], "type": "appStoreVersionLocalizations",
                  "attributes": {"promotionalText": "…"}}})
```

**Read it back from Apple afterwards.** A successful PATCH is not proof the value
landed as intended — assets have failed asynchronously here before. Print what
the API returns, not what was sent.

Then commit the generator and the regenerated files, and say in the message what
changed and why.

## Identifiers

| | |
|---|---|
| App | `6798018586` — `com.bierchiller.app` |
| iOS version 1.0 | `a0665d57-2308-4c01-8c83-d527d2d6f7fb` |
| appInfo (name, subtitle, privacy URL) | `3f9a9539-93a8-4a3a-a4a9-a99218f595e4` |

`tools/asc.py` reads the app id from `ASC_APP_ID`, defaulting to the above. The
version and appInfo ids change when a new version is created — look them up
rather than trusting these:

```python
get(f"/apps/{APP_ID}/appStoreVersions", **{"limit": 5})
get(f"/apps/{APP_ID}/appInfos")
```

# BeerCHILLER for iOS

A native iOS/watchOS port of the Android app
[cauer71/BeerCHILLER](https://github.com/cauer71/BeerCHILLER) — it estimates how
long a bottle or can of beer needs in the fridge or freezer and alerts you when
the target temperature is reached.

## Requirements

* Xcode 26 (built and tested with 26.6)
* iOS 16.0 or later, watchOS 9.0 or later
* No third-party dependencies

## Project layout

The Xcode project is **generated** — there is no `xcodegen` or `xcodeproj` gem on
the target machine, so `tools/generate_project.py` emits `project.pbxproj`
directly. Regenerate after adding or moving files:

```bash
python3 tools/generate_project.py
```

| Target | Product | Notes |
|---|---|---|
| `BeerCHILLER` | iOS app | `com.bierchiller.app`, iOS 16.0, iPhone + iPad |
| `BeerCHILLERWidget` | widget extension | home screen, lock screen, Live Activity |
| `BeerCHILLERWatch` | watchOS app | standalone, embedded in the iOS app |
| `BeerCHILLERWatchWidget` | watch extension | face complications |
| `BeerCHILLERTests` | unit tests | model + widget timeline |
| `BeerCHILLERUITests` | UI tests | orientation, Dynamic Type, VoiceOver labels |

`Shared/` is compiled into every target — there is no framework, just shared
sources, which keeps the generated project simple.

Pass `--no-watch-embed` to the generator to build the iPhone app on a machine
without a watchOS **simulator runtime** installed. With the watch app embedded,
`xcodebuild` refuses to build for the iOS simulator unless the matching watchOS
runtime is present (`xcodebuild -downloadPlatform watchOS`).

## The cooling model

`Shared/CoolingModel.swift` is a 1:1 port of the *BeerChiller Calibrated V2*
model from `MainActivity.java`. Beer and container are treated as one lumped
system, the appliance air as a constant-temperature reservoir, and cooling slows
as the beer approaches that temperature:

```
Δ₀ = T₀ − T_D                        starting temperature difference
θ  = (T_Z − T_D) / (T₀ − T_D)        dimensionless target ratio

t  = τ₀ · f_D · f_P · (25/Δ₀)^n · f_cold · ((θ^−n − 1) / n)      n = 0.15

θ(t) = (1 + n · t/τ_eff)^(−1/n)      live progress curve
T(t) = T_D + (T₀ − T_D) · θ(t)
```

| Container | τ₀ | | Appliance | f_D | | Position | Bottle | Can |
|---|---:|---|---|---:|---|---|---:|---:|
| Bottle 0.33 l | 87 min | | Fridge | 1.00 | | Standing | 1.00 | 1.00 |
| Bottle 0.5 l | 110 min | | Freezer | 0.84 | | Lying | 0.95 | 0.92 |
| Bottle 1.0 l | 155 min | | | | | | | |
| Can 0.33 l | 85 min | | | | | | | |
| Can 0.5 l | 105 min | | | | | | | |

**`f_cold` is not in the upstream README but is in the shipped code.** The Java
implementation applies a freezer cold-start correction
(`MainActivity.coldBottleFreezerStartFactor`, line 1664 ff.) that ramps
smoothly from 1.0 at 24 °C to 1.70 at 16 °C and below, for bottles in the
freezer only. Its own unit test pins it, so the implementation — not the
README — was treated as authoritative and the factor is ported.

A 1.0 l can has no calibration and is reported invalid, exactly as upstream.

### Parity

`Tests/CoolingModelTests.swift` reproduces every expectation from the Android
unit tests verbatim (`ContainerCoolingModelTest`, `OrientationFactorTest`,
`TemperaturePreferenceDefaultsTest`), so the port cannot drift: 136 / 174 / 239
minutes for the fridge calibration, 62 for the freezer, the cold-start cases,
the 0.5 l example at 288, plus the invalid-input cases.

## Deliberate deviations from the Android app

1. **The running timer snapshots its inputs.** Android re-reads the *current*
   preferences when estimating the live beer temperature, so moving a slider
   mid-run distorts a running estimate. `ChillSession` stores the values the run
   was started with.
2. **No in-app language picker.** On iOS the per-app language lives in
   Settings → BeerCHILLER → Language; Settings deep-links there instead of
   duplicating it.
3. **Help page rendered natively.** Android ships KaTeX plus a WebView to render
   the formulas. `HelpView` typesets them with SwiftUI instead (see *Formula
   typesetting* below) — no WebView, works offline, scales with Dynamic Type and
   is readable by VoiceOver. The localized markdown itself is carried over
   unchanged.
4. **Beer style in widgets uses a gradient, not the photo.** Widget processes
   have a tight memory budget and a full-bleed photo buys nothing at that size.
5. **One brand mark for both visual styles.** Android switches between a
   snowflake (Classic) and a hops leaf (Beer); `BrandMark` is used in both and
   only recolours.
6. **"BeerCHILLER" in German too.** The Android German translation calls the app
   "BierCHILLER" while every other language and the bundle display name say
   "BeerCHILLER". Standardised on BeerCHILLER (`tools/prune_strings.py`). The
   bundle identifier stays `com.bierchiller.app` — renaming it would orphan
   existing installs.
7. **The visual styles are named "Classic" / "Beer", not "Classic UI" / "Beer
   UI".** Inside a menu group about appearance the "UI" is both redundant and
   jargon Apple's own interfaces avoid. New keys `style_classic` / `style_beer`.
8. **Android-only strings removed.** 33 of the 95 imported keys described
   concepts iOS does not have — notification channels, Google Play in-app
   updates, the Android 14 full-screen-intent permission — or duplicated a key
   already in use. Two of them (`version_alarm`, `info_text`) literally read
   "Android alarm", which would have been wrong in an iOS build. 62 keys remain
   and none is unused.

## Landscape

iPhone landscape is only ~400 pt tall, and the first version put the controls in a
scroll view — which pushed the appliance temperature *and* the start button below
the fold. You had to scroll to start a timer. The current arrangement fits
everything on screen:

* a trimmed header (smaller mark and wordmark)
* the dial at 30 % of the width on iPhone, 38 % on iPad
* the three temperature controls in a compact form, label directly above its
  stepper, sharing one row — with 44 pt hit targets kept intact
* `ViewThatFits` falls back to scrolling only at the largest accessibility text
  sizes, and the action buttons refuse vertical compression so that fallback
  actually triggers instead of the buttons silently clipping their labels

The full portrait temperature rows were tried on iPad and rejected: in a column
that wide the label ends up ~300 pt from its stepper and stops reading as one
control. iPad gets a larger dial and a width-capped, centred control column
instead. Verified on iPhone 17 and iPad Air 11-inch.

## Menu and Info screen

The `⋯` menu is one level deep with three groups: visual style, appearance
(System / Light / Dark), then Calculation model / Info / Settings. Every row
carries an SF Symbol so the text column does not jump, and the light/dark choice
is reachable in one tap instead of three. Note that iOS does not render `Section`
headers inside a menu — the group titles are supplied to SwiftUI but the system
shows dividers only.

`InfoView` is a normal iOS about screen: brand mark, word mark, version and the
tagline (translated in all ten languages but unused until now), plus a link into
the model page.

## Formula typesetting

`MathFormula.swift` is a small typesetter for the LaTeX subset the help pages
use — a recursive-descent parser plus a SwiftUI renderer. It replaced a
Unicode-flattening approach that could not work: Unicode has no subscript
capitals, so `T_D` kept a visible underscore, fractions collapsed onto one line,
and hyphens stood in for minus signs. What it does now:

* stacked fractions with a rule, aligned on the maths axis
* real sub- and superscripts, stacked when a base carries both
* italic variables against upright numerals and units, per convention
* growing delimiters for `\left( … \right)`
* U+2212 minus, hair spaces around relations, a thin space before units (`25 K`)
* wide formulas scroll sideways (`ViewThatFits`) rather than clip or shrink
* VoiceOver reads a spoken form, not the symbol sequence

`HelpFormulaTests` parses every formula in all ten localized files and asserts
that no LaTeX command name survives into the output. It exists because two
unhandled commands shipped unnoticed: `\text{min}` printed "textmin", and `\le`
— used 30 times across the files — printed a literal "le" instead of "≤". That
class of defect is invisible in review and obvious on screen, so it needs a test
rather than another read-through.

## Design

Two visual styles × light and dark, resolved in `Shared/Theme.swift` as plain
values rather than asset-catalog colour sets, so the identical palette type also
works on watchOS.

* **Classic** — system-native look, the default.
* **Beer** — the original's beer photo, with a scrim (heavier in dark mode) plus
  a translucent card behind every text block so contrast holds. `Reduce
  Transparency` drops the photo for a gradient; `Reduce Motion` disables the
  dial animation and the alarm pulse.
* **Appearance** — System / Light / Dark, selectable independently of the style.

`BrandMark` draws the word-mark glyph as vector geometry (half bottle, half
frost crystal on a shared axis, derived from the app icon). The crystal is
clipped at the split axis: without the clip each arm's round line cap bulges half
a stroke width past the centre and swallows the gap between the halves.

## Testing

```bash
xcodebuild -project BeerCHILLER.xcodeproj -scheme BeerCHILLER \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

43 tests, all passing: 26 model-parity, 7 widget-timeline, 4 help-formula, 6 UI.

`tools/inject_session.py` writes a `ChillSession` straight into the simulator's
App Group store so the running, nearly-done and finished states can be exercised
without waiting out a real cooling time:

```bash
python3 tools/inject_session.py <udid> running --progress 0.4 --minutes 34
python3 tools/inject_session.py <udid> finished
python3 tools/inject_session.py <udid> clear
```

### What was verified on a simulator

* **Live Activity on the Lock Screen**: a real timer started from the UI, the
  device locked, and the activity rendered with the countdown, the end time, the
  live temperature and the target — counting down correctly across a minute
  boundary. Note that seconds show as `--`: on the Lock Screen iOS updates a
  Live Activity timer once a minute by design.
* **The notification permission prompt** appears on the first start, in German,
  with the timer already visible behind it — the moment where the request has
  context.
* **The alarm flow end to end**, now covered by four UI tests driven by a
  debug-only `-seedFinishedSession` launch argument: a run that ended while the
  app was closed brings up the "your beer is cold" screen on the next launch,
  acknowledging it returns to the main screen and clears the stored run, a run
  still in progress is restored as a countdown, and no run starts idle.
* **The real start path** (`action.start` → `controller.start()`), which is what
  schedules the notification, opens the Live Activity and hands off to the watch.

* iPhone 17: portrait and landscape, Classic and Beer, light and dark, idle and
  running states; countdown and live temperature checked against the model by
  hand (15.2 °C at 42 % of a 34-minute freezer run).
* Dynamic Type at `AccessibilityXXXL` and every control carrying a VoiceOver
  label (both asserted by UI tests).
* Apple Watch Series 11 (42 mm): timer tab and inputs tab, same cooling time as
  the phone.
* Widget: registered and discoverable in the widget gallery with localized title,
  description and three size previews.
* All ten languages present; the German build was used throughout.

### What was *not* verified

* **The widget rendering live on the home screen.** It is present in the gallery
  and its timeline logic is unit-tested, but placing it on the home screen via UI
  automation did not succeed, so no screenshot of the placed widget exists.
* **Dynamic Island** specifically — the expanded and compact island
  presentations were not captured, only the Lock Screen one.
* **Lock-screen and watch complications** — same situation: implemented and
  building, not placed on a lock screen or watch face.
* **iPad.** The app builds for iPad and the two-column layout is exercised in
  landscape on iPhone, but no iPad simulator run was captured.
* **WatchConnectivity sync between the two devices — this one is BROKEN.** The
  simulators were paired and both sides report `paired: YES, reachable: YES,
  appInstalled: YES`. The phone genuinely issues `transferUserInfo` (156-byte
  payload, acknowledged for the watch's pairing ID) and the watch's WCSession
  dequeues the content (`hasContentPending: YES → NO`), but `didReceiveUserInfo`
  never runs in the watch app, so the run never lands on the watch: its store has
  no `chillSession` and its UI stays idle while the phone counts down. **Root
  cause not established.** Two things were found and fixed along the way — the
  delegate methods now carry explicit `@objc`, and `send()` no longer silently
  drops an update that arrives before the session finishes activating — but
  neither made the hand-off work. Treat the watch as standalone-only for now.
* **A real device.** Everything above is simulator-only. App Groups, Live
  Activities and notifications behave differently once code signing with a real
  team is involved.

## Bugs found and fixed while testing

* `preferredColorScheme(nil)` was applied for the "System" appearance; replaced
  with a modifier that is omitted entirely so the window follows the system.
* The header scrolled under the status bar and the Dynamic Island; it is now
  pinned outside the scroll view.
* Volume read `0,50 l`; the original shows `0,5 l`.
* The `⋯` menu had no VoiceOver label — `accessibilityLabel` on a `Menu` does not
  reach the button UIKit creates for it, so the label had to move onto the
  menu's content.
* All three volume options announced "bottle size": a container-level
  `accessibilityLabel` overrode the children's labels. Fixed with
  `accessibilityElement(children: .contain)`.
* The watch inputs reused unrelated string keys, labelling the container picker
  "bottle size" and the appliance picker "settings". Three new keys were added in
  all ten languages.

## A note on verifying with screenshots

The simulator framebuffer can serve a **stale frame** long after the UI has moved
on — during this work it returned a screen four minutes out of date, which made a
working alarm screen look broken and led to a pointless refactor. Interactions
force a redraw, so screenshots taken right after a tap are trustworthy; ones taken
after a delay are not. Assertions through the accessibility hierarchy (the UI
tests) are the reliable check. `xcrun simctl io <udid> screenshot` and the
attached-panel screenshots can disagree; compare the status-bar clock against the
host clock when in doubt.

## Known limitations

### Translations need a native-speaker pass

Every language other than **German, Italian and English** is machine-translated
and has not been checked by a native speaker — the interface strings, the ten
help pages, the fourteen iOS-only keys added for this port, and the diacritics
restored in the Czech, Croatian and Polish headings alike.

`tools/audit_translations.py` only covers what is mechanically checkable:
diacritic density, format-specifier mismatches, untranslated leftovers and length
outliers. It cannot tell whether a sentence reads naturally, whether the
terminology is used consistently, or whether a term is the one speakers of that
language would actually expect. Two findings from reading the strings show why
that matters:

* `bottle_size` and `bottle_volume` are byte-identical in all ten languages, and
  five of them render as plain "Bottle" — including when a *can* is selected.
* Six languages mix the English loanword "timer" into the button while using
  their own word in the widget name: *Uruchom timer* against *Minutnik
  chłodzenia* (pl), *Spustit timer* against *Časovač* (cs), likewise es, pt, hr
  and fr.

Both are wording decisions rather than typos, so they are left for whoever does
the language review.

### Partly transliterated help pages

**The Czech, Croatian and Polish help pages are partly transliterated.** They
arrived from upstream stripped of diacritics — a 207-line Polish document
contained not a single Polish character. The document title, both introductory
paragraphs and all section headings have been restored
(`tools/restore_diacritics.py`); the body paragraphs are still as upstream wrote
them. Restoring those would mean rewriting roughly 260 distinct words per
language, which is closer to re-translation than to proof-reading and should be
done by a native speaker.

`tools/audit_translations.py` reports the current state: diacritic density per
language, format-specifier mismatches, untranslated leftovers and length
outliers. Dutch shows zero diacritics and is a false positive — Dutch barely
uses them.

The German and Portuguese help pages had the same defect confined to section 6
(the passage added for model V2.1); both are fixed.

## Localization

Three scripts, run in this order:

1. `tools/make_xcstrings.py` converts the Android `values-*/strings.xml` files
   into `Localizable.xcstrings` (81 keys × 10 languages: cs, de, en, es, fr, hr,
   it, nl, pl, pt), converting `%1$s` to `%1$@` and decoding both XML entities
   and Android backslash escapes.
2. `tools/add_ios_strings.py` adds the 14 keys with no Android counterpart —
   appearance override, watch picker titles, plain style names, and the spoken
   forms VoiceOver uses for formulas — also in all ten languages.
3. `tools/prune_strings.py` normalises the brand name and deletes the
   Android-only keys. It refuses to delete anything the Swift sources still
   reference, so it stays safe to re-run.

Result: **62 keys × 10 languages, none unused.**

Provenance: the 48 keys imported from the Android project carry that project's
translations; the 14 added for this port were translated for it. Outside German,
Italian and English none of them has had a native-speaker review — see *Known
limitations*.

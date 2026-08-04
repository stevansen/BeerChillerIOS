# BeerCHILLER — App Store submission

Everything needed to submit, split into what is already done in this repo and
what needs the Apple Developer account.

Developer account: **Stefan.Hellweger@mac.com**

---

## 1. Only you can do these

These need someone signed in to the Apple Developer portal or App Store Connect.

### 1.1 Find the Team ID

Apple Developer → **Membership details**. It is a ten-character string like
`ABCDE12345`. Everything below takes it as `$TEAM`.

```bash
export TEAM=ABCDE12345
```

### 1.2 Register the identifiers

Certificates, Identifiers & Profiles → **Identifiers** → new App ID for each of
the four bundles. The suffixes matter: iOS builds the watch and widget
relationships from the prefix.

| Bundle ID | Target |
|---|---|
| `com.bierchiller.app` | iOS app |
| `com.bierchiller.app.widget` | widget extension |
| `com.bierchiller.app.watchkitapp` | watchOS app |
| `com.bierchiller.app.watchkitapp.widget` | watch complications |

On the iOS app ID, the watch app ID and the widget ID, enable the **App Groups**
capability and add the group `group.com.bierchiller.app.shared` (register it under
Identifiers → App Groups first). Without it the widget and the watch cannot see
the running timer — it is the only capability the app needs. No push
notifications, no iCloud, no sign-in.

> `com.bierchiller.app` is unrelated to the Android package name; nothing is
> inherited from the Play Store listing. Renaming it later orphans installs, so it
> is worth being sure now.

### 1.3 Check the name is free

App Store Connect reserves app names globally. **BeerCHILLER** may be taken. Try
to create the app record early — that is the only way to find out. If it is
taken, the fallback is a distinguishing suffix in the *store* name only
(`BeerCHILLER – Beer Cooling Timer`); the on-device display name stays
`BeerCHILLER` and needs no code change.

### 1.4 Create the app record

App Store Connect → Apps → **+** → New App:

* Platforms: **iOS** (the watch app ships inside it — it is not a separate record)
* Name / Primary language: **BeerCHILLER** / German or English, your call
* Bundle ID: `com.bierchiller.app`
* SKU: anything unique, e.g. `beerchiller-ios-1`
* User Access: Full Access

### 1.5 Answer the questionnaires

Recommended answers are in section 4.

---

## 2. Build and upload

### 2.1 Switch the project to your team

Signing is parameterised — ad-hoc signing is the committed default so that
simulator builds work without a developer account:

```bash
python3 tools/generate_project.py --team $TEAM
```

This turns on automatic signing for all four targets. **Do not commit the
result**; it hardcodes your Team ID. Regenerate without `--team` afterwards, or
use the `BEERCHILLER_TEAM_ID` environment variable instead.

### 2.2 Archive

Clean first. A language was removed from this build, and stale `.lproj`
directories from an earlier incremental build are **not** pruned — an incremental
archive would ship Czech, Croatian and Polish as empty localizations.

```bash
rm -rf build
xcodebuild archive \
  -project BeerCHILLER.xcodeproj \
  -scheme BeerCHILLER \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/BeerCHILLER.xcarchive
```

Confirm the archive carries exactly the seven shipped languages:

```bash
ls -d build/BeerCHILLER.xcarchive/Products/Applications/BeerCHILLER.app/*.lproj
```

Expected: `de en es fr it nl pt` — nothing else.

### 2.3 Export and upload

```bash
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST

xcodebuild -exportArchive \
  -archivePath build/BeerCHILLER.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export
```

Validate before uploading — it catches icon, manifest and entitlement problems in
seconds instead of after an upload:

```bash
xcrun altool --validate-app -f build/export/BeerCHILLER.ipa \
  -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```

Then upload with `--upload-app` and the same arguments. An App Store Connect API
key (Users and Access → Integrations → **App Store Connect API**) avoids typing an
app-specific password; Xcode's Organizer works too if you prefer clicking.

---

## 3. Already done in this repo

| Requirement | State |
|---|---|
| App icon without alpha channel | Flattened onto its own sampled amber, not white |
| Watch app icon | Present — watchOS submissions are rejected without one |
| `PrivacyInfo.xcprivacy` | In all four bundles: `1C8F.1` (App Group defaults) and `CA92.1` (standard-defaults fallback) |
| `ITSAppUsesNonExemptEncryption = false` | Set, so upload does not stop for export compliance |
| Deployment targets | iOS 16.0, watchOS 9.0 |
| Store metadata, 7 languages | `AppStore/metadata/<locale>/` — within Apple's length limits, checked by the generator |
| Screenshots | `AppStore/screenshots/` — see section 5 |
| Privacy policy | [`PRIVACY.md`](../PRIVACY.md), reachable at a public URL — Apple requires one for every app |

---

## 4. Questionnaire answers

### 4.1 Age rating

The app is about beer, so the alcohol question applies. It depicts no drinking,
sells nothing, and encourages no consumption; the description closes with "enjoy
responsibly".

| Question | Answer |
|---|---|
| Alcohol, Tobacco, or Drug Use or References | **Yes — infrequent/mild** |
| Everything else (violence, sexual content, gambling, horror, profanity, contests, medical/treatment information) | **None** |
| Unrestricted web access | **No** |
| Made for Kids | **No** |

App Store Connect computes the final band from these answers rather than letting
you pick it. Expect something in the 16+/17+ region — that is normal for
alcohol-related utilities and is not a problem. **Read what it computes and
sanity-check it**; Apple has revised these bands recently and I would not swear to
the exact result.

### 4.2 App privacy ("nutrition label")

Answer **"No, we do not collect data from this app."**

That is literally true: there is no network code in the binary, no analytics SDK,
no third-party SDK of any kind. If the reviewer asks, the privacy manifest lists
the two `NSUserDefaults` required-reason codes and nothing else.

Do **not** declare Identifiers or Usage Data because the app uses `UserDefaults` —
required-reason API declarations and data-collection declarations are different
questions, and local storage is not collection.

### 4.3 Export compliance

`ITSAppUsesNonExemptEncryption = false` in the Info.plist answers this before it
is asked. The app uses no encryption at all.

### 4.4 Content rights

No third-party content. The beer artwork is generated procedurally by
`tools/make_beer_background.swift` from primitives — no source photograph, no
stock imagery, no licence to attribute. The formulas and the model come from the
Android original by C. Auer, ported with his agreement; `LICENSE.md` and
`ACKNOWLEDGEMENTS.md` record the authorship.

### 4.5 Review notes

Worth pasting into App Store Connect → "Notes for the reviewer":

> BeerCHILLER estimates how long a beer needs in a fridge or freezer and times
> it. No account, no sign-in, no network — the app has no network code at all, so
> there is nothing to test online and no demo credentials are needed.
>
> The Apple Watch app is included in the same build and works standalone; it can
> start and stop a run by itself and syncs with the iPhone over
> WatchConnectivity.
>
> To see the timer without waiting: set the appliance to Freezer, a 0.33 l bottle,
> start temperature 22 °C and target 8 °C — that is a few minutes. The
> calculation model behind the estimate, with every formula, is documented in the
> app under ⋯ → Calculation model.

---

## 5. Screenshots

Generated by a UI test rather than by hand, so they can be regenerated after any
UI change:

```bash
bash tools/make_appstore_screenshots.sh
```

Apple requires one iPhone size and, because the app supports iPad, one iPad size;
smaller sizes are scaled from those automatically.

| Directory | Device | Pixels |
|---|---|---|
| `AppStore/screenshots/iphone-6.9/` | iPhone 17 Pro Max | 1320 × 2868 |
| `AppStore/screenshots/ipad-13/` | iPad Pro 13-inch | 2064 × 2752 |
| `AppStore/screenshots/watch/` | Apple Watch Series 11 46 mm | device native |

Six scenes: idle and running in each visual style, the calculation-model page, and
landscape. Each capture asserts the frame is not blank — the simulator can hand
back a stale or empty framebuffer, and a silently blank store screenshot is worse
than a failing test.

Upload order in App Store Connect is the display order, so keep the numeric
prefixes.

---

## 6. Known review risks

**None of these is a known blocker; they are the places I would expect friction.**

1. **The name may be taken.** Section 1.3.
2. **Alcohol rating.** Expected and fine, but it does put the app behind an age
   gate in some regions.
3. **Watch app.** The iPhone↔Watch hand-off works, verified in both directions on
   simulators. It has **never been run on real hardware**, and WatchConnectivity
   behaves differently there — this is the one part of the app I would test on a
   device before submitting, if a device is available.
4. **Widgets and Live Activities.** The widget code and its timeline are unit
   tested, but a widget on a real Home Screen, the Dynamic Island presentations
   and lock-screen and watch-face complications were never verified in place.
   Guideline 2.1 rejections usually come from a feature that does not work, so it
   is worth adding a widget to a Home Screen once before submitting.
5. **Machine-translated store copy.** The descriptions in es, fr, nl and pt were
   written for this port and have not had a native-speaker pass, same as the app's
   own strings. Apple does not check this, but users do.

## 7. Order of operations

1. Register the identifiers and the App Group (1.2)
2. Create the app record, confirming the name is free (1.3, 1.4)
3. `python3 tools/generate_project.py --team $TEAM`
4. `rm -rf build` and archive, then check the `.lproj` list (2.2)
5. Validate, then upload (2.3)
6. Paste the metadata from `AppStore/metadata/`, upload the screenshots
7. Answer the questionnaires (4)
8. Submit
9. Regenerate the project without `--team` so the repo keeps its ad-hoc default

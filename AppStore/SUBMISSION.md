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

### 1.3 Register one device

Counter-intuitive but required: `xcodebuild archive` with automatic signing asks
Apple for a **development** provisioning profile even for a Release archive — the
distribution identity is applied afterwards, by `-exportArchive`. Apple refuses to
issue a development profile to a team with no devices:

> Your team has no devices from which to generate a provisioning profile.

So the team needs at least one, and **connecting a device does not register it**.
`xcodebuild -allowProvisioningUpdates` will not do it either — it fails with
*"Device … isn't registered in your developer account"* and stops. Registration is
a separate, deliberate step:

* **Portal**: developer.apple.com → Certificates, Identifiers & Profiles →
  **Devices** → **+** → Platform *iOS*, paste the UDID.
* **Xcode.app**: Window → Devices and Simulators, select the device, or just run
  the app to it once — Xcode offers to register it.

Read a connected device's UDID with:

```bash
xcrun devicectl list devices --json-output /tmp/d.json >/dev/null \
  && python3 -c "import json;[print(x['deviceProperties']['name'], x['hardwareProperties']['udid']) for x in json.load(open('/tmp/d.json'))['result']['devices']]"
```

A UDID looks like `00008110-001925E034FA801E` — not the `devicectl` identifier,
which is a different UUID and the portal will reject it.

**The watch app may need its own device.** Provisioning profiles are per platform,
so the embedded watchOS targets can require a registered Apple Watch even after an
iPhone or iPad is in the list. If no Apple Watch is available, the way out is
manual signing (section 2.4), which needs no devices at all.

Pinning `CODE_SIGN_IDENTITY = "Apple Distribution"` for Release looks like the fix
and is not — automatic signing rejects it: *"is automatically signed for
development, but a conflicting code signing identity Apple Distribution has been
manually specified"*. The note in `tools/generate_project.py` records both dead
ends.

You need a device anyway: the widget on a real Home Screen, the Dynamic Island
presentations and the watch complications are the part of this app that
simulators cannot confirm.

### 1.4 Check the name is free

App Store Connect reserves app names globally. **BeerCHILLER** may be taken. Try
to create the app record early — that is the only way to find out. If it is
taken, the fallback is a distinguishing suffix in the *store* name only
(`BeerCHILLER – Beer Cooling Timer`); the on-device display name stays
`BeerCHILLER` and needs no code change.

### 1.5 Create the app record

App Store Connect → Apps → **+** → New App:

* Platforms: **iOS** (the watch app ships inside it — it is not a separate record)
* Name / Primary language: **BeerCHILLER** / German or English, your call
* Bundle ID: `com.bierchiller.app`
* SKU: anything unique, e.g. `beerchiller-ios-1`
* User Access: Full Access

### 1.6 Answer the questionnaires

Recommended answers are in section 4.

---

## 2. Build and upload

### 2.0 Sign Xcode in to the account first

**Do this before anything else.** Automatic signing cannot invent a certificate:
without one, `xcodebuild archive` fails with four *"No profiles for
com.bierchiller.app… were found"* errors, and the message only suggests a missing
flag — it does not mention that the machine has no signing identity at all.

Xcode → **Settings** → **Accounts** → **+** → Apple ID → sign in with
`Stefan.Hellweger@mac.com`, then select the team and **Manage Certificates** →
**+** → *Apple Development* and *Apple Distribution*.

This is interactive and needs the Apple ID password and two-factor code, so it
cannot be scripted.

Check the machine is ready:

```bash
bash tools/check_signing.sh
```

It verifies the four things that have to line up — a team in the project, a
development certificate, a distribution certificate, and at least one
provisioning profile — and names the missing one instead of letting a three-minute
archive fail at the end.

### 2.1 Switch the project to your team

Signing is parameterised — ad-hoc signing is the committed default so that
simulator builds work without a developer account:

```bash
python3 tools/generate_project.py --team $TEAM
```

This turns on automatic signing for all four targets. **Do not commit the
result**; it hardcodes your Team ID. Regenerate without `--team` afterwards, or
use the `BEERCHILLER_TEAM_ID` environment variable instead.

### 2.1a Bump the build number

App Store Connect refuses an upload whose build number it has already seen, even
if the code is identical. One edit:

```python
# tools/generate_project.py
MARKETING_VERSION = "1.0"   # what users see; changes for a release
BUILD_NUMBER = "2"          # must rise for every upload
```

Then regenerate. All four bundles read these through
`$(CURRENT_PROJECT_VERSION)` and `$(MARKETING_VERSION)` in their Info.plist, so
one edit moves the app, the widget, the watch app and the watch complications
together.

> They used to be literal `1` and `1.0` in each Info.plist, which silently won
> over the build setting: bumping `BUILD_NUMBER` produced an archive still
> stamped `1.0 (1)`. Nothing warned — the mismatch would only have surfaced as a
> rejected upload. Check the archive after building:
>
> ```bash
> /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
>   build/BeerCHILLER.xcarchive/Products/Applications/BeerCHILLER.app/Info.plist
> ```

### 2.2 Archive

Clean first. A language was removed from this build, and stale `.lproj`
directories from an earlier incremental build are **not** pruned — an incremental
archive would ship Czech, Croatian and Polish as empty localizations.

`-allowProvisioningUpdates` is not optional. Without it xcodebuild refuses to
create or refresh a profile even when the account could — it fails with *"No
profiles for 'com.bierchiller.app' were found"* — and with it, Xcode registers the
four App IDs and the App Group for you if they are not in the portal yet.

```bash
rm -rf build
xcodebuild archive \
  -project BeerCHILLER.xcodeproj \
  -scheme BeerCHILLER \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/BeerCHILLER.xcarchive \
  -allowProvisioningUpdates
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

### 2.4 Fallback: manual signing, no devices needed

The device requirement in 1.3 exists only because automatic signing insists on a
*development* profile for the archive. App Store distribution profiles need no
devices, so manual signing sidesteps the problem entirely — at the cost of four
profiles made by hand.

Worth taking when there is no Apple Watch to register, or when this runs on a
build machine that should not depend on a device list.

1. In the portal, create four **App Store** distribution profiles, one per App ID
   from the table in 1.2. Download and double-click each one.
2. Regenerate with manual signing, naming the profiles:

   ```bash
   python3 tools/generate_project.py --team $TEAM --manual-signing \
     --profile com.bierchiller.app="BeerCHILLER App Store" \
     --profile com.bierchiller.app.widget="BeerCHILLER Widget App Store" \
     --profile com.bierchiller.app.watchkitapp="BeerCHILLER Watch App Store" \
     --profile com.bierchiller.app.watchkitapp.widget="BeerCHILLER Watch Widget App Store"
   ```

   Substitute the exact profile names as the portal shows them.
3. Archive as in 2.2. `-allowProvisioningUpdates` is unnecessary with manual
   signing, and harmless if left in.

> This path is documented but has not been exercised here — no App Store profiles
> exist for this team yet. If you take it and a profile name does not match, the
> error names the profile it looked for, which is enough to correct it.

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
| Alcohol, Tobacco, or Drug Use or References | **Yes — frequent/intense** |
| Everything else (violence, sexual content, gambling, horror, profanity, contests, medical/treatment information) | **None** |
| Unrestricted web access | **No** |
| Made for Kids | **No** |

This says *frequent*, not *infrequent/mild*, and that distinction cost a
rejection. Submitted as infrequent/mild, App Review rejected the build under
**guideline 2.3.6**: an app must be rated for the highest level of content it
offers, and every screen of this one is about beer. Frequent is the honest answer
for an app whose entire subject is a beverage, even though it depicts no drinking.

App Store Connect computes the band from these answers rather than letting you
pick it: frequent yields **17+** (16 in Brazil), where infrequent/mild yielded
12+.

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

### 4.4a No references to other platforms

App Review rejected the first submission under **guideline 2.3.10** as well: the
descriptions closed with "a port of the Android app by C. Auer", and store copy
must not point users at other platforms.

The credit itself has to stay — the design is licensed CC BY 4.0, which requires
attribution — so only the platform went: "BeerCHILLER is built on an original
concept and design by C. Auer."

`tools/make_appstore_metadata.py` holds the copy. After editing it, check the
whole directory rather than the file you touched:

```bash
grep -rniE "android|google|play store|windows" AppStore/metadata/
```

The app's own strings were already clean — the Android-only keys were dropped
during the port — so this was purely a metadata problem.

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

Watch screenshots must match the display type exactly. 416 × 496 is
`APP_WATCH_SERIES_10` (46 mm); sending it as `APP_WATCH_ULTRA` is accepted by the
upload and then fails asynchronously with `IMAGE_INCORRECT_DIMENSIONS`, so check
`assetDeliveryState` rather than trusting the upload's success.

---

## 5a. TestFlight

The upload alone does not put a build in front of testers.

* **Internal group** — gets every build automatically. Assigning one explicitly
  is rejected: *"Cannot add internal group to a build."*
* **External group** — needs the build assigned to it, and the group needs a
  passed beta review.
* **Testers** must accept their invitation. A tester sitting at `INVITED` sees
  nothing in the TestFlight app, and the device has to be signed in with that
  same Apple ID. The public link (`publicLink` on the external group) sidesteps
  both.
* **"What to Test"** is `betaBuildLocalizations.whatsNew`, per build. Empty by
  default, so testers are told nothing about what changed unless it is set.

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
2. Register a device, then create the app record, confirming the name
   is free (1.3, 1.4, 1.5)
3. `python3 tools/generate_project.py --team $TEAM`
4. `rm -rf build` and archive, then check the `.lproj` list (2.2)
5. Validate, then upload (2.3)
6. Paste the metadata from `AppStore/metadata/`, upload the screenshots
7. Answer the questionnaires (4)
8. Submit
9. Regenerate the project without `--team` so the repo keeps its ad-hoc default

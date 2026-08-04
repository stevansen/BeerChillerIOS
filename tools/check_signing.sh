#!/bin/bash
#
# Preflight for `xcodebuild archive`: reports what is missing for code signing.
#
# Exists because the failure it diagnoses is badly reported. With automatic
# signing and no certificate, xcodebuild spends minutes building and then prints
# four copies of
#
#   No profiles for 'com.bierchiller.app' were found ...
#   Automatic signing is disabled and unable to generate a profile.
#   To enable automatic signing, pass -allowProvisioningUpdates
#
# which points at a missing *flag* and says nothing about the actual cause — that
# the machine has no signing identity, because Xcode was never signed in to the
# developer account. Adding the flag alone does not help.
#
# Usage: bash tools/check_signing.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/BeerCHILLER.xcodeproj/project.pbxproj"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

problems=0
ok()   { printf "  \033[32mok\033[0m    %s\n" "$1"; }
bad()  { printf "  \033[31mmissing\033[0m %s\n" "$1"; problems=$((problems + 1)); }
note() { printf "        %s\n" "$1"; }

echo "Signing preflight"
echo

# 1. A team in the project.
team="$(grep -m1 "DEVELOPMENT_TEAM = " "$PROJECT" | sed 's/.*= //; s/;.*//')"
if [[ -n "$team" && "$team" != '""' ]]; then
  ok "development team in the project: $team"
else
  bad "no DEVELOPMENT_TEAM in the project"
  note "python3 tools/generate_project.py --team ABCDE12345"
fi

# 2. A development certificate — needed to build.
if security find-identity -v -p codesigning 2>/dev/null \
   | grep -qE "Apple Development|iPhone Developer"; then
  ok "Apple Development certificate"
else
  bad "no Apple Development certificate in the keychain"
  note "Xcode → Settings → Accounts → Manage Certificates → + → Apple Development"
fi

# 3. A distribution certificate — needed to export for the App Store.
if security find-identity -v -p codesigning 2>/dev/null \
   | grep -qE "Apple Distribution|iPhone Distribution"; then
  ok "Apple Distribution certificate"
else
  bad "no Apple Distribution certificate in the keychain"
  note "Xcode → Settings → Accounts → Manage Certificates → + → Apple Distribution"
fi

# 4. At least one provisioning profile. Xcode creates these on demand with
#    -allowProvisioningUpdates, so this is a warning rather than a hard failure —
#    but an empty directory alongside a missing certificate confirms the account
#    was never connected.
count=0
[[ -d "$PROFILES" ]] && count="$(find "$PROFILES" -name '*.mobileprovision' | wc -l | tr -d ' ')"
if (( count > 0 )); then
  ok "$count provisioning profile(s) installed"
else
  bad "no provisioning profiles installed"
  note "normal before the first archive — xcodebuild creates them with"
  note "-allowProvisioningUpdates, provided the certificates above exist"
fi

# 5. An account in Xcode at all. This is the root cause when everything above is
#    empty, and nothing in xcodebuild's output mentions it.
if defaults read com.apple.dt.Xcode IDEProvisioningTeams >/dev/null 2>&1; then
  ok "Xcode has a developer account configured"
else
  bad "no Apple Developer account in Xcode"
  note "Xcode → Settings → Accounts → + → Apple ID. Interactive: it needs the"
  note "Apple ID password and a two-factor code, so it cannot be scripted."
fi

echo
if (( problems == 0 )); then
  echo "Ready to archive:"
  echo "  rm -rf build && xcodebuild archive -project BeerCHILLER.xcodeproj \\"
  echo "    -scheme BeerCHILLER -configuration Release \\"
  echo "    -destination 'generic/platform=iOS' \\"
  echo "    -archivePath build/BeerCHILLER.xcarchive -allowProvisioningUpdates"
  exit 0
fi

echo "$problems item(s) to fix before archiving. Start with the Xcode account —"
echo "signing in usually resolves the certificates and profiles in one step."
exit 1

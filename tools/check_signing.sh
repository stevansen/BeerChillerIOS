#!/bin/bash
#
# Preflight for `xcodebuild archive`: reports what is actually wrong with code
# signing, and distinguishes the three failures that look identical from the
# outside.
#
# xcodebuild reports all of them the same way — after minutes of building:
#
#   No profiles for 'com.bierchiller.app' were found ...
#   Automatic signing is disabled and unable to generate a profile.
#   To enable automatic signing, pass -allowProvisioningUpdates
#
# It points at a missing flag. The cause is usually one of:
#
#   1. no developer account in Xcode      -> no certificate can be issued
#   2. certificates issued but not usable -> the WWDR intermediate that signed
#                                            them is missing, so the chain cannot
#                                            be built and macOS treats the
#                                            identity as invalid
#   3. -allowProvisioningUpdates omitted  -> profiles are never created
#
# Case 2 is the nastiest: the certificate *is* in the keychain, Keychain Access
# shows it, and a naive `security find-certificate` finds it — while
# `find-identity -v` quietly leaves it out. Note that `security verify-cert
# -p codeSign` reports success for such a certificate, so it is not a usable
# check; the authority is `find-identity -v -p codesigning`.
#
# Usage: bash tools/check_signing.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/BeerCHILLER.xcodeproj/project.pbxproj"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

problems=0
ok()   { printf "  \033[32mok\033[0m      %s\n" "$1"; }
bad()  { printf "  \033[31mproblem\033[0m %s\n" "$1"; problems=$((problems + 1)); }
note() { printf "          %s\n" "$1"; }

# Cache the two identity listings: with -v macOS applies the full code-signing
# policy, without it every cert+key pair is listed. The difference is the point.
all_identities="$(security find-identity -p codesigning 2>/dev/null)"
valid_identities="$(security find-identity -v -p codesigning 2>/dev/null)"

echo "Signing preflight"
echo

# --- 1. team in the project ---
team="$(grep -m1 "DEVELOPMENT_TEAM = " "$PROJECT" | sed 's/.*= //; s/;.*//')"
if [[ -n "$team" && "$team" != '""' ]]; then
  ok "development team in the project: $team"
else
  bad "no DEVELOPMENT_TEAM in the project"
  note "python3 tools/generate_project.py --team ABCDE12345"
fi

# --- 2. an account in Xcode ---
#
# The key is IDEProvisioningTeamByIdentifier, not IDEProvisioningTeams: an
# earlier version of this script read the latter, found nothing, and told the user
# to sign in to an account they had already added.
if defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier >/dev/null 2>&1 \
   || defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists >/dev/null 2>&1; then
  ok "Xcode has a developer account configured"
else
  bad "no Apple Developer account in Xcode"
  note "Xcode → Settings → Accounts → + → Apple ID. Interactive: it needs the"
  note "Apple ID password and a two-factor code, so it cannot be scripted."
fi

# --- 3. the two certificates, present *and* valid ---
check_identity() {
  local label="$1" purpose="$2"
  if grep -q "$label" <<<"$valid_identities"; then
    ok "$label certificate is valid ($purpose)"
  elif grep -q "$label" <<<"$all_identities"; then
    bad "$label is in the keychain but macOS rejects it as invalid"
    note "the certificate and its private key are both present — what is missing"
    note "is the intermediate that signed it (see the WWDR check below)"
  else
    bad "no $label certificate ($purpose)"
    note "Xcode → Settings → Accounts → Manage Certificates → + → $label"
  fi
}
check_identity "Apple Development"  "needed to build"
check_identity "Apple Distribution" "needed to export for the App Store"

# --- 4. the WWDR intermediate ---
#
# Apple has issued several under the *same* common name. The G1 expired on
# 7 February 2023 and is still present on plenty of machines; on its own it cannot
# validate a certificate issued by G3, which is what Apple issues now.
wwdr_pem="$(mktemp)"
security find-certificate -a -c "Apple Worldwide Developer Relations" -p \
  >"$wwdr_pem" 2>/dev/null
usable=0
expired=0
while IFS= read -r line; do
  [[ "$line" == "-----BEGIN CERTIFICATE-----" ]] && current=""
  current+="$line"$'\n'
  if [[ "$line" == "-----END CERTIFICATE-----" ]]; then
    if openssl x509 -checkend 0 -noout <<<"$current" >/dev/null 2>&1; then
      usable=$((usable + 1))
    else
      expired=$((expired + 1))
      until_date="$(openssl x509 -noout -enddate <<<"$current" 2>/dev/null | sed 's/notAfter=//')"
    fi
  fi
done <"$wwdr_pem"
rm -f "$wwdr_pem"

if (( usable > 0 )); then
  ok "$usable in-date WWDR intermediate certificate(s)"
  (( expired > 0 )) && note "also $expired expired one(s) — harmless once a current one is present"
else
  bad "no in-date WWDR intermediate certificate"
  if (( expired > 0 )); then
    note "found $expired, all expired (latest valid until: ${until_date:-unknown})."
    note "Apple issues Development and Distribution certificates from WWDR G3;"
    note "without it the chain cannot be built and the identities count as invalid."
  fi
  note "Download and install the current intermediate:"
  note "  curl -O https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"
  note "  open AppleWWDRCAG3.cer          # adds it to the login keychain"
  note "Then delete the expired one in Keychain Access (login → Certificates,"
  note "the entry showing an expiry in the past) so it cannot shadow the new one."
fi

# --- 5. profiles (informational) ---
count=0
[[ -d "$PROFILES" ]] && count="$(find "$PROFILES" -name '*.mobileprovision' 2>/dev/null | wc -l | tr -d ' ')"
if (( count > 0 )); then
  ok "$count provisioning profile(s) installed"
else
  note "no provisioning profiles yet — normal before the first archive;"
  note "xcodebuild creates them with -allowProvisioningUpdates once the"
  note "certificates above are valid"
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

echo "$problems problem(s) to fix before archiving."
exit 1

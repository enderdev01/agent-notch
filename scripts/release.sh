#!/usr/bin/env bash
# Builds the distributable disk image: build/AgentNotch-<version>.dmg
#
# Usage: scripts/release.sh
# Env:
#   DEVELOPER_ID    "Developer ID Application: Your Name (TEAMID)". Without it the DMG is ad-hoc signed
#                   and other Macs will show a Gatekeeper warning.
#   NOTARY_PROFILE  keychain profile created once with:
#                   xcrun notarytool store-credentials <name> --apple-id <id> --team-id <TEAMID>
#                   (it prompts for the app-specific password, so it never lands in your shell history).
#                   Needs DEVELOPER_ID too. Notarizes the DMG and staples the ticket.
# Full setup: docs/notarization.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="build/Agent Notch.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw packaging/Info.plist)"
DMG="build/AgentNotch-$VERSION.dmg"

# Fail before building if the signing setup is incomplete: notarization takes minutes, a typo should not.
if [ -n "${NOTARY_PROFILE:-}" ] && [ -z "${DEVELOPER_ID:-}" ]; then
  echo "error: NOTARY_PROFILE needs DEVELOPER_ID; Apple only notarizes Developer ID signatures" >&2
  exit 1
fi
if [ -n "${DEVELOPER_ID:-}" ]; then
  # Name or SHA-1 both work for codesign; the identity must be a Developer ID Application one (not Apple Development).
  if ! security find-identity -v -p codesigning | grep -F -- "$DEVELOPER_ID" | grep -q "Developer ID Application"; then
    echo "error: no valid 'Developer ID Application' identity matching '$DEVELOPER_ID' in your keychain (see docs/notarization.md)" >&2
    exit 1
  fi
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
  if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "error: notarytool profile '$NOTARY_PROFILE' is missing or its credentials are rejected (see docs/notarization.md)" >&2
    exit 1
  fi
fi

# A missing translation would silently fall back to English.
python3 scripts/check-strings.py

make app

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --options runtime --timestamp \
    --entitlements packaging/AgentNotch.entitlements --sign "$DEVELOPER_ID" "$APP"
else
  echo "warning: DEVELOPER_ID not set, keeping the ad-hoc signature (not distributable without a Gatekeeper warning)" >&2
fi
codesign --verify --deep --strict "$APP"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Agent Notch" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
fi

if [ -n "${NOTARY_PROFILE:-}" ] && [ -n "${DEVELOPER_ID:-}" ]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl --assess --type open --context context:primary-signature -v "$DMG"
  echo "notarized and stapled: $DMG"
else
  echo "not notarized (set DEVELOPER_ID and NOTARY_PROFILE to notarize)"
fi

# diskimages-helper sometimes still holds a fresh DMG for a moment, which makes verify fail with "Resource temporarily unavailable".
for try in 1 2 3; do
  hdiutil verify "$DMG" >/dev/null 2>&1 && break
  if [ "$try" = 3 ]; then
    echo "error: hdiutil verify failed; if 'hdiutil info' lists $DMG as attached, eject it and verify again" >&2
    exit 1
  fi
  sleep 3
done
echo "built $DMG ($(du -h "$DMG" | cut -f1))"

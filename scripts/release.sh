#!/usr/bin/env bash
# Builds the distributable disk image: build/AgentNotch-<version>.dmg
#
# Usage: scripts/release.sh
# Env:
#   DEVELOPER_ID    "Developer ID Application: Your Name (TEAMID)". Without it the DMG is ad-hoc signed
#                   and other Macs will show a Gatekeeper warning.
#   NOTARY_PROFILE  keychain profile created once with:
#                   xcrun notarytool store-credentials <name> --apple-id <id> --team-id <TEAMID> --password <app-specific-password>
#                   Needs DEVELOPER_ID too. Notarizes the DMG and staples the ticket.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="build/Agent Notch.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw packaging/Info.plist)"
DMG="build/AgentNotch-$VERSION.dmg"

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
  spctl --assess --type open --context context:primary-signature -v "$DMG"
  echo "notarized and stapled: $DMG"
else
  echo "not notarized (set DEVELOPER_ID and NOTARY_PROFILE to notarize)"
fi

hdiutil verify "$DMG" >/dev/null
echo "built $DMG ($(du -h "$DMG" | cut -f1))"

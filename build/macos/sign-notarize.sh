#!/bin/bash
# Signs Report Manager Designer.app with a Developer ID certificate, builds its
# disk image, has Apple notarize it and staples the ticket to it:
#
#   build/macos/sign-notarize.sh <app> <dmg> [volume name]
#
# Environment:
#   RP_SIGN_IDENTITY   the signing identity (default "Developer ID Application")
#   RP_SIGN_KEYCHAIN   the keychain that holds it (optional)
#   NOTARY_KEY_P8      the App Store Connect API key (.p8 file); without it the
#                      disk image is signed but not notarized
#   NOTARY_KEY_ID      its Key ID
#   NOTARY_ISSUER_ID   its Issuer ID
#
# The code is signed with the hardened runtime, which notarization requires,
# from the inside out (every library, then the bundle) and with a secure
# timestamp. The only entitlement (designer.entitlements) turns library
# validation off: the designer loads the database client libraries the user
# installed. The keychain must also hold Apple's Developer ID G2 intermediate
# (certs/DeveloperIDG2CA.cer) when the Mac has no Xcode.
set -euo pipefail

[ $# -ge 2 ] && [ -d "$1/Contents/MacOS" ] || {
    echo "Usage: $0 <app> <dmg> [volume name]" >&2
    exit 2
}
APP=$(cd "$1" && pwd)
DMG=$2
VOLUME=${3:-$(basename "$APP" .app)}
IDENTITY=${RP_SIGN_IDENTITY:-Developer ID Application}
HERE=$(cd "$(dirname "$0")" && pwd)
ENTITLEMENTS=$HERE/designer.entitlements
KEYCHAIN=()
[ -n "${RP_SIGN_KEYCHAIN:-}" ] && KEYCHAIN=(--keychain "$RP_SIGN_KEYCHAIN")
EXE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$APP/Contents/Info.plist")

sign() {
    codesign --force --timestamp --options runtime "${KEYCHAIN[@]}" --sign "$IDENTITY" "$@"
}

echo "== Developer ID signature ($IDENTITY)"
rm -rf "$APP/Contents/_CodeSignature"
# Every Mach-O but the main executable first: the bundle's signature seals them
n=0
while IFS= read -r -d '' f; do
    if [ "$f" != "$APP/Contents/MacOS/$EXE" ] && file "$f" | grep -q 'Mach-O'; then
        sign "$f"
        n=$((n + 1))
    fi
done < <(find "$APP/Contents" -type f -print0)
echo "   $n libraries"
sign --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=2 "$APP" 2>&1 | grep -E '^(Authority|TeamIdentifier|Timestamp|CodeDirectory)'

echo "== Disk image"
STAGE=$(mktemp -d)
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
codesign --force --timestamp "${KEYCHAIN[@]}" --sign "$IDENTITY" "$DMG"

if [ -z "${NOTARY_KEY_P8:-}" ]; then
    echo "== No NOTARY_KEY_P8: the disk image is signed, not notarized"
    exit 0
fi

echo "== Notarization (Apple)"
NOTARY=(--key "$NOTARY_KEY_P8" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
ANSWER=$(mktemp)
xcrun notarytool submit "$DMG" "${NOTARY[@]}" --wait --timeout 2h --output-format plist > "$ANSWER" || true
STATUS=$(/usr/libexec/PlistBuddy -c "Print :status" "$ANSWER" 2>/dev/null || echo unknown)
ID=$(/usr/libexec/PlistBuddy -c "Print :id" "$ANSWER" 2>/dev/null || echo "")
rm -f "$ANSWER"
echo "   submission $ID: $STATUS"
if [ "$STATUS" != "Accepted" ]; then
    # Apple's report says which file and why
    [ -n "$ID" ] && xcrun notarytool log "$ID" "${NOTARY[@]}" || true
    echo "ERROR: Apple did not accept the disk image ($STATUS)" >&2
    exit 1
fi

echo "== Ticket stapled to the disk image"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

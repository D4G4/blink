#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Read version from project.yml — match the assignment line specifically
# ("MARKETING_VERSION:" with a colon) so we don't also catch the
# CFBundleShortVersionString: $(MARKETING_VERSION) substitution line.
VERSION=$(grep -E '^[[:space:]]*MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -z "$VERSION" ]; then
    echo "Error: could not read version from project.yml"
    exit 1
fi

BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Blink.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/Blink.dmg"
# Keychain profile holding App Store Connect API key for notarytool.
# Created via: xcrun notarytool store-credentials AC_NOTARY \
#   --key ~/.appstoreconnect/private_keys/AuthKey_<KEY>.p8 \
#   --key-id <KEY> --issuer <ISSUER>
NOTARY_PROFILE="AC_NOTARY"

echo "=== Building Blink v$VERSION ==="

# Clean previous build
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_PATH"
mkdir -p "$BUILD_DIR"

# Regenerate xcodeproj
echo "→ Generating project..."
xcodegen generate

# Archive.
# Sign the archive directly with the Developer ID Application cert rather
# than the project's default Automatic style. Automatic signing resolves a
# *development* identity ("Apple Development"/"Mac Development") for the
# build phase, which a local Xcode mints on demand via the signed-in Apple
# ID — but CI has no Apple ID session and only the Developer ID cert in its
# keychain, so Automatic fails there with "No Mac Development signing
# certificate". Manual Developer ID needs no provisioning profile for this
# app's entitlements (sandbox + network.client + audio-input), so this is
# deterministic and Apple-ID-independent in both CI and local runs.
echo "→ Archiving..."
xcodebuild archive \
    -project Blink.xcodeproj \
    -scheme Blink \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -quiet \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM=6V6FZW3FFN

# Export with Developer ID Application signing.
# method=developer-id tells xcodebuild to sign with the Developer ID
# Application certificate (vs Apple Distribution for App Store).
# Automatic signing picks the cert matching DEVELOPMENT_TEAM in
# project.yml (6V6FZW3FFN). Hardened runtime is required for
# notarization — it's already on via ENABLE_HARDENED_RUNTIME=true.
echo "→ Exporting (Developer ID)..."
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>6V6FZW3FFN</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -quiet

# Verify signed .app + version
echo "→ Verifying signed .app..."
codesign --verify --deep --strict --verbose=2 "$EXPORT_DIR/Blink.app" 2>&1 | tail -5
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$EXPORT_DIR/Blink.app/Contents/Info.plist")
echo "  Bundle version: $APP_VERSION"

if [ "$APP_VERSION" != "$VERSION" ]; then
    echo "Error: bundle version ($APP_VERSION) doesn't match project.yml ($VERSION)"
    exit 1
fi

# Generate DMG background
echo "→ Generating DMG background..."
swift scripts/dmg-background.swift "$BUILD_DIR/dmg-background.png"

# Stage the app in a temp dir so we can add the Applications icon
echo "→ Staging DMG contents..."
STAGE_DIR="$BUILD_DIR/dmg-stage"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$EXPORT_DIR/Blink.app" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

# Apply system Applications folder icon to the symlink
APP_FOLDER_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns"
if [ -f "$APP_FOLDER_ICON" ]; then
    cp "$APP_FOLDER_ICON" "$STAGE_DIR/Applications/.VolumeIcon.icns" 2>/dev/null || true
    if command -v fileicon &>/dev/null; then
        fileicon set "$STAGE_DIR/Applications" "$APP_FOLDER_ICON" 2>/dev/null || true
    fi
fi

echo "→ Creating DMG..."
create-dmg \
    --volname "Blink" \
    --background "$BUILD_DIR/dmg-background.png" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 128 \
    --icon "Blink.app" 160 170 \
    --icon "Applications" 380 170 \
    --hide-extension "Blink.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$STAGE_DIR/" \
    || true  # create-dmg exits 2 on "no custom icon" warning, which is fine

rm -rf "$STAGE_DIR"

# Sign the DMG itself so Gatekeeper trusts the container, not just the
# .app inside. Required for clean Homebrew install (no quarantine warnings).
echo "→ Signing DMG..."
codesign --sign "Developer ID Application: DAKSH DAVINDER KUMAR GARGAS (6V6FZW3FFN)" \
    --timestamp \
    "$DMG_PATH"

# Submit DMG to Apple's notary service. --wait blocks until the result
# comes back (typically 1–5 min). Notarization checks the contained
# .app for: signed with valid Developer ID + hardened runtime +
# secure-timestamp + no disallowed entitlements.
echo "→ Submitting DMG to notary (this can take several minutes)..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# Staple the notarization ticket onto the DMG. After this, Gatekeeper
# trusts the DMG offline — no internet round-trip needed on the user's
# Mac to check the notarization status.
echo "→ Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

# Final spot-check: spctl should report "accepted" + "source=Notarized
# Developer ID" for both the .app and the DMG.
echo "→ Gatekeeper assessment..."
spctl --assess --type open --context context:primary-signature -vv "$DMG_PATH" 2>&1 | tail -3

# Summary
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
DMG_SHA=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)

echo ""
echo "=== Done ==="
echo "  DMG: $DMG_PATH ($DMG_SIZE)"
echo "  SHA: $DMG_SHA"
echo "  Version: $VERSION"
echo ""
echo "Next steps:"
echo "  1. git tag v$VERSION && git push --tags"
echo "  2. gh release create v$VERSION $DMG_PATH --title \"v$VERSION\" --generate-notes"
echo "  3. Update homebrew-blink: version + sha256 (remove xattr postflight)"

#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Read version from project.yml
VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -z "$VERSION" ]; then
    echo "Error: could not read version from project.yml"
    exit 1
fi

BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Blink.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/Blink.dmg"

echo "=== Building Blink v$VERSION ==="

# Clean previous build
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_PATH"
mkdir -p "$BUILD_DIR"

# Regenerate xcodeproj
echo "→ Generating project..."
xcodegen generate

# Archive
echo "→ Archiving..."
xcodebuild archive \
    -project Blink.xcodeproj \
    -scheme Blink \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -quiet

# Export (ad-hoc, no signing)
echo "→ Exporting..."
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
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

# Verify
echo "→ Verifying..."
codesign --verify --deep --strict "$EXPORT_DIR/Blink.app"
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$EXPORT_DIR/Blink.app/Contents/Info.plist")
echo "  Bundle version: $APP_VERSION"

if [ "$APP_VERSION" != "$VERSION" ]; then
    echo "Error: bundle version ($APP_VERSION) doesn't match project.yml ($VERSION)"
    exit 1
fi

# Create DMG
echo "→ Creating DMG..."
DMG_TEMP="$BUILD_DIR/Blink_rw.sparseimage"
rm -f "$DMG_TEMP"

hdiutil create -size 50m -type SPARSE -fs HFS+ -volname "Blink" "$DMG_TEMP"
MOUNT_POINT=$(hdiutil attach "$DMG_TEMP" -nobrowse | tail -1 | awk '{print $NF}')

cp -R "$EXPORT_DIR/Blink.app" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"

hdiutil detach "$MOUNT_POINT" -quiet
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_PATH"
rm -f "$DMG_TEMP"

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
echo "  3. Update homebrew-blink: version + sha256"

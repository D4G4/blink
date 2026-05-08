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

# Generate DMG background
echo "→ Generating DMG background..."
swift scripts/dmg-background.swift "$BUILD_DIR/dmg-background.png"

# Create DMG
echo "→ Creating DMG..."
rm -f "$DMG_PATH"

# Stage the app in a temp dir so we can add the Applications icon
STAGE_DIR="$BUILD_DIR/dmg-stage"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$EXPORT_DIR/Blink.app" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

# Apply system Applications folder icon to the symlink
APP_FOLDER_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns"
if [ -f "$APP_FOLDER_ICON" ]; then
    cp "$APP_FOLDER_ICON" "$STAGE_DIR/Applications/.VolumeIcon.icns" 2>/dev/null || true
    # Use fileicon if available, otherwise use Rez/DeRez
    if command -v fileicon &>/dev/null; then
        fileicon set "$STAGE_DIR/Applications" "$APP_FOLDER_ICON" 2>/dev/null || true
    fi
fi

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

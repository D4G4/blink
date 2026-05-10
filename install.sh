#!/bin/bash
set -euo pipefail

REPO="D4G4/blink"
APP_NAME="Blink"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info() { echo -e "${BOLD}$1${RESET}"; }
success() { echo -e "${GREEN}$1${RESET}"; }
error() { echo -e "${RED}$1${RESET}" >&2; exit 1; }

install_macos() {
    info "Installing $APP_NAME for macOS..."

    command -v curl >/dev/null 2>&1 || error "curl is required but not installed."

    # Get latest release DMG URL
    info "Fetching latest release..."
    DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep "browser_download_url.*\.dmg" \
        | head -1 \
        | cut -d '"' -f 4)

    [ -z "$DOWNLOAD_URL" ] && error "Could not find DMG in latest release."

    TMPDIR=$(mktemp -d)
    DMG_PATH="$TMPDIR/$APP_NAME.dmg"

    # Download
    info "Downloading $APP_NAME..."
    curl -fSL --progress-bar "$DOWNLOAD_URL" -o "$DMG_PATH"

    # Mount DMG
    info "Installing..."
    MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -quiet | grep "/Volumes" | cut -f3-)

    # Copy to Applications
    if [ -d "/Applications/$APP_NAME.app" ]; then
        rm -rf "/Applications/$APP_NAME.app"
    fi
    cp -R "$MOUNT_POINT/$APP_NAME.app" /Applications/

    # Unmount and clean up
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$TMPDIR"

    # Strip quarantine (same as Homebrew postflight)
    xattr -cr "/Applications/$APP_NAME.app" 2>/dev/null || true

    success "$APP_NAME installed to /Applications/$APP_NAME.app"
    echo ""
    info "Next steps:"
    echo "  1. Open $APP_NAME from Applications or Spotlight"
    echo "  2. Grant Accessibility when prompted:"
    echo "     System Settings → Privacy & Security → Accessibility → toggle $APP_NAME"
    echo ""
    success "Done!"
}

# Detect OS and install
case "$(uname -s)" in
    Darwin)
        install_macos
        ;;
    *)
        error "Unsupported OS. Download Windows builds from https://github.com/$REPO/releases/latest"
        ;;
esac

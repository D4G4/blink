#!/usr/bin/env bash
# Promote freshly-recorded snapshot PNGs from the test container into the
# source tree. Run AFTER:
#
#   xcodebuild -scheme Blink test -only-testing:BlinkSnapshotTests
#
# was invoked with SNAPSHOT_RECORD=1 in the scheme's TestAction environment
# (see Blink.xcscheme). The test process writes new PNGs to ~/Library/
# Application Support/BlinkSnapshots/ because macOS hardened-runtime blocks
# direct writes to source paths from the test host. This script bridges
# that gap: copy → source, report counts, leave container clean.

set -euo pipefail

CONTAINER="$HOME/Library/Containers/com.blink20.app/Data/Library/Application Support/BlinkSnapshots"
DEST="$(cd "$(dirname "$0")/.." && pwd)/BlinkSnapshotTests/__Snapshots__"

if [[ ! -d "$CONTAINER" ]]; then
    echo "❌ Container directory missing: $CONTAINER"
    echo "   Did you run xcodebuild test with SNAPSHOT_RECORD=1?"
    exit 1
fi

# Only top-level PNGs (skip __Failures__/)
shopt -s nullglob
pngs=("$CONTAINER"/*.png)
shopt -u nullglob

if [[ ${#pngs[@]} -eq 0 ]]; then
    echo "❌ No PNGs in $CONTAINER — nothing to promote."
    exit 1
fi

mkdir -p "$DEST"
copied=0
for png in "${pngs[@]}"; do
    cp "$png" "$DEST/"
    copied=$((copied + 1))
done

echo "✅ Promoted $copied snapshot(s) → $DEST"
echo "   Remove container originals? (Ctrl-C to keep, Enter to clean up)"
read -r
rm "$CONTAINER"/*.png
echo "🧹 Container cleared."

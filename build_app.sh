#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRATCH="${TMPDIR:-/tmp}/ats-telemetry-build"
APP="$ROOT/ATS Telemetry.app"

swift build -c release --scratch-path "$SCRATCH"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$SCRATCH/release/ATSTelemetry" "$APP/Contents/MacOS/ATSTelemetry"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

if [ -d "$ROOT/Resources/Indicators" ]; then
    cp "$ROOT/Resources/Indicators/"*.png "$APP/Contents/Resources/"
fi

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "App lista: $APP"

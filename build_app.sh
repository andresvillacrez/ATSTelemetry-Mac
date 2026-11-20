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
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || cp /tmp/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -d "$ROOT/Resources" ]; then
    # Copia el arbol completo de recursos (indicadores, logos, fotos de camion).
    cp -R "$ROOT/Resources/." "$APP/Contents/Resources/"
fi

chmod -R u+rwX,go+rX "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "App lista: $APP"

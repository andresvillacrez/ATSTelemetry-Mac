#!/bin/bash
# Instala el modo juego como LaunchAgent del usuario (sin sudo).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/Application Support/ATS Telemetry/game-mode"
LOGS="$HOME/Library/Logs/ATS Telemetry"
LA="$HOME/Library/LaunchAgents"
UID_NUM="$(/usr/bin/id -u)"

GAME_LABEL="com.andresvillacrez.atstelemetry.gamemode"
MVK_LABEL="com.andresvillacrez.atstelemetry.mvk-env"
GAME_PLIST="$LA/$GAME_LABEL.plist"
MVK_PLIST="$LA/$MVK_LABEL.plist"

mkdir -p "$DEST" "$LOGS" "$LA"

cp "$ROOT/game-mode.sh" "$DEST/game-mode.sh"
cp "$ROOT/mvk-env.sh" "$DEST/mvk-env.sh"
if [ ! -f "$DEST/config.sh" ]; then
    cp "$ROOT/config.sh" "$DEST/config.sh"
fi
chmod 755 "$DEST/game-mode.sh" "$DEST/mvk-env.sh" 2>/dev/null || true

cat > "$GAME_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$GAME_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$DEST/game-mode.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityIO</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>$LOGS/game-mode.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS/game-mode.err.log</string>
</dict>
</plist>
PLIST

cat > "$MVK_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$MVK_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$DEST/mvk-env.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$UID_NUM" "$GAME_PLIST" 2>/dev/null || true
launchctl bootout "gui/$UID_NUM" "$MVK_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$GAME_PLIST"
launchctl bootstrap "gui/$UID_NUM" "$MVK_PLIST"
launchctl enable "gui/$UID_NUM/$GAME_LABEL" 2>/dev/null || true
launchctl enable "gui/$UID_NUM/$MVK_LABEL" 2>/dev/null || true

# Aplicar las variables MoltenVK ya, para la próxima vez que se abra Steam.
bash "$DEST/mvk-env.sh"

echo "Modo juego instalado."
echo "  Script: $DEST/game-mode.sh"
echo "  Config: $DEST/config.sh"
echo "  Log:    $LOGS/game-mode.log"
echo ""
echo "Reinicia Steam una vez para que ATS/ETS2 hereden las variables de MoltenVK."
echo "El modo juego se activa solo al abrir ATS o ETS2."

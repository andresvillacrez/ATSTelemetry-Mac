#!/bin/bash
# Desinstala el modo juego y retira las variables MoltenVK del usuario.
set -euo pipefail

DEST="$HOME/Library/Application Support/ATS Telemetry/game-mode"
LA="$HOME/Library/LaunchAgents"
UID_NUM="$(/usr/bin/id -u)"
GAME_LABEL="com.andresvillacrez.atstelemetry.gamemode"
MVK_LABEL="com.andresvillacrez.atstelemetry.mvk-env"

launchctl bootout "gui/$UID_NUM/$GAME_LABEL" 2>/dev/null || true
launchctl bootout "gui/$UID_NUM/$MVK_LABEL" 2>/dev/null || true
/bin/rm -f "$LA/$GAME_LABEL.plist" "$LA/$MVK_LABEL.plist"

/bin/launchctl unsetenv MVK_CONFIG_LOG_LEVEL 2>/dev/null || true
/bin/launchctl unsetenv MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION 2>/dev/null || true
/bin/launchctl unsetenv MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS 2>/dev/null || true
/bin/launchctl unsetenv MVK_CONFIG_PREALLOCATE_DESCRIPTORS 2>/dev/null || true
/bin/launchctl unsetenv MVK_CONFIG_USE_COMMAND_POOLING 2>/dev/null || true

/bin/rm -rf "$DEST"

echo "Modo juego desinstalado. Reinicia Steam para volver al entorno normal."

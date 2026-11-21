#!/bin/bash
# Aplica un perfil de suavidad a ATS/ETS2 sin bajar la calidad gráfica:
# - desactiva VSync (evita el bloqueo 60/30 y los tirones de sincronización)
# - mantiene el límite de 60 FPS
# - limpia la ruta corrupta de r_vulkan_runtime
# Los ajustes de calidad (sombras, SSAO, espejos, etc.) NO se tocan.
set -euo pipefail

if /usr/bin/pgrep -x amtrucks >/dev/null 2>&1 || /usr/bin/pgrep -x eurotrucks2 >/dev/null 2>&1; then
    echo "Cierra ATS/ETS2 antes de aplicar el perfil."
    exit 1
fi

STAMP="$(/bin/date +%Y%m%d-%H%M%S)"
CONFIGS=(
    "$HOME/Library/Application Support/American Truck Simulator/config.cfg"
    "$HOME/Library/Application Support/Euro Truck Simulator 2/config.cfg"
)

for CFG in "${CONFIGS[@]}"; do
    [ -f "$CFG" ] || continue
    if [ ! -f "$CFG.bak-smooth-original" ]; then
        cp -p "$CFG" "$CFG.bak-smooth-original"
    fi
    cp -p "$CFG" "$CFG.bak-smooth-$STAMP"
    /usr/bin/sed -i '' 's/^uset r_vsync ".*"/uset r_vsync "0"/' "$CFG"
    /usr/bin/sed -i '' 's|^uset r_vulkan_runtime ".*"|uset r_vulkan_runtime ""|' "$CFG"
    /usr/bin/sed -i '' 's/^uset t_limit_fps ".*"/uset t_limit_fps "60"/' "$CFG"
    /usr/bin/sed -i '' 's/^uset t_locked_fps ".*"/uset t_locked_fps "60"/' "$CFG"
    echo "Perfil aplicado: $CFG"
    echo "  backup: $CFG.bak-smooth-$STAMP"
done

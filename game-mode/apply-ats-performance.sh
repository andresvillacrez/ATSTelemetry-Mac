#!/bin/bash
# Perfil de rendimiento para ATS/ETS2 en macOS.
# Incluye el perfil de suavidad y reduce los ajustes de calidad con mayor coste
# (espejos, sombras, SSAO y AA). Guarda una copia antes de tocar nada.
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
    cp -p "$CFG" "$CFG.bak-perf-$STAMP"

    # Suavidad: mismos valores que apply-ats-smooth.sh.
    /usr/bin/sed -i '' 's/^uset r_vsync ".*"/uset r_vsync "0"/' "$CFG"
    /usr/bin/sed -i '' 's|^uset r_vulkan_runtime ".*"|uset r_vulkan_runtime ""|' "$CFG"
    /usr/bin/sed -i '' 's/^uset t_limit_fps ".*"/uset t_limit_fps "60"/' "$CFG"
    /usr/bin/sed -i '' 's/^uset t_locked_fps ".*"/uset t_locked_fps "60"/' "$CFG"

    # Rendimiento: ajustes de calidad con mayor coste.
    /usr/bin/sed -i '' 's/^uset r_mirror_view_distance ".*"/uset r_mirror_view_distance "90"/' "$CFG"
    /usr/bin/sed -i '' 's/^uset r_sun_shadow_quality ".*"/uset r_sun_shadow_quality "1"/' "$CFG"
    /usr/bin/sed -i '' 's/^uset r_sun_shadow_texture_size ".*"/uset r_sun_shadow_texture_size "1024"/' "$CFG"
    /usr/bin/sed -i '' 's/^uset r_ssao ".*"/uset r_ssao "1"/' "$CFG"
    /usr/bin/sed -i '' 's/^uset r_aa ".*"/uset r_aa "5"/' "$CFG"

    echo "Perfil de rendimiento aplicado: $CFG"
    echo "  backup: $CFG.bak-perf-$STAMP"
done

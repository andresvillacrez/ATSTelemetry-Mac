#!/bin/bash
# Restaura el config.cfg más reciente guardado por apply-ats-smooth.sh.
set -euo pipefail

if /usr/bin/pgrep -x amtrucks >/dev/null 2>&1 || /usr/bin/pgrep -x eurotrucks2 >/dev/null 2>&1; then
    echo "Cierra ATS/ETS2 antes de restaurar la configuración."
    exit 1
fi

CONFIGS=(
    "$HOME/Library/Application Support/American Truck Simulator/config.cfg"
    "$HOME/Library/Application Support/Euro Truck Simulator 2/config.cfg"
)

for CFG in "${CONFIGS[@]}"; do
    [ -f "$CFG" ] || continue
    SOURCE="$CFG.bak-smooth-original"
    if [ ! -f "$SOURCE" ]; then
        SOURCE="$(/bin/ls -t "$CFG".bak-smooth-* 2>/dev/null | /usr/bin/head -n 1 || true)"
    fi
    if [ -z "${SOURCE:-}" ] || [ ! -f "$SOURCE" ]; then
        echo "Sin backup para: $CFG"
        continue
    fi
    cp -p "$SOURCE" "$CFG"
    echo "Restaurado: $CFG <- $SOURCE"
done

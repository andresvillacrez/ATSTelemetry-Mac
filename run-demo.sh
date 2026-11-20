#!/bin/zsh
# Lanzador: ATS Telemetry en modo demo (datos de prueba)
cd "$(dirname "$0")"
APP="ATS Telemetry.app"
if [ ! -d "$APP" ]; then
  echo "No encuentro $APP. Compila primero con ./build_app.sh"
  exit 1
fi
open "$APP" --args --demo --windowed

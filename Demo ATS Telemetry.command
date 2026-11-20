#!/bin/zsh
cd "$(dirname "$0")"
if [ ! -d "ATS Telemetry.app" ]; then
  echo "Compilando..."
  ./build_app.sh
fi
open "ATS Telemetry.app" --args --demo --windowed

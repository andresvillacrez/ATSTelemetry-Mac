#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Xcode tiene la licencia pendiente en este Mac; el toolchain de CLT compila igual.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"

VERSION="2.7.1"
APP="$ROOT/ATS Telemetry.app"
PLUGIN="$ROOT/Resources/Plugins/libscs-telemetry.dylib"
PKG="$ROOT/ATS-Telemetry-Installer-$VERSION.pkg"
STAGE="${TMPDIR:-/tmp}/ats-telemetry-installer-stage"
SCRIPTS_STAGE="${TMPDIR:-/tmp}/ats-telemetry-installer-scripts"
SCRIPTS="$ROOT/installer"

if [ ! -f "$PLUGIN" ]; then
    echo "Falta el plugin de telemetría: $PLUGIN"
    exit 1
fi

echo "1/4 Compilando la app..."
bash "$ROOT/build_app.sh"

echo "2/4 Preparando el payload del instalador..."
rm -rf "$STAGE" "$SCRIPTS_STAGE"
mkdir -p "$STAGE" "$SCRIPTS_STAGE"

# ditto conserva la estructura del bundle; el chmod se aplica en APFS.
ditto "$APP" "$STAGE/ATS Telemetry.app"
find "$STAGE/ATS Telemetry.app" -type d -exec chmod 755 {} +
find "$STAGE/ATS Telemetry.app" -type f -exec chmod 644 {} +
chmod 755 "$STAGE/ATS Telemetry.app/Contents/MacOS/ATSTelemetry"
chmod 755 "$STAGE/ATS Telemetry.app/Contents/Resources/Plugins/libscs-telemetry.dylib"

cp "$SCRIPTS/preinstall" "$SCRIPTS/postinstall" "$SCRIPTS_STAGE/"
chmod 755 "$SCRIPTS_STAGE/preinstall" "$SCRIPTS_STAGE/postinstall"

echo "   App:  $(stat -f '%Sp' "$STAGE/ATS Telemetry.app/Contents/MacOS/ATSTelemetry")"
echo "   Plugin: $(stat -f '%Sp' "$STAGE/ATS Telemetry.app/Contents/Resources/Plugins/libscs-telemetry.dylib")"

echo "3/4 Creando el paquete .pkg..."
COMPONENT_PLIST="${TMPDIR:-/tmp}/ats-telemetry-component.plist"
pkgbuild --analyze --root "$STAGE" "$COMPONENT_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST" 2>/dev/null || true

rm -f "$PKG"
pkgbuild \
    --root "$STAGE" \
    --component-plist "$COMPONENT_PLIST" \
    --identifier "com.andresvillacrez.atstelemetry.installer" \
    --version "$VERSION" \
    --install-location "/Applications" \
    --ownership recommended \
    --scripts "$SCRIPTS_STAGE" \
    "$PKG"

cat > "$ROOT/LEEME-INSTALADOR.txt" <<'TXT'
ATS Telemetry — Instalador macOS
=================================

Doble clic en ATS-Telemetry-Installer-2.7.1.pkg para instalar.

El instalador:
  1. Copia ATS Telemetry.app a /Applications.
  2. Instala libscs-telemetry.dylib en ATS y ETS2 si están instalados
     y todavía no tienen el plugin.
  3. No sobrescribe un plugin que ya exista.
  4. Cierra ATS Telemetry antes de actualizar la app.

Después de instalar, abre ATS Telemetry y arranca ATS/ETS2.
Si el juego estaba abierto, ciérralo y vuelve a abrirlo para que cargue el plugin.

Registro de instalación del plugin:
  /tmp/ATS-Telemetry-installer.log

Si macOS bloquea el instalador por no estar firmado:
  clic derecho sobre el .pkg > Abrir.

El instalador no instala ETS2; si el juego no está presente, ese paso se omite.
TXT

echo "4/4 Verificando..."
pkgutil --payload-files "$PKG" | /usr/bin/sed -n '1,12p'

echo ""
echo "Instalador listo: $PKG"
ls -lh "$PKG"
cd "$ROOT"
shasum -a 256 "$(basename "$PKG")" | tee "$(basename "$PKG").sha256"

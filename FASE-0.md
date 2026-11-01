# Fase 0 — Preparación y línea base

**Estado:** en curso — preparación completada; build y plugin pendientes en macOS  
**Fecha:** 31/10/2026  
**Base:** `Mac Os` — SwiftUI/AppKit 0.1.0  
**Referencia:** `Windows Native Final` FH6 v2.7

---

## 1. Baseline registrado

| Dato | Valor |
|---|---|
| App | `ATS Telemetry.app` |
| Versión | `0.1.0` (`CFBundleVersion` 1) |
| Arquitectura | `x86_64` |
| Fecha del binario | 23/10/2026 09:39 |
| Tamaño del ejecutable | 955.904 bytes |
| SHA-256 del ejecutable | `0C0E9875ACCE376A68C3FC8A89FEBDA661E45AA13C2513947204A2F55B3BE2E2` |
| Commit base | `2183979c854470631396241775d76e8a014c21cd` |
| Commit corto | `2183979 baseline macOS 0.1.0` |

### Hashes de referencia del fuente

| Archivo | Bytes | SHA-256 |
|---|---:|---|
| `Info.plist` | 1.173 | `3047265048ABA44214C09BEA480E04CF47FFE038AD30F90E23E4F175F5D3F20D` |
| `Package.swift` | 284 | `19F7D4E770FCB92EFBBE8B8E04F0D0F53548107DDD9AA5BF96431C795EBD76AC` |
| `Sources/ATSTelemetry/DashboardView.swift` | 81.310 | `F0FB2621C626CA5014944BDC7E34F7DCA88EC8FB1B53706A0931A21176EAAAC7` |
| `Sources/ATSTelemetry/TelemetryReader.swift` | 14.243 | `402D480AC3DF333C63CED4D42845E398621BBA1ECD04FA4C35E462C19AADFAB3` |
| `Sources/ATSTelemetry/BankBalanceReader.swift` | 16.850 | `A3794AD3114082107BFA9F3F79B86E8CB46192EB350CF5A0A6CEC7AF0ECAF285` |
| `Sources/ATSTelemetry/main.swift` | 4.687 | `3B9A4005CA8F9F25AE3A5A9F2418FD275D9CF65E5D5665C19A533679E2198725` |

### Inventario de assets

| Carpeta | Archivos |
|---|---:|
| `Resources/Indicators` | 14 PNG |
| `Resources/BrandLogos` | 0 (pendiente) |
| `Resources/CompanyLogos` | 0 (pendiente) |
| `Resources/TruckImages` | 0 (pendiente) |

---

## 2. Completado

- [x] **M0-01. Git y baseline.**
  - Repositorio git inicializado en `Mac Os`.
  - Identidad local: `ATS Telemetry <atstelemetry@local>`.
  - `.gitignore` con builds, `.app`, `dist`, `build`, `.DS_Store` y residuos de
    PyInstaller.
  - `.gitattributes` con `eol=lf` para `.sh`, `.swift`, `.md`, `.plist` y `.py`.
  - Commit base `2183979 baseline macOS 0.1.0`.
- [x] **M0-01b. Residuos de PyInstaller identificados.**
  - `main.py` y `TuAplicacion.spec` son un ejemplo ajeno a la app.
  - Se excluyeron del baseline; **no se borraron** del disco.
  - `dist/TuAplicacion.exe` y `build/TuAplicacion` quedan ignorados por
    `dist/` y `build/`.
- [x] **M0-04a. Referencia visual de Windows.**
  - Copiadas `fh6-v27-1920.png` y `fh6-v27-1280.png` a `Mac Os/screenshots/`.
- [x] **M0-05. Decisiones por defecto confirmadas.**
  - Clima manual/inferido; sin clima en vivo en la v2.7 Mac.
  - 30 FPS estables como objetivo; 60 FPS opcional.
  - Avisos del juego incluidos, con posibilidad de posponerlos.
  - Finanzas completas: empresa, logo, conductores y saldo.
  - Tipografía SF Pro/SF Rounded; OFL solo si se exige paridad tipográfica.
  - Binario `x86_64` ahora; universal más adelante.

---

## 3. Pendiente en el Hackintosh

- [ ] **M0-02. Compilar la app actual.**
  - Ejecutar `./build_app.sh`.
  - Abrir `ATS Telemetry.app` en modo demo.
  - Registrar versión de macOS, Swift, Xcode Command Line Tools y GPU.
- [ ] **M0-03. Plugin macOS.**
  - Instalar el build macOS de `truckermudgeon/scs-sdk-plugin` v1.12.1.
  - Verificar `SDK=1` en `/SCSTelemetry`.
  - Probar ATS/ETS2 y confirmar lectura pasiva.
- [ ] **M0-04b. Captura de la app Mac actual.**
  - Capturar la app 0.1.0 en demo a 1920×1080.
  - Guardarla en `Mac Os/screenshots/`.
- [ ] **M0-06. Cierre de Fase 0.**
  - Confirmar que el baseline compila y abre en el Hackintosh.
  - Anotar cualquier diferencia real de pantalla, GPU o plugin.

---

## 4. Comandos para completar en macOS

```zsh
cd "/ruta/a/APP Telemetria/Mac Os"

chmod +x build_app.sh
./build_app.sh
open "ATS Telemetry.app" --args --demo
```

Si el build falla, guardar la salida completa de `swift build` y la versión de
Swift/Xcode:

```zsh
swift --version
xcode-select -p
```

Para el plugin, ajustar la ruta real del juego y el nombre del `.dylib`:

```zsh
mkdir -p "$HOME/Library/Application Support/Steam/steamapps/common/American Truck Simulator/American Truck Simulator.app/Contents/MacOS/plugins"
cp /ruta/al/plugin/scs-telemetry.dylib "$HOME/Library/Application Support/Steam/steamapps/common/American Truck Simulator/American Truck Simulator.app/Contents/MacOS/plugins/"
open "ATS Telemetry.app"
```

Comprobación: con el juego abierto, la app debe mostrar `EN LÍNEA` y recibir
datos. Si no, revisar la ruta del plugin y que `/SCSTelemetry` tenga `SDK=1`.

---

## 5. Notas

- No se modificó código de la app en esta fase.
- El binario `.app` no se versiona en git; el baseline queda reproducible con
  `./build_app.sh`.
- El commit base incluye fuente, assets, documentación, `.gitignore` y
  `.gitattributes`.
- La app actual sigue siendo la red de seguridad hasta que la vista FH6 esté
  validada.

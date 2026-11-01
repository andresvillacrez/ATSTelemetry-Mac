# Historial de creación — ATS Telemetry

Este documento resume el proceso de creación y evolución de la aplicación, las
decisiones importantes y el estado en que quedó el proyecto. Está pensado para
leer el contexto sin tener que reconstruirlo a partir del código.

Última actualización: **31 de octubre de 2026**.

---

## 1. Punto de partida

El objetivo era tener un panel de telemetría para **American Truck Simulator**
(compatible también con ETS2) pensado para el monitor **PM1562** a
**1920×1080**, con fondo negro, sin bordes de ventana y con la información
necesaria para conducir sin apartar la vista de la carretera.

Desde el principio se establecieron dos restricciones:

- La telemetría se lee en modo **solo lectura**.
- No se modifica ni se sustituye el plugin de Ajazz
  (`com.hsgaming.scsmon`) ni `com.hsgaming.vitals`.

En macOS, la fuente de datos es el segmento de memoria POSIX
`/SCSTelemetry`, generado por el plugin de telemetría de SCS. En Windows el
equivalente es el memory-mapped file `Local\SCSTelemetry`.

---

## 2. Primera versión macOS

La app macOS se construyó como una aplicación nativa:

- **SwiftUI** para la composición visual del panel.
- **AppKit** para la ventana borderless, la pantalla PM1562 y el menú de
  estado.
- **Foundation / Darwin** para leer la memoria compartida y descifrar el
  savegame.
- **CommonCrypto** para el contenedor cifrado de los guardados.

La estructura principal quedó así:

```text
Sources/ATSTelemetry/
  main.swift              Ventana, pantalla y menú
  DashboardView.swift     Panel de 1920×1080
  TelemetryReader.swift   Offsets REV12 y lectura de /SCSTelemetry
  BankBalanceReader.swift Savegame, ScsC/BSII y saldo bancario
Resources/Indicators/     Iconos de testigos y diagnóstico
```

La app se dibuja a **12 fotogramas por segundo**, sin cuadrícula de maquetado,
y se coloca automáticamente en la pantalla llamada `PM1562`. Si no la
encuentra, usa la pantalla principal.

### Elementos del panel

- **Velocímetro** analógico de 0 a 160 km/h, con aguja, lectura digital, límite
  de velocidad y odómetro total.
- **Tacómetro** analógico con zona roja, lectura de RPM, indicador de marcha y
  check engine.
- **Fila de 12 testigos** por encima de los relojes, usando los iconos del
  paquete de Ajazz `Truck and Bus Driving Simulator Pack`.
- **Encuadre de viaje** de 220×92 px con distancia recorrida, planificada,
  restante y tiempo estimado.
- **Paneles de daños, carga y GPS** de 400×280 px en la columna derecha.
- **Indicadores redondos** de temperatura de agua y presión de aceite en PSI.
- **Panel financiero** de 200×200 px con ingresos, egresos y dinero total.
- **Panel de combustible** de 200×200 px, con galones estadounidenses.
- **Panel de clima y hora** de 200×200 px.
- **Pie de página** con el estado de la lectura y el modo demo.

Los testigos inactivos se muestran en blanco al 40 %. Baliza, freno de
estacionamiento, bloqueo de diferencial y limpiabrisas pulsan suavemente
cuando están activos.

---

## 3. Decisiones de diseño y ajustes

A lo largo de las iteraciones se tomaron estas decisiones:

1. **Combustible en galones estadounidenses.** La telemetría entrega litros;
   el panel convierte con `1 L = 0,264172 gal`.
2. **Clima limitado por REV12.** La telemetría no expone nubosidad ni
   tormenta. En modo automático solo se puede inferir lluvia cuando los
   limpiabrisas están activos; el resto se fija desde el menú **Clima**.
3. **Check engine por desgaste.** En REV12, `O_ENG` significa motor encendido,
   no el testigo de check engine. El testigo se activa con desgaste del motor
   igual o superior al 5 %.
4. **Odómetro sin rótulo.** Se muestra en el mismo tipo de cuadro que la
   marcha, leyendo `O_ODOMETER = 1056`.
5. **Presión de aceite en PSI.** Sustituyó al antiguo indicador de temperatura
   de aceite para dejar sitio al panel financiero.
6. **Panel de clima a la derecha del combustible.** Ambos quedaron en
   200×200 px para mantener una fila compacta debajo de los relojes.
7. **Ancho fijo del cuadro de marcha.** El indicador de marcha se dibuja en un
   cuadro de 210 px de ancho.
8. **Saldo bancario desde el savegame.** REV12 no expone `bank.money_account`.
   `BankBalanceReader` busca el `game.sii` más reciente, descifra el
   contenedor ScsC, descomprime el BSII y lee `money_account`.
9. **Iconos reutilizados.** Los PNG del paquete de Ajazz se copiaron a
   `Resources/Indicators` para que el panel no dependa de ese plugin en tiempo
   de ejecución.
10. **Títulos compactos y testigos inactivos.** `FINANZAS`, `COMBUSTIBLE` y
    `CLIMA` usan el mismo tamaño y tracking que los paneles grandes y se alinean
    arriba a la izquierda; los testigos inactivos se dibujan en blanco al 40 %.

El saldo se actualiza cuando ATS autoguarda o cuando el jugador hace un
guardado rápido. Mientras no haya un guardado nuevo, se conserva el último
saldo conocido.

---

## 4. Port para Windows

La app original usa AppKit, SwiftUI y memoria compartida POSIX, así que no se
puede compilar tal cual para Windows. Se optó por un **port independiente**, no
por una modificación de la app macOS.

### Enfoque elegido

- **C# / WinForms** sobre **.NET 8** (`net8.0-windows`).
- **SkiaSharp** para dibujar el panel completo en un lienzo virtual de
  1920×1080, con aceleración por hardware.
- El lienzo se escala y se centra en cualquier resolución, conservando la
  relación de aspecto.
- Distribución como **un solo ejecutable autocontenido** para `win-x64`.
- La carpeta `windows/` contiene **fuente + script de compilación**, no un
  binario precompilado.

### Estructura Windows

```text
windows/
  build.ps1                         Compilación y publicación win-x64
  build.bat                         Lanzador de build.ps1
  install-plugin.ps1                Instala el plugin en ATS/ETS2
  install-plugin.bat                Lanzador de install-plugin.ps1
  run.bat                           Ejecuta en PM1562
  run-demo.bat                      Ejecuta en modo demo
  Assets/Indicators/                Iconos compartidos con la app macOS
  Assets/Plugins/                   scs-telemetry.dll (RenCloud v1.12.x)
  README.md                         Guía de compilación y uso
  src/
    ATSTelemetry.Windows.csproj
    Program.cs
    MainForm.cs
    DashboardControl.cs
    TelemetryReader.cs
    BankBalanceReader.cs
    Snap.cs
    app.manifest
```

### Telemetría

`TelemetryReader.cs` usa los mismos offsets de REV12 que la app macOS y el
backend de Ajazz. Intenta abrir, en este orden:

1. `Local\SCSTelemetry`
2. `SCSTelemetry`
3. `Global\SCSTelemetry`

La lectura es pasiva: no escribe en el MMF y no envía teclas al juego.

### Saldo bancario en Windows

`BankBalanceReader.cs` busca el guardado más reciente en:

- `Documentos\American Truck Simulator\profiles`
- `Documentos\American Truck Simulator\steam_profiles`
- Steam Cloud: `<Steam>\userdata\<usuario>\270880\remote\profiles`
- `OneDrive\Documents\American Truck Simulator`
- `OneDrive\Documentos\American Truck Simulator`

La ruta de Steam se obtiene del Registro de Windows y de las ubicaciones
habituales de instalación. El contenedor ScsC se descifra con AES-256-CBC y el
flujo BSII se descomprime con `ZLibStream`, con un respaldo para DEFLATE sin
cabecera.

### Pantalla y controles

- La ventana es borderless, fullscreen, `TopMost` y sin presencia en la barra de
  tareas.
- Busca la pantalla `PM1562` mediante `EnumDisplayDevices`; si no la encuentra,
  usa la principal. También acepta `--screen=...`.
- El icono de la bandeja permite fijar el clima o salir.
- `Ctrl+Shift+Q` cierra la app.
- `--demo` activa datos de prueba y alterna día/noche y los cuatro estados de
  clima.

---

## 5. Verificación realizada

### Compilación Windows

Se instaló temporalmente el SDK **.NET 8.0.426** y se compiló el proyecto desde
macOS usando `EnableWindowsTargeting`. El resultado fue:

```text
Build succeeded.
0 Warning(s)
0 Error(s)
```

Se generó un `ATSTelemetry.exe` autocontenido de aproximadamente 154 MB,
formato `PE32+`, junto con `Assets/Indicators`. Esa compilación de prueba se
dejó en un directorio temporal; **no se copió a `windows/dist`** porque el
proyecto se entrega como fuente + script.

### Parser de saldo

Se probó `SiiBankParser` contra un `game.sii` real de ATS (perfil de Steam
Cloud). El resultado fue:

```text
Balance: 5341147
```

Ese valor coincide con el saldo esperado del guardado utilizado.

### Verificación en Windows real (23/10/2026)

En el equipo con Windows, pantalla PM1562 y ATS 1.61.3.18s:

- Se instaló **.NET SDK 8.0.426 x64** y se compiló con `windows\build.bat` sin
  errores ni advertencias.
- El modo demo se mostró correctamente en PM1562, escalado y centrado.
- Se corrigió la detección de pantalla: `EnumDisplayDevices` devolvía
  `Generic PnP Monitor`; ahora se lee el nombre EDID (`PM1562`) del registro y
  la ventana se reposiciona si cambian las pantallas.
- `SiiBankParser` leyó el guardado real de Steam Cloud:
  **5.353.754** (el valor anterior de referencia era 5.341.147).
- Se copió `scs-telemetry.dll` a `bin\win_x64\plugins` de ATS y ETS2. Tras
  reiniciar ATS, `Local\SCSTelemetry` respondió con `SDK=1`.
- El modo real mostró `PAUSA`, `DINERO TOTAL` y el resto de paneles conectados
  al plugin.

Queda por validar en un trayecto activo: velocidad, RPM, marcha, testigos,
ruta, combustible y actualización del saldo al autoguardar.

### Verificación en Windows real (26/10/2026)

- Se generó la release autocontenida `win-x64` en
  `windows\dist\ATS-Telemetry-Windows\ATSTelemetry.exe`.
- El modo demo se mostró correctamente en la pantalla PM1562.
- Se probó con **ETS2 1.61.1.9** en ejecución: `Local\SCSTelemetry` respondió
  con `SDK=1` y el panel mostró velocidad, RPM, marcha, daños, carga,
  combustible, clima, ruta y GPS en vivo.
- Se corrigió la codificación UTF-8 de los textos del panel (por ejemplo,
  `LÍMITE`, `DAÑOS`, `SEÑAL`) y el solapamiento entre el valor grande y su
  unidad (`80` / `km/h`).
- `BankBalanceReader` ahora distingue entre ATS y ETS2 y lee el savegame del
  juego activo. En ETS2 mostró el saldo correcto del perfil
  (**203.752.550**), no el de ATS.
- El plugin `scs-telemetry.dll` está instalado en
  `bin\win_x64\plugins` de ATS y ETS2.
- Se diseñó un icono propio (velocímetro cian con zona roja) y se incrustó en
  `ATSTelemetry.exe`; la ventana y la bandeja usan el mismo icono.
- `build.ps1` genera la carpeta portátil completa con los lanzadores
  `Iniciar ATS Telemetry.bat`, `Iniciar en modo demo.bat`,
  `Instalar plugin en ATS y ETS2.bat`, el icono y `LEEME.txt`. Se verificó que
  el lanzador de demo y el de telemetría en vivo abren el panel en PM1562.
- La misma carpeta se publica como `dist\ATS-Telemetry-Windows.zip` para
  copiarla a otra ubicación.
- Se abrió **ATS 1.61.3.18** (`GAME=2`, `SDK=1`) y el panel mostró el
  **Peterbilt 389**, 650 RPM, 67 % de combustible, 30 °C de agua, 57 PSI,
  daños 5 %, GPS y el saldo correcto de ATS (**4.222.132**), sin mostrar el
  saldo de ETS2.

Queda pendiente comprobar en movimiento la velocidad, la marcha, la ruta y la
actualización del saldo tras un guardado rápido.

---

## 6. Cómo compilar y ejecutar

### macOS

```zsh
./build_app.sh
open "ATS Telemetry.app"
```

Modo demo:

```zsh
open "ATS Telemetry.app" --args --demo
```

### Windows

En un PC Windows con .NET 8 SDK x64:

```bat
windows\build.bat
```

El ejecutable queda en:

```text
windows\dist\ATS-Telemetry-Windows\ATSTelemetry.exe
```

Ejecutar:

```bat
windows\run.bat
```

Modo demo:

```bat
windows\run-demo.bat
```

---

## 7. Estado actual

- La app macOS existente se conserva y no se modificó durante el port.
- El port Windows compila sin advertencias ni errores.
- Tasa de refresco optimizada a **60 FPS estables** (16 ms) mediante
  aceleración por hardware con SkiaSharp/OpenGL.
- El panel demo y el modo real se validaron en la pantalla PM1562.
- El plugin `scs-telemetry.dll` está incluido en la app y se instaló en ATS y
  ETS2; `Local\SCSTelemetry` respondió con `SDK=1`.
- El parser de saldo funciona con los savegames reales de ATS y ETS2, y elige
  el juego activo.
- La carpeta `windows/` contiene fuente, plugin e instalador.
- ETS2 quedó validado en marcha el 26/10/2026.
- Falta la prueba en marcha con ATS y comprobar el cambio de **DINERO TOTAL**
  tras un guardado rápido.

### Siguientes pasos recomendados

1. Repetir la trayectoria en ATS y comprobar velocidad, RPM, marcha, testigos,
   ruta y combustible.
2. Hacer un guardado rápido en ATS y verificar que **DINERO TOTAL** cambia.
3. Ajustar posiciones o tamaños si la pantalla real lo requiere.

---

## 8. Documentos relacionados

- [`README.md`](README.md): estado, uso y plan de la app macOS.
- [`PLAN-TRABAJO.md`](PLAN-TRABAJO.md): plan por fases de la migración a FH6 v2.7.
- [`../Windows Native Final/README.md`](../Windows%20Native%20Final/README.md):
  documentación de la app Windows v2.7.
- `Sources/ATSTelemetry/DashboardView.swift`: implementación visual actual
  (pre-FH6).
- `../Windows Native Final/src/DashboardRenderer.cs`: referencia visual y de
  comportamiento de FH6 v2.7.

---

## 9. Plan de migración macOS FH6 v2.7 (31/10/2026)

La app macOS se conservó sin cambios durante el port Windows y quedó en la
versión **0.1.0**, anterior al rediseño FH6. El 31/10/2026 se decidió continuar
el desarrollo sobre la base nativa **SwiftUI/AppKit** y portar la interfaz y el
comportamiento de la **FH6 v2.7**, en lugar de portar WinForms o ejecutar la app
Windows con Wine.

La decisión se apoya en que la app Mac ya resuelve la lectura POSIX de
`/SCSTelemetry`, la ventana AppKit, el menú de barra y el savegame ScsC/BSII.
El trabajo pendiente es la capa visual FH6, los assets compartidos y algunos
datos del perfil.

El plan por fases, los criterios de aceptación, la matriz de pruebas y los
riesgos están en [`PLAN-TRABAJO.md`](PLAN-TRABAJO.md).

**Estado:** planificado; no se han hecho cambios de código todavía.

# ATS Telemetry para macOS

Panel nativo de telemetría para **American Truck Simulator (ATS)** y
**Euro Truck Simulator 2 (ETS2)**, pensado para el monitor **PM1562** a
**1920×1080**. Lee `/SCSTelemetry` en modo **solo lectura** y no modifica los
plugins de Ajazz.

> **Estado (31/10/2026):** esta carpeta contiene la base nativa macOS **0.1.0**,
> anterior al rediseño FH6. El objetivo activo es llevarla a **FH6 v2.7**,
> usando `Windows Native Final` como referencia visual y de comportamiento.
> El plan por fases está en [`PLAN-TRABAJO.md`](PLAN-TRABAJO.md) y el estado de
> la preparación en [`FASE-0.md`](FASE-0.md).
>
> La sección [Funcionalidad actual](#funcionalidad-actual-010) describe la
> versión 0.1.0; **no** es el estado final. Las diferencias con la v2.7 están
> resumidas más abajo.

---

## Objetivo

Llevar la app Mac a paridad con la **FH6 v2.7** de Windows conservando el host
nativo SwiftUI/AppKit y la lectura pasiva de `/SCSTelemetry`:

- Layout FH6 de 1920×1080: cabecera, 13 testigos, cluster central, paneles
  laterales, indicadores verticales de agua/aire y franja inferior.
- **CHECK** oculto sin motor, blanco con motor y amarillo con avería.
- **Chip de crucero** siempre visible: gris con `-- km/h` inactivo y verde con
  la velocidad fijada activo.
- **Combustible** encendido sin motor.
- **45 imágenes** de camiones con fundido de 0,5 s al cambiar de modelo.
- **Telemetría pasiva**: solo lectura de `/SCSTelemetry`.
- Empresa, logo y saldo desde el savegame/perfil.

No se portan WinForms, Avalonia ni Wine en esta fase.

---

## Estado actual

- Aplicación nativa **SwiftUI + AppKit**, `Package.swift` con macOS 14+.
- Binario existente `x86_64`; app `0.1.0`.
- Lectura POSIX de `/SCSTelemetry` y descifrado del savegame ScsC/BSII.
- Renderizado a **12 FPS** con el layout anterior a FH6.
- 14 iconos en `Resources/Indicators`; sin fotos de camiones ni logos.
- Git inicializado con el commit base `2183979 baseline macOS 0.1.0`; el
  binario `.app`, `build/` y `dist/` están ignorados.
- Fase 0 en curso: preparación completada; faltan build, captura Mac y prueba
  del plugin en el Hackintosh.

La app compilada actual sirve como **línea base** y red de seguridad. La
migración se hará sin romperla hasta que la nueva vista FH6 esté validada.

---

## Diferencias con Windows v2.7

| Área | macOS 0.1.0 | Objetivo FH6 v2.7 |
|---|---|---|
| Cabecera | Texto ATS + camión | Logo de marca + camión + cilindrada + estado + monitor |
| Testigos | 12 iconos, fila antigua | 13 puestos con CHECK, retarder y freno de motor |
| Cluster | Dos relojes separados | Arco de 224°, número 184 px, chip de crucero, marcha, RPM y odómetro |
| Laterales | Finanzas 200×200, daños 400×280 | Empresa/carga a la izquierda; daños con imagen y GPS a la derecha |
| Indicadores | Agua y aceite redondos | Agua y aire verticales de 88×440 |
| Franja inferior | Combustible y clima 200×200 | Combustible 240×142, avisos 438×142, clima 237×142 |
| Imagen del camión | No existe | 45 JPG, fundido de 0,5 s y fallback |
| Empresa | Solo nombre en finanzas | Nombre, logo real y conductores desde `profile.sii` |
| Encendido | Sin secuencia global | Chequeo de testigos 1,25 s y barrido de agujas/indicadores |
| Avisos | No existe | Mensajes de entregas, multas, peajes, etc. |
| Rendimiento | 12 FPS | 30/60 FPS |
| Ventana | Solo PM1562, borderless | Selector de pantalla, modo ventana/F11 y preferencias |

La referencia exacta de coordenadas, colores y métodos está en
[`Windows Native Final/GUIA-INTERFAZ.md`](../Windows%20Native%20Final/GUIA-INTERFAZ.md)
y en la captura
[`fh6-v27-1920.png`](../Windows%20Native%20Final/screenshots/fh6-v27-1920.png).

---

## Requisitos

- macOS 14 o superior (Hackintosh Intel; el binario actual es `x86_64`).
- Xcode Command Line Tools / Swift 5.9 o superior.
- ATS o ETS2 con el plugin de telemetría macOS instalado.
- No requiere .NET, Wine ni Avalonia.

---

## Compilar y ejecutar

```zsh
chmod +x build_app.sh
./build_app.sh
open "ATS Telemetry.app"
```

Modo demo, sin juego:

```zsh
open "ATS Telemetry.app" --args --demo
```

En modo demo se alternan la hora del juego y los estados de clima para validar
los iconos de día y de noche. En modo real, el clima se infiere de los
limpiabrisas o se fija desde el menú **Clima**.

> `build_app.sh` copia actualmente solo `Resources/Indicators`. La Fase 5 del
> plan amplía el script para copiar también logos y fotos de camiones.

---

## Plugin de telemetría en macOS

La app lee el segmento POSIX `/SCSTelemetry`. El plugin debe estar en la carpeta
`plugins` dentro del paquete de la aplicación del juego:

```text
American Truck Simulator.app/Contents/MacOS/plugins/
Euro Truck Simulator 2.app/Contents/MacOS/plugins/
```

Para macOS se puede usar el build de
[`truckermudgeon/scs-sdk-plugin`](https://github.com/truckermudgeon/scs-sdk-plugin)
(v1.12.1). Verificar que cargue en la versión actual del juego; si el ABI cambió,
hay que recompilarlo desde el código fuente.

Comprobación rápida: con el juego abierto, la app debe mostrar `EN LÍNEA` y el
panel debe recibir datos. Si no, revisar la ruta del plugin y que
`/SCSTelemetry` tenga `SDK=1`.

---

## Menú actual

- **Clima**: Automático (lluvia por limpiabrisas), Despejado, Nublado, Lluvia o
  Tormenta.
- **Salir**: cierra la app.

Se usa el icono de la app en la barra de menús. El selector de pantalla y el
modo ventana/F11 están planificados para la Fase 5.

---

## Funcionalidad actual (0.1.0)

- Velocímetro analógico de 0 a 160 km/h, aguja, lectura digital, límite de
  velocidad y odómetro total.
- Tacómetro analógico con zona roja, RPM, marcha y check engine por desgaste.
- Fila de 12 testigos con iconos del paquete de Ajazz.
- Encuadre de viaje de 220×92 px.
- Paneles de daños, carga y GPS de 400×280 px.
- Indicadores redondos de agua y presión de aceite.
- Panel financiero de 200×200 px y panel de combustible de 200×200 px.
- Panel de clima y hora del juego.
- Pie con estado de lectura y modo demo.
- Saldo bancario desde `bank.money_account` del savegame más reciente.

Los detalles de la versión 0.1.0 están en [`HISTORIAL.md`](HISTORIAL.md).

---

## Estructura

```text
Mac Os/
  Sources/ATSTelemetry/
    main.swift              Ventana, pantalla y menú
    DashboardView.swift     Panel actual (pre-FH6)
    TelemetryReader.swift   Offsets REV12 y lectura de /SCSTelemetry
    BankBalanceReader.swift Savegame, ScsC/BSII y saldo
  Resources/Indicators/     Iconos de testigos
  screenshots/              Referencias visuales de FH6 v2.7
  ATS Telemetry.app         App compilada actual (x86_64)
  build_app.sh              Compilación y empaquetado
  Info.plist                Metadatos del bundle
  PLAN-TRABAJO.md           Plan por fases
  FASE-0.md                 Registro de la preparación y línea base
  README.md                 Este documento
  HISTORIAL.md              Historial de decisiones y pruebas
```

La estructura objetivo añade `Snap.swift`, `ProfileReader.swift`,
`SiiParser.swift`, `TruckCatalog.swift`, `TelemetryStore.swift` y la carpeta
`Fh6/` con el renderer. Está detallada en
[`PLAN-TRABAJO.md`](PLAN-TRABAJO.md#5-arquitectura-objetivo).

---

## Plan de trabajo (resumen)

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Baseline, git, plugin macOS, capturas | En curso |
| 1 | Refactor, tema, layout, telemetry store | Pendiente |
| 2 | Shell visual FH6 | Pendiente |
| 3 | Assets y reglas v2.7 (CHECK, crucero, fundido) | Pendiente |
| 4 | Empresa, logo, conductores y retarder | Pendiente |
| 5 | Pantalla, ventana, rendimiento y empaquetado | Pendiente |
| 6 | Release, documentación y tag `mac-v2.7.0` | Pendiente |

El detalle, los criterios de aceptación, la matriz de pruebas y los riesgos
están en [`PLAN-TRABAJO.md`](PLAN-TRABAJO.md).

---

## Pruebas

La app Mac se compiló por última vez el 23/10/2026. **No se ha validado en vivo
en este equipo Windows**; la Fase 0 debe confirmar en el Hackintosh:

- Apertura de la app y colocación en la pantalla correcta.
- Carga del plugin y lectura de `/SCSTelemetry`.
- Saldo del savegame de ATS/ETS2.
- Demo a 1920×1080 y 1280×720.

La matriz completa de pruebas de la migración está en
[`PLAN-TRABAJO.md`](PLAN-TRABAJO.md#7-matriz-de-pruebas).

---

## Windows v2.7 como referencia

El desarrollo activo de Windows vive en
[`Windows Native Final`](../Windows%20Native%20Final/README.md). Allí están la
interfaz FH6 v2.7, los 45 JPG de camiones, los logos y la guía de coordenadas.
La app Mac **no** modifica ese proyecto; solo reutiliza sus assets y su
especificación visual.

---

## Ajustes de noche de ATS/ETS2

Los ajustes de iluminación nocturna aplicados a los juegos están documentados
en [`ajustes-noche/README.md`](ajustes-noche/README.md), con las líneas exactas
de `config.cfg` y las copias de seguridad. No forman parte de la app; son notas
para reproducir la configuración en el Hackintosh.

---

## Historial

El proceso de creación, las decisiones de diseño y el estado de las pruebas de
la versión 0.1.0 están documentados en [`HISTORIAL.md`](HISTORIAL.md). La
migración a FH6 v2.7 se registra en
[`PLAN-TRABAJO.md`](PLAN-TRABAJO.md).

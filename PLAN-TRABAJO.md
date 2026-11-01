# Plan de trabajo — ATS Telemetry macOS FH6 v2.7

**Proyecto:** ATS Telemetry para macOS  
**Base de código:** `Mac Os` — SwiftUI/AppKit 0.1.0  
**Referencia visual y de comportamiento:** `Windows Native Final` v2.7 (FH6)  
**Estado:** Fase 0 en curso — preparación completada; build y plugin pendientes en macOS  
**Última actualización:** 31/10/2026

---

## 1. Objetivo

Llevar la app nativa de macOS desde su estado actual (0.1.0, anterior al rediseño
FH6) a una versión equivalente a la **FH6 v2.7** de Windows, conservando:

- Lectura **pasiva** de `/SCSTelemetry` en modo solo lectura.
- Ventana nativa AppKit, sin bordes, en la pantalla del panel.
- Lectura del saldo bancario desde el savegame.
- Menú de barra y preferencias de pantalla/clima.
- Assets compartidos con la versión Windows (iconos, logos y fotos).

La app Mac **no se reescribe desde cero**. Se conserva el host SwiftUI/AppKit y
se sustituye la capa visual por el layout FH6, reutilizando `TelemetryReader` y
`BankBalanceReader`.

### Fuera de alcance en esta fase

- Portar WinForms, Avalonia o Wine.
- Leer el clima en vivo con offsets de Windows.
- Modificar el repositorio `Windows Native Final`.
- Escribir en la memoria del juego o en los savegames.

---

## 2. Decisiones de arquitectura

1. **Host nativo:** SwiftUI + AppKit. Es la opción con mejor integración en
   macOS/Hackintosh y reutiliza la lectura POSIX ya probada.
2. **Fuente de verdad visual:** `Windows Native Final/GUIA-INTERFAZ.md` y la
   captura `screenshots/fh6-v27-1920.png`. Las coordenadas son las mismas:
   lienzo virtual de **1920×1080** escalado y centrado.
3. **Renderizado:** un único `Canvas` de 1920×1080 (o un `ZStack` con posiciones
   absolutas) para que las coordenadas coincidan con FH6. Evitar anidar muchos
   `HStack`/`VStack` para el layout principal.
4. **Datos:** mantener `TelemetryReader.swift` y `BankBalanceReader.swift`;
   extraer un modelo `Snap` y añadir solo los campos que falten.
5. **Rendimiento:** lectura de telemetría a 10–20 Hz y dibujo a 30 FPS como
   objetivo estable; 60 FPS solo si el Hackintosh lo mantiene sin tirones.
6. **Assets:** copiar los 45 JPG, 14 logos de marca, 8 logos de empresa y los
   iconos nuevos desde `Windows Native Final/Assets`. Los nombres son únicos;
   se pueden copiar planos a `Contents/Resources` para conservar el loader
   actual basado en `Bundle.main.url(forResource:)`.
7. **Clima:** se mantiene manual y, como mucho, inferido por limpiabrisas. El
   clima en vivo de Windows depende de `ReadProcessMemory` y offsets de Windows;
   no forma parte del criterio de aceptación de la v2.7 Mac.

---

## 3. Definición de terminado

La migración se considera terminada cuando:

- [ ] `./build_app.sh` compila sin errores ni advertencias nuevas.
- [ ] `ATS Telemetry.app` abre en el Hackintosh y se coloca en la pantalla
      configurada.
- [ ] Lee `/SCSTelemetry` con `SDK=1` en modo solo lectura.
- [ ] Funciona en demo y con ATS/ETS2 reales.
- [ ] El layout FH6 se ve correctamente a 1920×1080 y 1280×720.
- [ ] El CHECK se oculta sin motor, aparece blanco con motor y amarillo con
      avería.
- [ ] El chip de crucero está siempre visible: gris con `-- km/h` inactivo y
      verde con la velocidad fijada activo.
- [ ] La tarjeta de combustible sigue encendida sin motor.
- [ ] La imagen del camión hace fundido de 0,5 s al cambiar de modelo.
- [ ] Los 45 modelos oficiales tienen imagen y fallback textual.
- [ ] El saldo, la empresa y el logo se leen del perfil correcto (ATS/ETS2).
- [ ] No hay regresiones en la lectura pasiva ni en el savegame.
- [ ] `README.md`, `PLAN-TRABAJO.md` y `HISTORIAL.md` están sincronizados.
- [ ] La versión del bundle es `2.7.0` y existe un tag de git.

---

## 4. Línea base y brechas

### Estado actual de `Mac Os`

- SwiftUI/AppKit, `Package.swift` con macOS 14+.
- Binario existente `x86_64`, app `0.1.0`.
- 12 FPS, layout anterior a FH6.
- 14 iconos en `Resources/Indicators`.
- Sin fotos de camiones, sin logos de marca/empresa y sin franja de avisos.
- `TelemetryReader` lee `/SCSTelemetry`; `BankBalanceReader` lee el saldo.
- No hay git inicializado en la carpeta.

### Brechas principales

| Área | Mac 0.1.0 | Objetivo FH6 v2.7 |
|---|---|---|
| Cabecera | Texto ATS + camión | Logo de marca + camión + cilindrada + estado + monitor |
| Testigos | 12 iconos, fila antigua | 13 puestos, CHECK integrado, retarder y freno de motor |
| Cluster | Dos relojes separados | Arco de 224°, número 184 px, chip de crucero, marcha, RPM, odómetro y testigos de batería/aceite |
| Laterales | Finanzas 200×200, daños 400×280 | Empresa/carga a la izquierda; daños con imagen y GPS a la derecha |
| Indicadores | Agua y aceite redondos | Agua y aire verticales de 88×440 |
| Franja inferior | Combustible y clima 200×200 | Combustible 240×142, avisos 438×142, clima 237×142 |
| Imagen del camión | No existe | 45 JPG, fundido de 0,5 s y fallback |
| Empresa | Solo nombre en finanzas | Nombre, logo real y conductores desde `profile.sii` |
| Encendido | Sin secuencia global | Chequeo de testigos 1,25 s y barrido de agujas/indicadores |
| Avisos | No existe | Mensajes de entregas, multas, peajes, etc. |
| Rendimiento | 12 FPS | 30/60 FPS |
| Ventana | Solo PM1562, borderless | Selector de pantalla, modo ventana/F11 y preferencias |

---

## 5. Arquitectura objetivo

La estructura propuesta evita un `DashboardView.swift` de más de 150 KB y separa
datos, layout, dibujo y assets:

```text
Sources/ATSTelemetry/
  main.swift                  Ventana, pantalla, menú y preferencias
  Snap.swift                  Modelo de una muestra de telemetría
  TelemetryReader.swift       Lectura POSIX /SCSTelemetry
  BankBalanceReader.swift     Savegame, saldo y perfil
  ProfileReader.swift         Empresa, logo y conductores (nuevo)
  SiiParser.swift             Parser SII/BSII compartido (nuevo)
  TruckCatalog.swift          Mapa TruckId → imagen (nuevo)
  TelemetryStore.swift        Polling y publicación del snapshot (nuevo)
  DashboardView.swift         Host de la vista actual
  Fh6/
    Fh6DashboardView.swift    Composición 1920×1080
    Fh6Theme.swift            Colores, fuentes y medidas
    Fh6Layout.swift           Coordenadas de la guía
    Fh6Renderer.swift         Dibujo del cluster y paneles
    Fh6Components.swift       Tarjetas, filas, iconos y ayudas
Resources/
  Indicators/                 Iconos de testigos
  BrandLogos/                 Logos de marca
  CompanyLogos/               Logos de empresa
  TruckImages/                45 JPG + README.txt
```

> Los nombres exactos pueden ajustarse durante la Fase 1, pero la separación por
> responsabilidades se mantiene.

---

## 6. Fases y pasos

### Fase 0 — Preparación y línea base

**Objetivo:** tener una red de seguridad y confirmar que la base actual funciona
antes de tocar código.

- [x] **M0-01. Git y baseline.** Repositorio inicializado, `.gitignore` y
      `.gitattributes` añadidos, commit `2183979 baseline macOS 0.1.0`.
      `main.py` y `TuAplicacion.spec` se excluyeron del baseline por ser un
      ejemplo de PyInstaller ajeno a la app; no se borraron del disco.
- [ ] **M0-02. Compilar la app actual.** Ejecutar `./build_app.sh` y abrir
      `ATS Telemetry.app` en modo demo. Registrar versión de macOS, Swift y GPU.
      **Pendiente en el Hackintosh.**
- [ ] **M0-03. Plugin macOS.** Instalar el build macOS de
      `truckermudgeon/scs-sdk-plugin` v1.12.1 en
      `<juego>.app/Contents/MacOS/plugins` y verificar `SDK=1` en
      `/SCSTelemetry`. Si el juego no está disponible, dejar constancia y usar
      demo. **Pendiente en el Hackintosh.**
- [ ] **M0-04. Capturas de referencia.** Referencia Windows copiada a
      `screenshots/` (`fh6-v27-1920.png` y `fh6-v27-1280.png`). Falta la
      captura de la app Mac actual en el Hackintosh.
- [x] **M0-05. Cerrar decisiones abiertas.** Confirmados clima manual/inferido,
      30 FPS estables (60 opcional), avisos incluidos, finanzas completas,
      tipografía SF y binario `x86_64` por ahora.

**Criterio de aceptación:** la app actual compila, abre y (si hay juego) recibe
telemetría; existe un commit base y capturas de referencia.

**Estado actual:** preparación completada (git, `.gitignore`, referencias y
decisiones). Pendiente el build, la captura Mac y la prueba del plugin en el
Hackintosh. El registro detallado está en [`FASE-0.md`](FASE-0.md).

**Estimación:** 0,5–1 día.

---

### Fase 1 — Refactor de base

**Objetivo:** preparar la app para el nuevo layout sin cambiar el comportamiento
visible.

- [ ] **M1-01. Extraer `Snap`.** Mover el modelo desde `TelemetryReader.swift` a
      `Snap.swift`; conservar todos los campos y valores por defecto.
- [ ] **M1-02. `TelemetryStore`.** Crear un `ObservableObject` que lea la
      telemetría a 10–20 Hz y publique un snapshot inmutable. La vista no debe
      leer la memoria compartida en cada frame.
- [ ] **M1-03. `Fh6Theme`.** Extraer colores, fuentes, radios y medidas de
      `GUIA-INTERFAZ.md`/`DashboardRenderer.cs`. Usar SF Pro/SF Rounded o una
      fuente OFL si se decide paridad tipográfica.
- [ ] **M1-04. `Fh6Layout`.** Trasladar las coordenadas de la guía a constantes
      (`header`, `indicatorRow`, `cluster`, `water`, `air`, paneles y tarjetas).
- [ ] **M1-05. `AssetCatalog`.** Loader con caché para iconos, logos y fotos;
      soportar recursos planos en `Contents/Resources`.
- [ ] **M1-06. Esqueleto FH6.** Crear `Fh6DashboardView` con un `Canvas` negro de
      1920×1080 y el fondo. Mantener la vista antigua compilando hasta que la
      nueva esté validada.
- [ ] **M1-07. Prueba de regresión.** La app antigua debe seguir abriendo y
      mostrando datos; el nuevo esqueleto se selecciona solo con un flag interno
      o una variable de desarrollo.

**Criterio de aceptación:** compila; la app antigua no cambia; el nuevo canvas
se dibuja a 1920×1080 y escala sin deformarse.

**Estimación:** 1–2 días.

---

### Fase 2 — Shell visual FH6

**Objetivo:** reproducir la composición de la v2.7 con datos reales, todavía sin
las reglas finas de encendido.

- [ ] **M2-01. Cabecera.** Logo de marca, camión, cilindrada, estado, monitor y
      línea inferior en `y = 92`.
- [ ] **M2-02. Fila de testigos.** 13 puestos con iconos de 32 px y separación de
      18 px; primero estáticos, después conectados al `Snap`.
- [ ] **M2-03. Cluster central.** Arco de 224°, número de velocidad, marcha, barra
      de RPM, odómetro y chip de crucero (placeholder).
- [ ] **M2-04. Indicadores verticales.** Agua en `486, 300` y aire en
      `1346, 300`, ambos de 88×440, con escalas 40–120 °C y 0–120 PSI.
- [ ] **M2-05. Paneles izquierdos.** Empresa y carga con las medidas de la guía.
- [ ] **M2-06. Paneles derechos.** Daños (sin imagen todavía) y GPS con rumbo,
      origen, destino, distancias, llegada y posición.
- [ ] **M2-07. Franja inferior y pie.** Combustible, avisos, clima y footer.
- [ ] **M2-08. Ajuste visual.** Comparar con la captura de referencia; corregir
      coordenadas, tamaños y márgenes. No hace falta pixel-perfect por fuentes,
      pero sí que la composición coincida.

**Criterio de aceptación:** demo a 1920×1080 y 1280×720 con la composición FH6;
sin crashes; los datos existentes se muestran en su nuevo sitio.

**Estimación:** 3–5 días.

---

### Fase 3 — Assets y comportamiento v2.7

**Objetivo:** completar la parte que hace que la app se sienta v2.7.

- [ ] **M3-01. Copiar assets.** 45 JPG de `TruckImages`, 14 logos de
      `BrandLogos`, 8 de `CompanyLogos` y los iconos nuevos
      (`check-engine-line`, `engine-brake-round`, `retarder-c`). Validar conteos.
- [ ] **M3-02. `TruckCatalog`.** Normalizar `TruckId`
      (`vehicle.kenworth.w900` → `kenworth_w900`), quitar variantes
      `_gtm`/`_mod`/`_custom` y usar `TruckBrand` + `TruckName` como respaldo.
      Demo: W900.
- [ ] **M3-03. Imagen del camión.** Dibujarla en el área inferior del panel de
      daños, centrada, proporcional, con 8 px de margen y esquinas redondeadas.
      Fundido cruzado de 0,5 s; primera carga inmediata; fallback textual.
- [ ] **M3-04. CHECK.** Sin motor no se dibuja; con motor y sin avería, icono y
      texto en blanco; con `EngineDmg >= 5`, amarillo. Integrarlo en la fila de
      13 puestos.
- [ ] **M3-05. Crucero.** Chip siempre visible: inactivo gris con `-- km/h`;
      activo verde con la velocidad fijada.
- [ ] **M3-06. Combustible.** La tarjeta no debe apagarse con el motor; conservar
      nivel, galones, autonomía y barra. Verificar que la condición sea
      `snap.active`, no `snap.engine`.
- [ ] **M3-07. Secuencia de encendido.** Chequeo de testigos 1,25 s y barrido de
      agujas/indicadores (0,90 s subida + 0,15 s mantenido + 1,05 s bajada).
- [ ] **M3-08. Avisos.** Detectar cambios de ingresos, entregas, multas, peajes,
      ferry y tren; mostrar 2,5 s con 0,5 s de fundido. Si se decide reducir
      alcance, dejar `SIN AVISOS` y documentarlo.
- [ ] **M3-09. Escenarios demo.** Añadir flags para probar sin juego:
      `--demo-engine-off`, `--demo-check-yellow`, `--demo-cruise-off`,
      `--demo-truck=<id>`.

**Criterio de aceptación:** matriz de pruebas de la sección 7 superada en demo y,
si es posible, en vivo.

**Estimación:** 3–5 días.

---

### Fase 4 — Paridad de datos

**Objetivo:** completar la información que la v2.7 muestra y la Mac todavía no
lee.

- [ ] **M4-01. Retarder.** Añadir el offset `108` (`truck_ui.retarderBrake`) al
      `Snap` y al testigo correspondiente.
- [ ] **M4-02. Parser SII compartido.** Extraer de `BankBalanceReader` la lectura
      de SII/BSII a `SiiParser.swift` para reutilizarla en `profile.sii`.
- [ ] **M4-03. `ProfileReader`.** Localizar el `profile.sii` junto al `game.sii`
      más reciente; leer `company_name` y `logo` (`logo_0..logo_7`).
- [ ] **M4-04. Conductores.** Leer `driver_ai` y
      `profit_log_entry.revenue`; contar conductores y sumar ingresos, sin
      incluir al jugador.
- [ ] **M4-05. Panel de finanzas FH6.** Trabajo actual, conductores, egresos de
      ruta, ganancia neta, dinero total y margen operativo.
- [ ] **M4-06. Clima.** Mantener manual + inferencia por limpiabrisas; etiquetar
     claramente el modo automático. No prometer clima en vivo.
- [ ] **M4-07. Preferencias.** `UserDefaults` para clima, pantalla y modo de
      ventana; restaurar al abrir.

**Criterio de aceptación:** ATS y ETS2 muestran empresa, logo, conductores y
saldo correctos; el saldo se actualiza tras un guardado; no se escribe nada.

**Estimación:** 3–5 días.

---

### Fase 5 — Ventana, rendimiento y empaquetado

**Objetivo:** convertir el port en una app usable a diario en el Hackintosh.

- [ ] **M5-01. Selector de pantalla.** Listar `NSScreen.screens`, guardar un UUID
      de pantalla y recordar la elección; fallback a la principal.
- [ ] **M5-02. Modo ventana/F11.** Alternar borderless/fullscreen y ventana
      normal; guardar la preferencia. Mantener `ignoresMouseEvents` solo en modo
      dashboard.
- [ ] **M5-03. Rendimiento.** Medir CPU/GPU a 30 y 60 FPS; usar un solo Canvas,
      cachear imágenes y evitar recalcular formateadores por frame. Objetivo:
      30 FPS estables; 60 solo si no hay tirones.
- [ ] **M5-04. `build_app.sh`.** Copiar todos los assets a `Contents/Resources`
      (plano o con subcarpetas, según el loader). Añadir compilación universal
      `x86_64 + arm64` si se quiere compatibilidad futura.
- [ ] **M5-05. Versión y firma.** `CFBundleShortVersionString = 2.7.0`,
      `CFBundleVersion` incremental, firma ad-hoc y nota de Gatekeeper.
- [ ] **M5-06. QA final.** 1920×1080, 1280×720, multi-monitor, demo/live, motor
      apagado/encendido, CHECK blanco/amarillo, crucero inactivo/activo, cambio
      de camión, clima manual, saldo tras guardado.

**Criterio de aceptación:** release candidate estable en el Hackintosh, sin
regresiones de telemetría ni del savegame.

**Estimación:** 2–4 días.

---

### Fase 6 — Cierre y release

- [ ] **M6-01. Documentación.** Actualizar `README.md`, `PLAN-TRABAJO.md` y
      `HISTORIAL.md` con el estado real, capturas y limitaciones.
- [ ] **M6-02. Tag.** Crear `mac-v2.7.0` sobre el commit de release.
- [ ] **M6-03. Paquete.** Generar `.app` y ZIP de distribución; incluir
      instrucciones del plugin macOS.
- [ ] **M6-04. Validación final.** Repetir la matriz de pruebas en el Hackintosh
      y archivar capturas 1920/1280.

**Estimación:** 1–2 días.

---

## 7. Matriz de pruebas

| Caso | Preparación | Resultado esperado |
|---|---|---|
| Demo básica | `--demo` | Panel completo, datos coherentes, sin crashes |
| Sin motor | `--demo-engine-off` o juego apagado | CHECK oculto; crucero gris `-- km/h`; combustible encendido; testigos apagados |
| Motor sin avería | Juego con motor encendido | CHECK blanco; crucero gris/activo según ajuste; combustible encendido |
| Motor con avería | Desgaste de motor ≥ 5 % | CHECK amarillo, con pulso |
| Crucero inactivo | Sin crucero | Chip visible, gris, `-- km/h` |
| Crucero activo | Crucero fijado | Chip verde con velocidad |
| Cambio de camión | Cambiar `TruckId` en demo o juego | Fundido de 0,5 s; primera carga inmediata |
| Modelo sin imagen | `--demo-truck=modelo_desconocido` | Fallback textual, sin crash |
| ATS | ATS en marcha | Empresa/logo/saldo de ATS |
| ETS2 | ETS2 en marcha | Empresa/logo/saldo de ETS2 |
| Guardado | Guardado rápido | Saldo actualizado tras el guardado |
| Pantalla | 1920×1080 y 1280×720 | Escalado y centrado correctos |
| Multi-monitor | Dos pantallas | Selección y restauración correctas |
| Sin plugin | Juego cerrado | Placeholders, sin crash, reintento |
| Clima manual | Menú Clima | Estado fijo y persistente |
| Clima automático | Limpiabrisas | Lluvia inferida; resto manual |
| Pasivo | Inspección de código | `shm_open(O_RDONLY)` y `mmap(PROT_READ)`; sin escrituras |

---

## 8. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| El plugin macOS no carga en la versión actual del juego | Alto | Probar v1.12.1; si falla, recompilar desde `truckermudgeon/scs-sdk-plugin` |
| Clima en vivo no portable | Medio | Aceptar manual/inferido; documentarlo como diferencia |
| SwiftUI no mantiene 60 FPS | Medio | Canvas único, 30 FPS objetivo, cachear imágenes y textos |
| Hackintosh sin Metal/aceleración | Alto | Verificar GPU; 30 FPS; considerar `NSView`/Core Graphics si hace falta |
| Tipografías distintas | Bajo | SF Pro/Rounded o fuente OFL; no bloquear la paridad funcional |
| Dos codebases divergen | Medio | Assets y `trucks.json` compartidos; `GUIA-INTERFAZ.md` como contrato |
| Scope creep (clima, avisos, modo ventana) | Alto | Fases con criterios de aceptación; defectos fuera de alcance al backlog |
| Assets con licencias dudosas | Bajo/medio | Revisar fuentes antes de distribuir públicamente |

---

## 9. Decisiones abiertas (valores por defecto)

- **Clima en vivo:** no; manual + limpiabrisas. Se puede investigar después con
  `mach_vm_read` y offsets de macOS, fuera de la v2.7 Mac.
- **FPS:** 30 estables; 60 opcional si el Hackintosh lo permite.
- **Avisos del juego:** incluidos; si el tiempo aprieta, se posponen y se
  documenta `SIN AVISOS`.
- **Finanzas completas:** incluidas (empresa, logo, conductores, ganancia neta).
  Si se retrasa el parser de conductores, el panel puede mostrar solo empresa,
  logo y saldo en una primera entrega.
- **Tipografía:** SF Pro/SF Rounded por defecto; fuente OFL solo si se exige un
  parecido especial con Bahnschrift.
- **Universal binary:** x86_64 ahora; universal cuando haya acceso a Apple
  Silicon o se quiera distribuir.

---

## 10. Orden de ejecución y estimación

| Fase | Contenido | Depende de | Estimación |
|---|---|---|---|
| 0 | Baseline, git, plugin, capturas | — | 0,5–1 día |
| 1 | Refactor, tema, layout, store | Fase 0 | 1–2 días |
| 2 | Shell FH6 | Fase 1 | 3–5 días |
| 3 | Assets y reglas v2.7 | Fase 2 | 3–5 días |
| 4 | Datos: perfil, empresa, conductores | Fase 1; puede solaparse con 3 | 3–5 días |
| 5 | Ventana, rendimiento, empaquetado | Fases 2–4 | 2–4 días |
| 6 | Release y documentación | Fase 5 | 1–2 días |

**Total orientativo:** 2–4 semanas de trabajo efectivo si se reutiliza bien la
base; más si hay que depurar el plugin, el GPU del Hackintosh o la paridad
tipográfica.

**Ruta crítica:** Fase 0 → Fase 1 → Fase 2 → Fase 3 → Fase 5 → Fase 6. La Fase 4
puede ejecutarse en paralelo con la Fase 3.

---

## 11. Comandos de la Fase 0

El baseline git ya está hecho: commit `2183979 baseline macOS 0.1.0`. En el
Hackintosh quedan el build, la captura y la prueba del plugin:

```zsh
cd "/ruta/a/APP Telemetria/Mac Os"
chmod +x build_app.sh
./build_app.sh
open "ATS Telemetry.app" --args --demo
```

Si el juego está instalado, después:

```zsh
# Ajustar la ruta real del juego y el nombre del plugin descargado.
mkdir -p "$HOME/Library/Application Support/Steam/steamapps/common/American Truck Simulator/American Truck Simulator.app/Contents/MacOS/plugins"
cp /ruta/al/plugin/scs-telemetry.dylib "$HOME/Library/Application Support/Steam/steamapps/common/American Truck Simulator/American Truck Simulator.app/Contents/MacOS/plugins/"
open "ATS Telemetry.app"
```

> El nombre exacto del `.dylib` depende del zip de `truckermudgeon/scs-sdk-plugin`.
> Verificar que el juego lo cargue y que `/SCSTelemetry` tenga `SDK=1`.

---

## 12. Registro de avance

| Fecha | Fase | Nota |
|---|---|---|
| 31/10/2026 | Plan | Plan creado; sin cambios de código todavía |
| 31/10/2026 | Fase 0 | Git inicializado; commit base `2183979`; referencias de Windows copiadas; decisiones por defecto confirmadas |
| 31/10/2026 | Fase 0 | Pendiente en Hackintosh: build, captura Mac y prueba del plugin macOS |

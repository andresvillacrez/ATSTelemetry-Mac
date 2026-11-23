# Modo juego ATS/ETS2 — macOS

Scripts para reducir tirones en ATS/ETS2 en este Mac sin bajar la calidad gráfica
ni cambiar ajustes visuales de macOS.

## Hardware y configuración detectada

- MacPro7,1 · Intel Core i7-9700F (8 núcleos / 8 hilos) · 32 GB RAM.
- AMD Radeon RX 6600 8 GB · Metal 3.
- 3 pantallas 1920×1080 a 60 Hz.
- ATS usa **Vulkan + MoltenVK** con `-rdevice vk -nointro -color_mode sdr`.
- Calidad gráfica actual: preset alto/ultra en 1920×1080, VSync activo y límite 60.
- `r_vulkan_runtime` apuntaba a una ruta truncada (`.../A`), no al runtime real.

## Cambios en ATS

`apply-ats-smooth.sh` conserva la configuración original en
`config.cfg.bak-smooth-original` y ajusta solo lo necesario:

- `r_vsync 0`: evita el bloqueo de VSync a 30 FPS cuando un frame no llega a 60.
  Puede aparecer un poco de *tearing*; si molesta, usa `restore-ats-config.sh`.
- `r_vulkan_runtime ""`: elimina la ruta corrupta; el juego usa su MoltenVK incluido.
- Mantiene `t_limit_fps 60` y `t_locked_fps 60`.
- **No cambia** sombras, SSAO, espejos, texturas, escalado ni ninguna opción de
  calidad gráfica. Para bajar también esos ajustes, usa el perfil de rendimiento
  de la sección siguiente.

El juego reescribe `config.cfg` al salir y puede devolver `r_vsync` a `1`. El
watcher de modo juego **reaplica el perfil automáticamente** tras cerrar ATS/ETS2
(espera 3 s a que el juego vuelque el archivo) y también al detectar el
siguiente arranque. Así el perfil de suavidad queda persistente sin tener que
ejecutar el script a mano.

## Mejoras de rendimiento (calidad)

`apply-ats-performance.sh` aplica el perfil de suavidad y además baja los
ajustes de calidad con mayor coste. Guarda una copia en
`config.cfg.bak-perf-<fecha>` antes de tocar nada. Valores aplicados en esta
máquina:

| Ajuste | Antes | Ahora | Efecto |
|---|---|---|---|
| `r_mirror_view_distance` | 120 | **90** | Menos geometría en espejos (CPU + GPU) |
| `r_sun_shadow_quality` | 2 | **1** | Sombras más baratas |
| `r_sun_shadow_texture_size` | 2048 | **1024** | Menos memoria y filtrado |
| `r_ssao` | 2 | **1** | Menos coste de oclusión ambiental |
| `r_aa` | 6 | **5** | Menos coste de antialiasing |

En este equipo el límite suele estar en CPU (i7-9700F, 8 hilos), así que las
mejoras de mayor impacto real son **distancia de espejos**, **sombras** y
**SSAO**; el resto afecta sobre todo a GPU.

Para volver a la calidad original: `restore-ats-config.sh` (o restaurar el
`config.cfg.bak-perf-*` correspondiente).

## Prioridad de la app de telemetría

La app corre a 60 FPS y consume ~0,3 núcleos. Si quieres que el juego tenga aún
más CPU, añade `ATSTelemetry` a `LOWER_PRIORITY_APPS` en `config.sh`: la app
seguirá funcionando, pero puede perder algún frame en momentos de carga. No se
añade por defecto para no degradar el panel.

## Consumo de combustible

El perfil tenía `g_fuel_simulation 0` (consumo no realista). Se cambió a `1`
para que el nivel de combustible y el consumo respondan a la conducción.
Backup del perfil: `config.cfg.bak-fuel-*` en el perfil de Steam.

La app calcula además un consumo instantáneo propio con el nivel de combustible
y la distancia recorrida en una ventana de 20 s; muestra `L/h` cuando el camión
está parado o al ralentí.

## MoltenVK

`mvk-env.sh` configura variables de rendimiento para el usuario:

- `MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION=1` — compila shaders en paralelo
  y reduce los tirones de compilación.
- `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0` — mantiene la ruta estable en x86_64
  (el propio juego la desactiva por problemas de alineación).
- `MVK_CONFIG_PREALLOCATE_DESCRIPTORS=1` y `MVK_CONFIG_USE_COMMAND_POOLING=1`.
- `MVK_CONFIG_LOG_LEVEL=0` — menos logging.

Steam debe reiniciarse una vez para que ATS/ETS2 hereden estas variables.
El LaunchAgent las vuelve a aplicar al iniciar sesión.

## Modo juego automático

`install-game-mode.sh` instala un LaunchAgent de usuario que vigila ATS/ETS2:

- Pasa a prioridad de fondo (`taskpolicy -b`) OBS, Safari, WhatsApp, Chrome, Edge y Firefox.
  No los cierra: siguen funcionando, pero ceden CPU al juego. Al salir se restaura
  su prioridad normal con `taskpolicy -B`, sin dejar cambios permanentes.
- Pausa temporalmente `photoanalysisd`, `mediaanalysisd` y `mdworker_shared`.
- Si Time Machine está copiando, pausa la copia y la reanuda al salir.
- Restaura todo al cerrar el juego.
- No requiere `sudo` y no modifica ajustes visuales de macOS.

Configuración editable: `~/Library/Application Support/ATS Telemetry/game-mode/config.sh`.
Log: `~/Library/Logs/ATS Telemetry/game-mode.log`.

## Instalación y reversión

```bash
bash game-mode/install-game-mode.sh
bash game-mode/apply-ats-smooth.sh
bash game-mode/apply-ats-performance.sh   # suavidad + calidad orientada a rendimiento
```

Revertir:

```bash
bash game-mode/restore-ats-config.sh
bash game-mode/uninstall-game-mode.sh
```

## Nota sobre OBS

Durante la auditoría, OBS aparecía utilizando ~97 % de CPU. Si no estás grabando
o transmitiendo, ciérralo antes de jugar: es el mayor consumidor de recursos del
sistema y el modo juego solo puede bajarle la prioridad, no eliminar su impacto.
Si grabas, usa codificación por hardware (VideoToolbox) y baja la carga del preview.

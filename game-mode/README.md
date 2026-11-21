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
  calidad gráfica.

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

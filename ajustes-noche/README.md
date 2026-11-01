# Ajustes de noche — ATS y ETS2

**Fecha:** 31/10/2026  
**Ámbito:** ajustes del juego, sin mods (opción 1 del plan de noche).  
**Versiones comprobadas:**

- American Truck Simulator **1.61.3.18**
- Euro Truck Simulator 2 **1.61.1.9**

## Rutas de los `config.cfg`

En este equipo Windows:

- `C:\Users\hs-se\OneDrive\Documentos\American Truck Simulator\config.cfg`
- `C:\Users\hs-se\OneDrive\Documentos\Euro Truck Simulator 2\config.cfg`

En el Hackintosh/macOS:

- `~/Library/Application Support/American Truck Simulator/config.cfg`
- `~/Library/Application Support/Euro Truck Simulator 2/config.cfg`

## Cambios aplicados

| Ajuste | Antes | Después | Efecto |
|---|---:|---:|---|
| `r_peak_brightness` | `1.0` | `1.1` | Brillo global suave; debería aclarar un poco la noche sin tocar el gamma |
| `g_light_span_factor` | `1` | `2.5` | Charco de luz más amplio en farolas, carteles y luces |
| `g_light_distance_factor` | `1` | `3` | Las luces se ven desde más lejos |
| `g_vehicle_flare_lights` | `1` | `1` | Sin cambio; luces secundarias ya activadas |
| `g_auto_traffic_headlights` | `1` | `1` | Sin cambio; faros del tráfico ya activados |

Líneas exactas:

```cfg
uset r_peak_brightness "1.1"
uset g_light_span_factor "2.5"
uset g_light_distance_factor "3"
uset g_vehicle_flare_lights "1"
uset g_auto_traffic_headlights "1"
```

## Sobre `r_gamma`

El plan inicial incluía `r_gamma "1.15"`, pero en la versión **1.61** esa variable ya no existe en el binario del juego. Añadirla al `config.cfg` no tendría efecto. El brillo global se controla con el slider de **Brillo** del juego; en el `config.cfg` el valor asociado es `r_peak_brightness`.

Si el día queda demasiado brillante, baja `r_peak_brightness` a `1.05` o vuelve a `1.0`. Si la noche sigue oscura, el siguiente paso es un mod de clima nocturno, no subir más el brillo global.

> Los cambios están aplicados en los `config.cfg`, pero **no se han validado visualmente en partida**. El efecto se comprueba al abrir cada juego.

## Copias de seguridad

Antes de editar se guardaron copias:

- `...\American Truck Simulator\config.cfg.bak-20261031-noche`
- `...\Euro Truck Simulator 2\config.cfg.bak-20261031-noche`

Para revertir, cierra el juego y copia el backup sobre `config.cfg`.

## Cómo probar

1. Cierra el juego antes de editar el `config.cfg`.
2. En **Opciones > Gráficos**:
   - **Light visibility ranges / Rangos de visibilidad de luces:** Alto.
   - **Secondary vehicle lights / Luces secundarias:** Activado.
   - **Traffic headlights / Faros del tráfico:** Activado.
3. Opcional, para saltar a la noche: activa la consola en `config.cfg`:

```cfg
uset g_console "1"
uset g_developer "1"
uset g_minicon "1"
```

Dentro del juego pulsa `~` y escribe:

```text
g_set_time 22
```

4. Si notas caída de FPS, baja `g_light_span_factor` a `2` y `g_light_distance_factor` a `2.5`.

## Notas

- Los factores de luces afectan a farolas, carteles y luces en general, no solo a los faros del camión.
- Si cambias el preset gráfico dentro del juego, revisa que no se hayan sobrescrito estos valores.
- No se instalaron mods. Los ajustes son reversibles y no modifican partidas.
- En el camión, usa luces largas y, si está disponible, una barra de luces o faros auxiliares funcionales.

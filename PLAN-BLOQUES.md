# Plan por bloques — ATS Telemetry macOS FH6 v2.7

**Objetivo:** completar la app macOS sin pedir autorización por cada cambio.
Cada bloque se ejecuta de una vez: implementar → compilar → probar demo → relanzar.

---

## Bloque A — Interfaz restante (detalle fino + temas/accesibilidad)
**Estimación:** 3-5 días  
**Riesgo:** medio

### A1. Drag & drop de layout (Ctrl+Shift+E)
- Editor de layout con arrastre de paneles.
- Guardado en `layout.json` en Application Support.
- Restaurar posiciones al abrir.
- **Archivos:** nuevo `LayoutEditor.swift`, `DashboardView.swift`, `main.swift`.
- **Criterio:** paneles arrastrables en modo edición, posiciones persistidas.

### A2. Temas claro/alto contraste en caliente
- Aplicar tema en caliente sin reiniciar.
- Invalidar caché del fondo (SwiftUI redraw).
- Título de ventana y menú adaptados.
- **Archivos:** `main.swift`, `DashboardView.swift` (`Theme`).
- **Criterio:** cambio de tema inmediato, sin flicker.

### A3. Accesibilidad
- Contraste WCAG: elevar `TextTertiary` a 4.82:1.
- Etiquetas de daño para daltonismo (ya parcial).
- Escala tipográfica 100/125/150 % (ya parcial).
- Unidades métrico/imperial (ya parcial, falta velocidad y presión).
- **Archivos:** `DashboardView.swift`, `main.swift`.
- **Criterio:** contraste verificado, unidades convertidas.

### A4. Detalle fino restante
- Empresa: conductores/egresos en detalle expandible.
- Carga: bloques Carga/Viaje, tipo/trabajo/remolque en detalle.
- GPS: origen/odómetro/recorrido/posición en detalle secundario.
- Combustible: consumo medio, marcador de reserva (ya parcial).
- Avisos: icono y color por tipo; ticker en Compact.
- Clima: mover a cabecera en Compact.
- **Archivos:** `DashboardView.swift`.
- **Criterio:** cada panel revisado en demo a 1920×1080 y 1280×720.

---

## Bloque B — Integración de datos
**Estimación:** 3-5 días  
**Riesgo:** medio-alto

### B1. ProfileReader (empresa, logo, conductores)
- Localizar `profile.sii` junto al `game.sii` más reciente.
- Leer `company_name`, `logo` (`logo_0..logo_7`).
- Leer `driver_ai` y `profit_log_entry.revenue`.
- **Archivos:** nuevo `ProfileReader.swift`, `SiiParser.swift`.
- **Criterio:** ATS y ETS2 muestran empresa, logo, conductores y saldo correctos.

### B2. SiiParser compartido
- Extraer lectura de SII/BSII de `BankBalanceReader` a `SiiParser.swift`.
- Reutilizar en `profile.sii`.
- **Archivos:** nuevo `SiiParser.swift`, `BankBalanceReader.swift`.
- **Criterio:** sin duplicación, saldo actualizado tras guardado.

### B3. Retarder en Snap
- Añadir offset 108 (`truck_ui.retarderBrake`) al `Snap`.
- Testigo correspondiente.
- **Archivos:** `TelemetryReader.swift`, `DashboardView.swift`.
- **Criterio:** retarder visible en testigos.

### B4. Clima manual + inferencia
- Mantener manual + inferencia por limpiabrisas.
- Etiquetar claramente el modo automático.
- **Archivos:** `main.swift`, `DashboardView.swift`.
- **Criterio:** clima manual funciona; automático inferido.

---

## Bloque C — Ventana, rendimiento y empaquetado
**Estimación:** 2-4 días  
**Riesgo:** medio

### C1. Selector de pantalla
- Listar `NSScreen.screens`, guardar UUID, restaurar.
- **Archivos:** `main.swift`.
- **Criterio:** selección y restauración correctas en multi-monitor.

### C2. Modo ventana/F11
- Alternar borderless/fullscreen y ventana normal.
- Guardar preferencia.
- **Archivos:** `main.swift`.
- **Criterio:** F11 alterna modos; preferencia persistida.

### C3. Rendimiento 30/60 FPS
- Medir CPU/GPU a 30 y 60 FPS.
- Usar un solo Canvas, cachear imágenes y textos.
- **Archivos:** `DashboardView.swift`.
- **Criterio:** 30 FPS estables; 60 solo si no hay tirones.

### C4. Compilación universal
- Añadir `x86_64 + arm64` si se quiere compatibilidad futura.
- **Archivos:** `build_app.sh`, `Package.swift`.
- **Criterio:** binario universal compila.

---

## Bloque D — Release y documentación
**Estimación:** 1-2 días  
**Riesgo:** bajo

### D1. Documentación
- Actualizar `README.md`, `PLAN-TRABAJO.md`, `HISTORIAL.md`.
- **Criterio:** docs sincronizados con el estado real.

### D2. Tag y paquete
- Crear tag `mac-v2.7.0`.
- Generar `.app` y ZIP de distribución.
- **Criterio:** paquete listo para distribución.

### D3. Validación final
- Repetir matriz de pruebas en Hackintosh.
- Archivar capturas 1920/1280.
- **Criterio:** release candidate estable.

---

## Orden de ejecución

```
Bloque A (interfaz) → Bloque B (integración) → Bloque C (ventana/rendimiento) → Bloque D (release)
```

Bloque B puede solaparse con Bloque A (Fase 4 puede ejecutarse en paralelo con Fase 3).

## Comandos de validación por bloque

```zsh
cd "/Volumes/Software/Proyectos de software/APP Telemetria/Mac Os"
./build_app.sh
open "ATS Telemetry.app" --args --demo
```

## Undo
- Cada bloque es un commit separado.
- Revertir con `git revert` o restaurar desde backup.
- No se modifican `src\bin`, `src\obj` ni `dist`.

---

## Estado actual (2026-11-20)

### Interfaz completada
- Velocímetro 180 km/h.
- Testigos 40 px.
- Bordes removidos de paneles/gauges.
- Testigos inactivos al 20 %.
- CHECK ENGINE con pulso.
- Pulso sin ampliación (solo opacidad).
- Panel GPS simplificado.
- Combustible centrado + consumo L/100/MPG/gal + marcador de reserva.
- Panel ESTADO DE CARGA sin TIPO.
- Imagen del camión ampliada (360×180).
- Líneas horizontales removidas.
- Numeración en velocímetro (0..180).
- Minipanel de distancia en panel de GPS.
- Testigo de crucero subido.
- Números del kilometraje redistribuidos.
- Clima eliminado del menú (modo automático).
- Ajustes por delante del panel principal.
- Tema claro/alto contraste en caliente.
- Título de ventana según tema.
- Submenús con texto claro.
- Marcos de panel cacheados (drawingGroup).
- Daños sin fondo + etiqueta de severidad.
- Avisos con fondo tintado por tipo.
- Overlay de diagnóstico (FPS + frame time).
- Botones Ajustes/Créditos solo en Full.
- Diálogo de Créditos ampliado.
- Reflow para 150 %.
- Unidades métrico/imperial (toggle).

### Pendiente
- Bloque A: drag & drop, temas en caliente (completo), accesibilidad completa, detalle fino restante.
- Bloque B: ProfileReader, SiiParser, retarder, clima.
- Bloque C: selector pantalla, modo ventana, rendimiento, universal.
- Bloque D: docs, tag, paquete, validación.

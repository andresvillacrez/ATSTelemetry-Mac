# Mejoras de interfaz FH6 v3.2.0 — ATS Telemetry macOS

## Objetivo
Llevar la app macOS a paridad visual con **Windows Native Final v3.2.0** (FH6),
conservando el host SwiftUI/AppKit y la lectura pasiva. La integración (telemetría
real, savegame, empresa, conductores, clima) se deja pendiente para realizarla
paso a paso (ver `INTEGRACION-PENDIENTE.md`).

## Referencia
- Windows: `../Windows Native Final/README.md`, `GUIA-INTERFAZ.md`, capturas `screenshots/`.
- Coordenadas del lienzo virtual: 1920×1080 (Full), 1280×720 (Compact), 960×540 (Minimal).

## Mejoras de interfaz aplicadas (2026-11-20) — Bloque A completado

### Pendiente opcional (alto riesgo)
- Drag & drop de layout (Ctrl+Shift+E) — requiere refactor mayor de posiciones.
- Empresa: conductores/egresos en detalle expandible (requiere datos).
- Carga: bloques Carga/Viaje, tipo/trabajo/remolque en detalle.
- GPS: origen/odómetro/recorrido/posición en detalle secundario (parcial).
- Avisos: ticker en Compact.
- Clima: mover a cabecera en Compact (parcial).
- [x] Velocímetro ampliado a **180 km/h** (maxSpeed y barrido de ignición).
- [x] Testigos superiores ampliados a **40 px** (iconos de la fila).
- [x] **CHECK ENGINE** con pulso al activarse.
- [x] Pulso sin ampliación (solo opacidad) en testigos con pulso.
- [x] Testigos inactivos al **20 %** de opacidad.
- [x] Eliminado el encuadre (borde) de paneles y gauges.
- [x] Panel ESTADO DE CARGA: removido TIPO (sin TIPO/REMOLQUE/línea).
- [x] Panel de combustible: texto centrado (icono y porcentaje centrados).
- [x] Panel GPS: removido rumbo/odómetro/llegada/hora prevista.
- [x] Panel de carga: imagen del camión ampliada (360×180).
- [x] Líneas horizontales removidas de gauges y paneles.
- [x] Numeración añadida al círculo del velocímetro (0..180).
- [x] Rendimiento 30 FPS (TimelineView 1/30).
- [x] Clima movido a cabecera en modo Compact.
- [x] Contraste elevado (text tertiary 0.4 → 0.55).
- [x] Botones Ajustes/Créditos solo en modo Full (cabecera).
- [x] Overlay de diagnóstico mejorado (FPS + frame time).
- [x] Unidades métrico/imperial (toggle en Ajustes, temperatura convertida).
- [x] Detalle fino: imagen de daños sin fondo (esquema de camión).
- [x] Detalle fino: daños con etiqueta textual de severidad (daltonismo).
- [x] Diálogo de Créditos ampliado (creador, derechos, tecnologías, agradecimientos).
- [x] Combustible: marcador de reserva en la barra.
- [x] Avisos: fondo tintado según tipo de mensaje.
- [x] Tema claro/alto contraste aplicable en caliente (título de ventana actualizado).
- [x] Título de ventana claro/oscuro según tema (aplicado al arrancar y al cambiar).
- [x] Submenús con texto claro (apariencia darkAqua forzada).
- [x] Marcos de panel cacheados (drawingGroup en paneles y tarjetas).
- [x] Reflow completo para 150 % (LayoutMode considera uiScale).
- [x] Consumo L/100 km / MPG / gal en combustible con selector en Ajustes.
- [x] Clima eliminado del menú de bandeja (modo automático fijo).
- [x] Ajustes se abre por delante del panel principal.
- [x] Clima eliminado del menú de bandeja (modo automático fijo).
- [x] Redistribuido: número centrado arriba, recorrido de ruta abajo, odómetro en y=736.
- [x] Minipanel de distancia colocado dentro del panel de GPS (parte inferior).
- [x] Testigo de crucero subido.
- [x] Números del kilometraje redistribuidos para mejor visibilidad.
- [x] Gauges de aire/temperatura reducidos 20 % y barra engrosada.
- [x] Versión del bundle actualizada a **2.7.0**.
- [x] Build verificado sin errores.

## Mejoras de interfaz pendientes (v3.2.0)
- [ ] Pulso sin ampliación (solo opacidad) en testigos con pulso.
- [ ] Testigo CHECK ENGINE con pulso al activarse.
- [ ] Gauges de aire y temperatura modernizados (barra gruesa, sin indicador, 20 % más pequeños).
- [ ] Panel de combustible: icono y porcentaje centrados, autonomía debajo.
- [ ] Panel de carga: imagen ampliada (88 % del espacio libre).
- [ ] Panel GPS: brújula restaurada, destino entre brújula y límite.
- [ ] Panel ESTADO DE CARGA: sin TIPO ni REMOLQUE ni línea divisoria; nombre más cerca; integridad en fila.
- [ ] Eliminado el encuadre (borde) de paneles y gauges (se conserva el de testigos).
- [ ] Paneles de empresa, carga y ruta reorganizados; testigos inactivos al 20 %.
- [ ] Mensajes con encabezado y valor; respaldo de logo/carga para ETS2.
- [ ] Editor de layout drag & drop (Ctrl+Shift+E), guardado en `layout.json`.
- [ ] Layouts responsive Full/Compact/Minimal con canvas propio y ultrawide/16:10.
- [ ] Temas: oscuro, claro, alto contraste (barra de título y menús adaptados).
- [ ] Accesibilidad: contraste WCAG, etiquetas de daño para daltonismo, escala tipográfica, unidades métrico/imperiales.
- [ ] Componentes: cabecera con estado útil, botones Ajustes/Créditos, chips, estados vacíos, onboarding.
- [ ] Rendimiento: suavizado de valores en vivo, fondo y marcos cacheados, overlay de diagnóstico.

## Notas
- La interfaz base (FH6 v3) ya está implementada en `DashboardView.swift`.
- Cada cambio se valida con `./build_app.sh` y, cuando sea posible, con demo (`--demo`).
- Las mejoras se aplicarán en commits pequeños para facilitar la reversión.

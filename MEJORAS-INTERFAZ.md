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

### Bloque D — Release
- [x] Documentación actualizada (README.md, PLAN-TRABAJO.md).
- [x] Tag `mac-v2.7.0` creado.
- [x] App final compilada (`ATS Telemetry.app`).
- [x] ZIP de distribución generado (`ATS-Telemetry-macOS-2.7.0.zip`).

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
- [~] Reflow 150 %: el lienzo ya no se recorta; quedan ajustes internos en tarjetas (parcial).
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

## Rediseño de interfaz v3.1 (2026-11-20)

### Ronda 1 — Solapamientos, clipping y duplicados
- [x] Cluster recentrado: marcha, RPM y odómetro en filas propias; `km/h` y `LÍMITE` ya no quedan tapados.
- [x] Testigos de batería/aceite fuera de los dígitos de velocidad; crucero sobre el número, no dentro del arco.
- [x] GPS: corregido el porcentaje literal, eliminadas coordenadas duplicadas y `TripBadge`; una sola fila de ruta.
- [x] Clima y combustible ensanchados a 280 px; sin recortes de `DESPEJADO`/`NUBLADO` ni del consumo.
- [x] Daños: imagen con fallback por marca (T680 para T800), sin caption ni leyenda 5/20/50; el contenido ya cabe.
- [x] Cabecera: estado único (DEMO/EN LÍNEA/PAUSA) y camión sin duplicar la marca junto al logo.
- [x] Pie: versión real del bundle y sin estados duplicados.
- [x] Eliminados badges DEMO de Avisos/Clima y `TRABAJO ACTUAL`/`INTEGRIDAD` de Carga.
- [x] Carga con una sola unidad de peso y `CARGADA` en verde; consumo coherente con la unidad elegida.
- [x] Fila inferior alineada: 280 / 400 / 280 entre los paneles laterales.

### Ronda 2 — Legibilidad y jerarquía
- [x] Escala tipográfica sin tamaños de 6–9 pt en elementos visibles; etiquetas a 10–11, títulos 13, héroes 24–30.
- [x] `PanelHeader` único en todos los paneles (icono 14, título 13, tracking 2.4, estado 10).
- [x] Opacidades de texto unificadas; etiquetas secundarias más contrastadas.
- [x] Colores semánticos: verde positivo/cargado, cian información, ámbar aviso, rojo crítico.
- [x] Gauges verticales con unidad visible, valor por umbral, mín/máx alineados y contenedor propio.
- [x] Testigos normalizados a 40 px, inactivos al 30 %, iconos monocromos coloreados por estado.
- [x] Cruise badge y chip de límite legibles; sombras decorativas reducidas.

### Ronda 3 — Minimalismo y consistencia
- [x] Radios unificados (paneles 24, tarjetas 20, chips 8) y superficie de panel al 3 %.
- [x] Logo de empresa sin fondo blanco conectado a los bordes + chip oscuro.
- [x] Botones de cabecera solo icono con tooltip; retirado `SALIR` del pie.
- [x] Título de ventana `ATS Telemetry · Claro` / `· Alto contraste`.
- [x] Eliminada la barra de margen, la leyenda de daños y el caption del camión.
- [x] Un solo lienzo 1920×1080 escalable: Full, Compact (1280×720) y Minimal (960×540) ya no se recortan.

### Validación
- [x] Build release sin errores.
- [x] Demo Full 1904×1039, Compact 1280×720 y Minimal 960×540 sin solapamientos ni clipping.
- [ ] Prueba en vivo con ATS (pendiente de sesión real).

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

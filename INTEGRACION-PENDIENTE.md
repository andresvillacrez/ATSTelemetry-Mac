# Mejoras de integración pendientes — ATS Telemetry macOS

Estas tareas se realizarán **paso a paso** después de cerrar las mejoras de
interfaz (ver `MEJORAS-INTERFAZ.md`). No afectan la capa visual.

## Integración de telemetría y datos
- [ ] Verificar lectura pasiva de `/SCSTelemetry` en el Hackintosh (SDK=1).
- [ ] Instalar y validar el plugin macOS (`truckermudgeon/scs-sdk-plugin` v1.12.1).
- [ ] Saldo bancario desde `game.sii` (BankBalanceReader) con actualización tras guardado.
- [ ] Empresa, logo y conductores desde `profile.sii` (ProfileReader).
- [ ] Parser SII compartido (SiiParser) para reutilizar en `profile.sii`.
- [ ] Retarder (offset 108) en Snap y testigo correspondiente.
- [ ] Clima: mantener manual + inferencia por limpiabrisas; etiquetar modo automático.

## Ventana, rendimiento y empaquetado
- [ ] Selector de pantalla con UUID y fallback.
- [ ] Modo ventana/F11 y persistencia de preferencias (`UserDefaults`).
- [ ] Medir CPU/GPU a 30/60 FPS; cachear imágenes y textos.
- [ ] Compilación universal x86_64 + arm64 (opcional).
- [ ] Firma ad-hoc y nota de Gatekeeper.

## Release
- [ ] Actualizar `README.md`, `PLAN-TRABAJO.md` y `HISTORIAL.md`.
- [ ] Crear tag `mac-v2.7.0`.
- [ ] Generar `.app` y ZIP de distribución.
- [ ] Validación final en Hackintosh (matriz de pruebas).

## Orden sugerido
1. Telemetría pasiva y plugin.
2. Savegame/empresa/conductores.
3. Ventana y rendimiento.
4. Release y documentación.

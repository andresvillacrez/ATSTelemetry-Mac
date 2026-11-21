# Configuración del modo juego de ATS Telemetry.
# Edita estas listas si quieres añadir o quitar aplicaciones/servicios.

# Aplicaciones a las que se pasa a prioridad de fondo mientras ATS/ETS2 está abierto.
# No se cierran: siguen funcionando, pero ceden CPU al juego.
LOWER_PRIORITY_APPS=(
    "OBS"
    "Safari"
    "WhatsApp"
    "Google Chrome"
    "Microsoft Edge"
    "Firefox"
)

# Daemons de mantenimiento que se pausan mientras juegas y se reanudan al salir.
# Son procesos de usuario; no se desactivan de forma permanente.
PAUSE_DAEMONS=(
    "photoanalysisd"
    "mediaanalysisd"
    "mdworker_shared"
)

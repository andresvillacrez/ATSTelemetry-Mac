#!/bin/bash
# Modo juego: detecta ATS/ETS2 y libera recursos de fondo de forma reversible.
# No cambia ninguna configuración visual de macOS.
set -u

SUPPORT="$HOME/Library/Application Support/ATS Telemetry/game-mode"
STATE="$SUPPORT/state"
LOG="$HOME/Library/Logs/ATS Telemetry/game-mode.log"
CONFIG="$SUPPORT/config.sh"

mkdir -p "$STATE" "$(dirname "$LOG")"

# Valores por defecto; config.sh puede sobrescribirlos.
LOWER_PRIORITY_APPS=("OBS" "Safari" "WhatsApp" "Google Chrome" "Microsoft Edge" "Firefox")
PAUSE_DAEMONS=("photoanalysisd" "mediaanalysisd" "mdworker_shared")

if [ -f "$CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG"
fi

ACTIVE="$STATE/active"
BG_FILE="$STATE/background.txt"
PAUSED_FILE="$STATE/paused.txt"
TM_FILE="$STATE/timemachine.txt"

log() {
    /bin/echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

game_pids() {
    /usr/bin/pgrep -x amtrucks 2>/dev/null || true
    /usr/bin/pgrep -x eurotrucks2 2>/dev/null || true
}

start_game_mode() {
    /usr/bin/touch "$ACTIVE"
    : > "$BG_FILE"
    : > "$PAUSED_FILE"
    /bin/echo "0" > "$TM_FILE"
    log "JUEGO detectado: activando modo juego."

    local app pid
    for app in "${LOWER_PRIORITY_APPS[@]}"; do
        while IFS= read -r pid; do
            [ -n "$pid" ] || continue
            if /usr/sbin/taskpolicy -b -p "$pid" >/dev/null 2>&1; then
                /bin/echo "$pid" >> "$BG_FILE"
                log "Prioridad de fondo: $app (PID $pid)."
            fi
        done < <(/usr/bin/pgrep -x "$app" 2>/dev/null || true)
    done

    local daemon
    for daemon in "${PAUSE_DAEMONS[@]}"; do
        if /usr/bin/pgrep -x "$daemon" >/dev/null 2>&1; then
            if /usr/bin/killall -STOP "$daemon" >/dev/null 2>&1; then
                /bin/echo "$daemon" >> "$PAUSED_FILE"
                log "Pausado temporalmente: $daemon."
            fi
        fi
    done

    if /usr/bin/tmutil status 2>/dev/null | /usr/bin/grep -q "Running = 1"; then
        if /usr/bin/tmutil stopbackup >/dev/null 2>&1; then
            /bin/echo "1" > "$TM_FILE"
            log "Time Machine pausado durante el juego."
        fi
    fi
}

stop_game_mode() {
    log "Juego cerrado: restaurando el sistema."

    if [ -f "$PAUSED_FILE" ]; then
        local daemon
        while IFS= read -r daemon; do
            [ -n "$daemon" ] || continue
            if /usr/bin/killall -CONT "$daemon" >/dev/null 2>&1; then
                log "Reanudado: $daemon."
            fi
        done < "$PAUSED_FILE"
    fi

    if [ -f "$BG_FILE" ]; then
        local pid
        while IFS= read -r pid; do
            [ -n "$pid" ] || continue
            if /bin/kill -0 "$pid" 2>/dev/null; then
                if /usr/sbin/taskpolicy -B -p "$pid" >/dev/null 2>&1; then
                    log "Prioridad normal restaurada: PID $pid."
                fi
            fi
        done < "$BG_FILE"
    fi

    if [ -f "$TM_FILE" ] && [ "$(/bin/cat "$TM_FILE")" = "1" ]; then
        if /usr/bin/tmutil startbackup --auto >/dev/null 2>&1; then
            log "Time Machine reanudado."
        fi
    fi

    /bin/rm -f "$ACTIVE" "$BG_FILE" "$PAUSED_FILE" "$TM_FILE"
}

cleanup() {
    stop_game_mode
    exit 0
}
trap cleanup TERM INT HUP

log "Watcher de modo juego iniciado (PID $$)."

while true; do
    pids="$(game_pids)"
    if [ -n "$pids" ] && [ ! -f "$ACTIVE" ]; then
        start_game_mode
    elif [ -z "$pids" ] && [ -f "$ACTIVE" ]; then
        stop_game_mode
    fi
    /bin/sleep 5
done

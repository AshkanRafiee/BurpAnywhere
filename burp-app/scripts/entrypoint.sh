#!/usr/bin/env sh

set -e

PROJECT_CONFIG="${HOME}/config/project_options.json"
USER_CONFIG="${HOME}/config/user_options.json"
BURPSUITE_JAR="${HOME}/burpsuite.jar"
BURPSUITE_MODE="${BURPSUITE_MODE:-download}"
ENABLE_WEB_UI="${ENABLE_WEB_UI:-true}"
VNC_DISPLAY="${VNC_DISPLAY:-:1}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
NOVNC_WEB_DIR="${NOVNC_WEB_DIR:-/usr/share/novnc}"
XVFB_GEOMETRY="${XVFB_GEOMETRY:-1920x1080x24}"
VNC_PASSWORD="${VNC_PASSWORD:-burp}"
NOVNC_UTILS_DIR="${NOVNC_UTILS_DIR:-/usr/share/novnc/utils}"

RESTART_ON_EXIT="${RESTART_ON_EXIT:-true}"
RESTART_DELAY="${RESTART_DELAY:-2}"
RESTART_MAX="${RESTART_MAX:-0}"

XVFB_PID=""
FLUXBOX_PID=""
VNC_SERVER_PID=""
NOVNC_PID=""
BURP_PID=""

cleanup() {
    STATUS=$?
    trap - INT TERM EXIT
    set +e
    for PID in "$NOVNC_PID" "$VNC_SERVER_PID" "$FLUXBOX_PID" "$XVFB_PID" "$BURP_PID"; do
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null
            wait "$PID" 2>/dev/null
        fi
    done
    exit $STATUS
}

trap cleanup INT TERM EXIT

wait_for_display() {
    DISPLAY_NUM=$(echo "$1" | sed 's/^://')
    SOCKET="/tmp/.X11-unix/X${DISPLAY_NUM}"
    ATTEMPTS=0
    while [ $ATTEMPTS -lt 40 ]; do
        if [ -S "$SOCKET" ]; then
            return 0
        fi
        ATTEMPTS=$((ATTEMPTS + 1))
        sleep 0.25
    done
    echo "[ERROR] Timed out waiting for display $1" >&2
    exit 1
}

start_virtual_desktop() {
    export DISPLAY="$VNC_DISPLAY"
    mkdir -p "$HOME/.vnc"
    x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null 2>&1

    echo "[INFO] Starting Xvfb on $DISPLAY (geometry: $XVFB_GEOMETRY)"
    Xvfb "$DISPLAY" -screen 0 "$XVFB_GEOMETRY" -nolisten tcp >/tmp/xvfb.log 2>&1 &
    XVFB_PID=$!

    wait_for_display "$DISPLAY"

    echo "[INFO] Starting fluxbox window manager"
    fluxbox >/tmp/fluxbox.log 2>&1 &
    FLUXBOX_PID=$!

    echo "[INFO] Starting x11vnc on port $VNC_PORT"
    x11vnc \
        -display "$DISPLAY" \
        -rfbport "$VNC_PORT" \
        -rfbauth "$HOME/.vnc/passwd" \
        -forever \
        -shared \
        -o /tmp/x11vnc.log &
    VNC_SERVER_PID=$!

    if [ -x "$NOVNC_UTILS_DIR/launch.sh" ]; then
        echo "[INFO] Starting noVNC (launch.sh) on port $NOVNC_PORT"
        "$NOVNC_UTILS_DIR/launch.sh" --listen "$NOVNC_PORT" --vnc "localhost:${VNC_PORT}" >/tmp/novnc.log 2>&1 &
        NOVNC_PID=$!
        return
    fi

    if [ -x "$NOVNC_UTILS_DIR/novnc_proxy" ]; then
        echo "[INFO] Starting noVNC (novnc_proxy) on port $NOVNC_PORT"
        set -- "$NOVNC_UTILS_DIR/novnc_proxy" --listen "$NOVNC_PORT" --vnc "localhost:${VNC_PORT}"
        if [ -d "$NOVNC_WEB_DIR" ]; then
            set -- "$@" --web "$NOVNC_WEB_DIR"
        fi
        "$@" >/tmp/novnc.log 2>&1 &
        NOVNC_PID=$!
        return
    fi

    if command -v websockify >/dev/null 2>&1; then
        echo "[INFO] Starting websockify on port $NOVNC_PORT"
        if [ -d "$NOVNC_WEB_DIR" ]; then
            set -- websockify --web "$NOVNC_WEB_DIR" "$NOVNC_PORT" "localhost:${VNC_PORT}"
        else
            set -- websockify "$NOVNC_PORT" "localhost:${VNC_PORT}"
        fi
        "$@" >/tmp/novnc.log 2>&1 &
        NOVNC_PID=$!
        return
    fi

    echo "[ERROR] noVNC launch utility not found in $NOVNC_UTILS_DIR" >&2
    exit 1
}

is_web_ui_enabled() {
    VALUE=$(printf '%s' "$ENABLE_WEB_UI" | tr '[:upper:]' '[:lower:]')
    case "$VALUE" in
        1|true|yes|on)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Verify configuration files exist
if [ ! -f "$PROJECT_CONFIG" ]; then
    echo "Error: Project configuration file not found at $PROJECT_CONFIG"
    exit 1
fi

if [ ! -f "$USER_CONFIG" ]; then
    echo "Warning: User configuration file not found at $USER_CONFIG. Creating empty file."
    mkdir -p "$(dirname "$USER_CONFIG")"
    echo "{}" > "$USER_CONFIG"
fi

# Log startup information (helpful for debugging)
echo "Starting Burp Suite with configuration:"
echo "  Project Config: $PROJECT_CONFIG"
echo "  User Config: $USER_CONFIG"
echo "  Java Options: $JAVA_OPTS"
echo "  Mode: $BURPSUITE_MODE"

# Execute download script only in LOCAL mode (for development)
if [ "$BURPSUITE_MODE" = "local" ]; then
    echo "[INFO] Running in LOCAL mode..."
    # /home/burp/download.sh
elif [ "$BURPSUITE_MODE" != "download" ]; then
    echo "[ERROR] Invalid BURPSUITE_MODE: $BURPSUITE_MODE" >&2
    echo "[ERROR] Allowed modes: 'download' or 'local'" >&2
    exit 1
fi

# Verify burpsuite.jar exists before running
if [ ! -f "$BURPSUITE_JAR" ]; then
    echo "[ERROR] burpsuite.jar not found at $BURPSUITE_JAR" >&2
    exit 1
fi

# Adjust DISPLAY based on ENABLE_WEB_UI
if is_web_ui_enabled; then
    echo "[INFO] Browser-based UI support enabled"
    start_virtual_desktop
else
    echo "[INFO] Browser-based UI support disabled; using DISPLAY=${DISPLAY}"
fi

JAVA_DISPLAY=${DISPLAY}
if is_web_ui_enabled; then
    JAVA_DISPLAY="$VNC_DISPLAY"
fi
export DISPLAY="$JAVA_DISPLAY"


RESTART_COUNT=0
EXIT_CODE=0

while :; do
    if [ "$RESTART_MAX" != "0" ] && [ "$RESTART_COUNT" -ge "$RESTART_MAX" ]; then
        echo "[INFO] Reached max restarts ($RESTART_MAX). Not restarting."
        break
    fi

    echo "[INFO] Starting Burp Suite (attempt $((RESTART_COUNT + 1)))"
    java $JAVA_OPTS -jar "$BURPSUITE_JAR" \
        --config-file="$PROJECT_CONFIG" \
        --user-config-file="$USER_CONFIG" &
    BURP_PID=$!

    wait "$BURP_PID"
    EXIT_CODE=$?
    echo "[WARN] Burp Suite exited with code $EXIT_CODE"

    RESTART_COUNT=$((RESTART_COUNT + 1))

    # Decide whether to restart based on RESTART_ON_EXIT
    VALUE=$(printf '%s' "$RESTART_ON_EXIT" | tr '[:upper:]' '[:lower:]')
    case "$VALUE" in
        1|true|yes|on)
            if [ "$RESTART_MAX" = "0" ] || [ "$RESTART_COUNT" -lt "$RESTART_MAX" ]; then
                echo "[INFO] Restarting Burp Suite in ${RESTART_DELAY}s..."
                sleep "$RESTART_DELAY"
                continue
            fi
            echo "[INFO] Restart limit reached; exiting."
            break
            ;;
        *)
            echo "[INFO] RESTART_ON_EXIT is disabled; exiting."
            break
            ;;
    esac
done

exit $EXIT_CODE

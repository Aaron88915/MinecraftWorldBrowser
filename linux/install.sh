#!/bin/sh
set -eu
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "${1:-}" = --in-terminal ]; then
    shift
    MWB_TERMINAL=1
else
    MWB_TERMINAL=0
fi
if [ "$MWB_TERMINAL" = 0 ] && ! [ -t 0 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    if command -v xfce4-terminal >/dev/null 2>&1; then
        exec xfce4-terminal --disable-server --title='世界浏览器安装' --execute /bin/sh "$APP_DIR/install.sh" --in-terminal "$@"
    elif command -v gnome-terminal >/dev/null 2>&1; then
        exec gnome-terminal --wait -- /bin/sh "$APP_DIR/install.sh" --in-terminal "$@"
    elif command -v konsole >/dev/null 2>&1; then
        exec konsole -e /bin/sh "$APP_DIR/install.sh" --in-terminal "$@"
    elif command -v xterm >/dev/null 2>&1; then
        exec xterm -e /bin/sh "$APP_DIR/install.sh" --in-terminal "$@"
    fi
fi
if [ -x "$APP_DIR/runtime/python/bin/python3" ]; then
    PYTHON_BIN="$APP_DIR/runtime/python/bin/python3"
else
    PYTHON_BIN=${MWB_PYTHON:-python3}
fi
MWB_STATUS=0
"$PYTHON_BIN" "$APP_DIR/install.py" "$@" || MWB_STATUS=$?
if [ "$MWB_TERMINAL" = 1 ]; then
    printf '\n%s' '按回车关闭安装窗口…'
    read -r MWB_IGNORED || true
fi
exit "$MWB_STATUS"

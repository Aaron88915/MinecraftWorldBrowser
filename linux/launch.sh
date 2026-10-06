#!/bin/sh
set -eu
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -x "$APP_DIR/runtime/python/bin/python3" ]; then
    PYTHON_BIN="$APP_DIR/runtime/python/bin/python3"
elif [ -x "$APP_DIR/.venv/bin/python" ]; then
    PYTHON_BIN="$APP_DIR/.venv/bin/python"
else
    PYTHON_BIN=${MWB_PYTHON:-python3}
fi
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    printf '%s\n' '需要 Python 3.10 或更高版本。Ubuntu/Debian: sudo apt install python3 python3-venv'
    exit 1
fi
exec "$PYTHON_BIN" "$APP_DIR/MinecraftWorldBrowser.py" "$@"

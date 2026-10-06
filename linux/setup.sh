#!/bin/sh
set -eu
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PYTHON_BIN=${MWB_PYTHON:-python3}
"$PYTHON_BIN" -c 'import sys; assert (3, 10) <= sys.version_info < (3, 14), "此固定 Qt 版本需要 Python 3.10 至 3.13；离线启动包已附带 Python"'
"$PYTHON_BIN" -m venv "$APP_DIR/.venv"
"$APP_DIR/.venv/bin/python" -m pip install -r "$APP_DIR/requirements.txt"
printf '%s\n' '依赖安装完成。运行 sh launch.sh 启动世界浏览器。'

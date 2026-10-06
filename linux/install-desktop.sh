#!/bin/sh
set -eu
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec /bin/sh "$APP_DIR/install.sh" --shortcuts-only "$@"

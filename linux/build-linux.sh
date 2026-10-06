#!/bin/sh
set -eu
if [ "$(uname -s)" != Linux ]; then
    printf '%s\n' 'Linux 独立可执行文件必须在 Linux 上构建。源码启动包可在其他系统生成。' >&2
    exit 1
fi
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$APP_DIR"
sh setup.sh
.venv/bin/python -m pip install 'pyinstaller>=6.12,<7'
VERSION=$(.venv/bin/python MinecraftWorldBrowser.py --version)
.venv/bin/python MinecraftWorldBrowser.py --self-test
QT_QPA_PLATFORM=offscreen .venv/bin/python MinecraftWorldBrowser.py --ui-test
.venv/bin/python -m PyInstaller --noconfirm --clean --onedir --windowed \
    --name "MinecraftWorldBrowser-v$VERSION" --add-data 'assets:assets' MinecraftWorldBrowser.py
mkdir -p dist/licenses
cp THIRD_PARTY_NOTICES.md dist/licenses/
mkdir -p dist/"MinecraftWorldBrowser-v$VERSION"/licenses
cp THIRD_PARTY_NOTICES.md dist/"MinecraftWorldBrowser-v$VERSION"/licenses/
# Include the license files shipped by Qt/PySide and preserve the dynamically linked libraries.
.venv/bin/python tools/collect_licenses.py "dist/MinecraftWorldBrowser-v$VERSION/licenses"
ARCH=$(uname -m)
tar -czf "dist/MinecraftWorldBrowser-v$VERSION-linux-$ARCH.tar.gz" -C dist "MinecraftWorldBrowser-v$VERSION"
printf '构建完成：%s/dist/MinecraftWorldBrowser-v%s-linux-%s.tar.gz\n' "$APP_DIR" "$VERSION" "$ARCH"

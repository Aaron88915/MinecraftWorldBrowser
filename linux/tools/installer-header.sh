#!/bin/sh
set -eu
if [ "${1:-}" = --help ]; then
    printf '%s\n' 'Minecraft Java 世界浏览器 v@VERSION@ 一键安装' \
        '用法：sh MinecraftWorldBrowser-v@VERSION@-linux-x86_64-install.run' \
        '自动补齐 Kali / Debian / Ubuntu 依赖并创建桌面与菜单快捷图标。' \
        '附加选项：--skip-dependencies、--desktop-dir /目录'
    exit 0
fi
if [ "$(uname -s)" != Linux ]; then
    printf '%s\n' '请在 Linux 上运行这个安装包。' >&2
    exit 2
fi
if [ "$(uname -m)" != x86_64 ]; then
    printf '%s\n' '此安装包需要 x86_64 架构。' >&2
    exit 2
fi
MWB_SELF=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")
if [ "${1:-}" = --in-terminal ]; then
    shift
    MWB_TERMINAL=1
else
    MWB_TERMINAL=0
fi
if [ "$MWB_TERMINAL" = 0 ] && ! [ -t 0 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    if command -v xfce4-terminal >/dev/null 2>&1; then
        exec xfce4-terminal --disable-server --title='世界浏览器安装' --execute /bin/sh "$MWB_SELF" --in-terminal "$@"
    elif command -v gnome-terminal >/dev/null 2>&1; then
        exec gnome-terminal --wait -- /bin/sh "$MWB_SELF" --in-terminal "$@"
    elif command -v konsole >/dev/null 2>&1; then
        exec konsole -e /bin/sh "$MWB_SELF" --in-terminal "$@"
    elif command -v xterm >/dev/null 2>&1; then
        exec xterm -e /bin/sh "$MWB_SELF" --in-terminal "$@"
    fi
fi
MWB_TMP=$(mktemp -d "${TMPDIR:-/tmp}/mwb-install.XXXXXXXX")
mwb_cleanup() {
    MWB_RESULT=$?
    trap - 0
    rm -rf -- "$MWB_TMP"
    if [ "$MWB_TERMINAL" = 1 ]; then
        printf '\n%s' '按回车关闭安装窗口…'
        read -r MWB_IGNORED || true
    fi
    exit "$MWB_RESULT"
}
trap mwb_cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM HUP
printf '%s\n' '正在验证并解压 Minecraft 世界浏览器安装包…'
MWB_LINE=$(awk '/^__MWB_PAYLOAD_BELOW__$/ {print NR + 1; exit}' "$MWB_SELF")
if [ -z "$MWB_LINE" ]; then
    printf '%s\n' '安装包不完整，请重新下载。' >&2
    exit 1
fi
tail -n +"$MWB_LINE" "$MWB_SELF" > "$MWB_TMP/payload.tar.gz"
(cd "$MWB_TMP" && printf '%s  payload.tar.gz\n' '@PAYLOAD_SHA256@' | sha256sum -c -)
tar -xzf "$MWB_TMP/payload.tar.gz" -C "$MWB_TMP"
MWB_STATUS=0
/bin/sh "$MWB_TMP/@APP_PREFIX@/install.sh" "$@" || MWB_STATUS=$?
exit "$MWB_STATUS"
__MWB_PAYLOAD_BELOW__

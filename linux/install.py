#!/usr/bin/env python3
"""One-step installer for Kali, Debian and Ubuntu desktops."""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

from mwb import VERSION
from mwb.install import APP_ID, create_shortcuts, desktop_directory, install_application, install_dependencies, trust_shortcut


def main():
    parser = argparse.ArgumentParser(description="Minecraft 世界浏览器一键安装")
    parser.add_argument("--shortcuts-only", action="store_true", help="为当前程序目录创建桌面与菜单快捷图标")
    parser.add_argument("--skip-dependencies", action="store_true", help="系统依赖已由管理员安装时跳过 apt")
    parser.add_argument("--desktop-dir", type=Path, help="指定桌面目录")
    args = parser.parse_args()
    if sys.platform != "linux":
        print("请在 Linux 桌面环境运行安装器。", file=sys.stderr)
        return 2
    if os.geteuid() == 0 and os.environ.get("SUDO_USER", "root") != "root":
        print("请直接运行安装器，不要在前面加 sudo；它会按需请求安装依赖的权限。", file=sys.stderr)
        return 2
    source = Path(__file__).resolve().parent
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).expanduser()
    if not data_home.is_absolute():
        raise ValueError("XDG_DATA_HOME 必须是绝对路径")
    print(f"Minecraft Java 世界浏览器 · Linux v{VERSION}\n", flush=True)
    if args.shortcuts_only:
        desktop = args.desktop_dir or desktop_directory(Path.home())
        _, shortcut = create_shortcuts(source, data_home, desktop)
        app = source
    else:
        if not (source / "runtime/python/bin/python3").is_file():
            raise ValueError("请使用 Linux x86_64 一键安装包，或运行源码版 setup.sh 后使用 install-desktop.sh。")
        if not args.skip_dependencies:
            if not shutil.which("apt-get") or not shutil.which("dpkg-query"):
                raise ValueError("自动安装依赖适用于 Kali / Debian / Ubuntu；其他发行版请手动安装 Qt 系统库后加 --skip-dependencies。")
            install_dependencies(root=os.geteuid() == 0)
        desktop = args.desktop_dir or desktop_directory(Path.home())
        base = data_home / APP_ID
        base.mkdir(parents=True, exist_ok=True)
        import fcntl
        with (base / ".install.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise ValueError("已有安装任务正在运行，请等待它完成。")
            app, shortcut = install_application(source, data_home, desktop)
    trust_shortcut(shortcut)
    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", str(data_home / "applications")], check=False)
    print(f"\n安装完成。\n程序位置：{app}\n桌面图标：{shortcut}\n双击桌面的「Minecraft Java 世界浏览器」即可启动。", flush=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"\n安装未完成：{error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n安装已取消。", file=sys.stderr)
        sys.exit(130)

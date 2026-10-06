"""Diagnose X11 library failures before Qt can abort the whole process."""
from __future__ import annotations

import ctypes
import os
import sys
from pathlib import Path

APT_DEPENDENCIES = ("libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 "
                    "libxcb-render-util0 libxcb-xinerama0 libxkbcommon-x11-0 libgl1 libegl1")


def x11_dependency_error(qt_package: Path, environment=None, loader=None) -> str | None:
    if sys.platform != "linux":
        return None
    environment = os.environ if environment is None else environment
    platform = environment.get("QT_QPA_PLATFORM", "").split(":", 1)[0]
    if platform and platform != "xcb":
        return None
    if not platform and environment.get("WAYLAND_DISPLAY"):
        return None
    plugin = qt_package / "Qt" / "plugins" / "platforms" / "libqxcb.so"
    if not plugin.is_file():
        return None
    loader = ctypes.CDLL if loader is None else loader
    try:
        loader("libxcb-cursor.so.0")
        # Loading the actual plugin also checks its transitive dependencies;
        # the cursor warning alone does not identify every possible missing lib.
        loader(str(plugin))
    except OSError as error:
        return ("Qt 的 X11 图形依赖无法加载，程序尚未启动。\n"
                f"具体原因：{error}\n\n"
                "Kali / Debian / Ubuntu 可在终端执行：\n"
                "  sudo apt update\n"
                f"  sudo apt install {APT_DEPENDENCIES}\n"
                "安装成功后再运行 ./launch.sh。\n")
    return None

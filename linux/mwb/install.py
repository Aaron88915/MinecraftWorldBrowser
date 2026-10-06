"""Per-user installation and desktop shortcuts; the GUI toolkit is not needed."""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import subprocess
import tempfile
import uuid
from pathlib import Path

from . import VERSION
from .environment import APT_DEPENDENCIES

APP_ID = "minecraft-world-browser"
SYSTEM_PACKAGES = APT_DEPENDENCIES.split() + ["xdg-user-dirs", "desktop-file-utils"]


def exec_quote(value: str) -> str:
    if "\n" in value or "\r" in value:
        raise ValueError("安装路径不能包含换行符")
    # Desktop Entry has a value-escape layer followed by argument unquoting.
    escaped = "".join("\\" + char if char in '\\"`$' else char for char in value)
    return '"' + escaped.replace("\\", "\\\\").replace("%", "%%") + '"'


def desktop_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")


def atomic_write(path: Path, data: bytes, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".mwb-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def desktop_directory(home: Path, runner=subprocess.run) -> Path:
    try:
        result = runner(["xdg-user-dir", "DESKTOP"], capture_output=True, text=True, check=False)
        value = result.stdout.strip()
        if result.returncode == 0 and value and Path(value).is_absolute():
            return Path(value)
    except FileNotFoundError:
        pass
    for name in ["Desktop", "桌面"]:
        if (home / name).is_dir():
            return home / name
    return home / "Desktop"


def desktop_entry(app: Path) -> bytes:
    icon = desktop_value(str(app / "assets" / "MinecraftWorldBrowser-icon.png"))
    return ("[Desktop Entry]\nType=Application\nVersion=1.0\n"
            "Name=Minecraft Java 世界浏览器\nComment=浏览、搜索与备份 Minecraft Java 存档\n"
            f"Exec=/bin/sh {exec_quote(str(app / 'launch.sh'))}\nIcon={icon}\n"
            "Terminal=false\nCategories=Game;Utility;\nStartupNotify=true\n"
            "StartupWMClass=MinecraftWorldBrowser\n").encode("utf-8")


def create_shortcuts(app: Path, data_home: Path, desktop: Path) -> tuple[Path, Path]:
    menu = data_home / "applications" / f"{APP_ID}.desktop"
    shortcut = desktop / "Minecraft 世界浏览器.desktop"
    contents = desktop_entry(app)
    snapshots = {path: (path.read_bytes(), stat.S_IMODE(path.stat().st_mode)) if path.exists() else None for path in [menu, shortcut]}
    changed = []
    try:
        for path in [menu, shortcut]:
            atomic_write(path, contents, 0o755)
            changed.append(path)
    except BaseException:
        for path in reversed(changed):
            previous = snapshots[path]
            if previous is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path, *previous)
        raise
    return menu, shortcut


def trust_shortcut(shortcut: Path, runner=subprocess.run):
    digest = hashlib.sha256(shortcut.read_bytes()).hexdigest()
    for attribute, value in [("metadata::xfce-exe-checksum", digest), ("metadata::trusted", "true")]:
        try:
            runner(["gio", "set", str(shortcut), attribute, value], capture_output=True, text=True, check=False)
        except FileNotFoundError:
            return


def missing_packages(runner=subprocess.run) -> list[str]:
    result = runner(["dpkg-query", "-W", "-f=${Package}\t${db:Status-Status}\n", *SYSTEM_PACKAGES],
                    capture_output=True, text=True, check=False)
    installed = {line.split("\t", 1)[0] for line in result.stdout.splitlines() if line.endswith("\tinstalled")}
    return [package for package in SYSTEM_PACKAGES if package not in installed]


def install_dependencies(runner=subprocess.run, root=False):
    missing = missing_packages(runner)
    if not missing:
        print("系统依赖已经齐全。", flush=True)
        return
    print("安装系统依赖：" + "、".join(missing), flush=True)
    privilege = [] if root else ["sudo"]
    runner([*privilege, "apt-get", "update"], check=True)
    runner([*privilege, "apt-get", "install", "-y", *missing], check=True)


def remove_managed_directory(path: Path, parent: Path):
    if path.is_symlink() or path.parent.resolve() != parent.resolve() or path.name in {"", ".", ".."}:
        raise ValueError("拒绝清理安装目录以外的路径")
    if path.exists():
        shutil.rmtree(path)


def validate_runtime(app: Path):
    version = subprocess.run(["/bin/sh", str(app / "launch.sh"), "--version"], capture_output=True, text=True, check=True)
    if version.stdout.strip() != VERSION:
        raise ValueError("安装包版本校验失败")
    subprocess.run(["/bin/sh", str(app / "launch.sh"), "--check-dependencies"], check=True)


def install_application(source: Path, data_home: Path, desktop: Path, validator=validate_runtime) -> tuple[Path, Path]:
    source, data_home = source.resolve(), data_home.resolve()
    base = data_home / APP_ID
    base.mkdir(parents=True, exist_ok=True)
    target = base / "app"
    managed = False
    if target.exists() and not target.is_symlink():
        try:
            managed = json.loads((target / ".mwb-install.json").read_text(encoding="utf-8")).get("application") == APP_ID
        except (OSError, ValueError, AttributeError):
            pass
    if target.is_symlink() or (target.exists() and not managed):
        raise ValueError(f"安装位置已存在其他文件，请先移动该目录：{target}")
    if not (source / "runtime/python/bin/python3").is_file():
        raise ValueError("一键安装需要包含 runtime 的 Linux x86_64 启动包；源码版请先使用 setup.sh。")
    staging = Path(tempfile.mkdtemp(prefix=".install-", dir=base))
    previous = base / (".previous-" + uuid.uuid4().hex)
    moved = committed = False
    try:
        print("复制程序到用户安装目录…", flush=True)
        payload = staging / "app"
        shutil.copytree(source, payload, symlinks=True, ignore=shutil.ignore_patterns("__pycache__", ".venv", "build", "dist", "*.pyc"))
        for path in payload.glob("*.sh"):
            path.chmod(0o755)
        atomic_write(payload / ".mwb-install.json", json.dumps({"application": APP_ID, "version": VERSION}).encode())
        validator(payload)
        if target.exists():
            target.rename(previous)
            moved = True
        payload.rename(target)
        committed = True
        _, shortcut = create_shortcuts(target, data_home, desktop)
    except BaseException:
        if committed:
            remove_managed_directory(target, base)
        if moved:
            previous.rename(target)
        raise
    finally:
        remove_managed_directory(staging, base)
    if moved:
        remove_managed_directory(previous, base)
    return target, shortcut

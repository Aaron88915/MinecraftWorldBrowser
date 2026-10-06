"""Filesystem, metadata and backup services; no GUI or platform toolkit imports."""

from __future__ import annotations

import base64
import errno
import hashlib
import json
import os
import re
import shutil
import stat
import tempfile
import threading
import time
import uuid
import zipfile
from collections import deque
from dataclasses import dataclass
from pathlib import Path, PurePosixPath, PureWindowsPath
from typing import Callable

from . import VERSION
from .nbt import read_level

MANIFEST = ".pcl2-world-browser-backup.txt"
SKIP_DIRS = {".git", ".cache", "node_modules", "__pycache__", "proc", "sys", "dev", "lost+found", ".Trash", "Trash", ".venv"}
MODES = {0: "生存", 1: "创造", 2: "冒险", 3: "旁观"}
DIFFICULTIES = {0: "和平", 1: "简单", 2: "普通", 3: "困难"}
Progress = Callable[[str], None]


class Cancelled(Exception):
    pass


def check_cancel(cancel: threading.Event | None):
    if cancel is not None and cancel.is_set():
        raise Cancelled("操作已取消")


def normalize(path: str | Path) -> str:
    return str(Path(path).expanduser().resolve())


def encode(value: str) -> str:
    return base64.b64encode(value.encode("utf-8")).decode("ascii")


def decode(value: str) -> str:
    return base64.b64decode(value, validate=True).decode("utf-8")


def version_key(value: str) -> tuple:
    matches = re.findall(r"(?<!\d)(\d+)\.(\d+)(?:\.(\d+))?", value)
    return max((tuple(int(x or 0) for x in match) for match in matches), default=(0, 0, 0))


def version_from_data(number: int) -> str:
    for threshold, version in [(4189, "1.21.4 或更高"), (4080, "1.21.2 - 1.21.3"), (3953, "1.21 - 1.21.1"),
                               (3837, "1.20.5 - 1.20.6"), (3698, "1.20.3 - 1.20.4"), (3578, "1.20.2"),
                               (3463, "1.20 - 1.20.1"), (3337, "1.19.4"), (3218, "1.19.3"), (3105, "1.19 - 1.19.2"),
                               (2975, "1.18.2"), (2860, "1.18 - 1.18.1"), (2724, "1.17 - 1.17.1"),
                               (2566, "1.16 - 1.16.5"), (2225, "1.15 - 1.15.2"), (1952, "1.14 - 1.14.4"),
                               (1519, "1.13 - 1.13.2"), (1139, "1.12 - 1.12.2"), (819, "1.11 - 1.11.2"),
                               (510, "1.10 - 1.10.2"), (169, "1.9 - 1.9.4")]:
        if number >= threshold:
            return version
    return "1.8.9 或更早"


def format_size(value: int) -> str:
    size = float(value)
    for suffix in ["B", "KB", "MB", "GB", "TB"]:
        if size < 1024 or suffix == "TB":
            return f"{size:.0f} {suffix}" if suffix == "B" else f"{size:.2f} {suffix}"
        size /= 1024
    return str(value)


def directory_name(path: str) -> str:
    for name in ["PrismLauncher", "MultiMC", "HMCL", "PCL2", "Modrinth", "ATLauncher", "GDLauncher", "CurseForge"]:
        if name.casefold() in path.casefold():
            return name
    target = Path(path)
    if target == Path.home() / ".minecraft":
        return "官方启动器"
    return target.parent.name if target.name == ".minecraft" else target.name


def default_candidates(home: Path | None = None) -> list[Path]:
    home = home or Path.home()
    data = Path(os.environ.get("XDG_DATA_HOME", home / ".local" / "share"))
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    return [home / ".minecraft", home / "Games", home / "Minecraft", home / "Documents", home / "Downloads",
            home / ".local" / "share" / "minecraft", data / "PrismLauncher", data / "multimc", data / "MultiMC",
            data / "ATLauncher", data / "gdlauncher", data / "com.modrinth.theseus", config / "r2modmanPlus-local",
            config / "com.modrinth.theseus", config / "GDLauncher", config / "gdlauncher_next",
            home / ".var" / "app" / "org.prismlauncher.PrismLauncher" / "data" / "PrismLauncher",
            home / ".var" / "app" / "org.multimc.MultiMC" / "data" / "multimc",
            home / ".var" / "app" / "com.modrinth.ModrinthApp" / "data" / "com.modrinth.theseus"]


def scan_starts(home: Path | None = None) -> list[Path]:
    home = home or Path.home()
    starts = [home]
    for location in [Path("/mnt"), Path("/media"), Path("/run/media")]:
        if location.is_dir():
            starts.append(location)
    return starts


def is_game_root(path: Path) -> bool:
    return path.is_dir() and ((path / "saves").is_dir() or (path / "versions").is_dir() or (path / "launcher_profiles.json").is_file())


def discover_roots(starts, max_depth: int | None = 6, cancel=None, progress: Progress | None = None) -> list[str]:
    pending = deque((Path(value).expanduser(), 0) for value in starts)
    seen, found = set(), set()
    count = 0
    while pending:
        check_cancel(cancel)
        current, depth = pending.popleft()
        try:
            if current.is_symlink() or not current.is_dir():
                continue
            key = normalize(current)
            if key in seen:
                continue
            seen.add(key)
            count += 1
            if progress and count % 100 == 0:
                progress(f"已检查 {count:,} 个目录 · {current}")
            if is_game_root(current):
                found.add(key)
                # Explore launcher instances but do not walk large world data trees.
            if current.name == "saves":
                if any(child.is_dir() for child in current.iterdir()):
                    found.add(normalize(current.parent))
                continue
            if (current / "level.dat").is_file():
                found.add(key)
                continue
            if max_depth is not None and depth >= max_depth:
                continue
            with os.scandir(current) as children:
                for child in children:
                    if child.name not in SKIP_DIRS and child.name not in {"region", "entities", "poi", "libraries", "assets", "mods"} and child.is_dir(follow_symlinks=False):
                        pending.append((Path(child.path), depth + 1))
        except (OSError, ValueError):
            continue
    return sorted(found)


def fingerprint(path: Path) -> str:
    parts = []
    for name in ["level.dat", "icon.png", "region"]:
        try:
            value = (path / name).stat()
            parts.extend([value.st_mtime_ns, value.st_size])
        except OSError:
            parts.extend([0, 0])
    return hashlib.sha256(repr(parts).encode()).hexdigest()


def world_locked(path: Path) -> bool:
    lock = path / "session.lock"
    if not lock.exists():
        return False
    try:
        import fcntl
    except ImportError:
        # Only Linux's POSIX file lock semantics are used in the Linux release.
        return False
    try:
        with lock.open("rb") as stream:
            fcntl.lockf(stream, fcntl.LOCK_SH | fcntl.LOCK_NB)
            fcntl.lockf(stream, fcntl.LOCK_UN)
        return False
    except OSError as error:
        return error.errno in {errno.EACCES, errno.EAGAIN}


def infer_loader(instance: Path) -> str:
    paths = [instance, instance.parent] if instance.name == ".minecraft" else [instance]
    text = str(instance).casefold()
    for root in paths:
        for name in ["mmc-pack.json", "instance.cfg"]:
            try:
                text += (root / name).read_text(encoding="utf-8")[:1024 * 1024].casefold()
            except (OSError, UnicodeError):
                pass
    try:
        text += " ".join(file.name.casefold() for file in (instance / "mods").glob("*.jar"))
    except OSError:
        pass
    for token, name in [("neoforge", "NeoForge"), ("fabric", "Fabric"), ("quilt", "Quilt"), ("forge", "Forge")]:
        if token in text:
            return name
    return "原版"


@dataclass
class World:
    path: str
    root: str = ""
    instance: str = ""
    name: str = ""
    version: str = "未知"
    mode: str = "未知"
    health: str = "正常"
    loader: str = "原版"
    source: str = ""
    last_played: float = 0
    size: int = 0
    seed: int = 0
    difficulty: str = "未知"
    cheats: bool = False
    hardcore: bool = False
    data_version: int = 0
    favorite: bool = False
    tags: str = ""
    notes: str = ""
    auto_backup: bool = False
    last_backup_fingerprint: str = ""
    fingerprint: str = ""
    error: str = ""
    backup_count: int = 0


def read_world(path: Path, root: Path, instance: Path) -> World:
    world = World(normalize(path), normalize(root), normalize(instance), path.name,
                  source=instance.name, loader=infer_loader(instance), fingerprint=fingerprint(path))
    try:
        world.last_played = path.stat().st_mtime
        data = read_level(path / "level.dat")
        world.name = str(data.get("LevelName") or path.name)
        world.data_version = int(data.get("DataVersion", 0))
        world.version = str(data.get("Version", {}).get("Name") or version_from_data(world.data_version))
        world.hardcore = bool(data.get("hardcore", 0))
        world.mode = "极限" if world.hardcore else MODES.get(data.get("GameType"), "未知")
        world.difficulty = DIFFICULTIES.get(data.get("Difficulty"), "未知")
        world.cheats = bool(data.get("allowCommands", 0))
        world.seed = int(data.get("WorldGenSettings", {}).get("seed", data.get("RandomSeed", 0)))
        timestamp = int(data.get("LastPlayed", 0)) / 1000
        if 0 < timestamp < 253402300799:
            world.last_played = timestamp
        if world_locked(path):
            world.health = "使用中"
    except (OSError, ValueError, TypeError, AttributeError, EOFError) as error:
        world.health = "异常"
        world.error = f"level.dat: {error}"
    return world


def directory_size(path: Path, cancel=None) -> int:
    total = 0
    for current, directories, files in os.walk(path, followlinks=False):
        check_cancel(cancel)
        directories[:] = [name for name in directories if not (Path(current) / name).is_symlink()]
        for name in files:
            file = Path(current) / name
            try:
                if not file.is_symlink():
                    total += file.stat().st_size
            except OSError:
                pass
    return total


def scan_worlds(roots, metadata: dict | None = None, cancel=None, progress: Progress | None = None) -> list[World]:
    metadata = metadata or {}
    worlds, seen = [], set()
    game_roots = set()
    for root in roots:
        game_roots.update(discover_roots([root], 6, cancel, progress))
        if is_game_root(Path(root)) or (Path(root) / "level.dat").is_file():
            game_roots.add(normalize(root))
    for root_name in sorted(game_roots):
        check_cancel(cancel)
        root = Path(root_name)
        instances = [root]
        try:
            instances.extend(child for child in (root / "versions").iterdir() if child.is_dir() and not child.is_symlink())
        except OSError:
            pass
        candidates = [(root, root)] if (root / "level.dat").is_file() else []
        for instance in instances:
            try:
                candidates.extend((child, instance) for child in (instance / "saves").iterdir() if child.is_dir() and not child.is_symlink())
            except OSError:
                pass
        for path, instance in candidates:
            check_cancel(cancel)
            key = normalize(path)
            if key in seen:
                continue
            seen.add(key)
            world = read_world(path, root, instance)
            for name in ["favorite", "tags", "notes", "auto_backup", "last_backup_fingerprint"]:
                if name in metadata.get(key, {}):
                    setattr(world, name, metadata[key][name])
            if progress:
                progress(f"读取存档大小 · {world.name}")
            world.size = directory_size(path, cancel)
            worlds.append(world)
    return sorted(worlds, key=lambda world: world.last_played, reverse=True)


class Store:
    def __init__(self, directory: Path | None = None):
        self.directory = directory or Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "minecraft-world-browser"
        self.file = self.directory / "settings.json"
        self.roots: list[str] = []
        self.metadata: dict[str, dict] = {}
        self.history: list[dict] = []
        self.dark = False
        self.load_error = ""
        if self.file.exists():
            try:
                data = json.loads(self.file.read_text(encoding="utf-8"))
                if not isinstance(data, dict) or not isinstance(data.get("roots", []), list) or not isinstance(data.get("metadata", {}), dict) or not isinstance(data.get("history", []), list):
                    raise ValueError("配置结构无效")
                self.roots = [value for value in data.get("roots", []) if isinstance(value, str)]
                self.metadata = {key: value for key, value in data.get("metadata", {}).items() if isinstance(key, str) and isinstance(value, dict)}
                self.history = [entry for entry in data.get("history", []) if isinstance(entry, dict) and all(isinstance(entry.get(key), str) for key in ["world", "archive"])]
                self.dark = bool(data.get("dark", False))
            except (OSError, ValueError, TypeError) as error:
                self.load_error = f"配置读取失败：{error}"

    def save(self):
        self.directory.mkdir(parents=True, exist_ok=True)
        data = {"version": VERSION, "roots": self.roots, "metadata": self.metadata, "history": self.history, "dark": self.dark}
        descriptor, temporary = tempfile.mkstemp(prefix="settings-", suffix=".tmp", dir=self.directory)
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
                json.dump(data, stream, ensure_ascii=False, indent=2)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, self.file)
        finally:
            Path(temporary).unlink(missing_ok=True)

    def update_world(self, world: World):
        self.metadata[world.path] = {name: getattr(world, name) for name in ["favorite", "tags", "notes", "auto_backup", "last_backup_fingerprint"]}

    def record_backup(self, world: World, archive: Path):
        self.history.append({"world": world.path, "archive": normalize(archive), "created": time.time()})
        world.last_backup_fingerprint = world.fingerprint
        self.update_world(world)
        self.save()

    def export_config(self, destination: Path):
        lines = ["MinecraftWorldBrowserConfig=1"]
        lines += ["Root=" + encode(value) for value in self.roots]
        for path, value in self.metadata.items():
            fields = [encode(path), "1" if value.get("favorite") else "0", encode(str(value.get("tags", ""))),
                      encode(str(value.get("notes", ""))), "1" if value.get("auto_backup") else "0", encode(str(value.get("last_backup_fingerprint", "")))]
            lines.append("Meta=" + "\t".join(fields))
        destination.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def import_config(self, source: Path) -> int:
        lines = source.read_text(encoding="utf-8-sig").splitlines()
        if not lines or lines[0] != "MinecraftWorldBrowserConfig=1":
            raise ValueError("配置文件格式无效")
        roots, metadata, skipped = list(self.roots), dict(self.metadata), 0
        for line in lines[1:]:
            if line.startswith("Root="):
                root = decode(line[5:])
                if not Path(root).is_absolute() or not Path(root).is_dir():
                    skipped += 1
                    continue
                key = normalize(root)
                if key not in roots:
                    roots.append(key)
            elif line.startswith("Meta="):
                fields = line[5:].split("\t")
                if len(fields) < 4:
                    raise ValueError("配置元数据不完整")
                metadata[decode(fields[0])] = {"favorite": fields[1] == "1", "tags": decode(fields[2]), "notes": decode(fields[3]),
                                             "auto_backup": len(fields) > 4 and fields[4] == "1",
                                             "last_backup_fingerprint": decode(fields[5]) if len(fields) > 5 else ""}
        self.roots, self.metadata = roots, metadata
        self.save()
        return skipped


def safe_name(value: str) -> str:
    return re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", value).strip(" .") or "Minecraft World"


def create_backup(world: World, destination: Path, cancel=None, progress: Progress | None = None) -> Path:
    source = Path(world.path)
    destination = destination.expanduser().absolute()
    if source.is_symlink() or not (source / "level.dat").is_file():
        raise ValueError("存档目录无效")
    if destination.resolve().is_relative_to(source.resolve()):
        raise ValueError("备份不能放在存档目录内部")
    if world_locked(source):
        raise ValueError("存档正在使用，请先退出游戏再备份")
    if destination.exists():
        raise FileExistsError(f"备份文件已存在：{destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    before = fingerprint(source)
    descriptor, temporary = tempfile.mkstemp(prefix=".mwb-backup-", suffix=".zip", dir=destination.parent)
    os.close(descriptor)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as archive:
            for current, directories, files in os.walk(source, followlinks=False):
                check_cancel(cancel)
                directories[:] = [name for name in directories if not (Path(current) / name).is_symlink()]
                for name in files:
                    file = Path(current) / name
                    if file.is_symlink() or not file.is_file() or name == MANIFEST:
                        continue
                    check_cancel(cancel)
                    relative = file.relative_to(source).as_posix()
                    if progress:
                        progress(f"正在备份 · {relative}")
                    archive.write(file, relative)
            ticks = int((time.time() + 62135596800) * 10000000)
            manifest = ["PCL2WorldBrowserBackup=1", "OriginalPath=" + encode(world.path), "RootPath=" + encode(world.root),
                        "WorldName=" + encode(world.name), "Source=" + encode(world.source), "CreatedUtcTicks=" + str(ticks)]
            archive.writestr(MANIFEST, "\n".join(manifest) + "\n")
        check_cancel(cancel)
        if world_locked(source) or before != fingerprint(source):
            raise ValueError("备份期间存档发生变化，请退出游戏后重试")
        # Exclusive creation: never overwrite an archive that appeared during compression.
        with open(destination, "xb") as target, open(temporary, "rb") as stream:
            try:
                shutil.copyfileobj(stream, target, 1024 * 1024)
            except BaseException:
                target.close()
                destination.unlink(missing_ok=True)
                raise
        return destination
    finally:
        Path(temporary).unlink(missing_ok=True)


def read_manifest(source: Path) -> dict:
    with zipfile.ZipFile(source) as archive:
        try:
            entry = archive.getinfo(MANIFEST)
        except KeyError:
            return {}
        if entry.file_size > 1024 * 1024:
            raise ValueError("备份清单过大")
        lines = archive.read(entry).decode("utf-8-sig").splitlines()
    values = dict(line.split("=", 1) for line in lines if "=" in line)
    if values.get("PCL2WorldBrowserBackup") != "1":
        return {}
    return {key: decode(values.get(key, "")) for key in ["OriginalPath", "RootPath", "WorldName", "Source"]}


def safe_original_path(value: str) -> bool:
    if not value or PureWindowsPath(value).drive:
        return False
    path = Path(value)
    return path.is_absolute() and path.parent.name == "saves" and not path.is_symlink() and not path.parent.is_symlink()


def unique_directory(path: Path) -> Path:
    if not path.exists():
        return path
    for count in range(2, 10000):
        candidate = path.with_name(f"{path.name} ({count})")
        if not candidate.exists():
            return candidate
    return path.with_name(f"{path.name}-{uuid.uuid4().hex[:8]}")


def validate_entries(archive: zipfile.ZipFile) -> list[tuple[zipfile.ZipInfo, PurePosixPath]]:
    entries, seen, total = [], set(), 0
    for entry in archive.infolist():
        name = entry.filename.replace("\\", "/")
        path = PurePosixPath(name)
        if not name or "\0" in name or path.is_absolute() or ".." in path.parts or re.match(r"^[A-Za-z]:", name):
            raise ValueError(f"ZIP 包含不安全路径：{name}")
        mode = entry.external_attr >> 16
        kind = stat.S_IFMT(mode)
        if kind not in {0, stat.S_IFREG, stat.S_IFDIR}:
            raise ValueError(f"ZIP 包含链接或特殊文件：{name}")
        normalized = path.as_posix().rstrip("/")
        key = os.path.normcase(normalized)
        if key in seen:
            raise ValueError(f"ZIP 包含重复路径：{name}")
        seen.add(key)
        total += entry.file_size
        if total > 200 * 1024**3 or len(seen) > 1000000:
            raise ValueError("ZIP 展开大小或文件数超过上限")
        if normalized != MANIFEST:
            entries.append((entry, path))
    return entries


def restore_backup(source: Path, destination: Path, overwrite: bool = False, cancel=None, progress: Progress | None = None) -> Path:
    source = source.resolve()
    destination = destination.expanduser().absolute()
    if destination.name in {"", ".", ".."} or destination == destination.anchor or destination.is_symlink():
        raise ValueError("恢复目标无效")
    if destination.exists() and not overwrite:
        raise FileExistsError("目标存档已存在")
    if destination.exists() and (not destination.is_dir() or not (destination / "level.dat").is_file()):
        raise ValueError("只能覆盖包含 level.dat 的存档目录")
    if source.is_relative_to(destination.resolve()):
        raise ValueError("备份文件不能位于被覆盖的目录中")
    if world_locked(destination):
        raise ValueError("目标存档正在使用，请先退出游戏")
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Stage beside the target for atomic same-filesystem renames and complete rollback.
    with tempfile.TemporaryDirectory(prefix=".mwb-restore-", dir=destination.parent) as directory:
        staging = Path(directory) / "payload"
        staging.mkdir()
        with zipfile.ZipFile(source) as archive:
            entries = validate_entries(archive)
            for entry, path in entries:
                check_cancel(cancel)
                target = staging.joinpath(*path.parts)
                if not target.resolve().is_relative_to(staging.resolve()):
                    raise ValueError("ZIP 路径超出恢复目录")
                if entry.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if progress:
                        progress(f"正在恢复 · {path}")
                    with archive.open(entry) as stream, target.open("xb") as output:
                        while chunk := stream.read(1024 * 1024):
                            check_cancel(cancel)
                            output.write(chunk)
        payload = staging
        if not (payload / "level.dat").is_file():
            children = list(payload.iterdir())
            if len(children) != 1 or not children[0].is_dir() or not (children[0] / "level.dat").is_file():
                raise ValueError("ZIP 中没有可恢复的 Minecraft 世界")
            payload = children[0]
        read_level(payload / "level.dat")
        check_cancel(cancel)
        if world_locked(destination):
            raise ValueError("目标存档正在使用")
        rollback = destination.with_name(f".mwb-previous-{uuid.uuid4().hex}")
        moved = False
        try:
            if destination.exists():
                if not overwrite:
                    raise FileExistsError("目标存档已存在")
                destination.rename(rollback)
                moved = True
            payload.rename(destination)
        except BaseException:
            if moved:
                rollback.rename(destination)
            raise
        if moved:
            shutil.rmtree(rollback)
    return destination

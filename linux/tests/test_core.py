import gzip
import json
import os
import stat
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from mwb import VERSION
from mwb.core import Cancelled, MANIFEST, Store, create_backup, default_candidates, directory_size, discover_roots, encode, fingerprint, infer_loader, read_manifest, read_world, restore_backup, safe_original_path, scan_worlds, unique_directory, version_key, world_locked
from mwb.nbt import NBTError, Reader, read_level
from mwb.environment import x11_dependency_error


def nbt_string(value):
    value = value.encode("utf-8")
    return struct.pack(">H", len(value)) + value


def named(kind, name, payload):
    return bytes([kind]) + nbt_string(name) + payload


def fixture_bytes(name="Codex 测试世界 🌍", game_type=1):
    version = named(8, "Name", nbt_string("1.21.1")) + b"\0"
    worldgen = named(4, "seed", struct.pack(">q", -1234567890123456789)) + b"\0"
    data = named(8, "LevelName", nbt_string(name))
    data += named(3, "GameType", struct.pack(">i", game_type))
    data += named(3, "DataVersion", struct.pack(">i", 3953))
    data += named(1, "Difficulty", b"\x02")
    data += named(1, "allowCommands", b"\x01")
    data += named(4, "LastPlayed", struct.pack(">q", 1750000000000))
    data += named(10, "Version", version) + named(10, "WorldGenSettings", worldgen) + b"\0"
    return named(10, "", named(10, "Data", data) + b"\0")


def make_world(path, name="Codex 测试世界 🌍"):
    path.mkdir(parents=True, exist_ok=True)
    (path / "level.dat").write_bytes(gzip.compress(fixture_bytes(name)))
    (path / "region").mkdir(exist_ok=True)
    (path / "region" / "r.0.0.mca").write_bytes(b"region-content" * 40)
    (path / "notes.txt").write_text("存档文件\n", encoding="utf-8")
    return read_world(path, path.parent.parent, path.parent.parent)


class CoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.root = self.directory / ".minecraft"
        self.path = self.root / "saves" / "world"
        self.world = make_world(self.path)

    def tearDown(self):
        self.temporary.cleanup()

    def archive(self, name="backup.zip"):
        return create_backup(self.world, self.directory / name)

    def test_version_matches_windows(self):
        self.assertEqual(VERSION, "3.3.2")

    def test_missing_x11_cursor_reports_kali_install_command(self):
        qt = self.directory / "PySide6"
        plugin = qt / "Qt/plugins/platforms/libqxcb.so"
        plugin.parent.mkdir(parents=True)
        plugin.touch()
        def missing(name):
            raise OSError("libxcb-cursor.so.0: cannot open shared object file")
        with patch("mwb.environment.sys.platform", "linux"):
            error = x11_dependency_error(qt, {"DISPLAY": ":0"}, loader=missing)
        self.assertIn("libxcb-cursor.so.0", error)
        self.assertIn("sudo apt install libxcb-cursor0", error)
        self.assertIn("Kali", error)

    def test_other_missing_x11_dependency_is_identified(self):
        qt = self.directory / "PySide6"
        plugin = qt / "Qt/plugins/platforms/libqxcb.so"
        plugin.parent.mkdir(parents=True)
        plugin.touch()
        def load(name):
            if name == str(plugin):
                raise OSError("libxkbcommon-x11.so.0: cannot open shared object file")
        with patch("mwb.environment.sys.platform", "linux"):
            error = x11_dependency_error(qt, {"DISPLAY": ":0"}, loader=load)
        self.assertIn("libxkbcommon-x11.so.0", error)
        self.assertIn("libxkbcommon-x11-0", error)

    def test_available_x11_libraries_allow_startup(self):
        qt = self.directory / "PySide6"
        plugin = qt / "Qt/plugins/platforms/libqxcb.so"
        plugin.parent.mkdir(parents=True)
        plugin.touch()
        loaded = []
        with patch("mwb.environment.sys.platform", "linux"):
            self.assertIsNone(x11_dependency_error(qt, {"DISPLAY": ":0"}, loader=loaded.append))
        self.assertEqual(loaded, ["libxcb-cursor.so.0", str(plugin)])

    def test_x11_check_respects_offscreen_and_wayland(self):
        qt = self.directory / "PySide6"
        plugin = qt / "Qt/plugins/platforms/libqxcb.so"
        plugin.parent.mkdir(parents=True)
        plugin.touch()
        with patch("mwb.environment.sys.platform", "linux"):
            for environment in [{"QT_QPA_PLATFORM": "offscreen"}, {"QT_QPA_PLATFORM": "wayland"}, {"WAYLAND_DISPLAY": "wayland-0"}]:
                self.assertIsNone(x11_dependency_error(qt, environment, loader=lambda name: self.fail("X11 library checked for a different backend")))

    def test_nbt_world_metadata_and_signed_seed(self):
        self.assertEqual(self.world.name, "Codex 测试世界 🌍")
        self.assertEqual(self.world.version, "1.21.1")
        self.assertEqual(self.world.mode, "创造")
        self.assertEqual(self.world.seed, -1234567890123456789)
        self.assertEqual(self.world.difficulty, "普通")
        self.assertTrue(self.world.cheats)
        self.assertEqual(self.world.last_played, 1750000000)

    def test_all_nbt_numeric_and_array_types(self):
        payload = b""
        for kind, fmt, value in [(1, "b", -3), (2, "h", -500), (3, "i", 12345), (4, "q", -99999999999), (5, "f", 1.25), (6, "d", 2.5)]:
            payload += named(kind, str(kind), struct.pack(">" + fmt, value))
        payload += named(7, "bytes", struct.pack(">i", 3) + b"abc")
        payload += named(9, "list", b"\x03" + struct.pack(">i", 2) + struct.pack(">ii", 2, 3))
        payload += named(11, "ints", struct.pack(">iii", 2, -1, 4))
        payload += named(12, "longs", struct.pack(">iqq", 2, -2, 5))
        root = Reader(named(10, "", payload + b"\0")).root()
        self.assertEqual(root["bytes"], b"abc")
        self.assertEqual(root["list"], [2, 3])
        self.assertEqual(root["ints"], [-1, 4])
        self.assertEqual(root["longs"], [-2, 5])
        self.assertEqual(root["5"], 1.25)

    def test_modified_utf8_surrogate_pair_and_null(self):
        value = b"a\xc0\x80\xed\xa0\xbc\xed\xbc\x8d"
        root = Reader(named(10, "", named(8, "name", struct.pack(">H", len(value)) + value) + b"\0")).root()
        self.assertEqual(root["name"], "a\0🌍")

    def test_invalid_nbt_lengths_and_truncation(self):
        for data in [fixture_bytes()[:-5], named(10, "", named(7, "bad", struct.pack(">i", -1)) + b"\0"), b"\x0d\0\0"]:
            with self.subTest(data=data[:8]), self.assertRaises(NBTError):
                Reader(data).root()

    def test_nbt_depth_limit(self):
        data = b"\0"
        for _ in range(70):
            data = named(10, "x", data) + b"\0"
        with self.assertRaises(NBTError):
            Reader(named(10, "", data)).root()

    def test_corrupt_and_missing_level_are_visible(self):
        (self.path / "level.dat").write_bytes(b"broken")
        world = read_world(self.path, self.root, self.root)
        self.assertEqual(world.health, "异常")
        self.assertIn("level.dat", world.error)
        (self.path / "level.dat").unlink()
        self.assertEqual(read_world(self.path, self.root, self.root).health, "异常")

    def test_launcher_and_version_discovery_deduplicate(self):
        nested = self.directory / "PrismLauncher" / "instances" / "sample" / ".minecraft"
        make_world(nested / "saves" / "creative")
        make_world(self.root / "versions" / "1.21.1-Fabric" / "saves" / "version-world")
        roots = discover_roots([self.directory], 7)
        self.assertIn(str(nested.resolve()), roots)
        worlds = scan_worlds([self.directory, self.root])
        self.assertEqual(len(worlds), 3)
        self.assertEqual(len({world.path for world in worlds}), 3)
        self.assertEqual(next(world for world in worlds if "version-world" in world.path).loader, "Fabric")

    def test_standalone_world_directory(self):
        self.assertEqual(len(scan_worlds([self.path])), 1)

    def test_prism_loader_pack_detection(self):
        (self.root / "mmc-pack.json").write_text('{"components": [{"uid": "net.neoforged.neoforge"}]}')
        self.assertEqual(infer_loader(self.root), "NeoForge")

    def test_discovery_cancellation(self):
        cancel = threading.Event()
        cancel.set()
        with self.assertRaises(Cancelled):
            discover_roots([self.directory], cancel=cancel)

    def test_discovery_does_not_descend_world_data_or_caches(self):
        fake = self.directory / ".cache" / "unrelated" / ".minecraft"
        make_world(fake / "saves" / "ignored")
        self.assertNotIn(str(fake.resolve()), discover_roots([self.directory]))

    def test_linux_flatpak_defaults(self):
        values = default_candidates(self.directory)
        self.assertIn(self.directory / ".minecraft", values)
        self.assertTrue(any("org.prismlauncher.PrismLauncher" in str(path) for path in values))

    def test_version_sorting_is_numeric(self):
        values = ["1.9", "1.21.11", "1.21.4 或更高", "1.20.4", "unknown"]
        self.assertEqual(sorted(values, key=version_key, reverse=True), ["1.21.11", "1.21.4 或更高", "1.20.4", "1.9", "unknown"])

    def test_size_matches_actual_regular_files(self):
        expected = sum(path.stat().st_size for path in self.path.rglob("*") if path.is_file())
        self.assertEqual(directory_size(self.path), expected)
        self.assertEqual(scan_worlds([self.root])[0].size, expected)

    @unittest.skipUnless(os.name == "posix", "Linux symbolic link semantics")
    def test_symlinks_are_not_traversed_or_backed_up(self):
        secret = self.directory / "private.txt"
        secret.write_text("outside")
        (self.path / "linked-file").symlink_to(secret)
        (self.path / "linked-directory").symlink_to(self.directory, target_is_directory=True)
        size = directory_size(self.path)
        self.assertLess(size, 10000)
        with zipfile.ZipFile(self.archive()) as archive:
            self.assertNotIn("linked-file", archive.namelist())
            self.assertFalse(any("linked-directory" in name for name in archive.namelist()))

    def test_backup_manifest_matches_windows_format(self):
        archive = self.archive()
        manifest = read_manifest(archive)
        self.assertEqual(manifest["OriginalPath"], self.world.path)
        self.assertEqual(manifest["WorldName"], self.world.name)
        with zipfile.ZipFile(archive) as file:
            text = file.read(MANIFEST).decode()
            self.assertTrue(text.startswith("PCL2WorldBrowserBackup=1\n"))
            self.assertIn("CreatedUtcTicks=", text)
            self.assertEqual(file.read("notes.txt"), (self.path / "notes.txt").read_bytes())

    def test_backup_restore_exact_round_trip(self):
        archive = self.archive()
        destination = self.root / "saves" / "restored"
        restore_backup(archive, destination)
        for source in self.path.rglob("*"):
            if source.is_file():
                self.assertEqual(source.read_bytes(), (destination / source.relative_to(self.path)).read_bytes())
        self.assertFalse((destination / MANIFEST).exists())

    def test_restore_windows_manifest_and_wrapped_directory(self):
        archive = self.directory / "windows.zip"
        with zipfile.ZipFile(archive, "w") as file:
            file.writestr(MANIFEST, "PCL2WorldBrowserBackup=1\nOriginalPath=" + encode(r"D:\Minecraft\saves\世界") + "\nWorldName=" + encode("世界"))
            file.writestr("World/level.dat", (self.path / "level.dat").read_bytes())
            file.writestr("World/region/r.0.0.mca", b"world")
        self.assertFalse(safe_original_path(read_manifest(archive)["OriginalPath"]))
        destination = self.root / "saves" / "windows-restored"
        restore_backup(archive, destination)
        self.assertTrue((destination / "level.dat").is_file())

    def test_zip_path_traversal_and_absolute_names_rejected(self):
        for name in ["../outside.txt", "/absolute.txt", "C:/outside.txt", "..\\outside.txt", "world/../../outside.txt"]:
            with self.subTest(name=name):
                archive = self.directory / "malicious.zip"
                with zipfile.ZipFile(archive, "w") as file:
                    file.writestr("level.dat", (self.path / "level.dat").read_bytes())
                    file.writestr(name, "bad")
                destination = self.root / "saves" / "unsafe"
                with self.assertRaises(ValueError):
                    restore_backup(archive, destination)
                self.assertFalse(destination.exists())
                self.assertFalse((self.directory / "outside.txt").exists())

    def test_zip_symlink_and_special_files_rejected(self):
        for mode in [stat.S_IFLNK | 0o777, stat.S_IFIFO | 0o600]:
            archive = self.directory / "malicious-link.zip"
            with zipfile.ZipFile(archive, "w") as file:
                file.writestr("level.dat", (self.path / "level.dat").read_bytes())
                entry = zipfile.ZipInfo("linked")
                entry.create_system = 3
                entry.external_attr = mode << 16
                file.writestr(entry, "../../outside")
            with self.assertRaises(ValueError):
                restore_backup(archive, self.root / "saves" / "unsafe")

    def test_duplicate_normalized_zip_paths_rejected(self):
        archive = self.directory / "duplicate.zip"
        with zipfile.ZipFile(archive, "w") as file:
            file.writestr("level.dat", (self.path / "level.dat").read_bytes())
            file.writestr("region/file", "one")
            file.writestr("region/./file", "two")
        with self.assertRaises(ValueError):
            restore_backup(archive, self.root / "saves" / "unsafe")

    def test_restore_failure_preserves_existing_world(self):
        archive = self.directory / "corrupt.zip"
        original = (self.path / "level.dat").read_bytes()
        with zipfile.ZipFile(archive, "w") as file:
            file.writestr("level.dat", b"broken gzip")
        with self.assertRaises(OSError):
            restore_backup(archive, self.path, overwrite=True)
        self.assertEqual((self.path / "level.dat").read_bytes(), original)

    def test_restore_commit_failure_rolls_back_original(self):
        archive = self.archive()
        original = (self.path / "notes.txt").read_bytes()
        original_rename = Path.rename

        def rename(path, target):
            if path.name == "payload":
                raise OSError("simulated commit failure")
            return original_rename(path, target)

        with patch.object(Path, "rename", rename), self.assertRaises(OSError):
            restore_backup(archive, self.path, overwrite=True)
        self.assertEqual((self.path / "notes.txt").read_bytes(), original)
        self.assertFalse(list(self.path.parent.glob(".mwb-previous-*")))

    def test_cancellation_preserves_existing_world_and_archive(self):
        cancel = threading.Event()
        cancel.set()
        destination = self.directory / "cancelled.zip"
        with self.assertRaises(Cancelled):
            create_backup(self.world, destination, cancel)
        self.assertFalse(destination.exists())
        archive = self.archive()
        original = (self.path / "level.dat").read_bytes()
        with self.assertRaises(Cancelled):
            restore_backup(archive, self.path, overwrite=True, cancel=cancel)
        self.assertEqual((self.path / "level.dat").read_bytes(), original)

    def test_backup_not_inside_world_or_over_existing_archive(self):
        with self.assertRaises(ValueError):
            create_backup(self.world, self.path / "backup.zip")
        archive = self.archive()
        original = archive.read_bytes()
        with self.assertRaises(FileExistsError):
            create_backup(self.world, archive)
        self.assertEqual(archive.read_bytes(), original)

    def test_restore_will_not_overwrite_arbitrary_directory(self):
        destination = self.directory / "documents"
        destination.mkdir()
        (destination / "important.txt").write_text("preserve")
        with self.assertRaises(ValueError):
            restore_backup(self.archive(), destination, overwrite=True)
        self.assertEqual((destination / "important.txt").read_text(), "preserve")

    def test_store_metadata_and_history_survive_restart(self):
        store = Store(self.directory / "settings")
        store.roots = [str(self.root)]
        self.world.favorite, self.world.tags, self.world.notes, self.world.auto_backup = True, "主存档", "两行\n备注", True
        store.record_backup(self.world, self.archive())
        saved = Store(store.directory)
        self.assertEqual(saved.roots, [str(self.root)])
        self.assertEqual(saved.metadata[self.world.path]["notes"], "两行\n备注")
        self.assertEqual(saved.history[0]["world"], self.world.path)
        worlds = scan_worlds(saved.roots, saved.metadata)
        self.assertTrue(worlds[0].favorite)
        self.assertTrue(worlds[0].auto_backup)

    def test_config_import_export_and_invalid_import_atomicity(self):
        store = Store(self.directory / "settings")
        store.roots = [str(self.root)]
        self.world.favorite, self.world.tags, self.world.notes = True, "标签", "第一行\n第二行"
        store.update_world(self.world)
        config = self.directory / "export.mwconfig"
        store.export_config(config)
        target = Store(self.directory / "other-settings")
        self.assertEqual(target.import_config(config), 0)
        self.assertEqual(target.metadata, store.metadata)
        before = target.file.read_bytes()
        config.write_text("MinecraftWorldBrowserConfig=1\nMeta=bad\t1\tinvalid\tbad", encoding="utf-8")
        with self.assertRaises(ValueError):
            target.import_config(config)
        self.assertEqual(target.file.read_bytes(), before)

    def test_foreign_config_paths_are_skipped_without_losing_metadata(self):
        config = self.directory / "foreign.mwconfig"
        foreign = r"D:\Minecraft\saves\World"
        config.write_text("MinecraftWorldBrowserConfig=1\nRoot=" + encode(r"D:\nonexistent-minecraft") + "\nMeta=" + encode(foreign) + "\t1\t" + encode("标签") + "\t" + encode("备注"), encoding="utf-8")
        store = Store(self.directory / "settings")
        self.assertEqual(store.import_config(config), 1)
        self.assertEqual(store.metadata[foreign]["tags"], "标签")

    def test_corrupted_settings_report_error_without_overwriting(self):
        directory = self.directory / "settings"
        directory.mkdir()
        file = directory / "settings.json"
        file.write_text("not json")
        store = Store(directory)
        self.assertTrue(store.load_error)
        self.assertEqual(file.read_text(), "not json")

    def test_unique_restore_directory(self):
        value = unique_directory(self.path)
        self.assertEqual(value.name, "world (2)")
        self.assertFalse(value.exists())

    @unittest.skipUnless(os.name == "posix", "Linux POSIX byte-range locks")
    def test_running_java_style_world_lock_detected(self):
        (self.path / "session.lock").write_bytes(b"\0" * 8)
        script = "import fcntl,sys; f=open(sys.argv[1],'rb+'); fcntl.lockf(f,fcntl.LOCK_EX); print('locked',flush=True); sys.stdin.readline()"
        child = subprocess.Popen([sys.executable, "-c", script, str(self.path / "session.lock")], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        try:
            self.assertEqual(child.stdout.readline().strip(), "locked")
            self.assertTrue(world_locked(self.path))
            with self.assertRaises(ValueError):
                create_backup(self.world, self.directory / "locked.zip")
            with self.assertRaises(ValueError):
                restore_backup(self.archive_for_lock_test(), self.path, overwrite=True)
        finally:
            child.communicate("exit\n", timeout=5)
        self.assertFalse(world_locked(self.path))

    def archive_for_lock_test(self):
        archive = self.directory / "locked-restore.zip"
        with zipfile.ZipFile(archive, "w") as file:
            file.writestr("level.dat", (self.path / "level.dat").read_bytes())
        return archive


if __name__ == "__main__":
    unittest.main()

import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from mwb.install import APP_ID, SYSTEM_PACKAGES, atomic_write, create_shortcuts, desktop_directory, desktop_entry, exec_quote, install_application, install_dependencies, missing_packages, trust_shortcut


class InstallTests(unittest.TestCase):
    def setUp(self):
        fixture_root = Path(__file__).resolve().parents[2] / "build/installer-tests"
        fixture_root.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="test-", dir=fixture_root)
        self.base = Path(self.temporary.name)
        self.source = self.base / "下载" / "World Browser"
        (self.source / "runtime/python/bin").mkdir(parents=True)
        (self.source / "runtime/python/bin/python3").write_text("fixture")
        (self.source / "assets").mkdir()
        (self.source / "assets/MinecraftWorldBrowser-icon.png").write_bytes(b"PNG")
        (self.source / "launch.sh").write_text("#!/bin/sh\nprintf '3.3.2\\n'\n")
        self.data = self.base / "local share"
        self.desktop = self.base / "桌面"

    def tearDown(self):
        # All recursive cleanup remains under this explicit workspace fixture.
        self.assertTrue(self.base.resolve().is_relative_to(Path(__file__).resolve().parents[2]))
        self.temporary.cleanup()

    def install(self, **kwargs):
        return install_application(self.source, self.data, self.desktop, validator=kwargs.get("validator", lambda app: None))

    def test_shortcuts_point_to_installed_app_after_download_is_removed(self):
        app, shortcut = self.install()
        self.source.rename(self.source.with_name("download-removed"))
        contents = shortcut.read_text(encoding="utf-8")
        self.assertIn("Exec=/bin/sh " + exec_quote(str(app / "launch.sh")), contents)
        self.assertIn(str(app / "assets/MinecraftWorldBrowser-icon.png"), contents.replace("\\\\", "\\"))
        self.assertNotIn("下载", contents)
        self.assertTrue((app / "runtime/python/bin/python3").is_file())
        self.assertEqual((self.data / "applications/minecraft-world-browser.desktop").read_bytes(), shortcut.read_bytes())
        if os.name == "posix":
            self.assertTrue(stat.S_IMODE(shortcut.stat().st_mode) & 0o111)

    def test_reinstall_preserves_configuration_and_backups(self):
        app, _ = self.install()
        config = app.parent / "settings.json"
        archive = app.parent / "AutomaticBackups/world.zip"
        config.write_text('custom settings')
        archive.parent.mkdir()
        archive.write_bytes(b"existing backup")
        (self.source / "revision.txt").write_text("updated")
        again, _ = self.install()
        self.assertEqual(app, again)
        self.assertEqual((again / "revision.txt").read_text(), "updated")
        self.assertEqual(config.read_text(), "custom settings")
        self.assertEqual(archive.read_bytes(), b"existing backup")
        self.assertEqual(list(app.parent.glob(".previous-*")), [])

    def test_failed_validation_keeps_previous_install(self):
        app, shortcut = self.install()
        original = shortcut.read_bytes()
        (app / "original.txt").write_text("original")
        def fail(payload):
            raise ValueError("missing library")
        with self.assertRaises(ValueError):
            self.install(validator=fail)
        self.assertEqual((app / "original.txt").read_text(), "original")
        self.assertEqual(shortcut.read_bytes(), original)
        self.assertEqual(list(app.parent.glob(".install-*")), [])

    def test_failed_shortcut_creation_rolls_back_installed_files(self):
        app, _ = self.install()
        (app / "original.txt").write_text("original")
        with patch("mwb.install.create_shortcuts", side_effect=PermissionError("desktop read-only")):
            with self.assertRaises(PermissionError):
                self.install()
        self.assertEqual((app / "original.txt").read_text(), "original")

    def test_install_refuses_to_replace_unmanaged_directory(self):
        target = self.data / APP_ID / "app"
        target.mkdir(parents=True)
        (target / "personal.txt").write_text("preserve")
        with self.assertRaises(ValueError):
            self.install()
        self.assertEqual((target / "personal.txt").read_text(), "preserve")

    def test_shortcut_write_failure_restores_previous_menu(self):
        menu = self.data / "applications/minecraft-world-browser.desktop"
        menu.parent.mkdir(parents=True)
        menu.write_bytes(b"old menu")
        def write(path, data, mode):
            if path.parent == self.desktop:
                raise PermissionError("desktop read-only")
            atomic_write(path, data, mode)
        with patch("mwb.install.atomic_write", side_effect=write):
            with self.assertRaises(PermissionError):
                create_shortcuts(self.source, self.data, self.desktop)
        self.assertEqual(menu.read_bytes(), b"old menu")

    def test_localized_desktop_is_read_from_xdg(self):
        runner = lambda *args, **kwargs: subprocess.CompletedProcess(args[0], 0, str(self.desktop) + "\n")
        self.assertEqual(desktop_directory(self.base, runner=runner), self.desktop)

    def test_desktop_exec_escapes_spaces_percent_and_reserved_characters(self):
        value = '/home/user/应用 $cash`tick"quote\\path%20/launch.sh'
        quoted = exec_quote(value)
        self.assertTrue(quoted.startswith('"') and quoted.endswith('"'))
        self.assertIn("%%20", quoted)
        self.assertIn("\\\\$", quoted)
        self.assertIn("\\\\\\\\path", quoted)
        with self.assertRaises(ValueError):
            exec_quote("/home/user\nInjected=bad")

    def test_only_missing_packages_request_sudo_and_apt(self):
        commands = []
        missing = SYSTEM_PACKAGES[0]
        def runner(command, **kwargs):
            commands.append(command)
            if command[0] == "dpkg-query":
                return subprocess.CompletedProcess(command, 1, "".join(p + "\tinstalled\n" for p in SYSTEM_PACKAGES if p != missing))
            return subprocess.CompletedProcess(command, 0)
        install_dependencies(runner=runner)
        self.assertEqual(commands[1], ["sudo", "apt-get", "update"])
        self.assertEqual(commands[2], ["sudo", "apt-get", "install", "-y", missing])

    def test_installed_packages_do_not_request_root_or_network(self):
        commands = []
        def runner(command, **kwargs):
            commands.append(command)
            return subprocess.CompletedProcess(command, 0, "".join(p + "\tinstalled\n" for p in SYSTEM_PACKAGES))
        install_dependencies(runner=runner)
        self.assertEqual(len(commands), 1)

    def test_xfce_trust_checksum_matches_exact_shortcut_bytes(self):
        _, shortcut = create_shortcuts(self.source, self.data, self.desktop)
        commands = []
        def runner(command, **kwargs):
            commands.append(command)
            return subprocess.CompletedProcess(command, 0)
        trust_shortcut(shortcut, runner=runner)
        self.assertEqual(commands[0], ["gio", "set", str(shortcut), "metadata::xfce-exe-checksum", hashlib.sha256(shortcut.read_bytes()).hexdigest()])

    @unittest.skipUnless(os.name == "posix", "Linux runtime symbolic links")
    def test_bundled_runtime_links_survive_install(self):
        executable = self.source / "runtime/python/bin/python3"
        executable.unlink()
        executable.with_name("python3.12").write_text("native runtime fixture")
        executable.symlink_to("python3.12")
        app, _ = self.install()
        copied = app / "runtime/python/bin/python3"
        self.assertTrue(copied.is_symlink())
        self.assertEqual(copied.read_text(), "native runtime fixture")


if __name__ == "__main__":
    unittest.main()

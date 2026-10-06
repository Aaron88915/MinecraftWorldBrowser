"""Check archive content, native architecture, links, versions and POSIX modes."""
import ast
import hashlib
import json
import posixpath
import sys
import tarfile
from pathlib import Path, PurePosixPath

linux = Path(__file__).resolve().parents[1]
root = linux.parent
sys.path.insert(0, str(linux))
from mwb import VERSION

for kind in ["source", "x86_64"]:
    package = root / f"MinecraftWorldBrowser-v{VERSION}-linux-{kind}.tar.gz"
    prefix = f"MinecraftWorldBrowser-v{VERSION}-linux" + ("-x86_64" if kind == "x86_64" else "")
    native = 0
    with tarfile.open(package, "r:gz") as archive:
        names = set()
        for member in archive:
            if not member.name.startswith(prefix + "/") or ".." in PurePosixPath(member.name).parts:
                raise RuntimeError("Unexpected or unsafe package path: " + member.name)
            if member.name in names:
                raise RuntimeError("Duplicate package path")
            names.add(member.name)
            # Preserve upstream Python's own caches and pip's unused platform
            # launchers; only application files must be free of host artifacts.
            if "/runtime/" not in member.name and (any(part in {".venv", "__pycache__"} for part in PurePosixPath(member.name).parts) or member.name.endswith((".exe", ".dll"))):
                raise RuntimeError("Unexpected host artifact in Linux package: " + member.name)
            if member.issym():
                target = posixpath.normpath(posixpath.join(posixpath.dirname(member.name), member.linkname))
                if member.linkname.startswith("/") or not target.startswith(prefix + "/runtime/python/"):
                    raise RuntimeError("Symbolic link escapes runtime")
            if not member.isfile():
                continue
            with archive.extractfile(member) as stream:
                header = stream.read(20)
            if header[:4] == b"\x7fELF":
                if header[:6] != b"\x7fELF\x02\x01" or int.from_bytes(header[18:20], "little") != 62:
                    raise RuntimeError("Unexpected ELF architecture")
                native += 1
            if member.name.endswith(".sh") and "/runtime/" not in member.name:
                data = archive.extractfile(member).read()
                if b"\r" in data or not member.mode & 0o111:
                    raise RuntimeError("Invalid Linux shell script permissions or line endings")
        expected = ["MinecraftWorldBrowser.py", "mwb/__init__.py", "mwb/core.py", "mwb/nbt.py", "mwb/ui.py", "mwb/environment.py", "mwb/install.py", "launch.sh",
                    "install.py", "install.sh", "install-desktop.sh", "一键安装.desktop", "README.md", "THIRD_PARTY_NOTICES.md", "assets/NotoSansSC.ttf", "assets/NotoSansSC-OFL.txt",
                    "assets/check-white.svg", "assets/chevron-light.svg", "assets/chevron-dark.svg", "tests/test_core.py", "tests/test_ui.py", "tests/test_install.py"]
        if not all(prefix + "/" + item in names for item in expected):
            raise RuntimeError("Missing application component")
        tree = ast.parse(archive.extractfile(prefix + "/mwb/__init__.py").read().decode())
        version = next(ast.literal_eval(node.value) for node in tree.body if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "VERSION" for t in node.targets))
        if version != VERSION:
            raise RuntimeError("Archive version mismatch")
        if kind == "x86_64":
            info = json.load(archive.extractfile(prefix + "/BUILD-INFO.json"))
            if info["application_version"] != VERSION or info["native_elf_files"] != native:
                raise RuntimeError("Build metadata mismatch")
            binary = archive.getmember(prefix + "/runtime/python/bin/python3.12")
            if not binary.mode & 0o111:
                raise RuntimeError("Bundled Python is not executable")
            for name in ["python3", "python"]:
                if not archive.getmember(prefix + "/runtime/python/bin/" + name).issym():
                    raise RuntimeError("Bundled Python launcher link is missing")
            if not any(".dist-info/" in name and "license" in name.lower() for name in names):
                raise RuntimeError("Upstream runtime license texts are missing")
    with package.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    expected_digest = package.with_name(package.name + ".sha256").read_text(encoding="ascii").split()[0]
    if digest != expected_digest:
        raise RuntimeError("Package checksum mismatch")
    print(f"PACKAGE VERIFIED: {package.name}, {len(names)} entries, {native} Linux x86_64 ELF files")

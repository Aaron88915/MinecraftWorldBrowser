"""Assemble verified native Linux binaries with POSIX permissions on any host.

This packages upstream ELF binaries; it does not cross-compile or execute them.
The resulting runtime is exercised by the Ubuntu CI workflow.
"""
import argparse
import base64
import copy
import csv
import hashlib
import io
import json
import posixpath
import sys
import tarfile
import zipfile
from pathlib import Path, PurePosixPath

linux = Path(__file__).resolve().parents[1]
root = linux.parent
sys.path.insert(0, str(linux))
from mwb import VERSION

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=root / f"MinecraftWorldBrowser-v{VERSION}-linux-x86_64.tar.gz")
args = parser.parse_args()
cache = root / "build" / "linux-runtime"
wheels = sorted((root / "build" / "linux-wheels").glob("*.whl"))
sources = json.loads((cache / "sources.json").read_text(encoding="utf-8"))
runtime = cache / sources["python"].rsplit("/", 1)[1].replace("%2B", "+")
with runtime.open("rb") as stream:
    digest = hashlib.file_digest(stream, "sha256").hexdigest()
if digest != sources["python_sha256"]:
    raise RuntimeError("Python runtime checksum mismatch")
if len(wheels) != 2 or not all("6.8.3" in p.name and "manylinux_2_28_x86_64" in p.name for p in wheels):
    raise RuntimeError("Expected exactly the pinned Linux x86_64 PySide6-Essentials and Shiboken6 wheels")
if not {p.name.split("-", 1)[0].lower() for p in wheels} == {"pyside6_essentials", "shiboken6"}:
    raise RuntimeError("Unexpected runtime distributions")

prefix = f"MinecraftWorldBrowser-v{VERSION}-linux-x86_64"
site = prefix + "/runtime/python/lib/python3.12/site-packages/"
excluded = {".venv", "__pycache__", "build", "dist", ".pytest_cache"}
args.output.parent.mkdir(parents=True, exist_ok=True)
temporary = args.output.with_suffix(args.output.suffix + ".part")
names = set()
native = set()

def validate_name(name):
    if "\\" in name or name.startswith("/") or ".." in PurePosixPath(name).parts:
        raise RuntimeError(f"Unsafe archive member: {name}")

def add_info(archive, info, stream=None):
    validate_name(info.name)
    if info.name in names:
        raise RuntimeError(f"Duplicate archive member: {info.name}")
    names.add(info.name)
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    archive.addfile(info, stream)

def add_bytes(archive, name, data, mode=0o644):
    info = tarfile.TarInfo(name)
    info.size, info.mode = len(data), mode
    add_info(archive, info, io.BytesIO(data))

def check_elf(name, data):
    if data[:4] == b"\x7fELF":
        if data[:6] != b"\x7fELF\x02\x01" or int.from_bytes(data[18:20], "little") != 62:
            raise RuntimeError(f"Unexpected native architecture: {name}")
        native.add(name)

with tarfile.open(temporary, "w:gz", compresslevel=6) as output:
    for source in sorted(linux.rglob("*")):
        relative = source.relative_to(linux)
        if source.is_file() and not any(part in excluded for part in relative.parts) and source.suffix != ".pyc":
            data = source.read_bytes()
            if source.suffix == ".sh" and b"\r" in data:
                raise RuntimeError(f"Linux launcher has CRLF line endings: {source}")
            add_bytes(output, prefix + "/" + relative.as_posix(), data, 0o755 if source.suffix in {".sh", ".desktop"} else 0o644)
    with tarfile.open(runtime, "r:gz") as upstream:
        for member in upstream:
            if not member.name.startswith("python/"):
                raise RuntimeError(f"Unexpected runtime prefix: {member.name}")
            validate_name(member.name)
            if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
                raise RuntimeError(f"Unsupported runtime member: {member.name}")
            info = copy.copy(member)
            info.pax_headers = {}
            info.name = prefix + "/runtime/" + member.name
            info.mode &= 0o777
            if info.islnk():
                validate_name(info.linkname)
                if not info.linkname.startswith("python/"):
                    raise RuntimeError("Unsafe runtime hard link")
                info.linkname = prefix + "/runtime/" + info.linkname
            if info.issym():
                target = posixpath.normpath(posixpath.join(posixpath.dirname(member.name), info.linkname))
                if info.linkname.startswith("/") or not target.startswith("python/"):
                    raise RuntimeError("Runtime symbolic link escapes the runtime")
            if member.isfile():
                with upstream.extractfile(member) as stream:
                    data = stream.read()
                check_elf(info.name, data)
                add_info(output, info, io.BytesIO(data))
            else:
                add_info(output, info)
    for wheel in wheels:
        with zipfile.ZipFile(wheel) as distribution:
            record = next(name for name in distribution.namelist() if name.endswith(".dist-info/RECORD"))
            hashes = {row[0]: row[1] for row in csv.reader(io.StringIO(distribution.read(record).decode()))}
            for member in distribution.infolist():
                validate_name(member.filename)
                if member.is_dir():
                    continue
                if ".data/" in member.filename:
                    raise RuntimeError("Wheel data relocation must be explicitly implemented")
                data = distribution.read(member)
                recorded = hashes.get(member.filename, "")
                actual = "sha256=" + base64.urlsafe_b64encode(hashlib.sha256(data).digest()).decode().rstrip("=")
                if recorded and recorded != actual:
                    raise RuntimeError(f"Wheel RECORD checksum mismatch: {member.filename}")
                name = site + member.filename
                check_elf(name, data)
                add_bytes(output, name, data, 0o755 if name in native or member.filename.endswith(".so") else 0o644)
    info = {"application_version": VERSION, "platform": "linux-x86_64", "python": "3.12.14", "qt": "6.8.3",
            "runtime_source": sources, "wheels": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in wheels},
            "native_elf_files": len(native), "assembly_host": sys.platform,
            "validation": "Native Linux execution is performed by .github/workflows/linux.yml; assembly alone does not validate execution."}
    add_bytes(output, prefix + "/BUILD-INFO.json", (json.dumps(info, ensure_ascii=False, indent=2) + "\n").encode())

required_native = [prefix + "/runtime/python/bin/python3.12", site + "PySide6/QtCore.abi3.so",
                   site + "PySide6/Qt/lib/libQt6Core.so.6", site + "PySide6/Qt/plugins/platforms/libqxcb.so"]
if not all(name in native for name in required_native):
    raise RuntimeError("Portable runtime is missing required Linux ELF files")
temporary.replace(args.output)
with args.output.open("rb") as stream:
    package_digest = hashlib.file_digest(stream, "sha256").hexdigest()
args.output.with_name(args.output.name + ".sha256").write_text(package_digest + "  " + args.output.name + "\n", encoding="ascii")
print(f"LINUX PORTABLE PACKAGE OK: {args.output} ({args.output.stat().st_size:,} bytes, {len(native)} Linux ELF files)")
print("SHA256: " + package_digest)

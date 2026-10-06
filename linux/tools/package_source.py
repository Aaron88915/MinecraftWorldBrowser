"""Produce a Linux source launch package with POSIX modes even on Windows."""
import argparse
import hashlib
import sys
import tarfile
from pathlib import Path

linux = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(linux))
from mwb import VERSION

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=linux.parent / f"MinecraftWorldBrowser-v{VERSION}-linux-source.tar.gz")
args = parser.parse_args()
args.output.parent.mkdir(parents=True, exist_ok=True)
prefix = f"MinecraftWorldBrowser-v{VERSION}-linux"
excluded = {".venv", "__pycache__", "build", "dist", ".pytest_cache"}
with tarfile.open(args.output, "w:gz") as archive:
    for source in sorted(linux.rglob("*")):
        if source.is_file() and not any(part in excluded for part in source.relative_to(linux).parts) and source.suffix != ".pyc":
            name = prefix + "/" + source.relative_to(linux).as_posix()
            info = archive.gettarinfo(str(source), name)
            info.mode = 0o755 if source.suffix in {".sh", ".desktop"} else 0o644
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            with source.open("rb") as stream:
                archive.addfile(info, stream)
with args.output.open("rb") as stream:
    digest = hashlib.file_digest(stream, "sha256").hexdigest()
args.output.with_name(args.output.name + ".sha256").write_text(digest + "  " + args.output.name + "\n", encoding="ascii")
print(f"LINUX SOURCE PACKAGE OK: {args.output}")

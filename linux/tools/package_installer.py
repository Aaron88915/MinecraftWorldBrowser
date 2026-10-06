"""Wrap the verified portable tarball in a self-extracting Linux installer."""
import argparse
import hashlib
import shutil
import sys
from pathlib import Path

linux = Path(__file__).resolve().parents[1]
root = linux.parent
sys.path.insert(0, str(linux))
from mwb import VERSION

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=root / f"MinecraftWorldBrowser-v{VERSION}-linux-x86_64-install.run")
args = parser.parse_args()
prefix = f"MinecraftWorldBrowser-v{VERSION}-linux-x86_64"
payload = root / (prefix + ".tar.gz")
with payload.open("rb") as stream:
    digest = hashlib.file_digest(stream, "sha256").hexdigest()
if payload.with_name(payload.name + ".sha256").read_text(encoding="ascii").split()[0] != digest:
    raise RuntimeError("Portable package checksum mismatch")
header = (linux / "tools/installer-header.sh").read_text(encoding="utf-8")
header = header.replace("@VERSION@", VERSION).replace("@APP_PREFIX@", prefix).replace("@PAYLOAD_SHA256@", digest)
if not header.endswith("__MWB_PAYLOAD_BELOW__\n") or "\r" in header:
    raise RuntimeError("Invalid self-extracting shell header")
args.output.parent.mkdir(parents=True, exist_ok=True)
temporary = args.output.with_name(args.output.name + ".part")
with temporary.open("wb") as output, payload.open("rb") as stream:
    output.write(header.encode("utf-8"))
    shutil.copyfileobj(stream, output, 1024 * 1024)
temporary.chmod(0o755)
temporary.replace(args.output)
with args.output.open("rb") as stream:
    digest = hashlib.file_digest(stream, "sha256").hexdigest()
args.output.with_name(args.output.name + ".sha256").write_text(digest + "  " + args.output.name + "\n", encoding="ascii")
print(f"ONE-STEP INSTALLER OK: {args.output} ({args.output.stat().st_size:,} bytes)")
print("SHA256: " + digest)

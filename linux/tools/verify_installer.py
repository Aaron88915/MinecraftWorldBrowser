"""Verify the shell/payload boundary and the exact embedded portable tarball."""
import hashlib
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "linux"))
from mwb import VERSION

installer = root / f"MinecraftWorldBrowser-v{VERSION}-linux-x86_64-install.run"
payload = root / f"MinecraftWorldBrowser-v{VERSION}-linux-x86_64.tar.gz"
with installer.open("rb") as stream:
    header = bytearray()
    while True:
        line = stream.readline(16 * 1024)
        if not line or len(header) > 64 * 1024:
            raise RuntimeError("Self-extractor payload marker not found")
        header.extend(line)
        if line == b"__MWB_PAYLOAD_BELOW__\n":
            break
    embedded_hash = hashlib.file_digest(stream, "sha256").hexdigest()
with payload.open("rb") as stream:
    expected = hashlib.file_digest(stream, "sha256").hexdigest()
if embedded_hash != expected or expected.encode() not in header or b"\r" in header:
    raise RuntimeError("Embedded installer payload differs from the portable package")
with installer.open("rb") as stream:
    digest = hashlib.file_digest(stream, "sha256").hexdigest()
if installer.with_name(installer.name + ".sha256").read_text(encoding="ascii").split()[0] != digest:
    raise RuntimeError("Installer checksum mismatch")
print("INSTALLER VERIFIED: exact portable payload, valid LF shell header, SHA256 OK")

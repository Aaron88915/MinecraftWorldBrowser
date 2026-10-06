"""Download pinned Linux runtime assets and verify the GitHub asset digest."""
import hashlib
import json
import argparse
import urllib.parse
import urllib.request
from pathlib import Path

linux = Path(__file__).resolve().parents[1]
cache = linux.parent / "build" / "linux-runtime"
cache.mkdir(parents=True, exist_ok=True)
assets = linux / "assets"
assets.mkdir(parents=True, exist_ok=True)
TAG = "20260929"
NAME = f"cpython-3.12.14+{TAG}-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
parser = argparse.ArgumentParser()
parser.add_argument("--direct", action="store_true", help="Use direct HTTPS when the configured proxy is unavailable")
args = parser.parse_args()
opener = urllib.request.build_opener(urllib.request.ProxyHandler({})) if args.direct else urllib.request.build_opener()

def request(url):
    return opener.open(urllib.request.Request(url, headers={"User-Agent": "MinecraftWorldBrowser-build", "Accept": "application/vnd.github+json"}), timeout=60)

def download(url, destination):
    if destination.exists():
        return
    temporary = destination.with_suffix(destination.suffix + ".part")
    print("DOWNLOADING: " + destination.name, flush=True)
    with request(url) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    temporary.replace(destination)

metadata_file = cache / "python-release.json"
if metadata_file.exists():
    release = json.loads(metadata_file.read_text(encoding="utf-8"))
else:
    with request(f"https://api.github.com/repos/astral-sh/python-build-standalone/releases/tags/{TAG}") as response:
        release = json.load(response)
    metadata_file.write_text(json.dumps(release), encoding="utf-8")
asset = next(value for value in release["assets"] if value["name"] == NAME)
runtime = cache / NAME
download(asset["browser_download_url"], runtime)
digest = hashlib.sha256(runtime.read_bytes()).hexdigest()
expected = asset.get("digest", "")
if expected != "sha256:" + digest:
    raise RuntimeError(f"Python runtime checksum mismatch or missing upstream digest: {expected} / {digest}")
print("RUNTIME SHA256 OK: " + digest, flush=True)

download("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf", assets / "NotoSansSC.ttf")
download("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt", assets / "NotoSansSC-OFL.txt")
(cache / "sources.json").write_text(json.dumps({"python": asset["browser_download_url"], "python_sha256": digest,
                                              "font": "https://github.com/google/fonts/tree/main/ofl/notosanssc",
                                              "font_sha256": hashlib.sha256((assets / "NotoSansSC.ttf").read_bytes()).hexdigest()}, indent=2), encoding="utf-8")
print("RUNTIME ASSETS OK", flush=True)

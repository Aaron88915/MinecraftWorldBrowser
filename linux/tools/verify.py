"""Repeatable regression checks and light/dark screenshots, on either host OS."""
import argparse
import os
import subprocess
import sys
from pathlib import Path

linux = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=linux.parent / "build" / "linux-ui")
parser.add_argument("--capture-screen", action="store_true", help="Also show windows briefly and capture the actual desktop")
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", PYTHONUTF8="1")

def run(*arguments):
    subprocess.run([sys.executable, str(linux / "MinecraftWorldBrowser.py"), *arguments], check=True, env=environment, timeout=90)

run("--self-test")
run("--ui-test")
for theme in ["light", "dark"]:
    flags = ["--dark"] if theme == "dark" else []
    for option, prefix in [("--render-preview", "main"), ("--render-details-preview", "details")]:
        output = args.output / f"{prefix}-{theme}.png"
        run(option, str(output), *flags)
        if not output.is_file():
            raise RuntimeError(f"Preview missing: {output}")
        print(f"PREVIEW OK: {output}", flush=True)
if args.capture_screen:
    environment["QT_QPA_PLATFORM"] = "windows" if os.name == "nt" else "xcb"
    for theme in ["light", "dark"]:
        output = args.output / f"live-{theme}.png"
        run("--render-preview", str(output), "--capture-screen", *(["--dark"] if theme == "dark" else []))
        print(f"LIVE CAPTURE OK: {output}", flush=True)

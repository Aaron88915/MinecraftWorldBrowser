"""Copy upstream license texts into a binary distribution."""
import importlib.metadata
import shutil
import sys
from pathlib import Path

target = Path(sys.argv[1])
target.mkdir(parents=True, exist_ok=True)
for name in ["PySide6", "PySide6-Essentials", "PySide6-Addons", "shiboken6"]:
    try:
        distribution = importlib.metadata.distribution(name)
    except importlib.metadata.PackageNotFoundError:
        continue
    for item in distribution.files or []:
        if "license" in str(item).lower() or "copying" in str(item).lower():
            source = Path(distribution.locate_file(item))
            if source.is_file():
                destination = target / name / str(item).replace("..", "_")
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)

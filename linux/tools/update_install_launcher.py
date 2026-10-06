"""Generate a local installer launcher; %k also accepts a file:// URI."""
import sys
from pathlib import Path

linux = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(linux))
from mwb.install import exec_quote

code = ("import subprocess,sys; from pathlib import Path; from urllib.parse import urlparse,unquote; "
        "p=sys.argv[1]; u=urlparse(p); p=unquote(u.path) if u.scheme=='file' else p; "
        "sys.exit(subprocess.call(['/bin/sh',str(Path(p).resolve().parent/'install.sh'),'--in-terminal']))")
launcher = linux / "一键安装.desktop"
launcher.write_text("[Desktop Entry]\nType=Application\nVersion=1.0\n"
                    "Name=一键安装世界浏览器\nComment=安装依赖、程序和桌面快捷图标\n"
                    f"Exec=python3 -c {exec_quote(code)} %k\n"
                    "Icon=system-software-install\nTerminal=true\nCategories=Utility;\n", encoding="utf-8", newline="\n")
launcher.chmod(0o755)
print("INSTALL LAUNCHER OK: " + str(launcher))

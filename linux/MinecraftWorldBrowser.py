#!/usr/bin/env python3
"""Linux desktop entry point; non-GUI commands do not need Qt."""

import argparse
import os
import sys
import tempfile
from pathlib import Path

from mwb import VERSION


def main():
    parser = argparse.ArgumentParser(description="Minecraft Java 世界浏览器 · Linux")
    parser.add_argument("--version", action="version", version=VERSION)
    parser.add_argument("--self-test", action="store_true", help="运行文件服务回归测试，不启动界面")
    parser.add_argument("--ui-test", action="store_true", help="运行 Qt 界面回归测试")
    parser.add_argument("--render-preview", type=Path, metavar="PNG", help="以示例数据生成界面截图")
    parser.add_argument("--render-details-preview", type=Path, metavar="PNG", help="以示例数据生成详情截图")
    parser.add_argument("--dark", action="store_true", help="预览使用暗色主题")
    parser.add_argument("--capture-screen", action="store_true", help="预览时截取实际图形桌面上的窗口")
    parser.add_argument("--data-dir", type=Path, help="指定本地配置目录")
    parser.add_argument("--check-dependencies", action="store_true", help="检查 Qt 图形依赖，不启动界面")
    args = parser.parse_args()
    if args.capture_screen and not (args.render_preview or args.render_details_preview):
        parser.error("--capture-screen 需要同时指定 --render-preview 或 --render-details-preview")
    if args.self_test:
        import unittest
        directory = str(Path(__file__).parent / "tests")
        suite = unittest.TestSuite(unittest.defaultTestLoader.discover(directory, pattern=pattern) for pattern in ["test_core.py", "test_install.py"])
        return 0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1
    if args.ui_test:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        import unittest
        suite = unittest.defaultTestLoader.discover(str(Path(__file__).parent / "tests"), pattern="test_ui.py")
        return 0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1
    try:
        import PySide6
        from mwb.environment import x11_dependency_error
        error = x11_dependency_error(Path(PySide6.__file__).parent)
        if error:
            print(error, file=sys.stderr)
            return 2
        if args.check_dependencies:
            print("Qt 依赖预检通过（仅在 Linux X11 环境检查 xcb 动态库；不启动或连接桌面）。")
            return 0
        from PySide6.QtCore import QTimer
        from PySide6.QtGui import QIcon
        from PySide6.QtWidgets import QApplication
        from mwb.core import Store
        from mwb.ui import DetailsDialog, MainWindow, application_font
    except ImportError:
        print("缺少 Qt 依赖，请在 Linux 版目录中运行：sh setup.sh", file=sys.stderr)
        return 2

    app = QApplication(sys.argv[:1])
    app.setApplicationName("MinecraftWorldBrowser")
    app.setApplicationVersion(VERSION)
    app.setOrganizationName("MinecraftWorldBrowser")
    app.setDesktopFileName("minecraft-world-browser")
    app.setWindowIcon(QIcon(str(Path(__file__).parent / "assets" / "MinecraftWorldBrowser-icon.png")))
    app.setStyle("Fusion")
    app.setFont(application_font())
    preview = bool(args.render_preview or args.render_details_preview)
    # Previews never touch the user's real settings or archives.
    with tempfile.TemporaryDirectory(prefix="mwb-preview-") if preview else _NoTemporaryDirectory() as temporary:
        store = Store(Path(temporary)) if preview else Store(args.data_dir)
        if preview:
            store.dark = args.dark
        window = MainWindow(store, preview=preview)
        if preview:
            window.prepare_preview()
            window.show()
            app.processEvents()
            target = window
            output = args.render_preview
            if args.render_details_preview:
                target = DetailsDialog(window.worlds[0], window)
                target.show()
                output = args.render_details_preview
            app.processEvents()
            output.parent.mkdir(parents=True, exist_ok=True)
            if args.capture_screen:
                result = [1]
                def capture():
                    screen = target.screen()
                    pixmap = screen.grabWindow(target.winId())
                    result[0] = 0 if not pixmap.isNull() and pixmap.save(str(output)) else 1
                    target.close()
                    window.close()
                    app.quit()
                QTimer.singleShot(350, capture)
                app.exec()
                return result[0]
            if not target.grab().save(str(output)):
                raise RuntimeError("无法写入预览截图")
            target.close()
            window.close()
            return 0
        window.show()
        return app.exec()


class _NoTemporaryDirectory:
    def __enter__(self):
        return None

    def __exit__(self, *_):
        return False


if __name__ == "__main__":
    sys.exit(main())

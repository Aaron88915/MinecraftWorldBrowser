# Third-party components

This application uses Qt for Python (PySide6 and Shiboken6), distributed by The Qt Company under LGPL-3.0, GPL-2.0/GPL-3.0, or commercial terms, depending on the component. The application imports the Qt Widgets modules from separately installed, dynamically linked libraries. No Qt module is statically linked by this project.

- Qt for Python: https://doc.qt.io/qtforpython-6/licenses.html
- Qt licensing: https://doc.qt.io/qt-6/licensing.html
- PySide6 source: https://code.qt.io/cgit/pyside/pyside-setup.git/

Source launch packages obtain these libraries through `requirements.txt`; their license texts ship with the installed packages. Portable packages preserve those license texts in `runtime/python/lib/python3.12/site-packages/`, and the libraries remain replaceable. PyInstaller builds include available upstream license texts in `licenses/` and dynamically linked libraries in `_internal/`.

The portable package includes CPython 3.12.14 from the pinned `20260929` release of Astral's python-build-standalone project. Its upstream Python and dependency license texts are preserved within `runtime/python/`, including `lib/python3.12/LICENSE.txt`.

- CPython source: https://github.com/python/cpython/tree/v3.12.14
- Runtime source and build project: https://github.com/astral-sh/python-build-standalone/releases/tag/20260929
- Qt 6.8.3 source: https://download.qt.io/archive/qt/6.8/6.8.3/single/
- PySide6 6.8.3 source: https://code.qt.io/cgit/pyside/pyside-setup.git/tag/?h=v6.8.3

The bundled Noto Sans SC font is distributed under the SIL Open Font License 1.1. Its unmodified license and copyright notices are included in `assets/NotoSansSC-OFL.txt`. Font source: https://github.com/google/fonts/tree/main/ofl/notosanssc

These third-party notices do not change the license of the original project.

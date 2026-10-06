"""Qt desktop UI with the same flat surfaces and horizontal-only world rows."""

from __future__ import annotations

import copy
import os
import threading
import time
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QAbstractTableModel, QEasingCurve, QModelIndex, QObject, QPoint, QPropertyAnimation, QRect, QRectF, QRunnable, QSize, Qt, QThreadPool, QTimer, QUrl, Signal
from PySide6.QtGui import QColor, QDesktopServices, QFont, QFontDatabase, QIcon, QPainter, QPainterPath, QPalette, QPen, QPixmap
from PySide6.QtWidgets import QApplication, QAbstractItemView, QCheckBox, QComboBox, QDialog, QDialogButtonBox, QFileDialog, QFrame, QGridLayout, QHBoxLayout, QHeaderView, QLabel, QLineEdit, QListWidget, QListWidgetItem, QMainWindow, QMessageBox, QPlainTextEdit, QProgressBar, QPushButton, QSizePolicy, QStyledItemDelegate, QStyle, QTableView, QVBoxLayout, QWidget

from . import VERSION
from .core import Cancelled, Store, World, create_backup, default_candidates, directory_name, discover_roots, format_size, normalize, read_manifest, restore_backup, safe_name, safe_original_path, scan_starts, scan_worlds, unique_directory, version_key


def application_font() -> QFont:
    font = Path(__file__).resolve().parents[1] / "assets" / "NotoSansSC.ttf"
    family = ""
    if font.is_file():
        identifier = QFontDatabase.addApplicationFont(str(font))
        names = QFontDatabase.applicationFontFamilies(identifier)
        family = names[0] if names else ""
    if not family:
        # The Windows offscreen QA plugin has no system font database. Load a
        # host font for verification only; it is never copied into Linux packages.
        if os.name == "nt":
            host_font = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts" / "msyh.ttc"
            if host_font.is_file():
                identifier = QFontDatabase.addApplicationFont(str(host_font))
                names = QFontDatabase.applicationFontFamilies(identifier)
                family = names[0] if names else ""
        else:
            names = QFontDatabase.families()
            family = next((name for name in ["Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Micro Hei", "DejaVu Sans"] if name in names), "Sans Serif")
    return QFont(family or "Sans Serif", 10)


class Theme:
    def __init__(self, dark=False):
        self.dark = dark
        self.canvas = "#0e1621" if dark else "#edf3f8"
        self.surface = "#17212b" if dark else "#ffffff"
        self.header = "#202b36" if dark else "#f7f9fb"
        self.ink = "#e9f1f8" if dark else "#202b36"
        self.muted = "#8aa0b4" if dark else "#778b9d"
        self.line = "#253442" if dark else "#e5ecf2"
        self.accent = "#64b5ef" if dark else "#3390ec"
        self.primary = "#1f76c2" if dark else "#1a73c3"
        self.selection = "#2b5278" if dark else "#e2f0fc"
        self.button = "#243240" if dark else "#ffffff"
        self.border = "#465c70" if dark else "#a9bdd1"
        self.hover = "#2d4051" if dark else "#e1eefa"
        self.pressed = "#364f65" if dark else "#cde3f7"
        self.input = "#243240" if dark else "#f1f5f9"
        self.thumb = "#596d7f" if dark else "#b9c7d4"
        self.green = "#4ecb7b" if dark else "#237d4e"

    def stylesheet(self):
        assets = (Path(__file__).resolve().parents[1] / "assets").as_posix()
        arrow = f"{assets}/chevron-{'dark' if self.dark else 'light'}.svg"
        return f"""
        QWidget {{ color: {self.ink}; font-size: 14px; }}
        QMainWindow, QDialog, QWidget#Content {{ background: {self.canvas}; }}
        QWidget#Sidebar, QFrame#Card {{ background: {self.surface}; }}
        QWidget#Sidebar {{ border-right: 1px solid {self.line}; }}
        QFrame#Card {{ border: 0; border-radius: 9px; }}
        QLabel {{ background: transparent; border: 0; }}
        QLabel[muted="true"] {{ color: {self.muted}; }}
        QLabel#Title {{ font-size: 28px; font-weight: 700; }}
        QLabel#Brand {{ font-size: 23px; font-weight: 700; }}
        QPushButton {{ background: {self.button}; border: 1px solid {self.border}; border-radius: 8px; padding: 7px 13px; min-height: 18px; }}
        QPushButton:hover {{ background: {self.hover}; border-color: {self.accent}; }}
        QPushButton:pressed {{ background: {self.pressed}; }}
        QPushButton:focus {{ border-color: {self.accent}; }}
        QPushButton:disabled {{ color: {self.muted}; background: {self.input}; border-color: {self.line}; }}
        QPushButton[primary="true"] {{ background: {self.primary}; border-color: {self.primary}; color: white; }}
        QPushButton[primary="true"]:hover {{ background: #1c7bca; }}
        QPushButton[primary="true"]:pressed {{ background: #1666ad; }}
        QPushButton:checked {{ background: {self.selection}; border-color: {self.accent}; color: {self.accent}; }}
        QLineEdit, QPlainTextEdit {{ background: {self.surface}; color: {self.ink}; border: 1px solid {self.border}; border-radius: 7px; padding: 7px 10px; selection-background-color: {self.selection}; selection-color: {self.ink}; }}
        QLineEdit#Search {{ background: {self.input}; min-height: 27px; }}
        QLineEdit:focus, QPlainTextEdit:focus {{ border-color: {self.accent}; }}
        QComboBox {{ background: {self.button}; border: 1px solid {self.border}; border-radius: 8px; padding: 7px 11px; min-height: 18px; }}
        QComboBox:hover {{ background: {self.hover}; }}
        QComboBox:on {{ background: {self.pressed}; }}
        QComboBox::drop-down {{ border: 0; width: 23px; }}
        QComboBox::down-arrow {{ image: url("{arrow}"); width: 12px; height: 8px; }}
        QComboBox QAbstractItemView {{ background: {self.surface}; color: {self.ink}; border: 1px solid {self.border}; selection-background-color: {self.selection}; selection-color: {self.ink}; padding: 4px; }}
        QCheckBox {{ spacing: 8px; background: transparent; }}
        QCheckBox::indicator {{ width: 16px; height: 16px; border: 1px solid {self.border}; border-radius: 3px; background: {self.button}; }}
        QCheckBox::indicator:hover {{ border-color: {self.accent}; }}
        QCheckBox::indicator:checked {{ background: {self.primary}; border-color: {self.primary}; image: url("{assets}/check-white.svg"); }}
        QCheckBox::indicator:pressed {{ background: {self.pressed}; }}
        QListWidget, QTableView {{ background: {self.surface}; color: {self.ink}; border: 0; outline: 0; }}
        QHeaderView {{ background: {self.header}; border: 0; }}
        QHeaderView::section {{ color: {self.muted}; background: {self.header}; border: 0; border-bottom: 1px solid {self.line}; padding-left: 8px; padding-right: 8px; min-height: 40px; font-weight: 600; }}
        QTableView::item {{ border: 0; }}
        QScrollBar:vertical {{ background: {self.surface}; width: 8px; margin: 3px 1px; border: 0; }}
        QScrollBar::handle:vertical {{ background: {self.thumb}; border-radius: 3px; min-height: 26px; }}
        QScrollBar:horizontal {{ background: {self.surface}; height: 8px; margin: 1px 3px; border: 0; }}
        QScrollBar::handle:horizontal {{ background: {self.thumb}; border-radius: 3px; min-width: 26px; }}
        QScrollBar::handle:hover {{ background: {self.accent}; }}
        QScrollBar::add-line, QScrollBar::sub-line {{ width: 0; height: 0; }}
        QScrollBar::add-page, QScrollBar::sub-page {{ background: transparent; }}
        QProgressBar {{ background: {self.input}; border: 0; border-radius: 3px; height: 6px; }}
        QProgressBar::chunk {{ background: {self.accent}; border-radius: 3px; }}
        QToolTip {{ color: {self.ink}; background: {self.surface}; border: 1px solid {self.border}; padding: 6px; }}
        """


def label(text: str, muted=False, name="") -> QLabel:
    value = QLabel(text)
    value.setTextFormat(Qt.TextFormat.PlainText)
    value.setProperty("muted", muted)
    if name:
        value.setObjectName(name)
    return value


def button(text: str, callback, primary=False, name="") -> QPushButton:
    value = QPushButton(text)
    value.setProperty("primary", primary)
    value.setCursor(Qt.CursorShape.PointingHandCursor)
    value.setObjectName(name)
    value.clicked.connect(callback)
    return value


def fallback_icon() -> QPixmap:
    value = QPixmap(64, 64)
    value.fill(QColor("#9fd4f0"))
    painter = QPainter(value)
    painter.fillRect(0, 32, 64, 32, QColor("#65ab69"))
    painter.fillRect(0, 46, 64, 18, QColor("#6d9053"))
    painter.setPen(Qt.PenStyle.NoPen)
    river = QPainterPath()
    river.moveTo(31, 32)
    river.lineTo(39, 32)
    river.lineTo(28, 64)
    river.lineTo(15, 64)
    painter.fillPath(river, QColor("#4ca3db"))
    painter.fillRect(47, 25, 4, 20, QColor("#68523e"))
    painter.fillRect(40, 19, 18, 14, QColor("#387450"))
    painter.fillRect(45, 12, 11, 21, QColor("#387450"))
    painter.end()
    return value


def rounded_icon(path: Path | None = None, size=40) -> QPixmap:
    source = QPixmap(str(path)) if path and path.is_file() else QPixmap()
    if source.isNull():
        source = fallback_icon()
    result = QPixmap(size, size)
    result.fill(Qt.GlobalColor.transparent)
    painter = QPainter(result)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    clip = QPainterPath()
    clip.addEllipse(QRectF(0, 0, size, size))
    painter.setClipPath(clip)
    painter.drawPixmap(0, 0, source.scaled(size, size, Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation))
    painter.end()
    return result


class SmoothWheel:
    def init_scroll(self):
        self.setVerticalScrollMode(QAbstractItemView.ScrollMode.ScrollPerPixel)
        self.scroll_animation = QPropertyAnimation(self.verticalScrollBar(), b"value", self)
        self.scroll_animation.setDuration(120)
        self.scroll_animation.setEasingCurve(QEasingCurve.Type.OutCubic)

    def wheelEvent(self, event):
        if event.modifiers() & Qt.KeyboardModifier.ShiftModifier or event.angleDelta().x():
            return super().wheelEvent(event)
        bar = self.verticalScrollBar()
        delta = -event.pixelDelta().y() if not event.pixelDelta().isNull() else -event.angleDelta().y() / 120 * 128
        if not delta:
            return super().wheelEvent(event)
        pending = (self.scroll_animation.endValue() or bar.value()) - bar.value()
        running = self.scroll_animation.state() == QPropertyAnimation.State.Running
        basis = self.scroll_animation.endValue() if running and delta * pending > 0 else bar.value()
        self.scroll_animation.stop()
        self.scroll_animation.setStartValue(bar.value())
        self.scroll_animation.setEndValue(round(max(0, min(bar.maximum(), basis + delta))))
        self.scroll_animation.start()
        event.accept()

    def keyPressEvent(self, event):
        self.scroll_animation.stop()
        super().keyPressEvent(event)

    def mousePressEvent(self, event):
        self.scroll_animation.stop()
        super().mousePressEvent(event)


class RootDelegate(QStyledItemDelegate):
    def paint(self, painter, option, index):
        theme = self.parent().theme
        selected = bool(option.state & QStyle.StateFlag.State_Selected)
        hot = bool(option.state & QStyle.StateFlag.State_MouseOver)
        painter.save()
        painter.fillRect(option.rect, QColor(theme.primary if selected else theme.hover if hot else theme.surface))
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        avatar = QRect(option.rect.left() + 12, option.rect.top() + 14, 40, 40)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(255, 255, 255, 65) if selected else QColor("#4ea3db"))
        painter.drawEllipse(avatar)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.setPen(QPen(QColor("white"), 1.4))
        painter.drawRoundedRect(avatar.adjusted(11, 13, -8, -10), 1, 1)
        painter.drawLine(avatar.left() + 11, avatar.top() + 13, avatar.left() + 21, avatar.top() + 13)
        path = index.data(Qt.ItemDataRole.UserRole)
        painter.setPen(QColor("white" if selected else theme.ink))
        font = QFont(option.font)
        font.setBold(True)
        painter.setFont(font)
        bounds = QRect(option.rect.left() + 64, option.rect.top() + 8, option.rect.width() - 88, 26)
        painter.drawText(bounds, Qt.AlignmentFlag.AlignVCenter, painter.fontMetrics().elidedText(directory_name(path), Qt.TextElideMode.ElideRight, bounds.width()))
        font.setBold(False)
        font.setPointSizeF(max(8, font.pointSizeF() - 1))
        painter.setFont(font)
        painter.setPen(QColor("#e6f3ff" if selected else theme.muted))
        bounds.moveTop(option.rect.top() + 35)
        painter.drawText(bounds, Qt.AlignmentFlag.AlignVCenter, painter.fontMetrics().elidedText(path, Qt.TextElideMode.ElideRight, bounds.width()))
        painter.restore()

    def sizeHint(self, option, index):
        return QSize(260, 68)


class RootList(SmoothWheel, QListWidget):
    """The overlay thumb shares the item viewport: it has no rectangular backing."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.theme = Theme()
        self.init_scroll()
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setItemDelegate(RootDelegate(self))
        self.setMouseTracking(True)
        self.setSpacing(0)
        self.drag_offset = None
        self.thumb_hover = False
        self.verticalScrollBar().valueChanged.connect(self.viewport().update)
        self.verticalScrollBar().rangeChanged.connect(self.viewport().update)

    def thumb_rect(self):
        bar = self.verticalScrollBar()
        track = self.viewport().height() - 8
        if bar.maximum() <= 0 or track <= 0:
            return QRect()
        height = max(26, round(track * bar.pageStep() / (bar.maximum() + bar.pageStep())))
        y = 4 + round((track - height) * bar.value() / bar.maximum())
        return QRect(self.viewport().width() - 12, y, 12, height)

    def paintEvent(self, event):
        super().paintEvent(event)
        thumb = self.thumb_rect()
        if not thumb.isNull():
            painter = QPainter(self.viewport())
            painter.setRenderHint(QPainter.RenderHint.Antialiasing)
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QColor(self.theme.accent if self.drag_offset is not None else self.theme.thumb))
            width = 6 if self.thumb_hover or self.drag_offset is not None else 4
            painter.drawRoundedRect(QRectF(thumb.right() - 7 + (6 - width) / 2, thumb.top(), width, thumb.height()), width / 2, width / 2)
            painter.end()

    def mousePressEvent(self, event):
        thumb = self.thumb_rect()
        if not thumb.isNull() and event.position().x() >= thumb.left():
            self.scroll_animation.stop()
            if thumb.contains(event.position().toPoint()):
                self.drag_offset = event.position().y() - thumb.top()
            else:
                bar = self.verticalScrollBar()
                bar.setValue(bar.value() + (-1 if event.position().y() < thumb.top() else 1) * bar.pageStep())
            self.viewport().update()
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        thumb = self.thumb_rect()
        self.thumb_hover = not thumb.isNull() and event.position().x() >= thumb.left()
        if self.drag_offset is not None:
            travel = self.viewport().height() - 8 - thumb.height()
            if travel > 0:
                bar = self.verticalScrollBar()
                bar.setValue(round(bar.maximum() * max(0, min(travel, event.position().y() - 4 - self.drag_offset)) / travel))
        else:
            super().mouseMoveEvent(event)
        self.viewport().update()

    def mouseReleaseEvent(self, event):
        if self.drag_offset is not None:
            self.drag_offset = None
            self.viewport().update()
            event.accept()
        else:
            super().mouseReleaseEvent(event)

    def leaveEvent(self, event):
        self.thumb_hover = False
        self.viewport().update()
        super().leaveEvent(event)


COLUMNS = [("", "icon"), ("世界", "name"), ("版本", "version"), ("模式", "mode"), ("状态", "health"),
           ("大小", "size"), ("最后游玩", "last_played"), ("加载器", "loader"), ("存档位置", "path")]


class WorldModel(QAbstractTableModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.worlds: list[World] = []

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self.worlds)

    def columnCount(self, parent=QModelIndex()):
        return len(COLUMNS)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self.worlds):
            return None
        world = self.worlds[index.row()]
        if role == Qt.ItemDataRole.UserRole:
            return world
        if role == Qt.ItemDataRole.ToolTipRole:
            return world.path + ("\n" + world.error if world.error else "")
        if role == Qt.ItemDataRole.DisplayRole:
            field = COLUMNS[index.column()][1]
            if field == "icon":
                return ""
            if field == "size":
                return format_size(world.size)
            if field == "last_played":
                return datetime.fromtimestamp(world.last_played).strftime("%Y-%m-%d %H:%M") if world.last_played else "—"
            return getattr(world, field)
        return None

    def headerData(self, section, orientation, role=Qt.ItemDataRole.DisplayRole):
        if orientation == Qt.Orientation.Horizontal and role == Qt.ItemDataRole.DisplayRole:
            return COLUMNS[section][0]
        return None

    def replace(self, worlds):
        self.beginResetModel()
        self.worlds = worlds
        self.endResetModel()


class WorldDelegate(QStyledItemDelegate):
    def __init__(self, parent):
        super().__init__(parent)
        self.icons = {}

    def paint(self, painter, option, index):
        theme = self.parent().theme
        world = index.data(Qt.ItemDataRole.UserRole)
        if world is None:
            return
        painter.save()
        selected = bool(option.state & QStyle.StateFlag.State_Selected)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, False)
        painter.fillRect(option.rect, QColor(theme.selection if selected else theme.surface))
        bounds = option.rect.adjusted(8, 0, -8, 0)
        painter.setPen(QColor(theme.ink))
        font = QFont(option.font)
        painter.setFont(font)
        field = COLUMNS[index.column()][1]
        if field == "icon":
            if world.path not in self.icons:
                self.icons[world.path] = rounded_icon(Path(world.path) / "icon.png")
            painter.drawPixmap(option.rect.center().x() - 20, option.rect.center().y() - 20, self.icons[world.path])
        elif field in {"name", "last_played"}:
            if field == "name":
                first = ("★  " if world.favorite else "") + world.name
                second = world.source or "Minecraft Java"
                font.setBold(True)
                painter.setFont(font)
            else:
                value = datetime.fromtimestamp(world.last_played) if world.last_played else None
                first = value.strftime("%Y-%m-%d") if value else "—"
                second = value.strftime("%H:%M") if value else ""
            painter.drawText(QRect(bounds.left(), bounds.top() + 7, bounds.width(), 27), Qt.AlignmentFlag.AlignVCenter,
                             painter.fontMetrics().elidedText(first, Qt.TextElideMode.ElideRight, bounds.width()))
            font.setBold(False)
            font.setPointSizeF(max(8, font.pointSizeF() - 1))
            painter.setFont(font)
            painter.setPen(QColor(theme.muted))
            painter.drawText(QRect(bounds.left(), bounds.top() + 35, bounds.width(), 22), Qt.AlignmentFlag.AlignVCenter,
                             painter.fontMetrics().elidedText(second, Qt.TextElideMode.ElideRight, bounds.width()))
        else:
            if field == "health":
                painter.setPen(QColor(theme.green if world.health == "正常" else theme.accent if world.health == "使用中" else "#df705b"))
            painter.drawText(bounds, Qt.AlignmentFlag.AlignVCenter, painter.fontMetrics().elidedText(str(index.data()), Qt.TextElideMode.ElideRight, bounds.width()))
        painter.setPen(QPen(QColor(theme.line), 1))
        painter.drawLine(option.rect.bottomLeft(), option.rect.bottomRight())
        painter.restore()


class WorldTable(SmoothWheel, QTableView):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.theme = Theme()
        self.init_scroll()
        self.setShowGrid(False)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.setAlternatingRowColors(False)
        self.verticalHeader().hide()
        self.verticalHeader().setDefaultSectionSize(64)
        self.verticalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Fixed)
        self.horizontalHeader().setDefaultAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        self.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Interactive)
        self.horizontalHeader().setMinimumSectionSize(40)
        self.horizontalHeader().setFixedHeight(42)
        self.horizontalHeader().setSortIndicatorShown(True)
        self.setHorizontalScrollMode(QAbstractItemView.ScrollMode.ScrollPerPixel)
        self.setItemDelegate(WorldDelegate(self))


class WorkerSignals(QObject):
    progress = Signal(str)
    done = Signal(object)
    failed = Signal(str)
    cancelled = Signal()


class Worker(QRunnable):
    def __init__(self, function):
        super().__init__()
        self.function = function
        self.cancel = threading.Event()
        self.signals = WorkerSignals()
        self.last_progress = 0.0

    def progress(self, text):
        now = time.monotonic()
        if now - self.last_progress >= 0.08:
            self.last_progress = now
            self.signals.progress.emit(text)

    def run(self):
        try:
            self.signals.done.emit(self.function(self.cancel, self.progress))
        except Cancelled:
            self.signals.cancelled.emit()
        except Exception as error:
            self.signals.failed.emit(str(error))


class DetailsDialog(QDialog):
    def __init__(self, world: World, parent):
        super().__init__(parent)
        self.setWindowTitle("世界详情")
        self.setMinimumSize(560, 570)
        self.resize(660, 680)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 20)
        layout.setSpacing(18)
        header = QHBoxLayout()
        icon = QLabel()
        icon.setPixmap(rounded_icon(Path(world.path) / "icon.png", 56))
        header.addWidget(icon)
        title = QVBoxLayout()
        name = label(world.name, name="Brand")
        name.setWordWrap(True)
        title.addWidget(name)
        title.addWidget(label(f"{world.version}   /   {world.mode}   /   {world.loader}", True))
        header.addLayout(title, 1)
        layout.addLayout(header)
        card = QFrame()
        card.setObjectName("Card")
        fields = QGridLayout(card)
        fields.setContentsMargins(18, 14, 18, 14)
        fields.setVerticalSpacing(7)
        for row, (caption, value) in enumerate([("种子", str(world.seed)), ("难度", world.difficulty), ("作弊", "已开启" if world.cheats else "未开启"),
                                                ("DataVersion", str(world.data_version)), ("最后游玩", datetime.fromtimestamp(world.last_played).strftime("%Y-%m-%d %H:%M") if world.last_played else "—"),
                                                ("存档大小", format_size(world.size)), ("实例", world.source + " / " + world.loader), ("状态", world.health + f" / 备份 {world.backup_count} 份")]):
            fields.addWidget(label(caption, True), row, 0)
            field = label(value)
            field.setWordWrap(True)
            field.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
            fields.addWidget(field, row, 1)
        fields.setColumnStretch(1, 1)
        layout.addWidget(card)
        tags_row = QHBoxLayout()
        tags_row.addWidget(label("标签", True))
        self.tags = QLineEdit(world.tags)
        self.tags.setPlaceholderText("例如：生存、主存档")
        tags_row.addWidget(self.tags, 1)
        self.auto = QCheckBox("自动备份")
        self.auto.setChecked(world.auto_backup)
        self.auto.setToolTip("程序运行时每五分钟检查一次；只有存档发生变化且未被游戏锁定时才备份")
        tags_row.addWidget(self.auto)
        layout.addLayout(tags_row)
        layout.addWidget(label("备注", True))
        self.notes = QPlainTextEdit(world.notes)
        self.notes.setPlaceholderText("记录这个世界的故事或注意事项…")
        layout.addWidget(self.notes, 1)
        if world.error:
            error = label(world.error)
            error.setWordWrap(True)
            layout.addWidget(error)
        actions = QDialogButtonBox()
        cancel = actions.addButton("取消", QDialogButtonBox.ButtonRole.RejectRole)
        save = actions.addButton("保存", QDialogButtonBox.ButtonRole.AcceptRole)
        save.setProperty("primary", True)
        actions.accepted.connect(self.accept)
        actions.rejected.connect(self.reject)
        layout.addWidget(actions)


class HistoryDialog(QDialog):
    def __init__(self, world: World, history: list[dict], parent):
        super().__init__(parent)
        self.setWindowTitle(world.name + " · 备份历史")
        self.resize(720, 420)
        layout = QVBoxLayout(self)
        layout.addWidget(label("备份历史", name="Brand"))
        self.entries = QListWidget()
        for entry in reversed(history):
            if entry["world"] != world.path:
                continue
            archive = Path(entry["archive"])
            date = datetime.fromtimestamp(entry.get("created", 0)).strftime("%Y-%m-%d %H:%M")
            item = QListWidgetItem(f"{date}   {'已删除 · ' if not archive.is_file() else ''}{archive.name}\n{archive}")
            item.setData(Qt.ItemDataRole.UserRole, str(archive))
            item.setSizeHint(QSize(600, 58))
            self.entries.addItem(item)
        layout.addWidget(self.entries, 1)
        if not self.entries.count():
            layout.addWidget(label("还没有备份。选择一个世界后点击“备份”。", True))
        actions = QHBoxLayout()
        actions.addStretch()
        actions.addWidget(button("打开位置", self.open_location))
        actions.addWidget(button("恢复此备份", self.restore))
        actions.addWidget(button("关闭", self.reject))
        layout.addLayout(actions)
        self.selected_archive = None

    def open_location(self):
        item = self.entries.currentItem()
        if item:
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(Path(item.data(Qt.ItemDataRole.UserRole)).parent)))

    def restore(self):
        item = self.entries.currentItem()
        if item and Path(item.data(Qt.ItemDataRole.UserRole)).is_file():
            self.selected_archive = Path(item.data(Qt.ItemDataRole.UserRole))
            self.accept()


class MainWindow(QMainWindow):
    def __init__(self, store: Store, preview=False):
        super().__init__()
        self.store = store
        self.preview = preview
        self.theme = Theme(store.dark)
        self.worlds: list[World] = []
        self.worker = None
        self.busy_controls = []
        self.sort_column, self.sort_ascending = 6, False
        self.setWindowTitle(f"Minecraft Java 世界浏览器 · Linux v{VERSION}")
        self.resize(1280, 780)
        self.setMinimumSize(980, 620)
        self.setAcceptDrops(True)
        container = QWidget()
        layout = QHBoxLayout(container)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        self.setCentralWidget(container)
        layout.addWidget(self.build_sidebar())
        layout.addWidget(self.build_content(), 1)
        self.apply_theme(store.dark, persist=False)
        self.refresh_roots()
        self.update_details()
        self.auto_timer = QTimer(self)
        self.auto_timer.setInterval(5 * 60 * 1000)
        self.auto_timer.timeout.connect(lambda: self.scan(False) if not self.worker and any(world.auto_backup for world in self.worlds) else None)
        if not preview:
            self.auto_timer.start()
            QTimer.singleShot(0, self.initial_scan)

    def build_sidebar(self):
        sidebar = QWidget()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(296)
        layout = QVBoxLayout(sidebar)
        layout.setContentsMargins(18, 24, 16, 20)
        layout.setSpacing(8)
        brand = QHBoxLayout()
        icon = label("")
        asset = Path(__file__).resolve().parents[1] / "assets" / "MinecraftWorldBrowser-icon.png"
        pixmap = QPixmap(str(asset))
        icon.setPixmap(pixmap.scaled(38, 38, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation) if not pixmap.isNull() else rounded_icon(size=38))
        brand.addWidget(icon)
        words = QVBoxLayout()
        words.setSpacing(0)
        words.addWidget(label("世界浏览器", name="Brand"))
        words.addWidget(label("MINECRAFT JAVA", True))
        brand.addLayout(words, 1)
        layout.addLayout(brand)
        layout.addSpacing(10)
        heading = label("你的世界，一处管理")
        font = QFont(heading.font())
        font.setBold(True)
        heading.setFont(font)
        layout.addWidget(heading)
        layout.addWidget(label(f"跨启动器浏览、搜索与备份\nMinecraft Java · Linux v{VERSION}", True))
        layout.addSpacing(14)
        layout.addWidget(label("游戏目录", True))
        self.roots = RootList()
        self.roots.setObjectName("RootList")
        self.roots.currentRowChanged.connect(lambda _: self.remove_root_button.setEnabled(self.roots.currentRow() >= 0 and not self.worker))
        layout.addWidget(self.roots, 1)
        layout.addSpacing(4)
        self.add_root_button = button("添加目录", self.add_root, True)
        self.remove_root_button = button("移除目录", self.remove_root)
        self.restore_button = button("恢复 ZIP 备份", self.restore)
        self.export_button = button("导出配置", self.export_config)
        self.import_button = button("导入配置", self.import_config)
        for item in [self.add_root_button, self.remove_root_button, self.restore_button, self.export_button, self.import_button]:
            item.setFixedHeight(38)
            layout.addWidget(item)
            self.busy_controls.append(item)
        return sidebar

    def build_content(self):
        content = QWidget()
        content.setObjectName("Content")
        layout = QVBoxLayout(content)
        layout.setContentsMargins(20, 18, 20, 14)
        layout.setSpacing(12)
        header = QHBoxLayout()
        titles = QVBoxLayout()
        titles.setSpacing(0)
        titles.addWidget(label("全部世界", name="Title"))
        titles.addWidget(label("集中管理你的 Minecraft 存档", True))
        header.addLayout(titles, 1)
        self.summary = label("0 个世界 / 0 个目录", True)
        header.addWidget(self.summary)
        header.addSpacing(12)
        self.theme_button = button("切换暗色", lambda: self.apply_theme(not self.store.dark), name="ThemeToggleButton")
        self.theme_button.setMinimumWidth(132)
        header.addWidget(self.theme_button)
        layout.addLayout(header)
        toolbar = QHBoxLayout()
        toolbar.setSpacing(8)
        self.search = QLineEdit()
        self.search.setObjectName("Search")
        self.search.setPlaceholderText("搜索世界、版本或路径")
        self.search.setClearButtonEnabled(True)
        self.search.textChanged.connect(self.apply_filter)
        toolbar.addWidget(self.search, 1)
        toolbar.addSpacing(8)
        self.refresh_button = button("刷新", lambda: self.scan(False), name="RefreshButton")
        self.full_scan_button = button("全盘扫描", lambda: self.scan(True), name="FullScanButton")
        for item in [self.refresh_button, self.full_scan_button]:
            item.setMinimumWidth(108)
            toolbar.addWidget(item)
            self.busy_controls.append(item)
        layout.addLayout(toolbar)
        filters = QHBoxLayout()
        filters.setSpacing(10)
        self.version_filter = QComboBox()
        self.version_filter.setObjectName("VersionFilter")
        self.version_filter.setFixedWidth(184)
        self.version_filter.addItem("全部版本")
        self.version_filter.currentIndexChanged.connect(self.apply_filter)
        self.mode_filter = QComboBox()
        self.mode_filter.setObjectName("ModeFilter")
        self.mode_filter.setFixedWidth(128)
        self.mode_filter.addItems(["全部模式", "生存", "创造", "冒险", "旁观", "极限", "未知"])
        self.mode_filter.currentIndexChanged.connect(self.apply_filter)
        self.favorite_filter = button("仅收藏", self.apply_filter, name="FavoriteFilterButton")
        self.favorite_filter.setCheckable(True)
        filters.addWidget(self.version_filter)
        filters.addWidget(self.mode_filter)
        filters.addWidget(self.favorite_filter)
        filters.addStretch()
        filters.addWidget(label("点击表头排序", True))
        layout.addLayout(filters)
        card = QFrame()
        card.setObjectName("Card")
        table_layout = QVBoxLayout(card)
        table_layout.setContentsMargins(3, 3, 3, 3)
        self.table = WorldTable()
        self.table.setObjectName("WorldGrid")
        self.model = WorldModel(self)
        self.table.setModel(self.model)
        for column, width in enumerate([60, 210, 100, 66, 68, 96, 122, 108, 300]):
            self.table.setColumnWidth(column, width)
        self.table.selectionModel().selectionChanged.connect(self.update_details)
        self.table.doubleClicked.connect(lambda _: self.open_world())
        self.table.horizontalHeader().sectionClicked.connect(self.sort_by)
        self.table.horizontalHeader().setSortIndicator(6, Qt.SortOrder.DescendingOrder)
        table_layout.addWidget(self.table)
        layout.addWidget(card, 1)
        footer = QFrame()
        footer.setObjectName("Card")
        footer_layout = QHBoxLayout(footer)
        footer_layout.setContentsMargins(18, 10, 12, 10)
        description = QVBoxLayout()
        description.setSpacing(5)
        self.detail_name = label("选择一个世界查看详情", True)
        self.detail_path = label("")
        self.detail_name.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Fixed)
        self.detail_path.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Fixed)
        self.detail_path.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        description.addWidget(self.detail_name)
        description.addWidget(self.detail_path)
        footer_layout.addLayout(description, 1)
        self.favorite_button = button("☆", self.toggle_favorite)
        self.details_button = button("详情", self.details)
        self.history_button = button("历史", self.history)
        self.backup_button = button("备份", self.backup)
        self.copy_button = button("复制路径", self.copy_path)
        self.open_button = button("打开存档", self.open_world, True)
        self.world_buttons = [self.favorite_button, self.details_button, self.history_button, self.backup_button, self.copy_button, self.open_button]
        for item in self.world_buttons:
            item.setMinimumWidth(36)
            footer_layout.addWidget(item)
        layout.addWidget(footer)
        status = QHBoxLayout()
        self.status = label("准备就绪", True)
        self.status.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Fixed)
        status.addWidget(self.status, 1)
        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.setTextVisible(False)
        self.progress.setFixedSize(130, 6)
        self.progress.hide()
        self.cancel_button = button("取消", self.cancel_operation)
        self.cancel_button.hide()
        status.addWidget(self.progress)
        status.addWidget(self.cancel_button)
        layout.addLayout(status)
        return content

    def apply_theme(self, dark, persist=True):
        self.store.dark = dark
        self.theme = Theme(dark)
        self.roots.theme = self.theme
        self.table.theme = self.theme
        palette = QPalette()
        for role, color in [(QPalette.ColorRole.Window, self.theme.canvas), (QPalette.ColorRole.WindowText, self.theme.ink),
                            (QPalette.ColorRole.Base, self.theme.surface), (QPalette.ColorRole.Text, self.theme.ink),
                            (QPalette.ColorRole.Button, self.theme.button), (QPalette.ColorRole.ButtonText, self.theme.ink),
                            (QPalette.ColorRole.Highlight, self.theme.selection), (QPalette.ColorRole.HighlightedText, self.theme.ink),
                            (QPalette.ColorRole.PlaceholderText, self.theme.muted)]:
            palette.setColor(role, QColor(color))
        self.setPalette(palette)
        self.setStyleSheet(self.theme.stylesheet())
        self.theme_button.setText("切换亮色" if dark else "切换暗色")
        icon = QPixmap(20, 20)
        icon.fill(Qt.GlobalColor.transparent)
        painter = QPainter(icon)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(QPen(QColor(self.theme.ink), 1.4))
        if dark:
            painter.drawEllipse(QRectF(6, 6, 8, 8))
            import math
            for index in range(8):
                angle = index * math.pi / 4
                painter.drawLine(QPoint(round(10 + 6 * math.cos(angle)), round(10 + 6 * math.sin(angle))),
                                 QPoint(round(10 + 8 * math.cos(angle)), round(10 + 8 * math.sin(angle))))
        else:
            crescent, cutout = QPainterPath(), QPainterPath()
            crescent.addEllipse(QRectF(3, 3, 14, 14))
            cutout.addEllipse(QRectF(7, 0, 13, 13))
            painter.drawPath(crescent.subtracted(cutout))
        painter.end()
        self.theme_button.setIcon(QIcon(icon))
        self.roots.viewport().update()
        self.table.viewport().update()
        if persist and not self.preview:
            self.store.save()

    def initial_scan(self):
        if self.store.load_error:
            self.show_error(self.store.load_error)
            return
        self.scan(False, initial_defaults=not self.store.file.exists())

    def refresh_roots(self):
        current = self.roots.currentItem()
        selected = current.data(Qt.ItemDataRole.UserRole) if current else None
        offset = self.roots.verticalScrollBar().value()
        self.roots.clear()
        for path in sorted(self.store.roots):
            item = QListWidgetItem(path)
            item.setData(Qt.ItemDataRole.UserRole, path)
            item.setToolTip(path)
            self.roots.addItem(item)
            if path == selected:
                self.roots.setCurrentItem(item)
        self.roots.verticalScrollBar().setValue(offset)
        self.remove_root_button.setEnabled(self.roots.currentRow() >= 0 and not self.worker)

    def selected_world(self) -> World | None:
        indexes = self.table.selectionModel().selectedRows()
        return self.model.worlds[indexes[0].row()] if indexes else None

    def update_details(self, *_):
        world = self.selected_world()
        for item in self.world_buttons:
            item.setEnabled(world is not None and not self.worker)
        if not world:
            self.detail_name.setText("选择一个世界查看详情")
            self.detail_path.clear()
            return
        self.favorite_button.setText("★" if world.favorite else "☆")
        summary = f"{world.name} / {world.version} / {world.mode} / {world.health} / {world.loader}"
        # Keep the footer's text within its own space at minimum window width.
        available = max(150, self.detail_path.parentWidget().width() - 470)
        self.detail_name.setText(self.detail_name.fontMetrics().elidedText(summary, Qt.TextElideMode.ElideRight, available))
        self.detail_path.setText(self.detail_path.fontMetrics().elidedText(world.path, Qt.TextElideMode.ElideMiddle, available))
        self.detail_path.setToolTip(world.path)
        self.detail_name.setToolTip(summary)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if hasattr(self, "world_buttons"):
            QTimer.singleShot(0, self.update_details)

    def apply_filter(self, *_):
        selected = self.selected_world()
        path = selected.path if selected else None
        vertical = self.table.verticalScrollBar().value()
        horizontal = self.table.horizontalScrollBar().value()
        query = self.search.text().strip().casefold()
        version, mode = self.version_filter.currentText(), self.mode_filter.currentText()
        worlds = [world for world in self.worlds if (not query or query in " ".join(str(getattr(world, field)) for field in ["name", "version", "mode", "health", "loader", "source", "path", "tags", "notes"]).casefold())
                  and (self.version_filter.currentIndex() == 0 or world.version == version)
                  and (self.mode_filter.currentIndex() == 0 or world.mode == mode)
                  and (not self.favorite_filter.isChecked() or world.favorite)]
        field = COLUMNS[self.sort_column][1]
        if field == "version":
            key = lambda world: (version_key(world.version), world.version)
        else:
            key = lambda world: getattr(world, field).casefold() if isinstance(getattr(world, field), str) else getattr(world, field)
        worlds.sort(key=key, reverse=not self.sort_ascending)
        self.model.replace(worlds)
        index = next((row for row, world in enumerate(worlds) if world.path == path), 0 if worlds else None)
        if index is not None:
            self.table.selectRow(index)
        self.table.verticalScrollBar().setValue(vertical)
        self.table.horizontalScrollBar().setValue(horizontal)
        self.summary.setText(f"{len(worlds)} 个世界 / {len(self.store.roots)} 个目录")
        self.update_details()

    def sort_by(self, column):
        if column == 0:
            return
        self.sort_ascending = not self.sort_ascending if self.sort_column == column else True
        self.sort_column = column
        self.table.horizontalHeader().setSortIndicator(column, Qt.SortOrder.AscendingOrder if self.sort_ascending else Qt.SortOrder.DescendingOrder)
        self.apply_filter()
        self.table.verticalScrollBar().setValue(0)

    def set_busy(self, busy):
        for item in self.busy_controls:
            item.setEnabled(not busy)
        self.progress.setVisible(busy)
        self.cancel_button.setVisible(busy)
        self.update_details()
        self.remove_root_button.setEnabled(not busy and self.roots.currentRow() >= 0)

    def start_task(self, title, function, complete):
        if self.worker:
            return
        worker = Worker(function)
        self.worker = worker
        self.status.setText(title)
        self.set_busy(True)
        worker.signals.progress.connect(self.status.setText, Qt.ConnectionType.QueuedConnection)

        def finish(result):
            self.worker = None
            self.set_busy(False)
            try:
                complete(result)
            except Exception as error:
                self.show_error(str(error))

        def fail(text):
            self.worker = None
            self.set_busy(False)
            self.show_error(text)

        def cancelled():
            self.worker = None
            self.set_busy(False)
            self.status.setText("操作已取消")

        worker.signals.done.connect(finish, Qt.ConnectionType.QueuedConnection)
        worker.signals.failed.connect(fail, Qt.ConnectionType.QueuedConnection)
        worker.signals.cancelled.connect(cancelled, Qt.ConnectionType.QueuedConnection)
        QThreadPool.globalInstance().start(worker)

    def cancel_operation(self):
        if self.worker:
            self.worker.cancel.set()
            self.status.setText("正在取消…")

    def scan(self, discover_all=False, initial_defaults=False):
        if self.worker:
            return
        roots = list(self.store.roots)
        metadata = copy.deepcopy(self.store.metadata)

        def work(cancel, progress):
            candidates = scan_starts() if discover_all else default_candidates() if initial_defaults else []
            discovered = discover_roots(candidates, None if discover_all else 5, cancel, progress)
            active = list(dict.fromkeys(roots + discovered))
            return active, scan_worlds(active, metadata, cancel, progress)

        def complete(result):
            self.store.roots, self.worlds = result
            self.store.save()
            self.refresh_roots()
            self.table.itemDelegate().icons.clear()
            old_version = self.version_filter.currentText()
            self.version_filter.blockSignals(True)
            self.version_filter.clear()
            self.version_filter.addItem("全部版本")
            self.version_filter.addItems(sorted({world.version for world in self.worlds}, key=lambda value: (version_key(value), value), reverse=True))
            self.version_filter.setCurrentIndex(max(0, self.version_filter.findText(old_version)))
            self.version_filter.blockSignals(False)
            for world in self.worlds:
                world.backup_count = sum(entry["world"] == world.path and Path(entry["archive"]).is_file() for entry in self.store.history)
            self.apply_filter()
            self.status.setText(f"存档大小计算完成，共 {len(self.worlds)} 个世界")
            self.automatic_backups()

        self.start_task("正在全盘扫描…" if discover_all else "正在读取存档…", work, complete)

    def add_paths(self, paths):
        if self.worker:
            return
        changed = False
        for path in paths:
            if Path(path).is_dir():
                key = normalize(path)
                if key not in self.store.roots:
                    self.store.roots.append(key)
                    changed = True
        if changed:
            self.store.save()
            self.refresh_roots()
            self.scan(False)

    def add_root(self):
        path = QFileDialog.getExistingDirectory(self, "添加 .minecraft、启动器或游戏实例目录", str(Path.home()))
        if path:
            self.add_paths([path])

    def remove_root(self):
        item = self.roots.currentItem()
        if item:
            self.store.roots.remove(item.data(Qt.ItemDataRole.UserRole))
            self.store.save()
            self.refresh_roots()
            self.scan(False)

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls() and not self.worker:
            event.acceptProposedAction()

    def dropEvent(self, event):
        self.add_paths([url.toLocalFile() for url in event.mimeData().urls() if url.isLocalFile()])
        event.acceptProposedAction()

    def toggle_favorite(self):
        world = self.selected_world()
        if world:
            world.favorite = not world.favorite
            self.store.update_world(world)
            self.store.save()
            self.apply_filter()

    def details(self):
        world = self.selected_world()
        if world:
            dialog = DetailsDialog(world, self)
            if dialog.exec() == QDialog.DialogCode.Accepted:
                world.tags, world.notes, world.auto_backup = dialog.tags.text(), dialog.notes.toPlainText(), dialog.auto.isChecked()
                self.store.update_world(world)
                self.store.save()
                self.apply_filter()

    def open_world(self):
        world = self.selected_world()
        if world and Path(world.path).is_dir():
            if not QDesktopServices.openUrl(QUrl.fromLocalFile(world.path)):
                self.show_error("无法打开文件管理器，请复制存档路径手动打开")

    def copy_path(self):
        world = self.selected_world()
        if world:
            QApplication.clipboard().setText(world.path)
            self.status.setText("存档路径已复制")

    def backup(self):
        world = self.selected_world()
        if not world:
            return
        suggested = self.store.directory / "Backups" / f"{safe_name(world.name)}-{datetime.now():%Y%m%d-%H%M%S}.zip"
        suggested.parent.mkdir(parents=True, exist_ok=True)
        path, _ = QFileDialog.getSaveFileName(self, "创建 ZIP 备份", str(suggested), "ZIP 备份 (*.zip)")
        if path:
            destination = Path(path)
            if destination.suffix.casefold() != ".zip":
                destination = destination.with_suffix(".zip")
            self.start_task("正在创建备份…", lambda cancel, progress: create_backup(world, destination, cancel, progress),
                            lambda archive: self.backup_complete(world, archive))

    def backup_complete(self, world, archive):
        self.store.record_backup(world, archive)
        world.backup_count += 1
        self.status.setText("备份完成 · " + str(archive))
        self.update_details()

    def automatic_backups(self):
        if self.preview:
            return
        worlds = [world for world in self.worlds if world.auto_backup and world.health == "正常" and world.fingerprint != world.last_backup_fingerprint]
        if not worlds:
            return

        def work(cancel, progress):
            result = []
            for world in worlds:
                destination = self.store.directory / "AutomaticBackups" / f"{safe_name(world.name)}-{datetime.now():%Y%m%d-%H%M%S}-{os.urandom(3).hex()}.zip"
                try:
                    result.append((world, create_backup(world, destination, cancel, progress), ""))
                except Cancelled:
                    # Completed archives still need history records if cancellation occurs later.
                    return result
                except Exception as error:
                    result.append((world, None, str(error)))
            return result

        def complete(results):
            errors = []
            for world, archive, error in results:
                if archive:
                    self.store.record_backup(world, archive)
                    world.backup_count += 1
                else:
                    errors.append(f"{world.name}: {error}")
            self.status.setText("自动备份完成" if not errors else "自动备份未完成：" + "；".join(errors))
            self.update_details()

        self.start_task("正在自动备份…", work, complete)

    def history(self):
        world = self.selected_world()
        if world:
            dialog = HistoryDialog(world, self.store.history, self)
            if dialog.exec() == QDialog.DialogCode.Accepted and dialog.selected_archive:
                self.restore(dialog.selected_archive)

    def restore(self, archive=None):
        # clicked(bool) is not a path argument.
        if not isinstance(archive, Path):
            name, _ = QFileDialog.getOpenFileName(self, "选择世界 ZIP 备份", str(self.store.directory), "ZIP 备份 (*.zip)")
            if not name:
                return
            archive = Path(name)
        try:
            manifest = read_manifest(archive)
            original = manifest.get("OriginalPath", "")
            destination = None
            if safe_original_path(original):
                answer = QMessageBox.question(self, "恢复位置", f"恢复到原始位置？\n{original}", QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No | QMessageBox.StandardButton.Cancel)
                if answer == QMessageBox.StandardButton.Cancel:
                    return
                if answer == QMessageBox.StandardButton.Yes:
                    destination = Path(original)
            if destination is None:
                folder = QFileDialog.getExistingDirectory(self, "选择目标 .minecraft 或 saves 目录", str(Path.home() / ".minecraft"))
                if not folder:
                    return
                root = Path(folder)
                if (root / ".minecraft").is_dir():
                    root /= ".minecraft"
                saves = root if root.name == "saves" else root / "saves"
                destination = saves / safe_name(manifest.get("WorldName") or archive.stem)
            overwrite = False
            if destination.exists():
                prompt = QMessageBox(self)
                prompt.setWindowTitle("目标存档已存在")
                prompt.setText(f"{destination}\n请选择恢复方式。覆盖会替换该目录内的现有文件。")
                new = prompt.addButton("创建新存档", QMessageBox.ButtonRole.AcceptRole)
                replace = prompt.addButton("覆盖存档", QMessageBox.ButtonRole.DestructiveRole)
                prompt.addButton("取消", QMessageBox.ButtonRole.RejectRole)
                prompt.exec()
                if prompt.clickedButton() == new:
                    destination = unique_directory(destination)
                elif prompt.clickedButton() == replace:
                    overwrite = True
                else:
                    return

            def complete(path):
                root = normalize(path.parent.parent)
                if root not in self.store.roots:
                    self.store.roots.append(root)
                self.store.save()
                self.refresh_roots()
                self.status.setText("恢复完成 · " + str(path))
                self.scan(False)

            self.start_task("正在恢复备份…", lambda cancel, progress: restore_backup(archive, destination, overwrite, cancel, progress), complete)
        except Exception as error:
            self.show_error(str(error))

    def export_config(self):
        path, _ = QFileDialog.getSaveFileName(self, "导出配置", "MinecraftWorldBrowser-config.mwconfig", "世界浏览器配置 (*.mwconfig)")
        if path:
            try:
                destination = Path(path)
                if destination.suffix != ".mwconfig":
                    destination = destination.with_suffix(".mwconfig")
                self.store.export_config(destination)
                self.status.setText("配置已导出")
            except Exception as error:
                self.show_error(str(error))

    def import_config(self):
        path, _ = QFileDialog.getOpenFileName(self, "导入配置", str(Path.home()), "世界浏览器配置 (*.mwconfig)")
        if path:
            try:
                skipped = self.store.import_config(Path(path))
                self.refresh_roots()
                if skipped:
                    QMessageBox.information(self, "配置已导入", f"已跳过 {skipped} 个不存在或属于其他系统的路径，请添加 Linux 上的实际游戏目录。")
                self.scan(False)
            except Exception as error:
                self.show_error(str(error))

    def show_error(self, message):
        self.status.setText(message)
        QMessageBox.warning(self, "操作未完成", message)

    def closeEvent(self, event):
        if self.worker:
            self.cancel_operation()
            self.status.setText("正在取消操作，完成后可关闭窗口")
            event.ignore()
            return
        self.auto_timer.stop()
        event.accept()

    def prepare_preview(self):
        self.store.roots = ["/home/player/.minecraft", "/home/player/.local/share/PrismLauncher/instances", "/home/player/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances"] + [f"/home/player/Games/Profile {index:02d}/.minecraft" for index in range(1, 14)]
        self.refresh_roots()
        self.roots.setCurrentRow(0)
        now = datetime(2026, 10, 1, 18, 30).timestamp()
        self.worlds = [World("/home/player/.minecraft/saves/Survival Garden", name="Survival Garden", version="1.21.1", mode="生存", health="正常", loader="Fabric", source="1.21.1-Fabric", favorite=True, size=1328755507, last_played=now, seed=1234567890123456789, difficulty="普通", data_version=3953),
                       World("/home/player/.local/share/PrismLauncher/instances/Creative/.minecraft/saves/Creative Studio", name="Creative Studio", version="1.20.4", mode="创造", source="Creative", loader="Forge", size=486539264, last_played=now - 2 * 86400),
                       World("/home/player/.minecraft/saves/Redstone Lab", name="Redstone Lab", version="1.19.2", mode="生存", source=".minecraft", loader="NeoForge", size=203423744, last_played=now - 8 * 86400)]
        self.version_filter.blockSignals(True)
        self.version_filter.clear()
        self.version_filter.addItems(["全部版本", "1.21.1", "1.20.4", "1.19.2"])
        self.version_filter.blockSignals(False)
        self.apply_filter()
        self.status.setText("已发现 3 个世界 · 跨启动器存档已合并")

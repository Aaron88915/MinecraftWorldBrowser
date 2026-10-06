import copy
import os
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PySide6.QtCore import QPoint, QThread, Qt
from PySide6.QtGui import QColor, QFont, QRawFont
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication, QDialog
from mwb.core import Store, create_backup
from mwb.ui import DetailsDialog, MainWindow, application_font
from test_core import make_world


class UiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        cls.app.setStyle("Fusion")
        cls.app.setFont(application_font())

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.store = Store(self.directory / "settings")
        self.window = MainWindow(self.store, preview=True)
        self.window.prepare_preview()
        self.window.show()
        self.app.processEvents()

    def tearDown(self):
        if self.window.worker:
            self.window.cancel_operation()
            self.wait_worker()
        self.window.close()
        self.app.processEvents()
        self.temporary.cleanup()

    def wait_worker(self):
        deadline = time.monotonic() + 10
        while self.window.worker and time.monotonic() < deadline:
            self.app.processEvents()
            QTest.qWait(10)
        self.assertIsNone(self.window.worker, "background operation did not finish")
        self.app.processEvents()

    def test_preview_is_isolated_and_version_visible(self):
        self.assertIn("Linux v3.3.2", self.window.windowTitle())
        self.assertFalse(self.store.file.exists())
        self.assertEqual(len(self.window.model.worlds), 3)
        self.assertEqual(self.window.roots.count(), 16)

    def test_application_font_can_render_latin_and_chinese(self):
        font = QRawFont.fromFont(self.app.font())
        self.assertTrue(font.isValid())
        for character in "Minecraft世界浏览器0123":
            self.assertTrue(font.supportsCharacter(ord(character)), character)

    def test_actual_buttons_normal_pressed_released_in_both_themes(self):
        for dark in [False, True]:
            self.window.apply_theme(dark, False)
            self.app.processEvents()
            for control in [self.window.theme_button, self.window.refresh_button, self.window.full_scan_button, self.window.favorite_filter]:
                control.clearFocus()
                self.app.processEvents()
                normal = control.grab().toImage()
                face = normal.pixelColor(12, 6)
                canvas = QColor(self.window.theme.canvas)
                difference = abs(face.red() - canvas.red()) + abs(face.green() - canvas.green()) + abs(face.blue() - canvas.blue())
                self.assertGreaterEqual(difference, 24, control.objectName())
                control.setDown(True)
                self.app.processEvents()
                pressed = control.grab().toImage()
                self.assertNotEqual(normal.pixelColor(12, 6), pressed.pixelColor(12, 6))
                self.assertEqual(normal.pixelColor(0, 0), pressed.pixelColor(0, 0))
                control.setDown(False)
                self.app.processEvents()
                self.assertEqual(normal, control.grab().toImage())

    def test_filter_controls_have_visible_background_and_popup(self):
        for dark in [False, True]:
            self.window.apply_theme(dark, False)
            for combo in [self.window.version_filter, self.window.mode_filter]:
                image = combo.grab().toImage()
                self.assertNotEqual(image.pixelColor(12, 6), QColor(self.window.theme.canvas))
                combo.showPopup()
                self.app.processEvents()
                self.assertTrue(combo.view().isVisible())
                combo.hidePopup()
                self.app.processEvents()

    def test_world_grid_has_only_horizontal_dividers_selected_and_normal(self):
        self.assertFalse(self.window.table.showGrid())
        for dark in [False, True]:
            self.window.apply_theme(dark, False)
            for offset in [0, 60]:
                self.window.table.horizontalScrollBar().setValue(offset)
                self.app.processEvents()
                image = self.window.table.viewport().grab().toImage()
                for row in [0, 1]:
                    fill = QColor(self.window.theme.selection if row == 0 else self.window.theme.surface)
                    for column in range(8):
                        bounds = self.window.table.visualRect(self.window.model.index(row, column))
                        x = bounds.right()
                        if not 1 < x < image.width() - 2:
                            continue
                        for y in range(bounds.top() + 5, bounds.bottom() - 5):
                            self.assertEqual(image.pixelColor(x, y), fill, f"column {column}, row {row}, {x},{y}")
                        self.assertEqual(image.pixelColor(max(2, bounds.left() + 6), bounds.bottom()), QColor(self.window.theme.line))

    def test_root_overlay_scrollbar_preserves_selected_background_and_drag(self):
        for dark in [False, True]:
            self.window.apply_theme(dark, False)
            self.window.roots.verticalScrollBar().setValue(0)
            self.app.processEvents()
            image = self.window.roots.viewport().grab().toImage()
            for offset in [1, 11]:
                self.assertEqual(image.pixelColor(image.width() - offset, 14), QColor(self.window.theme.primary))
            thumb = self.window.roots.thumb_rect()
            self.assertGreater(thumb.height(), 0)
            QTest.mousePress(self.window.roots.viewport(), Qt.MouseButton.LeftButton, pos=thumb.center())
            QTest.mouseMove(self.window.roots.viewport(), thumb.center() + QPoint(0, 35))
            QTest.mouseRelease(self.window.roots.viewport(), Qt.MouseButton.LeftButton, pos=thumb.center() + QPoint(0, 35))
            self.app.processEvents()
            self.assertGreater(self.window.roots.verticalScrollBar().value(), 0)
            self.assertIsNone(self.window.roots.drag_offset)

    def test_search_version_mode_and_favorite_filters(self):
        self.window.search.setText("fabric")
        self.assertEqual(self.window.model.rowCount(), 1)
        self.window.search.clear()
        self.window.version_filter.setCurrentText("1.20.4")
        self.assertEqual(self.window.model.worlds[0].name, "Creative Studio")
        self.window.mode_filter.setCurrentText("生存")
        self.assertEqual(self.window.model.rowCount(), 0)
        self.window.version_filter.setCurrentIndex(0)
        self.window.mode_filter.setCurrentIndex(0)
        self.window.favorite_filter.setChecked(True)
        self.window.apply_filter()
        self.assertEqual(self.window.model.worlds[0].name, "Survival Garden")
        self.assertEqual(self.window.model.rowCount(), 1)

    def test_version_sort_and_live_column_resize(self):
        self.window.sort_by(2)
        self.assertEqual(self.window.model.worlds[0].version, "1.19.2")
        self.window.sort_by(2)
        self.assertEqual(self.window.model.worlds[0].version, "1.21.1")
        old = self.window.table.columnWidth(8)
        self.window.table.setColumnWidth(1, 280)
        self.assertEqual(self.window.table.columnWidth(1), 280)
        self.assertEqual(self.window.table.columnWidth(8), old)

    def test_favorite_update_preserves_selection_and_viewport(self):
        original = self.window.worlds[0]
        self.window.worlds = []
        for index in range(50):
            world = copy.copy(original)
            world.path = str(self.directory / f"world-{index}")
            world.name = f"World {index}"
            world.last_played += index
            self.window.worlds.append(world)
        self.window.apply_filter()
        self.window.table.selectRow(25)
        self.window.table.verticalScrollBar().setValue(760)
        self.window.table.horizontalScrollBar().setValue(60)
        before_path = self.window.selected_world().path
        vertical = self.window.table.verticalScrollBar().value()
        horizontal = self.window.table.horizontalScrollBar().value()
        self.window.toggle_favorite()
        self.assertEqual(self.window.selected_world().path, before_path)
        self.assertEqual(self.window.table.verticalScrollBar().value(), vertical)
        self.assertEqual(self.window.table.horizontalScrollBar().value(), horizontal)

    def test_details_edit_and_copy_path(self):
        world = self.window.selected_world()
        def edit(dialog):
            dialog.tags.setText("主存档")
            dialog.notes.setPlainText("新的备注\n第二行")
            dialog.auto.setChecked(True)
            return QDialog.DialogCode.Accepted
        with patch.object(DetailsDialog, "exec", edit):
            self.window.details()
        self.assertEqual(world.tags, "主存档")
        self.assertEqual(world.notes, "新的备注\n第二行")
        self.assertTrue(world.auto_backup)
        self.assertEqual(Store(self.store.directory).metadata[world.path]["tags"], "主存档")
        self.window.copy_path()
        self.assertEqual(self.app.clipboard().text(), world.path)

    def test_minimum_window_layout_has_all_actions_visible(self):
        self.window.resize(980, 620)
        self.app.processEvents()
        for control in [self.window.full_scan_button, self.window.theme_button, self.window.open_button]:
            position = control.mapTo(self.window.centralWidget(), QPoint(0, 0))
            self.assertGreaterEqual(position.x(), 296)
            self.assertLessEqual(position.x() + control.width(), self.window.centralWidget().width())

    def test_details_checkbox_is_visible_and_checked_in_both_themes(self):
        for dark in [False, True]:
            self.window.apply_theme(dark, False)
            dialog = DetailsDialog(self.window.selected_world(), self.window)
            dialog.show()
            self.app.processEvents()
            normal = dialog.auto.grab().toImage()
            self.assertNotEqual(normal.pixelColor(0, normal.height() // 2), QColor(self.window.theme.canvas))
            QTest.mousePress(dialog.auto, Qt.MouseButton.LeftButton, pos=QPoint(8, normal.height() // 2))
            self.app.processEvents()
            pressed = dialog.auto.grab().toImage()
            self.assertNotEqual(normal, pressed)
            QTest.mouseRelease(dialog.auto, Qt.MouseButton.LeftButton, pos=QPoint(8, normal.height() // 2))
            self.app.processEvents()
            self.assertTrue(dialog.auto.isChecked())
            self.assertNotEqual(normal, dialog.auto.grab().toImage())
            dialog.auto.setChecked(False)
            self.app.processEvents()
            self.assertEqual(normal, dialog.auto.grab().toImage())
            dialog.close()

    def test_refresh_does_not_restore_explicitly_removed_last_root(self):
        root = self.directory / "Games" / ".minecraft"
        make_world(root / "saves" / "sample")
        self.store.roots = [str(root)]
        self.store.save()
        self.window.refresh_roots()
        self.window.roots.setCurrentRow(0)
        with patch("mwb.ui.default_candidates", return_value=[root]) as defaults:
            self.window.remove_root()
            self.wait_worker()
            defaults.assert_not_called()
            self.assertEqual(self.store.roots, [])
            self.assertEqual(self.window.worlds, [])

    def test_background_results_are_applied_on_gui_thread(self):
        observed = []
        root = self.directory / "Games" / ".minecraft"
        make_world(root / "saves" / "sample")
        self.store.roots = [str(root)]
        self.window.preview = False
        self.window.automatic_backups = lambda: observed.append(QThread.currentThread() == self.app.thread())
        self.window.scan(False)
        self.wait_worker()
        self.assertEqual(len(self.window.worlds), 1)
        self.assertEqual(observed, [True])
        self.assertTrue(self.store.file.exists())

    def test_background_backup_updates_history_and_real_archive(self):
        world = make_world(self.directory / ".minecraft" / "saves" / "sample")
        archive = self.directory / "backup.zip"
        self.window.start_task("test", lambda cancel, progress: create_backup(world, archive, cancel, progress),
                               lambda result: self.window.backup_complete(world, result))
        self.wait_worker()
        self.assertTrue(archive.is_file())
        self.assertEqual(self.store.history[0]["archive"], str(archive.resolve()))
        self.assertEqual(world.backup_count, 1)

    def test_background_operation_cancellation_recovers_controls(self):
        from mwb.core import check_cancel
        def work(cancel, progress):
            while not cancel.is_set():
                time.sleep(0.01)
            check_cancel(cancel)
        self.window.start_task("test", work, lambda result: self.fail("cancelled operation completed"))
        self.assertFalse(self.window.refresh_button.isEnabled())
        self.window.cancel_operation()
        self.wait_worker()
        self.assertTrue(self.window.refresh_button.isEnabled())
        self.assertEqual(self.window.status.text(), "操作已取消")


if __name__ == "__main__":
    unittest.main()

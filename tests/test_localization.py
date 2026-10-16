
"""Coverage for localized display text, hot switching and language persistence."""
import ast
import copy
import re
import subprocess
import sys
import textwrap
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from PySide6.QtCore import QCoreApplication, QPoint
from core.config import DEFAULT_CONFIG, BUTTON_NAMES, PROFILE_BUTTON_NAMES
from core.key_simulator import ACTIONS
from ui.actions_ring_overlay import RING_LABEL_MAP
from ui.backend import Backend
from ui.locale_manager import LocaleManager, _TRANSLATIONS

ROOT = Path(__file__).resolve().parents[1]


class LocalizationCoverageTests(unittest.TestCase):
    def test_all_referenced_qml_keys_exist_in_every_locale(self):
        keys = set()
        for path in (ROOT / "ui/qml").glob("*.qml"):
            lines = [line for line in path.read_text(encoding="utf-8").splitlines()
                     if not line.lstrip().startswith("//")]
            keys.update(re.findall(r'(?:\bs|lm\.strings)\["([^"]+)"\]', "\n".join(lines)))
        for locale, strings in _TRANSLATIONS.items():
            with self.subTest(locale=locale):
                self.assertFalse(keys - strings.keys())
                self.assertTrue(all(strings[key].strip() for key in keys))

    def test_every_action_and_category_has_chinese_display_text(self):
        for locale in ("zh_CN", "zh_TW"):
            manager = LocaleManager(locale)
            for action in ACTIONS.values():
                with self.subTest(locale=locale, action=action["label"]):
                    translated = manager.trAction(action["label"])
                    if action["label"] == "Actions Ring":
                        self.assertEqual(translated, "Actions Ring")
                    else:
                        self.assertRegex(translated, r"[\u3400-\u9fff]")
                    self.assertRegex(manager.trCategory(action["category"]), r"[\u3400-\u9fff]")

    def test_every_configured_button_name_is_localized(self):
        labels = set(BUTTON_NAMES.values()) | set(PROFILE_BUTTON_NAMES.values())
        for locale in ("zh_CN", "zh_TW"):
            manager = LocaleManager(locale)
            for label in labels:
                with self.subTest(locale=locale, button=label):
                    translated = manager.trButton(label)
                    if label == "Actions Ring":
                        self.assertEqual(translated, "Actions Ring")
                    else:
                        self.assertRegex(translated, r"[\u3400-\u9fff]")

    def test_ring_short_labels_are_translated_except_brand_names(self):
        for locale in ("zh_CN", "zh_TW"):
            manager = LocaleManager(locale)
            for label in set(RING_LABEL_MAP.values()) - {"SmartShift"}:
                with self.subTest(locale=locale, label=label):
                    translated = manager.trAction(label)
                    if translated != "Actions Ring":
                        self.assertRegex(translated, r"[\u3400-\u9fff]")

    def test_actions_ring_brand_is_preserved_without_rewriting_user_names(self):
        for locale in ("zh_CN", "zh_TW"):
            manager = LocaleManager(locale)
            self.assertEqual(manager.strings["nav.actions_ring"], "Actions Ring")
            self.assertEqual(manager.trAction("Actions Ring"), "Actions Ring")
            self.assertEqual(manager.trAction("Ring"), "Actions Ring")
            self.assertEqual(manager.trButton("Actions Ring"), "Actions Ring")
            self.assertNotRegex(" ".join(manager.strings.values()), "动作环|動作環")
            self.assertEqual(manager.trProfile("custom", "动作环"), "动作环")
            self.assertEqual(manager.trAction("activate_actions_ring"), "activate_actions_ring")

    def test_default_profile_localization_preserves_user_names(self):
        manager = LocaleManager("zh_CN")
        self.assertEqual(manager.trProfile("default", "Default (All Apps)"), "默认（所有应用）")
        self.assertEqual(manager.trProfile("default", "My custom name"), "My custom name")
        self.assertEqual(manager.trProfile("work", "Default (All Apps)"), "Default (All Apps)")
        self.assertEqual(manager.trAction("custom:ctrl+f"), "custom:ctrl+f")

    def test_status_translation_preserves_paths_errors_and_versions(self):
        manager = LocaleManager("zh_CN")
        self.assertEqual(manager.trStatus("Saved"), "已保存")
        path = r"C:\Screenshots\example.png"
        self.assertEqual(manager.trStatus("Screenshot saved to " + path), "截图已保存至 " + path)
        self.assertEqual(manager.trStatus("Screenshot failed: EACCES"), "截图失败：EACCES")
        self.assertEqual(manager.trStatus("Mouser 3.7.5 is available"), "发现 Mouser 新版本：3.7.5")
        self.assertEqual(manager.trStatus("unknown diagnostic"), "unknown diagnostic")
        manager.setLanguage("en")
        self.assertEqual(manager.trStatus("Saved"), "Saved")

    def test_static_windows_status_messages_have_chinese_text(self):
        for filename, functions in {
            "ui/backend.py": {"self.statusMessage.emit"},
            "core/engine.py": {"self._emit_status"},
            "ui/windows_screenshot.py": {"self._status"},
        }.items():
            tree = ast.parse((ROOT / filename).read_text(encoding="utf-8"))
            for node in ast.walk(tree):
                if not isinstance(node, ast.Call) or not node.args:
                    continue
                value = node.args[0]
                if ast.unparse(node.func) in functions and isinstance(value, ast.Constant) and isinstance(value.value, str):
                    for locale in ("zh_CN", "zh_TW"):
                        with self.subTest(file=filename, line=node.lineno, locale=locale):
                            self.assertRegex(LocaleManager(locale).trStatus(value.value), r"[\u3400-\u9fff]")


class LocaleSwitchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication(["locale-tests"])

    def make_backend(self, manager):
        cfg = copy.deepcopy(DEFAULT_CONFIG)
        cfg["settings"]["language"] = "en"
        cfg["settings"]["check_for_updates"] = False
        with patch("ui.backend.load_config", return_value=cfg), \
             patch("ui.backend.save_config"), \
             patch("ui.backend.supports_login_startup", return_value=False), \
             patch.object(Backend, "_consumeUpdateResultMarker"), \
             patch.object(Backend, "_cleanupStaleUpdatePreparation"):
            return Backend(locale_manager=manager)

    def test_language_remains_selected_after_saving_another_setting(self):
        manager = LocaleManager("en")
        backend = self.make_backend(manager)
        with patch("ui.backend.save_config") as save:
            manager.setLanguage("zh_CN")
            self.assertEqual(backend._cfg["settings"]["language"], "zh_CN")
            backend.setHapticEnabled(False)
            self.assertEqual(save.call_args.args[0]["settings"]["language"], "zh_CN")

    def test_language_save_error_keeps_config_consistent_and_reports_failure(self):
        manager = LocaleManager("en")
        backend = self.make_backend(manager)
        messages = []
        backend.statusMessage.connect(messages.append)
        with patch("ui.backend.save_config", side_effect=OSError("test")):
            manager.setLanguage("zh_CN")
        self.assertEqual(backend._cfg["settings"]["language"], "en")
        self.assertEqual(messages, ["Could not save display language"])

    def test_ring_overlay_uses_current_language(self):
        manager = LocaleManager("zh_CN")
        backend = self.make_backend(manager)
        backend._ring_overlay = Mock()
        with patch("PySide6.QtGui.QCursor.pos", return_value=QPoint(0, 0)):
            backend._handleShowRing(["Copy", "Ctrl+Click"], False)
        self.assertEqual(backend._ring_overlay.show_ring.call_args.args[2], ["复制", "Ctrl＋左击"])
        with patch("ui.backend.save_config"):
            manager.setLanguage("en")
        with patch("PySide6.QtGui.QCursor.pos", return_value=QPoint(0, 0)):
            backend._handleShowRing(["Copy", "Ctrl+Click"], False)
        self.assertEqual(backend._ring_overlay.show_ring.call_args.args[2], ["Copy", "Ctrl+Click"])

    def test_qml_display_bindings_follow_language_without_reloading(self):
        # A GUI-capable application is needed by the QtQml plugin. The rest of
        # the repository's tests may already own a QCoreApplication, so isolate it.
        probe = r"""
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine
from ui.locale_manager import LocaleManager
app = QGuiApplication(["locale-probe", "-platform", "offscreen"])
manager = LocaleManager("en")
engine = QQmlEngine()
engine.rootContext().setContextProperty("lm", manager)
component = QQmlComponent(engine)
component.setData(b'''
import QtQuick
Item {
    property var strings: lm.strings
    property string hapticLabel: strings["haptic.enabled"]
    property string clickLabel: (lm.strings, lm.trAction("Ctrl + Left Click"))
    property string profileLabel: (lm.strings, lm.trProfile("default", "Default (All Apps)"))
}
''', QUrl())
obj = component.create()
assert obj is not None, [e.toString() for e in component.errors()]
assert obj.property("hapticLabel") == "Enable Haptic Feedback"
manager.setLanguage("zh_CN")
app.processEvents()
assert obj.property("hapticLabel") == "\u542f\u7528\u9707\u52a8\u53cd\u9988"
assert obj.property("clickLabel") == "Ctrl\uff0b\u5de6\u952e\u70b9\u51fb"
assert obj.property("profileLabel") == "\u9ed8\u8ba4\uff08\u6240\u6709\u5e94\u7528\uff09"
manager.setLanguage("zh_TW")
app.processEvents()
assert obj.property("hapticLabel") == "\u555f\u7528\u9707\u52d5\u56de\u994b"
manager.setLanguage("en")
app.processEvents()
assert obj.property("clickLabel") == "Ctrl + Left Click"
obj.deleteLater()
app.processEvents()
"""
        result = subprocess.run([sys.executable, "-c", textwrap.dedent(probe)],
                                cwd=ROOT, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()

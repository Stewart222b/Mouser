from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
MAIN_QML = (ROOT / "ui" / "qml" / "Main.qml").read_text(encoding="utf-8")
MOUSE_PAGE_QML = (ROOT / "ui" / "qml" / "MousePage.qml").read_text(
    encoding="utf-8"
)


class MainQmlShortcutGuardTests(unittest.TestCase):
    def test_mouse_page_exposes_blocking_dialog_flag(self):
        self.assertIn("readonly property bool hasBlockingDialog", MOUSE_PAGE_QML)
        self.assertIn("keyCaptureDialog.visible", MOUSE_PAGE_QML)
        self.assertIn("addAppDialog.visible", MOUSE_PAGE_QML)
        self.assertIn("deleteDialog.visible", MOUSE_PAGE_QML)

    def test_g502_os_buttons_use_onboard_editor(self):
        self.assertIn("function saveOnboardForKey", MOUSE_PAGE_QML)
        self.assertIn("onboardHScrollLeftCombo", MOUSE_PAGE_QML)
        self.assertIn("onboardHScrollRightCombo", MOUSE_PAGE_QML)
        self.assertIn('if (key === "g502_left" || key === "g502_right")', MOUSE_PAGE_QML)

    def test_hide_to_tray_shortcuts_are_window_scoped_and_gated(self):
        self.assertIn("readonly property bool shortcutsBlocked", MAIN_QML)
        self.assertIn("mousePageView.hasBlockingDialog", MAIN_QML)
        self.assertEqual(MAIN_QML.count("context: Qt.WindowShortcut"), 3)
        self.assertEqual(
            MAIN_QML.count("enabled: root.visible && !root.shortcutsBlocked"),
            3,
        )


if __name__ == "__main__":
    unittest.main()

"""Source guards for the Windows hook, which cannot be imported off Windows.

Both crash reports in issues #252 and #253 trace to one line: ``dwExtraInfo``
is a ULONG_PTR *value*, but the struct declared it as a pointer and the debug
path read ``.contents``, dereferencing whatever number the sender attached.
Any event carrying a non-zero value killed the process outright -- silently,
with nothing in the log -- whenever debug mode was on.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_HOOK = (ROOT / "core" / "mouse_hook_windows.py").read_text(encoding="utf-8")
KEY_CAPTURE = (ROOT / "core" / "key_capture.py").read_text(encoding="utf-8")


class ExtraInfoIsAValueNotAPointerTests(unittest.TestCase):
    def test_mouse_hook_struct_declares_extra_info_as_a_value(self):
        self.assertIn('("dwExtraInfo", wintypes.WPARAM)', WINDOWS_HOOK)

    def test_key_capture_struct_declares_extra_info_as_a_value(self):
        self.assertIn('("dwExtraInfo", wintypes.WPARAM)', KEY_CAPTURE)

    def test_no_hook_dereferences_extra_info(self):
        for name, source in (
            ("mouse_hook_windows", WINDOWS_HOOK),
            ("key_capture", KEY_CAPTURE),
        ):
            with self.subTest(module=name):
                self.assertNotIn("dwExtraInfo.contents", source)


class DebugLoggingIsRateLimitedTests(unittest.TestCase):
    def test_wheel_bursts_are_coalesced(self):
        # A hi-res wheel emits ~15 messages per detent; one debug line each
        # costs a Qt signal plus a QML list rebuild.
        self.assertIn("_DEBUG_BURST_MESSAGES", WINDOWS_HOOK)
        self.assertIn("def _debug_event_allowed", WINDOWS_HOOK)

    def test_debug_path_skips_mouse_moves_before_formatting(self):
        self.assertIn(
            "if self.debug_mode and self._debug_callback and wParam != WM_MOUSEMOVE:",
            WINDOWS_HOOK,
        )


if __name__ == "__main__":
    unittest.main()

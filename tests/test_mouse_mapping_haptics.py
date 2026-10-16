import copy
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from core.config import DEFAULT_CONFIG
from core.engine import Engine
from tests.test_engine import _FakeMouseHook, _FakeAppDetector


class MouseMappingHapticTests(unittest.TestCase):
    def make_engine(self, enabled=True, mapping="mouse_back_click"):
        bindings = {}
        class Hook(_FakeMouseHook):
            def __init__(self):
                super().__init__()
                self.blocked_events = set()

            def block(self, name):
                self.blocked_events.add(name)

            def register(self, name, callback):
                bindings[name] = callback
        cfg = copy.deepcopy(DEFAULT_CONFIG)
        cfg["settings"]["button_haptic"] = ["middle", "xbutton1", "xbutton2"] if enabled else []
        cfg["profiles"]["default"]["mappings"].update(xbutton1=mapping, xbutton2="mouse_forward_click")
        with (patch("core.engine.MouseHook", Hook),
              patch("core.engine.AppDetector", _FakeAppDetector),
              patch("core.engine.load_config", return_value=cfg)):
            engine = Engine()
        return engine, bindings

    def test_back_and_forward_vibrate_once_on_press_not_release(self):
        engine, bindings = self.make_engine()
        for button, action in (("xbutton1", "mouse_back_click"), ("xbutton2", "mouse_forward_click")):
            with self.subTest(button=button), patch.object(engine, "_play_haptic_async") as haptic, \
                 patch("core.engine.inject_mouse_down") as down, patch("core.engine.inject_mouse_up") as up, \
                 patch("core.engine.threading.Timer"):
                bindings[button+"_down"](SimpleNamespace(event_type=button+"_down"))
                down.assert_called_once_with(action)
                up.assert_not_called()
                bindings[button+"_up"](SimpleNamespace(event_type=button+"_up"))
                up.assert_called_once_with(action)
                haptic.assert_called_once_with(1, immediate=True)

    def test_button_switch_off_still_injects_mouse_without_haptic(self):
        engine, bindings = self.make_engine(enabled=False)
        with patch.object(engine, "_play_haptic_async") as haptic, patch("core.engine.inject_mouse_down") as down, patch("core.engine.threading.Timer"):
            bindings["xbutton1_down"](SimpleNamespace(event_type="xbutton1_down"))
        down.assert_called_once_with("mouse_back_click")
        haptic.assert_not_called()

    def test_master_haptic_switch_off_blocks_device_write(self):
        engine, _ = self.make_engine()
        engine.cfg["settings"]["haptic_enabled"] = False
        engine.hook._hid_gesture = Mock(haptic_supported=True)
        engine._play_haptic_async(1, immediate=True)
        engine.hook._hid_gesture.play_haptic_immediate.assert_not_called()

    def test_enabled_pass_through_button_is_observed_without_consuming(self):
        engine, bindings = self.make_engine(mapping="none")
        with patch.object(engine, "_play_haptic_async") as haptic, patch("core.engine.inject_mouse_down") as down:
            bindings["xbutton1_down"](SimpleNamespace(event_type="xbutton1_down"))
        down.assert_not_called()
        haptic.assert_called_once_with(1, immediate=True)

    def test_middle_press_sends_directly_without_blocking_native_click(self):
        engine, bindings = self.make_engine()
        device = Mock(haptic_supported=True)
        engine.hook._hid_gesture = device
        with patch("core.engine.inject_mouse_down") as down, patch("core.engine.inject_mouse_up") as up:
            bindings["middle_down"](SimpleNamespace(event_type="middle_down"))
        device.play_haptic_immediate.assert_called_once_with(1)
        device.queue_haptic_waveform.assert_not_called()
        down.assert_not_called()
        up.assert_not_called()
        self.assertNotIn("middle_down", engine.hook.blocked_events)
        self.assertNotIn("middle_up", engine.hook.blocked_events)
        self.assertNotIn("middle_up", bindings)

    def test_middle_haptic_switch_off_leaves_native_click_unobserved(self):
        engine, bindings = self.make_engine(enabled=False)
        self.assertNotIn("middle_down", bindings)
        self.assertNotIn("middle_up", bindings)
        self.assertNotIn("middle_down", engine.hook.blocked_events)
        self.assertNotIn("middle_up", engine.hook.blocked_events)

    def test_disabled_engine_does_not_inject_or_vibrate(self):
        engine, bindings = self.make_engine()
        engine._enabled = False
        with patch.object(engine, "_play_haptic_async") as haptic, patch("core.engine.inject_mouse_down") as down:
            bindings["xbutton1_down"](SimpleNamespace(event_type="xbutton1_down"))
        down.assert_not_called()
        haptic.assert_not_called()

    def test_ui_toggle_refreshes_pass_through_observers(self):
        from tests.test_backend import BackendDeviceLayoutTests
        engine = Mock(device_connected=False, connected_device=None, hid_features_ready=False, smart_shift_supported=False)
        backend = BackendDeviceLayoutTests()._make_backend(engine=None)
        backend._engine = engine
        with patch("ui.backend.save_config"), patch("core.config.save_config"):
            backend.setButtonHaptic("xbutton1", True)
        self.assertIn("xbutton1", engine.cfg["settings"]["button_haptic"])
        engine.reload_mappings.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()

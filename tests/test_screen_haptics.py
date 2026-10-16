import copy
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from core.config import DEFAULT_CONFIG
from core.screen_haptics import ScreenTransitionTracker
from tests import test_mouse_mapping_haptics as mouse_mapping_tests


LAYOUT = (("left", (-1920, 0, 1920, 1080)), ("right", (0, 0, 2560, 1440)))


class ScreenTransitionTests(unittest.TestCase):
    def test_first_sample_and_same_screen_are_silent(self):
        tracker = ScreenTransitionTracker()
        self.assertFalse(tracker.observe("left", LAYOUT, 0.0))
        self.assertFalse(tracker.observe("left", LAYOUT, 1.0))

    def test_crossing_in_either_direction_fires_once(self):
        tracker = ScreenTransitionTracker()
        tracker.observe("left", LAYOUT, 0.0)
        self.assertTrue(tracker.observe("right", LAYOUT, 0.01))
        self.assertFalse(tracker.observe("right", LAYOUT, 0.5))
        self.assertTrue(tracker.observe("left", LAYOUT, 1.0))

    def test_boundary_chatter_is_dropped_without_a_delayed_pulse(self):
        tracker = ScreenTransitionTracker()
        tracker.observe("left", LAYOUT, 0.0)
        self.assertTrue(tracker.observe("right", LAYOUT, 0.01))
        self.assertFalse(tracker.observe("left", LAYOUT, 0.05))
        self.assertFalse(tracker.observe("right", LAYOUT, 0.1))
        self.assertFalse(tracker.observe("right", LAYOUT, 1.0))
        self.assertTrue(tracker.observe("left", LAYOUT, 1.1))

    def test_changed_topology_establishes_a_new_baseline(self):
        tracker = ScreenTransitionTracker()
        tracker.observe("left", LAYOUT, 0.0)
        changed = (("right", (0, -1440, 2560, 1440)), ("left", (0, 0, 1920, 1080)))
        self.assertFalse(tracker.observe("right", changed, 1.0))
        self.assertTrue(tracker.observe("left", changed, 2.0))

    def test_unmapped_gap_does_not_make_a_phantom_crossing(self):
        tracker = ScreenTransitionTracker()
        tracker.observe("left", LAYOUT, 0.0)
        self.assertFalse(tracker.observe(None, LAYOUT, 0.1))
        self.assertFalse(tracker.observe("right", LAYOUT, 0.2))
        self.assertTrue(tracker.observe("left", LAYOUT, 1.0))

    def test_reset_after_pause_or_reconnect_is_silent(self):
        tracker = ScreenTransitionTracker()
        tracker.observe("left", LAYOUT, 0.0)
        tracker.reset()
        self.assertFalse(tracker.observe("right", LAYOUT, 1.0))
        self.assertTrue(tracker.observe("left", LAYOUT, 2.0))


class ScreenHapticEngineTests(unittest.TestCase):
    def make_engine(self):
        engine, _ = mouse_mapping_tests.MouseMappingHapticTests().make_engine()
        engine.cfg["settings"]["screen_switch_haptic"] = True
        engine.hook._hid_gesture = Mock(haptic_supported=True)
        return engine

    def test_screen_feedback_uses_immediate_device_write(self):
        engine = self.make_engine()
        engine.play_screen_switch_haptic()
        engine.hook._hid_gesture.play_haptic_immediate.assert_called_once_with(1)
        engine.hook._hid_gesture.queue_haptic_waveform.assert_not_called()

    def test_off_paused_and_unsupported_devices_stay_silent(self):
        for mode in ("feature_off", "global_off", "paused", "unsupported"):
            with self.subTest(mode=mode):
                engine = self.make_engine()
                if mode == "feature_off":
                    engine.cfg["settings"]["screen_switch_haptic"] = False
                elif mode == "global_off":
                    engine.cfg["settings"]["haptic_enabled"] = False
                elif mode == "paused":
                    engine._enabled = False
                else:
                    engine.hook._hid_gesture.haptic_supported = False
                engine.play_screen_switch_haptic()
                engine.hook._hid_gesture.play_haptic_immediate.assert_not_called()
                engine.hook._hid_gesture.queue_haptic_waveform.assert_not_called()

    def test_feature_is_opt_in(self):
        self.assertIs(DEFAULT_CONFIG["settings"]["screen_switch_haptic"], False)


class ScreenHapticBackendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from tests.test_backend import _ensure_qapp
        cls.app = _ensure_qapp()

    def setUp(self):
        from tests.test_backend import BackendDeviceLayoutTests
        self.platform_patch = patch("ui.backend.sys.platform", "win32")
        self.platform_patch.start()
        self.addCleanup(self.platform_patch.stop)
        self.backend = BackendDeviceLayoutTests()._make_backend()
        self.addCleanup(self.backend._screen_haptic_timer.stop)
        self.engine = SimpleNamespace(haptic_supported=True, enabled=True, play_screen_switch_haptic=Mock())
        self.backend._engine = self.engine
        self.backend._mouse_connected = True
        self.backend._hid_features_ready = True
        self.backend._cfg["settings"]["screen_switch_haptic"] = True

    def test_observed_crossings_dispatch_without_waiting_for_button_input(self):
        with patch("ui.backend._screen_haptic_snapshot", side_effect=[
            ("left", LAYOUT), ("right", LAYOUT), ("right", LAYOUT), ("left", LAYOUT),
        ]), patch("ui.backend.time.monotonic", side_effect=[0.0, 0.02, 0.1, 0.4]):
            for _ in range(4):
                self.backend._pollScreenHaptic()
        self.assertEqual(self.engine.play_screen_switch_haptic.call_count, 2)

    def test_pause_does_not_accumulate_a_crossing_for_resume(self):
        with patch("ui.backend._screen_haptic_snapshot", side_effect=[
            ("left", LAYOUT), ("right", LAYOUT), ("left", LAYOUT),
        ]), patch("ui.backend.time.monotonic", side_effect=[0.0, 1.0, 2.0]):
            self.backend._pollScreenHaptic()
            self.engine.enabled = False
            self.backend._pollScreenHaptic()
            self.engine.enabled = True
            self.backend._pollScreenHaptic()
            self.engine.play_screen_switch_haptic.assert_not_called()
            self.backend._pollScreenHaptic()
        self.engine.play_screen_switch_haptic.assert_called_once_with()

    def test_toggle_persists_only_the_new_setting_and_stops_the_timer(self):
        before = copy.deepcopy(self.backend._cfg)
        with patch("ui.backend.save_config") as save:
            self.backend.setScreenSwitchHaptic(True)
            self.assertTrue(self.backend._screen_haptic_timer.isActive())
            self.backend.setScreenSwitchHaptic(False)
        self.assertFalse(self.backend._screen_haptic_timer.isActive())
        before["settings"]["screen_switch_haptic"] = False
        self.assertEqual(self.backend._cfg, before)
        self.assertEqual(save.call_count, 2)
        self.assertIs(self.engine.cfg, self.backend._cfg)

    def test_global_off_and_device_disconnect_stop_polling(self):
        self.backend._configureScreenHaptics()
        self.assertTrue(self.backend._screen_haptic_timer.isActive())
        with patch("ui.backend.save_config"):
            self.backend.setHapticEnabled(False)
            self.assertFalse(self.backend._screen_haptic_timer.isActive())
            self.backend.setHapticEnabled(True)
        # The capability flag can outlive the disconnected HID handle.
        self.backend._hid_features_ready = False
        self.backend.hidFeaturesReadyChanged.emit()
        self.assertFalse(self.backend._screen_haptic_timer.isActive())
        with patch("ui.backend._screen_haptic_snapshot") as snapshot:
            self.backend._pollScreenHaptic()
        snapshot.assert_not_called()

    def test_unsupported_platform_does_not_poll(self):
        with patch("ui.backend.sys.platform", "linux"), patch("ui.backend._screen_haptic_snapshot") as snapshot:
            self.backend._configureScreenHaptics()
            self.backend._pollScreenHaptic()
        snapshot.assert_not_called()
        self.assertFalse(self.backend._screen_haptic_timer.isActive())

    def test_display_disappearing_during_read_resets_the_baseline(self):
        with patch("ui.backend._screen_haptic_snapshot", side_effect=[
            ("left", LAYOUT), RuntimeError("screen removed"), ("right", LAYOUT),
        ]):
            for _ in range(3):
                self.backend._pollScreenHaptic()
        self.engine.play_screen_switch_haptic.assert_not_called()


if __name__ == "__main__":
    unittest.main()

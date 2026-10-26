import copy
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

from core.config import DEFAULT_CONFIG
from core.mouse_hook import MouseEvent
from core.mouse_hook_types import HidRuntimeState


class _FakeMouseHook:
    def __init__(self):
        self.invert_vscroll = False
        self.invert_hscroll = False
        self.debug_mode = False
        self.connected_device = None
        self.device_connected = False
        self._hid_gesture = None
        self.start_called = False
        self.stop_called = False
        self.wheel_native_invert_active = False
        # Back-compat alias mirrored on the real BaseMouseHook for callers
        # from the divert+inject build of the test fixtures.
        self.wheel_divert_active = False

    def set_debug_callback(self, cb):
        self._debug_callback = cb

    def set_gesture_callback(self, cb):
        self._gesture_callback = cb

    def set_status_callback(self, cb):
        self._status_callback = cb

    def set_connection_change_callback(self, cb):
        self._connection_change_callback = cb

    def set_battery_notify_callback(self, cb):
        self._battery_notify_callback = cb

    def configure_gestures(self, **kwargs):
        self._gesture_config = kwargs

    def configure_wheel_multipliers(self, vertical, horizontal):
        # Retained for shape compatibility; real BaseMouseHook accepts but
        # no-ops the call in native-invert mode.
        return None

    def block(self, event_type):
        pass

    def register(self, event_type, callback):
        pass

    def reset_bindings(self):
        pass

    def start(self):
        self.start_called = True

    def stop(self):
        self.stop_called = True


class _FakeAppDetector:
    def __init__(self, callback):
        self.callback = callback
        self.start_called = False
        self.stop_called = False

    def start(self):
        self.start_called = True

    def stop(self):
        self.stop_called = True


class _ImmediateThread:
    def __init__(self, target=None, args=(), kwargs=None, **_):
        self._target = target
        self._args = args
        self._kwargs = kwargs or {}

    def start(self):
        if self._target:
            self._target(*self._args, **self._kwargs)


class _RecordedThread:
    def __init__(self, target=None, args=(), kwargs=None, name=None, **_):
        self._target = target
        self._args = args
        self._kwargs = kwargs or {}
        self.name = name
        self.start_called = False
        self.join = Mock()

    def start(self):
        self.start_called = True

    def run_target(self):
        if self._target:
            return self._target(*self._args, **self._kwargs)
        return None


class EngineHorizontalScrollTests(unittest.TestCase):
    def _make_engine(self, hscroll_threshold=1):
        from core.engine import Engine

        cfg = copy.deepcopy(DEFAULT_CONFIG)
        if hscroll_threshold is not None:
            cfg["settings"]["hscroll_threshold"] = hscroll_threshold

        with (
            patch("core.engine.MouseHook", _FakeMouseHook),
            patch("core.engine.AppDetector", _FakeAppDetector),
            patch("core.engine.load_config", return_value=cfg),
        ):
            return Engine()

    def test_hscroll_desktop_action_uses_cooldown(self):
        engine = self._make_engine()
        handler = engine._make_hscroll_handler("space_left")

        with patch("core.engine.execute_action") as execute_action_mock:
            handler(SimpleNamespace(
                event_type=MouseEvent.HSCROLL_LEFT,
                raw_data=1,
                timestamp=1.00,
            ))
            handler(SimpleNamespace(
                event_type=MouseEvent.HSCROLL_LEFT,
                raw_data=1,
                timestamp=1.05,
            ))
            handler(SimpleNamespace(
                event_type=MouseEvent.HSCROLL_LEFT,
                raw_data=1,
                timestamp=1.45,
            ))

        self.assertEqual(execute_action_mock.call_count, 2)

    def test_hscroll_accumulates_fractional_mac_deltas(self):
        engine = self._make_engine()
        handler = engine._make_hscroll_handler("space_right")

        with patch("core.engine.execute_action") as execute_action_mock:
            handler(SimpleNamespace(
                event_type=MouseEvent.HSCROLL_RIGHT,
                raw_data=0.35,
                timestamp=2.00,
            ))
            handler(SimpleNamespace(
                event_type=MouseEvent.HSCROLL_RIGHT,
                raw_data=0.40,
                timestamp=2.02,
            ))
            handler(SimpleNamespace(
                event_type=MouseEvent.HSCROLL_RIGHT,
                raw_data=0.30,
                timestamp=2.04,
            ))

        self.assertEqual(execute_action_mock.call_count, 1)

    def test_default_hscroll_threshold_handles_m720_fractional_delta(self):
        engine = self._make_engine(hscroll_threshold=None)
        handler = engine._make_hscroll_handler("space_right")

        with patch("core.engine.execute_action") as execute_action_mock:
            handler(SimpleNamespace(
                event_type=MouseEvent.HSCROLL_RIGHT,
                raw_data=0.100006103515625,
                timestamp=3.00,
            ))

        self.assertEqual(execute_action_mock.call_count, 1)

    def test_connection_callback_receives_current_state_immediately(self):
        engine = self._make_engine()
        engine.hook.device_connected = True

        seen = []
        engine.set_connection_change_callback(seen.append)

        self.assertEqual(seen, [True])

    def test_connection_callback_prefers_device_connected_flag_over_stale_identity(self):
        engine = self._make_engine()
        engine.hook.device_connected = False
        engine.hook.connected_device = SimpleNamespace(name="MX Master 3S")

        seen = []
        engine.set_connection_change_callback(seen.append)

        self.assertEqual(seen, [False])

    def test_hid_features_ready_requires_hid_identity(self):
        engine = self._make_engine()

        self.assertFalse(engine.hid_features_ready)

        engine.hook._hid_gesture = SimpleNamespace(connected_device=None)
        self.assertFalse(engine.hid_features_ready)

        engine.hook._hid_gesture = SimpleNamespace(
            connected_device=SimpleNamespace(name="MX Master 3S")
        )
        self.assertTrue(engine.hid_features_ready)

    def test_engine_projection_prefers_hid_runtime_state(self):
        engine = self._make_engine()
        device = SimpleNamespace(name="MX Master 3S")
        engine.hook.device_connected = False
        engine.hook.connected_device = SimpleNamespace(name="stale fallback")
        engine.hook._hid_gesture = None
        engine.hook.hid_runtime_state = HidRuntimeState(
            input_ready=True,
            hid_ready=True,
            connected_device=device,
        )

        seen = []
        engine.set_connection_change_callback(seen.append)

        self.assertTrue(engine.device_connected)
        self.assertIs(engine.connected_device, device)
        self.assertTrue(engine.hid_features_ready)
        self.assertEqual(seen, [True])

    def test_duplicate_connected_refresh_does_not_restart_battery_poller(self):
        engine = self._make_engine()
        seen = []
        engine.set_connection_change_callback(seen.append)
        engine.hook._hid_gesture = SimpleNamespace(connected_device=None)
        thread_instances = []

        def fake_thread(*args, **kwargs):
            thread = _RecordedThread(*args, **kwargs)
            thread_instances.append(thread)
            return thread

        with patch("core.engine.threading.Thread", side_effect=fake_thread):
            engine._on_connection_change(True)
            battery_threads = [
                thread for thread in thread_instances if thread.name == "BatteryPoll"
            ]
            self.assertEqual(len(battery_threads), 1)
            first_thread = battery_threads[0]

            engine.hook._hid_gesture = SimpleNamespace(
                connected_device=SimpleNamespace(name="MX Master 3S")
            )
            engine._on_connection_change(True)

        self.assertEqual(seen, [False, True, True])
        battery_threads = [
            thread for thread in thread_instances if thread.name == "BatteryPoll"
        ]
        self.assertEqual(len(battery_threads), 1)
        first_thread.join.assert_not_called()
        self.assertIs(engine._battery_poll_thread, first_thread)

    def test_start_applies_saved_dpi_without_reading_device_dpi(self):
        engine = self._make_engine()
        engine.hook._hid_gesture = SimpleNamespace(
            connected_device=SimpleNamespace(name="MX Master 3S"),
            set_dpi=Mock(return_value=True),
            read_dpi=Mock(),
            smart_shift_supported=False,
        )
        seen = []
        engine.set_dpi_read_callback(seen.append)

        with (
            patch("core.engine.threading.Thread", _ImmediateThread),
            patch("time.sleep", return_value=None),
        ):
            engine.start()

        expected = engine.cfg["settings"]["dpi"]
        engine.hook._hid_gesture.set_dpi.assert_called_once_with(expected)
        engine.hook._hid_gesture.read_dpi.assert_not_called()
        self.assertEqual(seen, [expected])
        self.assertTrue(engine.hook.start_called)
        self.assertTrue(engine._app_detector.start_called)


class EngineReplayPhaseOneTests(unittest.TestCase):
    def _make_engine(self):
        from core.engine import Engine

        cfg = copy.deepcopy(DEFAULT_CONFIG)

        with (
            patch("core.engine.MouseHook", _FakeMouseHook),
            patch("core.engine.AppDetector", _FakeAppDetector),
            patch("core.engine.load_config", return_value=cfg),
        ):
            return Engine()

    @staticmethod
    def _thread_factory(instances):
        def factory(*args, **kwargs):
            thread = _RecordedThread(*args, **kwargs)
            instances.append(thread)
            return thread

        return factory

    @staticmethod
    def _non_battery_threads(instances):
        return [thread for thread in instances if thread.name != "BatteryPoll"]

    def _make_hid(self, *, connected_device=None, dpi_result=True, smart_shift_result=True):
        return SimpleNamespace(
            connected_device=connected_device,
            read_battery=Mock(return_value=None),
            set_dpi=Mock(return_value=dpi_result),
            set_smart_shift=Mock(return_value=smart_shift_result),
            smart_shift_supported=True,
        )

    def test_hid_ready_transition_requests_replay_worker(self):
        engine = self._make_engine()
        engine.hook._hid_gesture = self._make_hid(connected_device=None)
        threads = []

        with patch("core.engine.threading.Thread", side_effect=self._thread_factory(threads)):
            engine._on_connection_change(True)
            self.assertEqual(len(threads), 1)
            self.assertEqual(self._non_battery_threads(threads), [])
            engine.hook._hid_gesture.set_dpi.assert_not_called()
            engine.hook._hid_gesture.set_smart_shift.assert_not_called()

            engine.hook._hid_gesture.connected_device = SimpleNamespace(name="MX Master 3S")
            engine._on_connection_change(True)

        expected_dpi = engine.cfg["settings"]["dpi"]
        expected_ss_mode = engine.cfg["settings"]["smart_shift_mode"]
        expected_ss_enabled = engine.cfg["settings"]["smart_shift_enabled"]
        expected_ss_threshold = engine.cfg["settings"]["smart_shift_threshold"]
        expected_ss_scroll_force = engine.cfg["settings"]["scroll_force"]
        replay_threads = self._non_battery_threads(threads)
        self.assertEqual(len(replay_threads), 1)
        replay_threads[0].run_target()
        engine.hook._hid_gesture.set_dpi.assert_called_once_with(expected_dpi)
        self.assertEqual(engine.hook._hid_gesture.set_smart_shift.call_count, 2)
        engine.hook._hid_gesture.set_smart_shift.assert_called_with(
            expected_ss_mode, expected_ss_enabled, expected_ss_threshold, expected_ss_scroll_force
        )

    def test_live_reconnect_replay_restores_saved_values_through_worker(self):
        engine = self._make_engine()
        engine.hook._hid_gesture = self._make_hid(connected_device=None)
        threads = []
        seen_dpi = []
        seen_smart_shift = []
        engine.set_dpi_read_callback(seen_dpi.append)
        engine.set_smart_shift_read_callback(seen_smart_shift.append)

        with patch("core.engine.threading.Thread", side_effect=self._thread_factory(threads)):
            engine._on_connection_change(True)
            engine.hook._hid_gesture.connected_device = SimpleNamespace(name="MX Master 3S")
            engine._on_connection_change(True)

        replay_threads = self._non_battery_threads(threads)
        self.assertEqual(len(replay_threads), 1)
        replay_threads[0].run_target()

        self.assertEqual(seen_dpi, [engine.cfg["settings"]["dpi"]])
        self.assertGreaterEqual(len(seen_smart_shift), 2)
        self.assertEqual(
            seen_smart_shift[-1],
            {
                "mode": engine.cfg["settings"]["smart_shift_mode"],
                "enabled": engine.cfg["settings"]["smart_shift_enabled"],
                "threshold": engine.cfg["settings"]["smart_shift_threshold"],
                "scroll_force": engine.cfg["settings"]["scroll_force"],
            },
        )

    def test_evdev_only_connected_true_does_not_request_replay_worker(self):
        engine = self._make_engine()
        engine.hook.connected_device = SimpleNamespace(name="MX Master 3S", source="evdev")
        engine.hook._hid_gesture = self._make_hid(connected_device=None)
        threads = []

        with patch("core.engine.threading.Thread", side_effect=self._thread_factory(threads)):
            engine._on_connection_change(True)
            engine._on_connection_change(True)

        self.assertEqual(len(threads), 1)
        self.assertEqual(self._non_battery_threads(threads), [])
        engine.hook._hid_gesture.set_dpi.assert_not_called()
        engine.hook._hid_gesture.set_smart_shift.assert_not_called()

    def test_duplicate_same_value_refresh_does_not_create_duplicate_replay_workers(self):
        engine = self._make_engine()
        engine.hook._hid_gesture = self._make_hid(connected_device=None)
        threads = []

        with patch("core.engine.threading.Thread", side_effect=self._thread_factory(threads)):
            engine._on_connection_change(True)

            engine.hook._hid_gesture.connected_device = SimpleNamespace(name="MX Master 3S")
            engine._on_connection_change(True)
            first_replay_threads = list(self._non_battery_threads(threads))

            engine._on_connection_change(True)

        self.assertEqual(len(first_replay_threads), 1)
        self.assertEqual(self._non_battery_threads(threads), first_replay_threads)

    def test_hid_disconnect_while_evdev_connected_allows_next_hid_replay(self):
        engine = self._make_engine()
        engine.hook.connected_device = SimpleNamespace(name="MX Master 3S", source="evdev")
        engine.hook._hid_gesture = self._make_hid(
            connected_device=SimpleNamespace(name="MX Master 3S")
        )
        threads = []

        with patch("core.engine.threading.Thread", side_effect=self._thread_factory(threads)):
            engine._on_connection_change(True)
            self.assertEqual(len(self._non_battery_threads(threads)), 1)
            self._non_battery_threads(threads)[0].run_target()

            engine.hook._hid_gesture.connected_device = None
            engine._on_connection_change(True)
            self.assertEqual(len(self._non_battery_threads(threads)), 1)

            engine.hook._hid_gesture.connected_device = SimpleNamespace(name="MX Master 3S")
            engine._on_connection_change(True)

        self.assertEqual(len(self._non_battery_threads(threads)), 2)

    def test_hid_disconnect_updates_last_hid_ready_without_connection_edge(self):
        engine = self._make_engine()
        engine.hook.connected_device = SimpleNamespace(name="MX Master 3S", source="evdev")
        engine.hook._hid_gesture = self._make_hid(
            connected_device=SimpleNamespace(name="MX Master 3S")
        )

        with patch("core.engine.threading.Thread", side_effect=self._thread_factory([])):
            engine._on_connection_change(True)
        self.assertTrue(engine._last_hid_features_ready)

        engine.hook._hid_gesture.connected_device = None
        engine._on_connection_change(True)

        self.assertFalse(engine._last_hid_features_ready)

    def test_startup_fallback_does_not_queue_replay_after_hid_ready_replay_requested(self):
        engine = self._make_engine()
        engine.hook._hid_gesture = self._make_hid(connected_device=None)
        threads = []

        with (
            patch("core.engine.threading.Thread", side_effect=self._thread_factory(threads)),
            patch("core.engine.time.sleep", return_value=None),
        ):
            engine.start()
            startup_threads = list(self._non_battery_threads(threads))
            self.assertEqual(len(startup_threads), 1)

            engine._on_connection_change(True)
            engine.hook._hid_gesture.connected_device = SimpleNamespace(name="MX Master 3S")
            engine._on_connection_change(True)

        non_battery_before_fallback = list(self._non_battery_threads(threads))
        self.assertEqual(len(non_battery_before_fallback), 2)
        replay_threads = [
            thread for thread in non_battery_before_fallback
            if thread not in startup_threads
        ]
        self.assertEqual(len(replay_threads), 1)
        replay_threads[0].run_target()

        self.assertEqual(engine.hook._hid_gesture.set_dpi.call_count, 1)
        self.assertEqual(engine.hook._hid_gesture.set_smart_shift.call_count, 2)

        startup_threads[0].run_target()

        expected_dpi = engine.cfg["settings"]["dpi"]
        expected_ss_mode = engine.cfg["settings"]["smart_shift_mode"]
        expected_ss_enabled = engine.cfg["settings"]["smart_shift_enabled"]
        expected_ss_threshold = engine.cfg["settings"]["smart_shift_threshold"]
        expected_ss_scroll_force = engine.cfg["settings"]["scroll_force"]
        engine.hook._hid_gesture.set_dpi.assert_called_once_with(expected_dpi)
        self.assertEqual(engine.hook._hid_gesture.set_smart_shift.call_count, 2)
        engine.hook._hid_gesture.set_smart_shift.assert_called_with(
            expected_ss_mode, expected_ss_enabled, expected_ss_threshold, expected_ss_scroll_force
        )

    def test_replay_failure_emits_engine_status_callback(self):
        engine = self._make_engine()
        status_messages = []
        engine.set_status_callback(status_messages.append)
        engine.hook._hid_gesture = self._make_hid(
            connected_device=None,
            dpi_result=False,
            smart_shift_result=True,
        )
        threads = []

        with patch("core.engine.threading.Thread", side_effect=self._thread_factory(threads)):
            engine._on_connection_change(True)
            engine.hook._hid_gesture.connected_device = SimpleNamespace(name="MX Master 3S")
            engine._on_connection_change(True)

        replay_threads = self._non_battery_threads(threads)
        self.assertEqual(len(replay_threads), 1)
        replay_threads[0].run_target()

        self.assertTrue(status_messages)
        self.assertTrue(
            any(
                "could not be restored" in message.lower()
                for message in status_messages
            ),
            status_messages,
        )

    def test_battery_poll_skips_smart_shift_reads_while_replay_is_inflight(self):
        engine = self._make_engine()
        engine.set_frontend_visible(True)
        stop_event = Mock()
        stop_event.is_set.return_value = False
        stop_event.wait.return_value = True
        engine._replay_inflight = True
        engine.hook._hid_gesture = SimpleNamespace(
            connected_device=SimpleNamespace(name="MX Master 3S"),
            smart_shift_supported=True,
            read_battery=Mock(return_value=None),
            read_smart_shift=Mock(return_value={"mode": "ratchet", "enabled": False, "threshold": 25}),
        )

        # This case tests replay gating, independently of desktop idle state.
        with patch("core.engine._system_idle_seconds", return_value=0.0):
            engine._battery_poll_loop(stop_event)

        engine.hook._hid_gesture.read_battery.assert_called_once_with()
        engine.hook._hid_gesture.read_smart_shift.assert_not_called()

    def test_battery_poll_skips_background_hid_reads_while_frontend_hidden(self):
        engine = self._make_engine()
        stop_event = Mock()
        stop_event.is_set.return_value = False
        stop_event.wait.return_value = True
        engine.hook._hid_gesture = SimpleNamespace(
            connected_device=SimpleNamespace(name="MX Master 3S"),
            smart_shift_supported=True,
            read_battery=Mock(return_value=None),
            read_smart_shift=Mock(return_value={
                "mode": "ratchet",
                "enabled": False,
                "threshold": 25,
            }),
        )

        engine._battery_poll_loop(stop_event)

        engine.hook._hid_gesture.read_battery.assert_not_called()
        engine.hook._hid_gesture.read_smart_shift.assert_not_called()

    def test_battery_poll_skips_background_hid_reads_while_system_idle(self):
        engine = self._make_engine()
        engine.set_frontend_visible(True)
        stop_event = Mock()
        stop_event.is_set.return_value = False
        stop_event.wait.return_value = True
        engine.hook._hid_gesture = SimpleNamespace(
            connected_device=SimpleNamespace(name="MX Master 3S"),
            smart_shift_supported=True,
            read_battery=Mock(return_value=None),
            read_smart_shift=Mock(return_value={
                "mode": "ratchet",
                "enabled": False,
                "threshold": 25,
            }),
        )

        with patch("core.engine._system_idle_seconds", return_value=120.0):
            engine._battery_poll_loop(stop_event)

        engine.hook._hid_gesture.read_battery.assert_not_called()
        engine.hook._hid_gesture.read_smart_shift.assert_not_called()

    def test_battery_poll_does_not_repeat_without_user_activity_after_poll(self):
        engine = self._make_engine()
        engine.set_frontend_visible(True)
        stop_event = Mock()
        stop_event.is_set.return_value = False
        stop_event.wait.side_effect = [False, False, True]
        engine.hook._hid_gesture = SimpleNamespace(
            connected_device=SimpleNamespace(name="MX Master 3S"),
            smart_shift_supported=True,
            read_battery=Mock(return_value=None),
            read_smart_shift=Mock(return_value=None),
        )

        with (
            patch("core.engine.time.time", side_effect=[
                0.0, 0.0, 0.0, 5.0, 300.0, 300.0,
            ]),
            patch("core.engine._system_idle_seconds", side_effect=[
                0.0, 0.0, 300.0,
            ]),
        ):
            engine._battery_poll_loop(stop_event)

        engine.hook._hid_gesture.read_battery.assert_called_once_with()
        engine.hook._hid_gesture.read_smart_shift.assert_called_once_with()


class WheelInvertConnectThreadingTests(unittest.TestCase):
    """The native wheel-invert write blocks until the HID listener thread
    services the queued request from its own main loop. Because the connect
    callback runs ON that listener thread, doing the write inline deadlocks
    until the request times out. It must be deferred to a worker instead.
    """

    def _make_engine(self):
        from core.engine import Engine

        cfg = copy.deepcopy(DEFAULT_CONFIG)
        with (
            patch("core.engine.MouseHook", _FakeMouseHook),
            patch("core.engine.AppDetector", _FakeAppDetector),
            patch("core.engine.load_config", return_value=cfg),
        ):
            return Engine()

    def test_setup_hooks_defers_wheel_invert_when_requested(self):
        engine = self._make_engine()
        with patch.object(engine, "_apply_wheel_invert_setting") as apply_mock:
            engine._setup_hooks(defer_wheel_invert=True)
            apply_mock.assert_not_called()
            engine._setup_hooks()
            apply_mock.assert_called_once_with()

    def test_ui_timing_reload_preserves_wheel_and_updates_local_gestures(self):
        engine = self._make_engine()
        cfg = copy.deepcopy(engine.cfg)
        cfg["settings"]["gesture_threshold"] = 95
        with patch("core.engine.load_config", return_value=cfg), \
             patch.object(engine, "_apply_wheel_invert_setting") as apply_mock:
            engine.reload_mappings(defer_wheel_invert=True)
            apply_mock.assert_not_called()
            self.assertEqual(engine.hook._gesture_config["threshold"], 95)
            engine.reload_mappings()
            apply_mock.assert_called_once_with()

    def test_connect_defers_wheel_invert_off_listener_thread(self):
        engine = self._make_engine()
        engine.cfg["settings"]["invert_vscroll"] = True
        device = SimpleNamespace(
            name="MX Master 4",
            has_hires_wheel=True,
            has_thumbwheel=False,
            gesture_via_sense_panel=False,
            supported_buttons=None,
        )
        engine.hook.connected_device = device
        engine.hook.device_connected = True
        engine.hook._hid_gesture = SimpleNamespace(
            connected_device=device,
            request_wheel_native_invert=Mock(return_value=True),
            set_wheel_divert_active_flags=Mock(),
            read_battery=Mock(return_value=None),
            _hires_wheel_idx=0,
            _thumbwheel_idx=None,
        )
        request = engine.hook._hid_gesture.request_wheel_native_invert

        threads = []

        def factory(*args, **kwargs):
            thread = _RecordedThread(*args, **kwargs)
            threads.append(thread)
            return thread

        with patch("core.engine.threading.Thread", side_effect=factory):
            engine._on_connection_change(True)
            # The blocking write must NOT run on the listener (callback) thread.
            request.assert_not_called()

            worker = next(t for t in threads if t.name == "WheelInvertApply")
            self.assertEqual(worker._target, engine._apply_wheel_invert_setting)

            # Once deferred to the worker, the write is applied with the
            # configured invert state.
            worker.run_target()
            request.assert_called_once_with(True, False)


class SettingsLatencyTests(unittest.TestCase):
    def test_haptic_preview_submits_state_then_waveform_without_waiting(self):
        import threading
        from core.hid_gesture import HidGestureListener, FAST_HAPTIC_SW, MY_SW
        for level, intensity in ((0, 25), (1, 50), (2, 75), (3, 100)):
            with self.subTest(level=level):
                listener = HidGestureListener.__new__(HidGestureListener)
                listener._dev = Mock()
                listener._dev_idx = 0xFF
                listener._haptic_idx = 0x25
                listener._tx_lock = threading.RLock()
                listener._request = Mock(side_effect=AssertionError("must not wait for acknowledgement"))
                listener._rx = Mock(side_effect=AssertionError("must not wait for listener"))
                self.assertTrue(listener.set_haptic_level_immediate(level, waveform_id=0))
                packets = [c.args[0] for c in listener._dev.write.call_args_list]
                self.assertEqual(len(packets), 2)
                self.assertEqual(packets[0][2:6], [0x25, 0x20 | FAST_HAPTIC_SW, 1, intensity])
                self.assertEqual(packets[1][2:5], [0x25, 0x40 | FAST_HAPTIC_SW, 0])
                self.assertNotEqual(FAST_HAPTIC_SW, MY_SW)
                listener._request.assert_not_called()
                listener._rx.assert_not_called()

    def test_haptic_preview_failed_state_write_does_not_send_waveform(self):
        import threading
        from core.hid_gesture import HidGestureListener
        listener = HidGestureListener.__new__(HidGestureListener)
        listener._dev = Mock()
        listener._dev.write.side_effect = OSError("disconnected")
        listener._dev_idx = 0xFF
        listener._haptic_idx = 0x25
        listener._tx_lock = threading.RLock()
        self.assertFalse(listener.set_haptic_level_immediate(0, waveform_id=0))
        self.assertEqual(listener._dev.write.call_count, 1)

    def test_fast_preview_reply_cannot_complete_a_queued_request(self):
        from core.hid_gesture import HidGestureListener, FAST_HAPTIC_SW, MY_SW, LONG_ID
        listener = HidGestureListener.__new__(HidGestureListener)
        listener._connected = False
        listener._consecutive_request_timeouts = 0
        listener._tx = Mock()
        fast = [LONG_ID, 0xFF, 0x25, 0x20 | FAST_HAPTIC_SW, 1, 25] + [0] * 14
        expected = [LONG_ID, 0xFF, 0x25, 0x20 | MY_SW, 1, 50] + [0] * 14
        listener._rx = Mock(side_effect=[fast, expected])
        listener._on_report = Mock()
        result = listener._request(0x25, 2, [1, 50])
        self.assertEqual(result[3], MY_SW)
        listener._on_report.assert_called_once_with(fast)

    def test_engine_preview_honors_master_switch_without_queued_commands(self):
        from core.engine import Engine
        engine = Engine.__new__(Engine)
        engine.cfg = copy.deepcopy(DEFAULT_CONFIG)
        device = Mock(haptic_supported=True)
        device.set_haptic_level_immediate.return_value = True
        engine.hook = SimpleNamespace(_hid_gesture=device)
        with patch("core.engine.save_config") as save:
            self.assertTrue(engine.preview_haptic_level(0))
            device.set_haptic_level_immediate.assert_called_once_with(0, waveform_id=0)
            engine.cfg["settings"]["haptic_enabled"] = False
            engine.preview_haptic_level(1)
            device.set_haptic_level_immediate.assert_called_with(1, waveform_id=None)
            save.assert_not_called()
        device.set_haptic_level.assert_not_called()
        device.play_haptic_waveform.assert_not_called()

    def test_dpi_hardware_write_does_not_replace_ui_preference_or_save_twice(self):
        from core.engine import Engine
        engine = Engine.__new__(Engine)
        engine.cfg = copy.deepcopy(DEFAULT_CONFIG)
        before = copy.deepcopy(engine.cfg)
        device = Mock()
        engine.hook = SimpleNamespace(_hid_gesture=device)
        with patch.object(Engine, "_hid_runtime_state", return_value=SimpleNamespace(connected_device=None)), \
             patch("core.engine.save_config") as save:
            engine.set_dpi(2400, persist=False)
            save.assert_not_called()
        self.assertEqual(engine.cfg, before)
        device.set_dpi.assert_called_once_with(2400)

    def test_background_wheel_and_force_writes_preserve_newer_ui_preferences(self):
        from core.engine import Engine
        engine = Engine.__new__(Engine)
        engine.cfg = copy.deepcopy(DEFAULT_CONFIG)
        before = copy.deepcopy(engine.cfg)
        device = Mock()
        engine.hook = SimpleNamespace(_hid_gesture=device)
        with patch("core.engine.save_config") as save:
            engine.set_smart_shift("freespin", True, 41, 72, persist=False)
            engine.set_force_sensitivity(192, persist=False)
            save.assert_not_called()
        self.assertEqual(engine.cfg, before)
        device.set_smart_shift.assert_called_once_with("freespin", True, 41, 72)
        device.set_force_sensing.assert_called_once_with(192)

    def test_non_ui_wheel_and_force_callers_still_persist_by_default(self):
        from core.engine import Engine
        engine = Engine.__new__(Engine)
        engine.cfg = copy.deepcopy(DEFAULT_CONFIG)
        engine.hook = SimpleNamespace(_hid_gesture=Mock())
        with patch("core.engine.save_config") as save:
            engine.set_smart_shift("freespin", True, 41, 72)
            engine.set_force_sensitivity(192)
            self.assertEqual(save.call_count, 2)
        settings = engine.cfg["settings"]
        self.assertEqual((settings["smart_shift_mode"], settings["smart_shift_enabled"],
                          settings["smart_shift_threshold"], settings["scroll_force"],
                          settings["force_sensitivity"]), ("freespin", True, 41, 72, 192))


if __name__ == "__main__":
    unittest.main()


class G502LegacyMappingTests(unittest.TestCase):
    _make_engine = EngineHorizontalScrollTests._make_engine
    def test_only_plus_suspends_legacy_mappings_without_deleting_config(self):
        engine = self._make_engine()
        cfg = copy.deepcopy(engine.cfg)
        with patch.object(type(engine), 'connected_device', new_callable=unittest.mock.PropertyMock) as device:
            device.return_value = SimpleNamespace(key='g502_x_plus', supported_buttons=('middle','xbutton1'))
            with patch.object(engine.hook, 'register') as register, patch.object(engine.hook, 'block') as block:
                engine._setup_hooks(defer_wheel_invert=True)
                register.assert_not_called()
                block.assert_not_called()
            self.assertEqual(engine.cfg, cfg)
            device.return_value = SimpleNamespace(key='mx_master_4', supported_buttons=('middle','xbutton1'))
            with patch.object(engine.hook, 'register') as register:
                engine._setup_hooks(defer_wheel_invert=True)
                self.assertTrue(register.called)

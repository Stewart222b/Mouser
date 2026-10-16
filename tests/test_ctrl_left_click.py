"""Ctrl+click regression checks: no real desktop input is sent."""
import sys
import copy
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from core import key_simulator as sim


@unittest.skipUnless(sys.platform == "win32", "Windows-only action")
class CtrlLeftClickTests(unittest.TestCase):
    def setUp(self):
        self.batches = []
        self.held = set()
        self.state_patch = patch.object(sim, "_key_is_down", side_effect=lambda vk: vk in self.held)
        self.state_patch.start()
        self.addCleanup(self.state_patch.stop)

    def capture(self, count, events, size):
        self.assertEqual(size, sim.sizeof(sim.INPUT))
        self.batches.append([
            ("key", events[i].union.ki.wVk, events[i].union.ki.dwFlags)
            if events[i].type == sim.INPUT_KEYBOARD
            else ("mouse", events[i].union.mi.dwFlags)
            for i in range(count)
        ])
        return count

    def test_complete_chord_in_one_batch_without_pointer_movement(self):
        with patch.object(sim, "SendInput", side_effect=self.capture):
            self.assertTrue(sim.send_ctrl_left_click())
        self.assertEqual(self.batches, [[
            ("key", sim.VK_CONTROL, 0),
            ("mouse", sim.MOUSEEVENTF_LEFTDOWN),
            ("mouse", sim.MOUSEEVENTF_LEFTUP),
            ("key", sim.VK_CONTROL, sim.KEYEVENTF_KEYUP),
        ]])

    def test_held_ctrl_is_never_released(self):
        self.held.add(sim.VK_CONTROL)
        with patch.object(sim, "SendInput", side_effect=self.capture):
            self.assertTrue(sim.send_ctrl_left_click())
        self.assertEqual(self.batches, [[("mouse", 2), ("mouse", 4)]])

    def test_drag_is_not_interrupted(self):
        self.held.add(0x01)
        with patch.object(sim, "SendInput") as sender:
            self.assertFalse(sim.send_ctrl_left_click())
        sender.assert_not_called()

    def test_partial_chord_releases_only_remaining_inputs(self):
        for accepted, expected in (
            (0, []),
            (1, [("key", sim.VK_CONTROL, sim.KEYEVENTF_KEYUP)]),
            (2, [("mouse", 4), ("key", sim.VK_CONTROL, sim.KEYEVENTF_KEYUP)]),
            (3, [("key", sim.VK_CONTROL, sim.KEYEVENTF_KEYUP)]),
        ):
            with self.subTest(accepted=accepted):
                self.batches.clear()
                def sender(count, events, size):
                    self.capture(count, events, size)
                    return accepted if len(self.batches) == 1 else count
                with patch.object(sim, "SendInput", side_effect=sender):
                    self.assertFalse(sim.send_ctrl_left_click())
                self.assertEqual(self.batches[1:], [expected] if expected else [])

    def test_partial_click_while_ctrl_held_releases_mouse_only(self):
        self.held.add(sim.VK_CONTROL)
        def sender(count, events, size):
            self.capture(count, events, size)
            return 1 if len(self.batches) == 1 else count
        with patch.object(sim, "SendInput", side_effect=sender):
            self.assertFalse(sim.send_ctrl_left_click())
        self.assertEqual(self.batches[-1], [("mouse", 4)])

    def test_exception_attempts_release_and_reports_failure(self):
        def sender(count, events, size):
            self.capture(count, events, size)
            if len(self.batches) == 1:
                raise OSError("injection interrupted")
            return count
        with patch.object(sim, "SendInput", side_effect=sender):
            self.assertFalse(sim.send_ctrl_left_click())
        self.assertEqual(self.batches[-1], [
            ("mouse", 4), ("key", sim.VK_CONTROL, sim.KEYEVENTF_KEYUP),
        ])

    def test_cleanup_failure_does_not_escape(self):
        with patch.object(sim, "SendInput", side_effect=OSError("blocked")):
            self.assertFalse(sim.send_ctrl_left_click())

    def test_action_dispatches_once_and_is_not_a_hold_mapping(self):
        self.assertIn("ctrl_left_click", sim.ACTIONS)
        self.assertFalse(sim.is_mouse_button_action("ctrl_left_click"))
        with patch.object(sim, "send_ctrl_left_click", return_value=True) as click:
            sim.execute_action("ctrl_left_click")
        click.assert_called_once_with()

    def test_sense_panel_executes_on_single_click_not_down_and_up(self):
        from core.config import DEFAULT_CONFIG
        from core.engine import Engine
        from tests.test_engine import _FakeMouseHook, _FakeAppDetector
        bindings = {}
        class Hook(_FakeMouseHook):
            def register(self, name, callback):
                bindings.setdefault(name, []).append(callback)
        cfg = copy.deepcopy(DEFAULT_CONFIG)
        cfg["profiles"]["default"]["mappings"]["actions_ring"] = "ctrl_left_click"
        with (patch("core.engine.MouseHook", Hook),
              patch("core.engine.AppDetector", _FakeAppDetector),
              patch("core.engine.load_config", return_value=cfg)):
            engine = Engine()
        self.assertEqual(len(bindings["sense_click"]), 1)
        self.assertNotIn("sense_button_down", bindings)
        self.assertNotIn("sense_button_up", bindings)
        with patch("core.engine.execute_action") as execute:
            bindings["sense_click"][0](SimpleNamespace(event_type="sense_click", raw_data=None))
        execute.assert_called_once_with("ctrl_left_click")
        self.assertIsNone(engine._ring)


if __name__ == "__main__":
    unittest.main()

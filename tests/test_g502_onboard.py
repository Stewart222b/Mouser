import unittest
import tempfile
import json
from pathlib import Path
from unittest.mock import patch
from core.g502_onboard import G502Onboard

from core.g502_onboard import (
    CONTROLS,
    SOFTWARE_KEYS,
    OnboardError,
    crc,
    decode_action,
    encode_action,
    patch_button,
)


def _profile(actions):
    data = bytearray(128)
    for slot in range(1, 12):
        action = actions.get(slot, "mouse_right_click")
        offset = 32 + (slot - 1) * 4
        data[offset:offset + 4] = encode_action(action)
    data[-2:] = crc(data[:-2])
    return bytes(data)


class G502OnboardCodecTests(unittest.TestCase):
    def test_encode_decode_roundtrip_for_standard_actions(self):
        for action, _label in (
            ("mouse_left_click", "Left click"),
            ("dpi_next", "Next DPI"),
            ("dpi_shift", "DPI Shift"),
            ("profile_cycle", "Cycle onboard profiles"),
            ("disabled", "Disabled"),
        ):
            with self.subTest(action=action):
                encoded = encode_action(action)
                self.assertEqual(len(encoded), 4)
                self.assertEqual(decode_action(encoded)[0], action)

    def test_shortcut_roundtrip(self):
        encoded = encode_action("shortcut:alt+f12")
        action, label = decode_action(encoded)
        self.assertEqual(action, "shortcut:alt+f12")
        self.assertEqual(label, "alt+f12")

    def test_patch_button_rewrites_one_slot_and_crc(self):
        original = _profile({1: "mouse_left_click", 10: "dpi_next"})  # slot 1 keeps left click
        updated = patch_button(original, 10, "dpi_previous")

        self.assertEqual(updated[-2:], crc(updated[:-2]))
        self.assertEqual(decode_action(updated[32:36])[0], "mouse_left_click")
        self.assertEqual(decode_action(updated[32 + 9 * 4:36 + 9 * 4])[0], "dpi_previous")
        self.assertEqual(original[:32], updated[:32])

    def test_patch_button_keeps_a_left_click(self):
        original = _profile({1: "mouse_left_click"})
        with self.assertRaisesRegex(OnboardError, "left click"):
            patch_button(original, 1, "disabled")

    def test_control_table_covers_eleven_slots(self):
        slots = [slot for slot, *_rest in CONTROLS]
        self.assertEqual(slots, list(range(1, 12)))
        self.assertEqual(
            SOFTWARE_KEYS,
            frozenset(("middle", "xbutton1", "xbutton2", "hscroll_left", "hscroll_right")),
        )

    def test_software_keys_are_writable_onboard_slots(self):
        original = _profile({
            1: "mouse_left_click",
            3: "mouse_middle_click",
            4: "mouse_back_click",
            6: "mouse_forward_click",
            7: "wheel_left",
            8: "wheel_right",
        })
        updated = patch_button(original, 3, "copy")
        updated = patch_button(updated, 4, "navigate_back")
        updated = patch_button(updated, 6, "navigate_forward")
        updated = patch_button(updated, 7, "disabled")
        updated = patch_button(updated, 8, "mouse_left_click")

        self.assertEqual(decode_action(updated[32 + 2 * 4:36 + 2 * 4])[0], "copy")
        self.assertEqual(decode_action(updated[32 + 3 * 4:36 + 3 * 4])[0], "navigate_back")
        self.assertEqual(decode_action(updated[32 + 5 * 4:36 + 5 * 4])[0], "navigate_forward")
        self.assertEqual(decode_action(updated[32 + 6 * 4:36 + 6 * 4])[0], "disabled")
        self.assertEqual(decode_action(updated[32 + 7 * 4:36 + 7 * 4])[0], "mouse_left_click")
        self.assertEqual(decode_action(updated[32:36])[0], "mouse_left_click")


if __name__ == "__main__":
    unittest.main()


class SimulatedMouse:
    """In-memory flash only: no HID handles or real device writes."""
    def __init__(self):
        self.meta = dict(mode=1, sector=1, size=255, sectors=3, profiles=1)
        profile = bytearray(255)
        for slot, _key, _name, _view, action in CONTROLS:
            profile[32+(slot-1)*4:36+(slot-1)*4] = encode_action(action)
        profile[-2:] = crc(profile[:-2])
        self.sectors = [bytes(255), bytes(profile), bytes(255)]
        self.writes = []
        self.corrupt = False
        self.change_other = False
        self.stale = False
        self.metadata_calls = 0

    def metadata(self):
        self.metadata_calls += 1
        meta = dict(self.meta)
        if self.stale and self.metadata_calls > 1:
            meta['sector'] = 2
        return meta

    def read_sector(self, sector, size):
        return self.sectors[sector]

    def request(self, function, params=(), timeout=2):
        self.writes.append(function)
        if function == 6:
            self.buffer = bytearray()
        elif function == 7:
            self.buffer.extend(params)
        elif function == 8:
            self.sectors[1] = bytes(self.buffer)
            if self.corrupt:
                self.sectors[1] = bytes(255)
            if self.change_other:
                self.sectors[2] = bytes([1])*255
        return bytes(16)

    def device(self):
        device = G502Onboard.__new__(G502Onboard)
        device.identity = 'test-device'
        device._metadata = self.metadata
        device._read_sector = self.read_sector
        device._request = self.request
        return device


class G502WriteSafetyTests(unittest.TestCase):
    def test_255_byte_write_backs_up_all_sectors_and_preserves_others(self):
        flash = SimulatedMouse()
        before = list(flash.sectors)
        with tempfile.TemporaryDirectory() as root:
            state, backup = flash.device().set_button(4, 'copy', root)
            manifest = json.loads((Path(backup)/'manifest.json').read_text())
            self.assertTrue(manifest['readback_verified'])
            self.assertTrue(manifest['applied'])
            for i, original in enumerate(before):
                self.assertEqual((Path(backup)/f'sector-{i:04x}.bin').read_bytes(), original)
            self.assertEqual(state['buttons'][3]['actionId'], 'copy')
        self.assertEqual(len(flash.sectors[1]), 255)
        self.assertEqual(flash.sectors[0], before[0])
        self.assertEqual(flash.sectors[2], before[2])
        changed = {i for i,(a,b) in enumerate(zip(before[1], flash.sectors[1])) if a != b}
        self.assertTrue(changed <= set(range(44,48)) | {253,254})

    def test_backup_failure_never_begins_a_write(self):
        flash = SimulatedMouse()
        with patch('core.g502_onboard.Path.mkdir', side_effect=PermissionError('denied')):
            with self.assertRaises(PermissionError):
                flash.device().set_button(4, 'copy', 'unused')
        self.assertEqual(flash.writes, [])

    def test_host_mode_rejects_write(self):
        flash = SimulatedMouse()
        flash.meta['mode'] = 2
        with self.assertRaises(OnboardError):
            flash.device().set_button(4, 'copy', 'unused')
        self.assertEqual(flash.writes, [])

    def test_stale_active_profile_rejects_write(self):
        flash = SimulatedMouse()
        flash.stale = True
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(OnboardError, 'changed'):
                flash.device().set_button(4, 'copy', root)
        self.assertEqual(flash.writes, [])

    def test_corrupt_initial_profile_rejects_write(self):
        flash = SimulatedMouse()
        flash.sectors[1] = bytes(255)
        with self.assertRaisesRegex(OnboardError, 'validation'):
            flash.device().set_button(4, 'copy', 'unused')
        self.assertEqual(flash.writes, [])

    def test_failed_readback_retains_unapplied_backup(self):
        for flag in ('corrupt', 'change_other'):
            with self.subTest(flag=flag), tempfile.TemporaryDirectory() as root:
                flash = SimulatedMouse()
                setattr(flash, flag, True)
                with self.assertRaisesRegex(OnboardError, 'backup:'):
                    flash.device().set_button(4, 'copy', root)
                manifest_file = next(Path(root).glob('*/manifest.json'))
                self.assertFalse(json.loads(manifest_file.read_text())['applied'])

    def test_unchanged_action_does_not_backup_or_write(self):
        flash = SimulatedMouse()
        with patch('core.g502_onboard.Path.mkdir') as mkdir:
            state, backup = flash.device().set_button(4, 'mouse_back_click', 'unused')
        mkdir.assert_not_called()
        self.assertEqual(backup, '')
        self.assertEqual(flash.writes, [])

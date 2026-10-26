import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from core.g502_lighting import encode_effect, decode_effect, lighting_state, patch_lighting
from core.g502_onboard import OnboardError, crc
from tests.test_g502_onboard import SimulatedMouse


class LightingCodecTests(unittest.TestCase):
    def profile(self):
        data = bytearray(SimulatedMouse().sectors[1])
        # Preserve unknown indicator effects and an existing factory animation.
        data[208:219] = bytes.fromhex('0111223300000000000000')
        data[230:241] = bytes.fromhex('1000000000000020640000')
        data[252] = 2
        data[-2:] = crc(data[:-2])
        return bytes(data)

    def test_all_supported_effects_round_trip(self):
        for mode in ('off', 'static', 'breathe', 'cycle'):
            with self.subTest(mode=mode):
                wire = encode_effect(dict(mode=mode, color='#12Ab34', periodMs=4000))
                result = decode_effect(wire)
                self.assertEqual(len(wire), 11)
                self.assertEqual(result['mode'], mode)
                if mode in ('static', 'breathe'):
                    self.assertEqual(result['color'], '#12AB34')
                if mode in ('breathe', 'cycle'):
                    self.assertEqual(result['periodMs'], 4000)

    def test_wire_period_offsets_and_intensity(self):
        breathe = encode_effect(dict(mode='breathe', color='#FF0000', periodMs=5000))
        cycle = encode_effect(dict(mode='cycle', periodMs=5000))
        self.assertEqual(breathe[4:6], b'\x13\x88')
        self.assertEqual(breathe[7], 100)
        self.assertEqual(cycle[6:8], b'\x13\x88')
        self.assertEqual(cycle[8], 100)

    def test_each_group_preserves_other_effects_timers_and_buttons(self):
        for key, offset in (('normal', 219), ('idle', 241)):
            with self.subTest(key=key):
                original = self.profile()
                updated = patch_lighting(original, {key:dict(mode='breathe', color='#66AAFF', periodMs=3000)})
                changed = {i for i,(a,b) in enumerate(zip(original,updated)) if a != b}
                self.assertTrue(changed <= set(range(offset,offset+11)) | {252,253,254})
                self.assertEqual(updated[252], 0)
                self.assertEqual(updated[-2:], crc(updated[:-2]))
                self.assertEqual(updated[:208], original[:208])
                self.assertEqual(updated[208:219], original[208:219])
                self.assertEqual(updated[230:241], original[230:241])

    def test_unknown_effect_and_animation_are_preserved_on_keep(self):
        original = self.profile()
        self.assertEqual(decode_effect(bytes([99])+bytes(10))['mode'], 'keep')
        self.assertTrue(lighting_state(original)['customAnimation'])
        self.assertEqual(patch_lighting(original, {'normal':{'mode':'keep'}, 'idle':{'mode':'keep'}}), original)

    def test_invalid_input_rejected(self):
        for changes in ({}, {'other':{'mode':'off'}}, {'normal':None},
                        {'normal':{'mode':'invalid'}}, {'idle':{'mode':'static','color':'red'}},
                        {'idle':{'mode':'breathe','color':'#ffffff','periodMs':70000}}):
            with self.subTest(changes=changes), self.assertRaises(OnboardError):
                patch_lighting(self.profile(), changes)

    def test_corrupt_or_short_profile_rejected(self):
        for data in (bytes(255), bytes(128)):
            with self.assertRaises(OnboardError):
                patch_lighting(data, {'normal':{'mode':'off'}})

    def test_both_groups_share_one_backed_up_verified_write(self):
        flash = SimulatedMouse()
        flash.sectors[1] = self.profile()
        before = list(flash.sectors)
        with tempfile.TemporaryDirectory() as root:
            state, backup = flash.device().set_lighting({'normal':{'mode':'off'},'idle':{'mode':'off'}}, root)
            manifest = json.loads((Path(backup)/'manifest.json').read_text())
            self.assertTrue(manifest['readback_verified'])
            self.assertIn('lighting_changes', manifest)
            self.assertEqual(flash.writes.count(8), 1)
            self.assertFalse(state['lighting']['customAnimation'])
            for index, data in enumerate(before):
                self.assertEqual((Path(backup)/f'sector-{index:04x}.bin').read_bytes(), data)
        self.assertEqual(flash.sectors[0], before[0])
        self.assertEqual(flash.sectors[2], before[2])
        self.assertEqual(flash.sectors[1][:208], before[1][:208])

    def test_backup_failure_and_host_mode_never_write(self):
        flash = SimulatedMouse()
        with patch('core.g502_onboard.Path.mkdir', side_effect=PermissionError('denied')):
            with self.assertRaises(PermissionError):
                flash.device().set_lighting({'normal':{'mode':'static','color':'#66AAFF'}}, 'unused')
        self.assertEqual(flash.writes, [])
        flash.meta['mode'] = 2
        with self.assertRaises(OnboardError):
            flash.device().set_lighting({'normal':{'mode':'off'}}, 'unused')
        self.assertEqual(flash.writes, [])

    def test_failed_lighting_readback_keeps_backup(self):
        flash = SimulatedMouse()
        flash.corrupt = True
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(OnboardError, 'backup:'):
                flash.device().set_lighting({'normal':{'mode':'static','color':'#66AAFF'}}, root)
            manifest = json.loads(next(Path(root).glob('*/manifest.json')).read_text())
            self.assertFalse(manifest['applied'])

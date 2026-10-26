import unittest
from types import SimpleNamespace
from unittest.mock import patch
from PySide6.QtCore import QObject, Signal, QCoreApplication
from ui.g502_backend import G502Backend


class Parent(QObject):
    deviceInfoChanged = Signal()
    mouseConnectedChanged = Signal()
    _root_dir = '.'
    _mouse_connected = True
    def _resolved_connected_device(self):
        return SimpleNamespace(key='g502_x_plus')


class G502BridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.parent = Parent()
        self.bridge = G502Backend(self.parent)
        self.bridge._supported = True

    def test_refresh_only_requests_read(self):
        with patch.object(self.bridge, '_run') as run:
            self.bridge.refresh()
            run.assert_called_once_with()

    def test_failed_operation_revokes_snapshot_and_does_not_emit_save(self):
        self.bridge._state = {'writable':True}
        saved = []
        self.bridge.saved.connect(lambda *args: saved.append(args))
        self.bridge._handle_result({'generation':0,'error':'timeout'})
        self.assertEqual(self.bridge.state, {})
        self.assertEqual(self.bridge.error, 'timeout')
        self.assertFalse(self.bridge.busy)
        self.assertEqual(saved, [])

    def test_success_emits_committed_slot_and_action(self):
        saved = []
        self.bridge.saved.connect(lambda *args: saved.append(args))
        self.bridge._handle_result({'generation':0,'state':{'writable':True},
                                   'slot':4,'action':'copy','backup':'test-backup'})
        self.assertEqual(saved, [(4,'copy')])
        self.assertEqual(self.bridge.lastBackup, 'test-backup')

    def test_stale_completion_cannot_restore_writable_snapshot(self):
        self.bridge._supported = False
        self.bridge._generation = 2
        self.bridge._handle_result({'generation':1,'state':{'writable':True}})
        self.assertEqual(self.bridge.state, {})

    def test_busy_rejects_duplicate_operation(self):
        self.bridge._busy = True
        with patch('ui.g502_backend.threading.Thread') as thread:
            self.bridge.save(4, 'copy')
            thread.assert_not_called()

    def test_lighting_save_requires_current_writable_lighting_snapshot(self):
        changes = {'normal': {'mode': 'off'}}
        with patch.object(self.bridge, '_run') as run:
            self.bridge.saveLighting(changes)
            run.assert_not_called()
            self.bridge._state = {'writable':True, 'lighting':{'supported':True}}
            self.bridge.saveLighting(changes)
            run.assert_called_once_with(lighting=changes)

    def test_lighting_success_does_not_emit_button_save(self):
        lighting_saved, button_saved = [], []
        self.bridge.lightingSaved.connect(lambda: lighting_saved.append(True))
        self.bridge.saved.connect(lambda *args: button_saved.append(args))
        self.bridge._handle_result({'generation':0, 'state':{'writable':True}, 'lighting':True})
        self.assertEqual(lighting_saved, [True])
        self.assertEqual(button_saved, [])

"""Asynchronous QML bridge for G502 X PLUS onboard settings."""
import threading
from pathlib import Path

from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot, Qt, QUrl

from core.config import CONFIG_DIR
from core.g502_onboard import CONTROLS, SOFTWARE_KEYS, G502Onboard, action_choices


class G502Backend(QObject):
    supportedChanged = Signal()
    stateChanged = Signal()
    busyChanged = Signal()
    saved = Signal(int, str)
    lightingSaved = Signal()
    _finished = Signal(object)

    def __init__(self, backend):
        super().__init__(backend)
        self._backend = backend
        self._supported = False
        self._busy = False
        self._state = {}
        self._error = ""
        self._message = ""
        self._backup = ""
        self._generation = 0
        self._finished.connect(self._handle_result, Qt.QueuedConnection)
        backend.deviceInfoChanged.connect(self._sync_device)
        backend.mouseConnectedChanged.connect(self._sync_device)

    @Property(bool, notify=supportedChanged)
    def supported(self):
        return self._supported

    @Property(bool, notify=busyChanged)
    def busy(self):
        return self._busy

    @Property("QVariantMap", notify=stateChanged)
    def state(self):
        return self._state

    @Property(str, notify=stateChanged)
    def error(self):
        return self._error

    @Property(str, notify=stateChanged)
    def message(self):
        return self._message

    @Property(str, notify=stateChanged)
    def lastBackup(self):
        return self._backup

    @Property(list, constant=True)
    def actions(self):
        return action_choices()

    @Property(list, notify=stateChanged)
    def buttons(self):
        if self._state.get("buttons"):
            return self._state["buttons"]
        return [{"slot":slot,"key":key,"name":name,"view":view,
                 "standardAction":standard,"actionId":"keep","actionLabel":"Not read",
                 "softwareCapable":key in SOFTWARE_KEYS,"standardOutput":False}
                for slot,key,name,view,standard in CONTROLS]

    @Slot(str, result=str)
    def imageSource(self, view):
        filename = ("side.png" if view == "side"
                    else "mouse.png")
        path = Path(self._backend._root_dir)/"images"/"logitech-mice"/"g502_x_plus"/filename
        return QUrl.fromLocalFile(str(path.resolve())).toString()

    def _is_g502_x_plus(self, device):
        if device is None:
            return False
        return (
            getattr(device, "key", "") == "g502_x_plus"
            or getattr(device, "display_name", "") == "G502 X PLUS"
            or getattr(device, "product_name", "") == "G502 X PLUS"
        )

    @Slot()
    def _sync_device(self):
        device = self._backend._resolved_connected_device()
        supported = self._backend._mouse_connected and self._is_g502_x_plus(device)
        if supported == self._supported:
            return
        self._supported = supported
        self._generation += 1
        self._state = {}
        self._error = ""
        self._message = ""
        self.supportedChanged.emit()
        self.stateChanged.emit()
        if supported:
            QTimer.singleShot(0,self.refresh)

    def _run(self, slot=None, action=None, lighting=None):
        if not self._supported or self._busy:
            return
        self._busy = True
        self._error = ""
        self._message = ""
        generation = self._generation
        self.busyChanged.emit()
        self.stateChanged.emit()

        def worker():
            device = None
            result = {"generation":generation}
            try:
                device = G502Onboard()
                if lighting is not None:
                    state,backup = device.set_lighting(lighting,Path(CONFIG_DIR)/"onboard-backups")
                    result.update(state=state,backup=backup,message="Saved to mouse and verified",lighting=True)
                elif slot is None:
                    result["state"] = device.state()
                else:
                    state,backup = device.set_button(slot,action,Path(CONFIG_DIR)/"onboard-backups")
                    result.update(state=state,backup=backup,message="Saved to mouse and verified",slot=slot,action=action)
            except Exception as exc:
                result["error"] = str(exc)
            finally:
                if device is not None:
                    try:
                        device.close()
                    except Exception:
                        pass  # Closing a handle must not strand the busy UI.
            self._finished.emit(result)

        threading.Thread(target=worker,daemon=True,name="G502OnboardSettings").start()

    @Slot()
    def refresh(self):
        self._run()

    @Slot(int,str)
    def save(self, slot, action):
        if action in ("keep", "__custom__"):
            return
        if not self._supported:
            self._error = "Connect one G502 X PLUS LIGHTSPEED receiver"
            self.stateChanged.emit()
            return
        self._run(slot, action)

    @Slot("QVariantMap")
    def saveLighting(self, changes):
        if self._supported and self._state.get("writable") and self._state.get("lighting",{}).get("supported"):
            self._run(lighting=dict(changes))

    @Slot(object)
    def _handle_result(self, result):
        self._busy = False
        self.busyChanged.emit()
        if result["generation"] != self._generation:
            if self._supported:
                QTimer.singleShot(0,self.refresh)
            return
        if "state" in result:
            self._state = result["state"]
        else:
            # Never offer another write based on a failed/stale snapshot.
            self._state = {}
        self._error = result.get("error","")
        self._message = result.get("message","")
        self._backup = result.get("backup",self._backup)
        self.stateChanged.emit()

        if "slot" in result and "state" in result:
            self.saved.emit(result["slot"], result["action"])

        if result.get("lighting") and "state" in result:
            self.lightingSaved.emit()

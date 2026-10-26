"""G502 X PLUS format-5 profiles, edited without changing mode or profile.

Protocol references: Solaar's HID++ 0x8100 implementation and capabilities
documentation. The transport and serializer below are implemented locally.
Every write preserves the original sector bytes and changes one descriptor
plus its CRC; a complete flash backup is required before the write begins.
"""
from __future__ import annotations

import binascii
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time
import uuid


CONTROLS = (
    (1, "g502_left", "Left button", "top", "mouse_left_click"),
    (2, "g502_right", "Right button", "top", "mouse_right_click"),
    (3, "middle", "Middle button", "top", "mouse_middle_click"),
    (4, "xbutton1", "Back button", "side", "mouse_back_click"),
    (5, "g502_dpi_shift", "DPI Shift button", "side", "dpi_shift"),
    (6, "xbutton2", "Forward button", "side", "mouse_forward_click"),
    (7, "hscroll_left", "Wheel tilt left", "top", "wheel_left"),
    (8, "hscroll_right", "Wheel tilt right", "top", "wheel_right"),
    (9, "g502_profile", "Profile button (G9)", "top", "profile_cycle"),
    (10, "g502_dpi_up", "DPI up (G8)", "top", "dpi_next"),
    (11, "g502_dpi_down", "DPI down (G7)", "top", "dpi_previous"),
)
# These slots also reach Windows as ordinary mouse events when the onboard
# action is still a standard click/tilt. The G502 UI writes them onboard
# anyway, so the assignment survives after Mouser quits.
SOFTWARE_KEYS = frozenset(("middle", "xbutton1", "xbutton2", "hscroll_left", "hscroll_right"))
MOUSE_ACTIONS = {
    "mouse_left_click": (1, "Left click"),
    "mouse_right_click": (2, "Right click"),
    "mouse_middle_click": (4, "Middle click"),
    "mouse_back_click": (8, "Back click"),
    "mouse_forward_click": (16, "Forward click"),
}
FUNCTION_ACTIONS = {
    "wheel_left": (1, "Wheel tilt left"), "wheel_right": (2, "Wheel tilt right"),
    "dpi_next": (3, "Next DPI"), "dpi_previous": (4, "Previous DPI"),
    "dpi_cycle": (5, "Cycle DPI"), "dpi_default": (6, "Default DPI"),
    "dpi_shift": (7, "DPI Shift"), "profile_next": (8, "Next onboard profile"),
    "profile_previous": (9, "Previous onboard profile"),
    "profile_cycle": (10, "Cycle onboard profiles"), "g_shift": (11, "G-Shift"),
    "battery_status": (12, "Show battery level"),
}
SHORTCUT_PRESETS = {
    "copy": ("ctrl+c", "Copy"), "paste": ("ctrl+v", "Paste"),
    "cut": ("ctrl+x", "Cut"), "select_all": ("ctrl+a", "Select All"),
    "undo": ("ctrl+z", "Undo"), "redo": ("ctrl+y", "Redo"),
    "go_to_definition": ("f12", "Go to definition (F12)"),
    "navigate_back": ("alt+left", "Navigate back (Alt+Left)"),
    "navigate_forward": ("alt+right", "Navigate forward (Alt+Right)"),
}
KEYS = {chr(97+i): 4+i for i in range(26)}
KEYS.update({str(i): 29+i for i in range(1, 10)})
KEYS.update({"0":39, "enter":40, "esc":41, "escape":41, "backspace":42,
             "tab":43, "space":44, "minus":45, "-":45, "equal":46, "=":46,
             "[":47, "]":48, "backslash":49, "semicolon":51, "quote":52,
             "backtick":53, "comma":54, "period":55, "slash":56,
             "insert":73, "home":74, "pageup":75, "delete":76, "end":77,
             "pagedown":78, "right":79, "left":80, "down":81, "up":82})
KEYS.update({f"f{i}":57+i for i in range(1,13)})
KEYS.update({f"f{i}":91+i for i in range(13,25)})
MODIFIERS = {"ctrl":1,"control":1,"shift":2,"alt":4,"win":8,"meta":8,"super":8}


class OnboardError(Exception):
    pass


def crc(data: bytes) -> bytes:
    return binascii.crc_hqx(data, 0xFFFF).to_bytes(2, "big")


def encode_shortcut(shortcut: str) -> bytes:
    parts = [p.strip().lower() for p in shortcut.split("+") if p.strip()]
    modifiers, keys = 0, []
    for part in parts:
        if part in MODIFIERS:
            modifiers |= MODIFIERS[part]
        else:
            keys.append(part)
    if len(keys) != 1 or keys[0] not in KEYS:
        raise OnboardError("Use one keyboard key with optional Ctrl, Shift, Alt or Win")
    return bytes((0x80, 2, modifiers, KEYS[keys[0]]))


def encode_action(action: str) -> bytes:
    if action in MOUSE_ACTIONS:
        return bytes((0x80, 1, 0, MOUSE_ACTIONS[action][0]))
    if action in FUNCTION_ACTIONS:
        return bytes((0x90, FUNCTION_ACTIONS[action][0], 0xFF, 0))
    if action in SHORTCUT_PRESETS:
        return encode_shortcut(SHORTCUT_PRESETS[action][0])
    if action == "disabled":
        return b"\xff\xff\xff\xff"
    if action.startswith("shortcut:"):
        return encode_shortcut(action.partition(":")[2])
    raise OnboardError("Unsupported onboard action")


def decode_action(data: bytes) -> tuple[str, str]:
    for key, (_, label) in {**MOUSE_ACTIONS, **FUNCTION_ACTIONS}.items():
        if data == encode_action(key):
            return key, label
    for key, (_, label) in SHORTCUT_PRESETS.items():
        if data == encode_action(key):
            return key, label
    if data == b"\xff\xff\xff\xff" or data[:2] == b"\x80\x00":
        return "disabled", "Disabled"
    if len(data) == 4 and data[:2] == b"\x80\x02":
        names = {v:k for k,v in KEYS.items() if len(k) == 1 or k.startswith("f")}
        names.update({40:"enter",41:"esc",42:"backspace",43:"tab",44:"space",73:"insert",
                      74:"home",75:"pageup",76:"delete",77:"end",78:"pagedown",
                      79:"right",80:"left",81:"down",82:"up"})
        if data[2] & 0xF0 == 0 and data[3] in names:
            parts = [name for name,bit in (("ctrl",1),("shift",2),("alt",4),("win",8)) if data[2] & bit]
            parts.append(names[data[3]])
            combo = "+".join(parts)
            return "shortcut:"+combo, combo
        return "keep", "Existing keyboard assignment"
    return "keep", "Existing device assignment"


def action_choices() -> list[dict]:
    rows = [{"id":"keep", "label":"Keep current assignment"}]
    rows += [{"id":key,"label":value[1]} for key,value in MOUSE_ACTIONS.items()]
    rows += [{"id":key,"label":value[1]} for key,value in SHORTCUT_PRESETS.items()]
    rows += [{"id":key,"label":value[1]} for key,value in FUNCTION_ACTIONS.items()]
    return rows + [{"id":"disabled","label":"Disabled"}, {"id":"__custom__","label":"Custom shortcut..."}]


def patch_button(original: bytes, slot: int, action: str) -> bytes:
    if not 1 <= slot <= 11 or len(original) < 128 or original[-2:] != crc(original[:-2]):
        raise OnboardError("The onboard profile failed validation")
    result = bytearray(original)
    offset = 32 + (slot-1)*4
    result[offset:offset+4] = encode_action(action)
    has_left = any(result[32+i*4:34+i*4] == b"\x80\x01"
                   and int.from_bytes(result[34+i*4:36+i*4], "big") & 1 for i in range(11))
    if not has_left:
        raise OnboardError("Keep at least one button assigned to left click")
    result[-2:] = crc(result[:-2])
    return bytes(result)


class HidppChannel:
    """Dedicated long-report handle; SW-ID differs from the live listener."""
    def __init__(self):
        import hid
        matches = [i for i in hid.enumerate(0x046D, 0xC547)
                   if i.get("usage_page") == 0xFF00 and i.get("usage") == 2]
        if len(matches) != 1:
            raise OnboardError("Connect one G502 X PLUS LIGHTSPEED receiver")
        self.device = hid.device()
        self.device.open_path(matches[0]["path"])
        self.device.set_nonblocking(False)

    def close(self):
        self.device.close()

    def request(self, feature, function, params=(), timeout=2):
        if len(params) > 16:
            raise OnboardError("Invalid HID++ packet")
        packet = [0x11, 1, feature, (function << 4) | 0xD] + list(params)
        packet += [0] * (20-len(packet))
        self.device.write(packet)
        deadline = time.monotonic()+timeout
        while time.monotonic() < deadline:
            raw = self.device.read(64, 100)
            if len(raw) < 4 or raw[1] != 1:
                continue
            if raw[2] == feature and raw[3] == ((function << 4) | 0xD):
                return bytes(raw[4:20])
            if (len(raw) >= 7 and raw[2] == 0xFF and raw[4] == feature
                    and raw[5] == ((function << 4) | 0xD)):
                raise OnboardError(f"The mouse rejected the request ({raw[6]})")
        raise OnboardError("The mouse did not respond; wake it and refresh")

    def feature(self, feature):
        index = self.request(0, 0, [feature >> 8, feature & 255, 0])[0]
        if not index:
            raise OnboardError("This mouse does not expose the required feature")
        return index


class G502Onboard:
    def __init__(self, channel=None):
        self.channel = channel or HidppChannel()
        try:
            name_feature = self.channel.feature(5)
            length = self.channel.request(name_feature, 0)[0]
            name = b"".join(self.channel.request(name_feature, 1, [o]) for o in range(0,length,16))[:length]
            if name != b"G502 X PLUS":
                raise OnboardError("The connected mouse is not G502 X PLUS")
            self.identity = hashlib.sha256(self.channel.request(self.channel.feature(3),0)).hexdigest()
            self.feature = self.channel.feature(0x8100)
        except Exception:
            self.close()
            raise

    def close(self):
        self.channel.close()

    def _request(self, function, params=(), timeout=2):
        return self.channel.request(self.feature, function, params, timeout)

    def _metadata(self):
        info = self._request(0)
        mode = self._request(2)[0]
        sector = int.from_bytes(self._request(4)[:2], "big")
        size = int.from_bytes(info[7:9], "big")
        if (info[0] != 1 or info[1] != 5 or info[5] != 11
                or not 128 <= size <= 4096 or not 2 <= info[6] <= 32):
            raise OnboardError("This onboard profile format is not supported")
        return {"mode":mode,"sector":sector,"size":size,"sectors":info[6],"profiles":info[3]}

    def _read_sector(self, sector, size):
        offsets = list(range(0,size-15,16))
        data = b"".join(self._request(5,[sector>>8,sector&255,o>>8,o&255]) for o in offsets)
        if len(data) < size:
            o = size-16
            last = self._request(5,[sector>>8,sector&255,o>>8,o&255])
            data += last[-(size-len(data)):]
        if len(data) != size:
            raise OnboardError("The mouse returned an incomplete profile")
        return data

    def read(self):
        meta = self._metadata()
        if not 0 < meta["sector"] < 0x200:
            raise OnboardError("The mouse has no active onboard profile")
        data = self._read_sector(meta["sector"],meta["size"])
        if data[-2:] != crc(data[:-2]):
            raise OnboardError("The onboard profile failed validation")
        return meta, data

    def state(self, meta=None, data=None):
        if meta is None or data is None:
            meta,data = self.read()
        rows = []
        for slot,key,name,view,standard in CONTROLS:
            action,label = decode_action(data[32+(slot-1)*4:36+(slot-1)*4])
            rows.append({"slot":slot,"key":key,"name":name,"view":view,
                         "actionId":action,"actionLabel":label,"standardAction":standard,
                         "softwareCapable":key in SOFTWARE_KEYS,
                         "standardOutput":action == standard})
        from core.g502_lighting import lighting_state
        return {"lighting":lighting_state(data), "mode":meta["mode"],"profile":meta["sector"] & 255,
                "writable":meta["mode"] == 1 and 0 < meta["sector"] < meta["sectors"],
                "buttons":rows}

    def set_button(self, slot, action, backup_root):
        meta,original = self.read()
        updated = patch_button(original,slot,action)
        return self._write_profile(meta,original,updated,backup_root,{"slot":slot,"new_action":action})

    def set_lighting(self, changes, backup_root):
        from core.g502_lighting import patch_lighting
        meta,original = self.read()
        updated = patch_lighting(original,changes)
        return self._write_profile(meta,original,updated,backup_root,{"lighting_changes":changes})

    def _write_profile(self, meta, original, updated, backup_root, change):
        if meta["mode"] != 1 or not 0 < meta["sector"] < meta["sectors"]:
            raise OnboardError("An editable onboard profile must be active")
        if updated == original:
            return self.state(meta,original), ""
        directory = Path(backup_root) / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")+"-"+uuid.uuid4().hex[:8])
        directory.mkdir(parents=True,mode=0o700)
        hashes = {}
        for sector in range(meta["sectors"]):
            data = self._read_sector(sector,meta["size"])
            with (directory/f"sector-{sector:04x}.bin").open("xb") as file:
                file.write(data)
            hashes[str(sector)] = hashlib.sha256(data).hexdigest()
        manifest = {"model":"G502 X PLUS","identity_hash":self.identity,"metadata":meta,
                    "sector_sha256":hashes,**change,
                    "new_sha256":hashlib.sha256(updated).hexdigest(),"applied":False}
        manifest_path = directory/"manifest.json"
        manifest_path.write_text(json.dumps(manifest,indent=2),encoding="utf-8")
        # Backup must match the snapshot, and the active device must still be
        # on that same profile immediately before the write begins.
        if (hashes[str(meta["sector"])] != hashlib.sha256(original).hexdigest()
                or self._metadata() != meta
                or self._read_sector(meta["sector"],meta["size"]) != original):
            raise OnboardError("The active profile changed; refresh before saving")
        sector,size = meta["sector"],meta["size"]
        try:
            self._request(6,[sector>>8,sector&255,0,0,size>>8,size&255])
            for offset in range(0,size,16):
                self._request(7,updated[offset:offset+16])
            self._request(8,timeout=5)
            if self._read_sector(sector,size) != updated:
                raise OnboardError("Device readback verification failed; the backup was retained")
            for other in range(meta["sectors"]):
                if other != sector and hashlib.sha256(self._read_sector(other,size)).hexdigest() != hashes[str(other)]:
                    raise OnboardError("Another onboard sector changed; the backup was retained")
            if self._metadata() != meta:
                raise OnboardError("The active profile changed during verification")
        except Exception as exc:
            raise OnboardError(f"Onboard write failed; backup: {directory}. {exc}") from exc
        manifest["applied"] = True
        manifest["readback_verified"] = True
        try:
            manifest_path.write_text(json.dumps(manifest,indent=2),encoding="utf-8")
        except OSError:
            pass  # the original backup already exists; device validation won
        return self.state(meta,updated), str(directory)

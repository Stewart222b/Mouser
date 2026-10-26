"""G502 X PLUS format-5 body LED settings (not host-driven RGB).

Wire layout references: libratbag src/hidpp20.{c,h} and driver-hidpp20.c;
Solaar docs/capabilities.md describes normal versus power-saving blocks.
G502 X PLUS uses the second LED slot. Preserve the indicator slots, sleep
timers, button assignments, and custom animation data in other sectors.
"""
from __future__ import annotations

import re

from core.g502_onboard import OnboardError, crc


OFFSETS = {"normal": 219, "idle": 241}
MODES = {"off": 0, "static": 1, "cycle": 3, "breathe": 10}


def decode_effect(data: bytes) -> dict:
    mode = next((key for key, value in MODES.items() if data[0] == value), "keep")
    color = "#" + data[1:4].hex().upper() if mode in ("static", "breathe") else "#66AAFF"
    offset = 6 if mode == "cycle" else 4
    period = int.from_bytes(data[offset:offset+2], "big") if mode in ("cycle", "breathe") else 5000
    return {"mode": mode, "color": color, "periodMs": period, "raw": data.hex()}


def lighting_state(data: bytes) -> dict:
    if len(data) < 255:
        return {"supported": False}
    return {"supported": True, "customAnimation": data[252] not in (0, 255),
            **{key: decode_effect(data[offset:offset+11]) for key, offset in OFFSETS.items()}}


def encode_effect(settings: dict) -> bytes:
    mode = settings.get("mode")
    if mode not in MODES:
        raise OnboardError("Unsupported lighting effect")
    data = bytearray(11)
    data[0] = MODES[mode]
    if mode in ("static", "breathe"):
        color = settings.get("color", "")
        if not isinstance(color, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
            raise OnboardError("Use a six-digit hex color such as #66AAFF")
        data[1:4] = bytes.fromhex(color[1:])
    if mode in ("cycle", "breathe"):
        period = settings.get("periodMs", 5000)
        if type(period) is not int or not 1000 <= period <= 20000:
            raise OnboardError("Lighting cycle must be between 1 and 20 seconds")
        offset = 6 if mode == "cycle" else 4
        data[offset:offset+2] = period.to_bytes(2, "big")
        data[8 if mode == "cycle" else 7] = 100
    return bytes(data)


def patch_lighting(original: bytes, changes: dict) -> bytes:
    if len(original) < 255 or original[-2:] != crc(original[:-2]):
        raise OnboardError("The onboard profile failed validation")
    if not isinstance(changes, dict) or not changes or set(changes) - set(OFFSETS):
        raise OnboardError("Unsupported lighting effect")
    result = bytearray(original)
    for key, settings in changes.items():
        if not isinstance(settings, dict):
            raise OnboardError("Unsupported lighting effect")
        if settings.get("mode") == "keep":
            continue
        offset = OFFSETS[key]
        result[offset:offset+11] = encode_effect(settings)
        # Factory/custom animations otherwise override these basic effects.
        # Disable the selector, preserving the animation itself in flash.
        result[252] = 0
    result[-2:] = crc(result[:-2])
    return bytes(result)

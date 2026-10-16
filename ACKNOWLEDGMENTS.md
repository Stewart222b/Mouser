# Acknowledgments

Mouser builds on the work of Tom Badash and the original project's contributors. The contributor notes below are preserved from the inherited documentation; the original [MIT license](LICENSE), copyright notices and source attribution remain intact.

- **[@andrew-sz](https://github.com/andrew-sz)** — macOS port: CGEventTap mouse hooking, Quartz key simulation, NSWorkspace app detection, and NSEvent media key support.
- **[@thisislvca](https://github.com/thisislvca)** — significant expansion of the project including macOS compatibility improvements, multi-device support, new UI features, and active triage of open issues.
- **[@awkure](https://github.com/awkure)** — cross-platform login startup (Windows registry + macOS LaunchAgent), single-instance guard, start-minimized option, and MX Master 4 detection.
- **[@hieshima](https://github.com/hieshima)** — Linux support (evdev + HID++ + uinput), mode-shift mapping, Smart Shift toggle, custom keyboard shortcut support, Linux connection-state stabilization, and macOS CGEventTap reliability fixes (auto re-enable on timeout, trackpad scroll filtering).
- **[@pavelzaichyk](https://github.com/pavelzaichyk)** — Next Tab / Previous Tab browser actions, persistent rotating log file storage, Smart Shift enhanced support (HID++ `0x2111`) with sensitivity control and scroll-mode sync.
- **[@nellwhoami](https://github.com/nellwhoami)** — Multi-language UI system (English, Simplified Chinese, Traditional Chinese) and Page Up / Page Down / Home / End navigation actions.
- **[@guilamu](https://github.com/guilamu)** — Mouse-to-mouse button remapping (left, right, middle, back, forward click) and HID++ stability fixes (stuck-button auto-release, auto-reconnect after consecutive timeouts, async dispatch queue for the Windows hook).
- **[@vcanuel](https://github.com/vcanuel)** — Logi Bolt receiver support on macOS via the `hidapi` fallback path.
- **[@farfromrefug](https://github.com/farfromrefug)** — smaller macOS bundle (Qt Quick Controls trim, QtDBus, Qt asset filtering).
- **[@MysticalMike60t](https://github.com/MysticalMike60t)** — README structure ideas (collapsible per-OS build sections).
- **[@davidnoyes](https://github.com/davidnoyes)** - Full Logitech MX Master 4 support: Actions Ring radial menu, per-slot haptics, stroke-aware gestures, dual-CID HID++ routing, and force-sensitivity control, integrating and adapting a range of community contributions; plus a charging-state indicator on the battery badge.
- **[@hughesyadaddy](https://github.com/hughesyadaddy)** - MX Master 4 firmware-first HID++ runtime, hardware-reported DPI persistence, Backend list-property memoization, and OS mouse-event passthrough when no Logitech device is connected.
- **[@laziukdavid](https://github.com/laziukdavid)** - Reworked swipe-gesture recognition and faster HID++ device detection.
- **[@FunJim](https://github.com/FunJim)** - Shift+wheel horizontal scroll on macOS/Windows/Linux, and preserving a symlinked config.json on atomic save.
- **[@chenqianhe](https://github.com/chenqianhe)** - macOS nested app-identity matching for per-app profiles.
- **[@liuxuAP369](https://github.com/liuxuAP369)** - Fractional macOS horizontal scroll delta handling.
- **[@winniesi](https://github.com/winniesi)** - Ping-pong desktop cycling action (macOS).
- **[@Archetipo95](https://github.com/Archetipo95)** - Physical scroll-wheel tilt support and reduced remapping latency on macOS.
- **[@zeward-lee](https://github.com/zeward-lee)** - Scan-code injection on remapped keystrokes so side-button copy/paste reaches UWP / Store apps.
- **[@ArtisticZhao](https://github.com/ArtisticZhao)** - Background HID polling no longer resets the system idle timer, so the display can sleep and the system can idle while Mouser runs (visibility-gated polling with an idle-grace period).
- **[@mizi](https://github.com/mizi)** - Scroll Force control: adjustable ratchet firmness for enhanced SmartShift (HID++ `0x2111`) devices, with a per-device Scroll page slider.
- **[@kevin-nous](https://github.com/kevin-nous)** - Original per-button slide-gesture concept (event-tap arming, dual-mode tap/gesture), which inspired the cross-platform "Gesture Swipe" action: any device-advertised button becomes a hold-and-slide gesture pad on Windows, macOS, and Linux.
- **[@unijiang](https://github.com/unijiang)** - Logitech M585/M590 Multi-Device Mouse support: device catalog entry (name/alias matched to avoid over-claiming the shared receiver PID), interactive hotspot layout, and wheel-tilt exposure as configurable left/right controls.

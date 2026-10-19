"""Real QML workflow coverage using fake hardware and an in-memory config."""
from pathlib import Path
import os
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SettingsUiTests(unittest.TestCase):
    def test_settings_workflow_preserves_unrelated_values(self):
        result = subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), "--probe"],
            cwd=ROOT, text=True, encoding="utf-8", errors="replace",
            env={**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"},
            capture_output=True, timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('"qml_warnings": []', result.stdout)


def probe():
    import copy
    import json
    from types import SimpleNamespace
    from unittest.mock import Mock, patch
    sys.path.insert(0, str(ROOT))
    from PySide6.QtCore import QObject, Property, QUrl, Qt, QMetaObject, Q_ARG, QPointF, QTimer
    from threading import Event
    from PySide6.QtGui import QPixmap, QFontDatabase, QFontMetricsF, QColor, QPainter
    from PySide6.QtSvg import QSvgRenderer
    from PySide6.QtQuick import QQuickImageProvider, QQuickItem
    from PySide6.QtWidgets import QApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuickControls2 import QQuickStyle
    from PySide6.QtTest import QTest
    from core.config import DEFAULT_CONFIG
    from core.version import APP_VERSION
    from tests.test_backend import _FakeEngine
    from ui.backend import Backend
    from ui.locale_manager import LocaleManager

    class IconProvider(QQuickImageProvider):
        def __init__(self): super().__init__(QQuickImageProvider.ImageType.Pixmap)
        def requestPixmap(self, icon_id, size, requested_size):
            from urllib.parse import parse_qs
            name, _, query = icon_id.partition("?")
            pixmap = QPixmap(24, 24)
            pixmap.fill(Qt.GlobalColor.transparent)
            svg = ROOT / "images/icons" / (name + ".svg")
            if svg.is_file():
                painter = QPainter(pixmap)
                QSvgRenderer(str(svg)).render(painter)
                painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceIn)
                painter.fillRect(pixmap.rect(), QColor(parse_qs(query).get("color", ["#242424"])[0]))
                painter.end()
            if size is not None:
                size.setWidth(24); size.setHeight(24)
            return pixmap

    class UiState(QObject):
        @Property(bool, constant=True)
        def darkMode(self): return os.environ.get("MOUSER_UI_DARK") == "1"
        @Property(bool, constant=True)
        def systemDarkMode(self): return self.darkMode
        @Property(str, constant=True)
        def fontFamily(self): return "Segoe UI"
        @Property(str, constant=True)
        def appearanceMode(self): return "dark" if self.darkMode else "light"

    QQuickStyle.setStyle("Material")
    app = QApplication(["settings-test", "-platform", "offscreen"])
    # Qt's Windows offscreen plugin starts without the native font database.
    if sys.platform == "win32" and not QFontDatabase.families():
        for font in ("segoeui.ttf", "msyh.ttc"):
            QFontDatabase.addApplicationFont(str(Path(os.environ["WINDIR"]) / "Fonts" / font))
    cfg = copy.deepcopy(DEFAULT_CONFIG)
    cfg["settings"]["check_for_updates"] = False
    cfg["settings"]["language"] = "zh_CN"
    cfg["settings"]["dpi_presets"] = [400, 800, 1600, 3200]
    cfg["settings"]["force_sensitivity"] = 128
    cfg["profiles"]["editor_test"] = {"label": "Custom editor", "apps": ["editor_test"],
                                      "mappings": copy.deepcopy(cfg["profiles"]["default"]["mappings"])}
    device = SimpleNamespace(key="mx_master_4", display_name="MX Master 4", ui_layout="mx_master_4",
        dpi_min=200, dpi_max=8000, supported_buttons=("middle", "gesture", "xbutton1", "xbutton2",
                                                     "mode_shift", "actions_ring", "hscroll_left", "hscroll_right"))
    fake = _FakeEngine(device_connected=True, connected_device=device, hid_features_ready=True)
    fake.haptic_supported = True
    fake.smart_shift_supported = True
    fake.smart_shift_force_supported = True
    fake.force_sensing_supported = True
    fake.force_sensing_range = (0, 255, 128)
    fake.cfg = cfg
    fake.enabled = True
    for name in ("play_screen_switch_haptic", "reload_mappings", "set_haptic_level", "play_haptic_waveform", "preview_haptic_level", "set_dpi", "set_smart_shift", "set_force_sensitivity"):
        setattr(fake, name, Mock())
    haptic_events = []
    def apply_haptic(level, play=True):
        haptic_events.append(("apply", level))
        if play:
            haptic_events.append(("preview", level))
        return True
    fake.preview_haptic_level.side_effect = apply_haptic
    lm = LocaleManager("zh_CN")
    with patch("ui.backend.load_config", return_value=cfg), patch("ui.backend.save_config") as save, \
         patch("core.config.save_config") as core_save, \
         patch("ui.backend.supports_login_startup", return_value=False), \
         patch.object(Backend, "beginShortcutCapture"), patch.object(Backend, "endShortcutCapture"), \
         patch.object(Backend, "_consumeUpdateResultMarker"), patch.object(Backend, "_cleanupStaleUpdatePreparation"):
        backend = Backend(engine=fake, root_dir=str(ROOT), locale_manager=lm)
        backend._update_timer.stop()
        backend._screen_haptic_timer.stop()
        state = UiState()
        engine = QQmlApplicationEngine()
        engine.addImageProvider("appicons", IconProvider())
        engine.addImageProvider("systemicons", IconProvider())
        warnings = []
        engine.warnings.connect(lambda messages: warnings.extend(m.toString() for m in messages))
        context = engine.rootContext()
        for key, value in {"backend": backend, "lm": lm, "uiState": state, "launchHidden": False,
                           "appVersion": APP_VERSION, "appBuildMode": "source", "appCommit": "test",
                           "appLaunchPath": "test"}.items():
            context.setContextProperty(key, value)
        engine.load(QUrl.fromLocalFile(str(ROOT / "ui/qml/Main.qml")))
        assert engine.rootObjects(), warnings
        window = engine.rootObjects()[0]
        def settle():
            app.processEvents(); QTest.qWait(60); app.processEvents()
        def objects():
            pending, seen, result = [window, window.contentItem()], set(), []
            while pending:
                obj = pending.pop()
                if id(obj) in seen:
                    continue
                seen.add(id(obj)); result.append(obj)
                pending.extend(obj.children())
                if isinstance(obj, QQuickItem):
                    pending.extend(obj.childItems())
            return result
        def find(name):
            matches = [o for o in objects() if o.objectName() == name]
            assert matches, (name, [o.objectName() for o in objects() if o.objectName()])
            visible_matches = [o for o in matches if o.property("visible")]
            return (visible_matches or matches)[-1]
        def assert_navigation_alignment():
            by_name = {obj.objectName(): obj for obj in objects() if obj.objectName()}
            for page in range(6):
                name = "navigation_" + str(page) if page < 5 else "aboutNavigation"
                label_name = "navigationLabel_" + str(page) if page < 5 else "aboutNavigationLabel"
                label = by_name[label_name]
                icon = by_name[name + "_icon"]
                background = by_name[name + "_background"]
                ink = QFontMetricsF(label.property("font")).tightBoundingRect(label.property("text"))
                ink_center = label.mapToScene(QPointF(
                    0, label.property("baselineOffset") + ink.y() + ink.height() / 2
                )).y()
                icon_center = icon.mapToScene(QPointF(0, icon.height() / 2)).y()
                background_center = background.mapToScene(QPointF(0, background.height() / 2)).y()
                assert abs(ink_center - icon_center) < 0.1, (name, ink_center, icon_center)
                assert abs(ink_center - background_center) < 0.1, (name, ink_center, background_center)
        def invoke(obj, method, value):
            assert QMetaObject.invokeMethod(obj, method, Q_ARG("QVariant", value)), method
            settle()
        def activate(combo, index):
            combo.setProperty("currentIndex", index)
            combo.activated.emit(index)
            settle()
        def toggle(control):
            assert control.property("enabled"), control.objectName()
            previous = control.property("checked")
            control.forceActiveFocus()
            QTest.keyClick(window, Qt.Key.Key_Space)
            settle()
            assert control.property("checked") != previous, control.objectName()
        def reveal(control):
            scroller = control.parentItem()
            while scroller is not None and scroller.property("contentY") is None:
                scroller = scroller.parentItem()
            if scroller is not None:
                center = control.mapToItem(scroller, QPointF(0, control.height() / 2))
                target = scroller.property("contentY") + center.y() - scroller.height() / 2
                maximum = max(0, scroller.property("contentHeight") - scroller.height())
                scroller.setProperty("contentY", max(0, min(maximum, target)))
                settle()
        def drag_and_commit(control, read_value):
            reveal(control)
            assert control.property("visible") and control.property("enabled"), control.objectName()
            value_before, saves_before = read_value(), save.call_count
            start = control.mapToScene(QPointF(25, control.height() / 2)).toPoint()
            end = control.mapToScene(QPointF(control.width() - 35, control.height() / 2)).toPoint()
            QTest.mousePress(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, start)
            QTest.mouseMove(window, end); QTest.qWait(350); settle()
            assert control.property("pressed"), control.objectName()
            assert read_value() == value_before, control.objectName()
            assert save.call_count == saves_before, control.objectName()
            selected = round(control.property("value"))
            QTest.mouseRelease(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, end); settle()
            assert read_value() == selected, (control.objectName(), read_value(), selected)
            assert save.call_count == saves_before + 1, control.objectName()
        def assert_gui_survives_device_wait(method, apply_setting):
            started, release, finished = Event(), Event(), Event()
            def slow_write(*args, **kwargs):
                started.set()
                try:
                    release.wait(2)
                finally:
                    finished.set()
            method.side_effect = slow_write
            try:
                apply_setting()
                assert started.wait(1)
                ticks = []
                QTimer.singleShot(0, lambda: ticks.append(True)); settle()
                assert ticks and not finished.is_set(), "Hardware I/O blocked the Qt event loop"
            finally:
                release.set()
                assert finished.wait(1)
                method.side_effect = None
        settle()
        mouse = next(o for o in window.findChildren(QObject) if o.metaObject().className().startswith("MousePage"))
        before = copy.deepcopy(cfg)
        for page in (0, 1, 2, 3, 4, 0):
            window.setProperty("currentPage", page); settle()
        assert cfg == before, "Opening pages must not write settings"
        save.assert_not_called(); core_save.assert_not_called()
        assert not haptic_events, "Opening settings must not play a preview"
        # Device status belongs to the persistent sidebar. Hardware reports
        # update it without saving preferences or borrowing a page's state.
        status = find("sidebarDeviceStatus")
        transport_before = backend._connected_device_transport
        connected_before = backend._mouse_connected
        battery_before = (backend.batteryLevel, backend.batteryCharging)
        for transport, icon in (("Bluetooth", "bluetooth"), ("Logi Bolt", "usb-receiver"),
                                ("USB Receiver", "usb-receiver"), ("evdev", "link"), ("", "link")):
            backend._connected_device_transport = transport
            backend.deviceInfoChanged.emit()
            backend._handleBatteryChange(95, False); settle()
            assert find("deviceConnectionIcon").property("name") == icon
            assert find("deviceBatteryText").property("text") == "95%"
            assert abs(find("deviceBatteryFill").width() - 15.2) < 0.01
            assert status.property("connectionLabel")
            if icon == "link":
                assert status.property("connectionLabel") == lm.strings["device.connection_unknown"]
        backend._connected_device_transport = "Bluetooth"
        backend.deviceInfoChanged.emit()
        backend._handleBatteryChange(61, True); settle()
        assert find("deviceConnectionIcon").property("name") == "bluetooth"
        assert find("deviceChargingIcon").property("visible")
        assert not find("deviceBatteryFill").property("visible")
        assert lm.strings["device.charging"] in status.property("batteryLabel")
        assert cfg == before
        save.assert_not_called(); core_save.assert_not_called()
        for lang in ("en", "zh_TW", "zh_CN"):
            lm.setLanguage(lang)
            backend._handleBatteryChange(8, False); settle()
            assert lm.strings["device.low_battery"] in find("deviceBatteryText").property("text")
            assert status.property("lowBattery")
            assert status.property("implicitWidth") <= status.width() + 1
        localization_saves = save.call_count
        for level in (-1, 120):
            backend._handleBatteryChange(level, False); settle()
            assert find("deviceBatteryText").property("text") == "—"
            assert not find("deviceBatteryFill").property("visible")
            assert lm.strings["device.battery_unknown"] == status.property("batteryLabel")
        backend._mouse_connected = False
        backend.mouseConnectedChanged.emit(); settle()
        assert find("deviceDisconnectedText").property("visible")
        assert not find("deviceBatteryIndicator").property("visible")
        assert not find("deviceConnectionIndicator").property("visible")
        backend._mouse_connected = connected_before
        backend._connected_device_transport = transport_before
        backend.mouseConnectedChanged.emit()
        backend.deviceInfoChanged.emit()
        backend._handleBatteryChange(*battery_before); settle()
        assert cfg == before
        assert save.call_count == localization_saves
        core_save.assert_not_called()
        for page in (0, 1, 2, 3, 4, 0):
            window.setProperty("currentPage", page); settle()
            assert status.property("visible")
        label_x = find("navigationLabel_0").mapToScene(QPointF()).x()
        for name in ("navigationLabel_4", "aboutNavigationLabel"):
            position_x = find(name).mapToScene(QPointF()).x()
            assert abs(position_x - label_x) < 1, (name, position_x, label_x)
        window.setProperty("currentPage", 1); settle()
        def visible(name): return any(o.property("visible") for o in window.findChildren(QObject) if o.objectName() == name)
        assert visible("pointerSettingsSection") and not visible("appearanceSettingsSection")
        window.setProperty("currentPage", 4); settle()
        assert not visible("pointerSettingsSection") and visible("appearanceSettingsSection")
        window.setProperty("currentPage", 0); settle()
        invoke(mouse, "selectButton", "middle")
        combo = find("buttonActionCombo")
        actions = mouse.property("availableButtonActions").toVariant()
        action_id = "ctrl_left_click" if sys.platform == "win32" else "copy"
        idx = next(i for i, row in enumerate(actions) if row["id"] == action_id)
        activate(combo, idx)
        assert cfg["profiles"]["default"]["mappings"]["middle"] == action_id
        assert cfg["profiles"]["editor_test"] == before["profiles"]["editor_test"]
        custom_idx = next(i for i, row in enumerate(actions) if row["id"] == "__custom__")
        activate(combo, custom_idx)
        dialog = find("shortcutCaptureDialog")
        assert dialog.property("visible")
        dialog.captured.emit("ctrl+alt+d")
        QMetaObject.invokeMethod(dialog, "close"); settle()
        assert cfg["profiles"]["default"]["mappings"]["middle"] == "custom:ctrl+alt+d"
        gesture_idx = next(i for i, row in enumerate(actions) if row["id"] == "gesture_swipe")
        activate(combo, gesture_idx)
        assert find("gestureButtonEditor").property("visible")
        threshold_before = backend.gestureThreshold
        drag_and_commit(find("gestureThresholdSlider"), lambda: backend.gestureThreshold)
        backend.setGestureThreshold(threshold_before); settle()
        backend.setProfileMapping("default", "middle", "cycle_dpi"); settle()
        assert find("dpiPresetEditor").property("visible")
        presets_before = backend.dpiPresets[:]
        drag_and_commit(find("dpiPresetSlider"), lambda: backend.dpiPresets[0])
        backend.setDpiPreset(0, presets_before[0]); settle()
        backend.setProfileMapping("default", "middle", action_id); settle()
        toggle(find("selectedButtonHapticSwitch"))
        expected_middle = "middle" in cfg["settings"]["button_haptic"]
        window.setProperty("currentPage", 2); settle()
        assert find("buttonHaptic_middle").property("checked") == expected_middle
        keys_before = [r["key"] for r in backend.hapticButtonRows]
        toggle(find("buttonHaptic_middle"))
        assert [r["key"] for r in backend.hapticButtonRows] == keys_before
        assert ("middle" in cfg["settings"]["button_haptic"]) != expected_middle
        assert not any(r["key"].startswith("hscroll") for r in backend.hapticButtonRows)
        level_before = cfg["settings"]["haptic_level"]
        for level in (0, 1, 2, 3, 3, level_before):
            radio = find("hapticLevel_" + str(level))
            position = radio.mapToScene(QPointF(radio.width() / 2, radio.height() / 2)).toPoint()
            count = len(haptic_events)
            QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, position); settle()
            assert cfg["settings"]["haptic_level"] == level
            assert haptic_events[count:] == [("apply", level), ("preview", level)]
        radio = find("hapticLevel_0")
        radio.forceActiveFocus(); QTest.keyClick(window, Qt.Key.Key_Space); settle()
        assert haptic_events[-2:] == [("apply", 0), ("preview", 0)]
        radio = find("hapticLevel_" + str(level_before))
        radio.forceActiveFocus(); QTest.keyClick(window, Qt.Key.Key_Space); settle()
        assert cfg["settings"]["haptic_level"] == level_before
        assert not any(o.objectName() == "hapticTestButton" for o in objects())
        toggle(find("hapticEnableSwitch"))
        assert not find("buttonHaptic_middle").property("enabled")
        assert all(not find("hapticLevel_" + str(level)).property("enabled") for level in range(4))
        count = len(haptic_events)
        radio = find("hapticLevel_0")
        position = radio.mapToScene(QPointF(radio.width() / 2, radio.height() / 2)).toPoint()
        QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, position); settle()
        assert len(haptic_events) == count
        assert cfg["settings"]["haptic_level"] == level_before
        toggle(find("hapticEnableSwitch"))
        haptic = next(o for o in window.findChildren(QObject) if o.metaObject().className().startswith("HapticPage"))
        haptic.setProperty("advancedExpanded", True); settle()
        toggle(find("hapticDedupSwitch"))
        assert cfg["settings"]["haptic_dedup"] != before["settings"]["haptic_dedup"]
        force_before = backend.forceSensitivity
        assert_gui_survives_device_wait(fake.set_force_sensitivity, lambda: backend.setForceSensitivity(192))
        backend.setForceSensitivity(force_before); settle()
        changed_settings = {k for k in cfg["settings"] if cfg["settings"][k] != before["settings"].get(k)}
        assert changed_settings <= {"button_haptic", "haptic_dedup"}, changed_settings
        window.setProperty("currentPage", 0); settle()
        assert find("selectedButtonHapticSwitch").property("checked") == ("middle" in cfg["settings"]["button_haptic"])
        for lang in ("en", "zh_TW", "zh_CN"):
            lm.setLanguage(lang); settle()
            assert lm.trButton("Middle button") in [o.property("text") for o in objects()]
        # Device settings retain keyboard/precise entry and change only their own values.
        window.setProperty("currentPage", 1); settle()
        device_before = copy.deepcopy(cfg)
        dpi = find("dpiSetting_slider")
        dpi.forceActiveFocus(); QTest.keyClick(window, Qt.Key.Key_Right); QTest.qWait(350); settle()
        assert cfg["settings"]["dpi"] == device_before["settings"]["dpi"] + 50
        # A paused drag still stays entirely local until release. The number
        # follows the handle, and the device receives only the final value.
        drag_before = cfg["settings"]["dpi"]
        calls_before = fake.set_dpi.call_count
        start = dpi.mapToScene(QPointF(25, dpi.height() / 2)).toPoint()
        end = dpi.mapToScene(QPointF(dpi.width() - 35, dpi.height() / 2)).toPoint()
        QTest.mousePress(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, start)
        QTest.mouseMove(window, end); QTest.qWait(350); settle()
        assert dpi.property("pressed")
        assert cfg["settings"]["dpi"] == drag_before
        assert fake.set_dpi.call_count == calls_before
        selected_dpi = round(dpi.property("value"))
        assert find("dpiSetting_value").property("value") == selected_dpi
        QTest.mouseRelease(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, end); settle()
        assert cfg["settings"]["dpi"] == selected_dpi
        assert fake.set_dpi.call_count == calls_before + 1
        # Deliberately stall the fake device: Qt must continue processing
        # timers while that hardware write is still waiting in its worker.
        started, release, finished = Event(), Event(), Event()
        def slow_dpi(*args, **kwargs):
            started.set()
            try:
                release.wait(2)
            finally:
                finished.set()
        fake.set_dpi.side_effect = slow_dpi
        try:
            backend.setDpi(1800)
            assert started.wait(1)
            ticks = []
            QTimer.singleShot(0, lambda: ticks.append(True)); settle()
            assert ticks and not finished.is_set(), "DPI I/O must not block the Qt event loop"
        finally:
            release.set()
            assert finished.wait(1)
            fake.set_dpi.side_effect = None
        precise = find("dpiSetting_value")
        reveal(precise)
        precise.property("contentItem").forceActiveFocus()
        QTest.keyClick(window, Qt.Key.Key_A, Qt.KeyboardModifier.ControlModifier)
        for key in (Qt.Key.Key_1, Qt.Key.Key_7, Qt.Key.Key_5, Qt.Key.Key_0):
            QTest.keyClick(window, key)
        QTest.keyClick(window, Qt.Key.Key_Return); settle()
        assert cfg["settings"]["dpi"] == 1750
        precise.setProperty("value", 1600); precise.valueModified.emit(); settle()
        assert cfg["settings"]["dpi"] == 1600
        toggle(find("invertHorizontalSwitch"))
        assert cfg["settings"]["invert_hscroll"] != device_before["settings"]["invert_hscroll"]
        toggle(find("invertHorizontalSwitch"))
        toggle(find("smartShiftSwitch"))
        assert cfg["settings"]["smart_shift_enabled"] != device_before["settings"]["smart_shift_enabled"]
        toggle(find("smartShiftSwitch"))
        if not backend.smartShiftEnabled:
            backend.setSmartShiftEnabled(True); settle()
        drag_and_commit(find("smartShiftThresholdSetting_slider"), lambda: backend.smartShiftThreshold)
        drag_and_commit(find("wheelForceSetting_slider"), lambda: backend.scrollForce)
        assert_gui_survives_device_wait(fake.set_smart_shift, lambda: backend.setScrollForce(60))
        backend.setSmartShiftThreshold(device_before["settings"]["smart_shift_threshold"])
        backend.setScrollForce(device_before["settings"]["scroll_force"])
        backend.setSmartShiftEnabled(device_before["settings"]["smart_shift_enabled"]); settle()
        device_changed = {key for key in cfg["settings"] if cfg["settings"][key] != device_before["settings"].get(key)}
        assert device_changed == {"dpi"}, device_changed
        assert cfg["profiles"] == device_before["profiles"]
        # Ring preview directions match the controller's clockwise sector order.
        window.setProperty("currentPage", 3); settle()
        ring = next(o for o in objects() if o.metaObject().className().startswith("ActionsRingConfig"))
        for direction, key in ((0, Qt.Key.Key_Up), (1, Qt.Key.Key_Right), (2, Qt.Key.Key_Down), (3, Qt.Key.Key_Left)):
            find("ringSector_0").forceActiveFocus(); QTest.keyClick(window, key); settle()
            assert ring.property("selectedSector") == direction
        ring.setProperty("selectedSector", 2); settle()
        profiles_before_ring = copy.deepcopy(cfg["profiles"])
        copy_index = next(i for i, row in enumerate(backend.allActions) if row["id"] == "copy")
        activate(find("ringActionCombo"), copy_index)
        assert cfg["settings"]["actions_ring_slots"][2] == "copy"
        assert cfg["profiles"] == profiles_before_ring
        global_slots = copy.deepcopy(cfg["settings"]["actions_ring_slots"])
        toggle(find("ringGlobalSwitch"))
        profile_index = next(i for i, row in enumerate(backend.profiles) if row["name"] == "editor_test")
        activate(find("ringProfileCombo"), profile_index)
        ring.setProperty("selectedSector", 1); settle()
        activate(find("ringActionCombo"), copy_index)
        assert cfg["profiles"]["editor_test"]["mappings"]["actions_ring_slots"][1] == "copy"
        assert cfg["settings"]["actions_ring_slots"] == global_slots
        assert cfg["profiles"]["default"] == profiles_before_ring["default"]
        ring_custom_index = next(i for i, row in enumerate(backend.allActions) if row["id"] == "__custom__")
        activate(find("ringActionCombo"), ring_custom_index)
        ring_dialog = find("ringShortcutCaptureDialog")
        assert ring_dialog.property("visible") and window.property("shortcutsBlocked")
        assert not find("navigation_0").property("enabled")
        ring.setProperty("selectedSector", 3)
        ring_dialog.captured.emit("ctrl+shift+k")
        QMetaObject.invokeMethod(ring_dialog, "close"); settle()
        assert cfg["profiles"]["editor_test"]["mappings"]["actions_ring_slots"][1] == "custom:ctrl+shift+k"
        cancel_before = copy.deepcopy(cfg)
        activate(find("ringActionCombo"), ring_custom_index)
        ring_dialog.cancelled.emit(); QMetaObject.invokeMethod(ring_dialog, "close"); settle()
        assert cfg == cancel_before and not window.property("shortcutsBlocked")
        actual_action = backend.actionLabelFor(backend.actionsRingSlots[3])
        assert find("ringActionCombo").property("displayText") == lm.trAction(actual_action)
        assert find("ringActionCombo").property("currentIndex") != ring_custom_index
        toggle(find("ringGlobalSwitch"))
        hold = find("ringHoldSetting_slider")
        drag_and_commit(hold, lambda: backend.actionsRingHoldMs)
        hold.forceActiveFocus(); QTest.keyClick(window, Qt.Key.Key_Home); QTest.qWait(350)
        QTest.keyClick(window, Qt.Key.Key_Right); QTest.qWait(350); settle()
        assert cfg["settings"]["actions_ring_hold_ms"] == 110
        backend.setActionsRingHoldMs(300)
        # App preferences are separate from device settings and update actions are gated.
        window.setProperty("currentPage", 4); settle()
        app_before = copy.deepcopy(cfg)
        toggle(find("startMinimizedSwitch")); toggle(find("startMinimizedSwitch"))
        activate(find("appearanceCombo"), 2)
        assert cfg["settings"]["appearance_mode"] == "dark"
        activate(find("appearanceCombo"), 0)
        assert cfg["settings"]["appearance_mode"] == "system"
        appearance = find("appearanceCombo")
        reveal(appearance)
        appearance.forceActiveFocus()
        QTest.keyClick(window, Qt.Key.Key_Space); settle()
        QTest.keyClick(window, Qt.Key.Key_Down)
        QTest.keyClick(window, Qt.Key.Key_Return); settle()
        assert cfg["settings"]["appearance_mode"] == "light"
        activate(appearance, 0)
        activate(find("languageCombo"), 0)
        assert cfg["settings"]["language"] == "en"
        activate(find("languageCombo"), 1)
        assert cfg["settings"]["language"] == "zh_CN"
        assert cfg["profiles"] == app_before["profiles"]
        assert cfg["settings"]["dpi"] == app_before["settings"]["dpi"]
        cfg["settings"]["screenshot_directory"] = str(ROOT / "test-screenshots")
        backend.settingsChanged.emit(); settle()
        reset = find("resetScreenshotFolderButton")
        assert reset.property("enabled")
        reset.forceActiveFocus(); QTest.keyClick(window, Qt.Key.Key_Space); settle()
        assert cfg["settings"]["screenshot_directory"] == ""
        backend._latest_update_version = "9.9.9-test"
        backend._setUpdateInstallState("downloading"); settle()
        assert not find("checkUpdateButton").property("enabled")
        assert find("cancelUpdateButton").property("visible")
        backend._setUpdateInstallState("ready_to_install", "", True); settle()
        assert find("installUpdateButton").property("visible") == backend.updateInstallEnabled
        backend._latest_update_version = ""
        backend._setUpdateInstallState("idle"); settle()
        # The enlarged target accepts a click outside the old 36px square.
        window.setProperty("currentPage", 0); settle()
        assert find("hotspotDot_xbutton1").property("width") == 18
        assert find("hotspotDot_xbutton1").property("color") == QColor("#f6f8fc")
        target = find("hotspotTarget_xbutton1")
        assert target.property("width") == 44
        click_before = copy.deepcopy(cfg)
        position = target.mapToScene(QPointF(42, 22)).toPoint()
        QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, position); settle()
        assert mouse.property("selectedButton") == "xbutton1"
        assert cfg == click_before
        # Every settings page must follow maximize/restore, not stay pinned
        # to the old 920px upper-left layout. Controls retain usable widths.
        resize_before = copy.deepcopy(cfg)
        content_names = {1: "pointerSettingsContent", 2: "hapticSettingsContent",
                         3: "ringSettingsContent", 4: "appSettingsContent"}
        ring_radii = []
        form_names = {1: "pointerSettingsForm", 2: "hapticSettingsForm",
                      3: "ringSettingsForm", 4: "appSettingsForm"}
        for width, height in ((1040, 620), (1240, 800), (1920, 1080), (2560, 1440), (1240, 800)):
            window.setWidth(width); window.setHeight(height); settle()
            title_positions = []
            for page, content_name in {0: "mouseSettingsContent", **content_names}.items():
                window.setProperty("currentPage", page); settle()
                assert_navigation_alignment()
                content = find(content_name)
                if page in content_names:
                    scroller = content.parentItem()
                    while scroller is not None and scroller.property("contentY") is None:
                        scroller = scroller.parentItem()
                    assert scroller is not None
                    scroller.setProperty("contentY", 0); settle()
                title = find("settingsPageTitle")
                position = title.mapToScene(QPointF(0, 0))
                title_positions.append((position.x(), position.y()))
                assert title.height() == 52, (page, title.height())
                assert title.property("font").pixelSize() == 24
                viewport = content.property("viewportWidth")
                assert abs(content.width() - min(viewport - 64, 1280)) < 1, (content_name, width, content.width())
                assert abs(content.x() + content.width() / 2 - viewport / 2) < 1, (content_name, width, content.x())
                if page in form_names:
                    form = find(form_names[page])
                    assert abs(form.width() - min(content.width(), 1040)) < 1
                    assert abs(form.mapToScene(QPointF()).x() - position.x()) < 1
                if page == 0:
                    assert find("mouseWorkbench").height() <= 540
                    assert find("mouseWorkbench").width() <= 1120
                    assert find("physicalButtonSelector").width() <= 280
                    assert find("profileSelector").height() == 36
                if page == 1:
                    assert find("dpiSetting_slider").width() <= 246
                    assert find("dpiSetting_value").height() == 36
                    assert find("dpiPresetCombo").height() == 36
                elif page == 2:
                    assert find("hapticLevel_0").height() == 36
                elif page == 3:
                    ring = find("ringPreview")
                    ring_radii.append(ring.property("outerRadius"))
                    assert ring.height() > 350
                    assert 299 <= find("ringActionCombo").width() <= 421
                    assert find("ringActionCombo").height() == 36
                    for index in range(4):
                        sector = find("ringSector_" + str(index))
                        assert sector.x() >= 0 and sector.x() + sector.width() <= ring.width() + 1
                        assert sector.y() >= 0 and sector.y() + sector.height() <= ring.height() + 1
                elif page == 4:
                    assert find("appearanceCombo").width() <= 181
                    assert find("appearanceCombo").height() == 36
            for position in title_positions[1:]:
                assert abs(position[0] - title_positions[0][0]) < 1, (width, title_positions)
                assert abs(position[1] - title_positions[0][1]) < 1, (width, title_positions)
        assert ring_radii[2] > ring_radii[1] > ring_radii[0], ring_radii
        assert abs(ring_radii[-1] - ring_radii[1]) < 1, ring_radii
        assert cfg == resize_before, "Maximize and restore must not write preferences"
        window.setWidth(int(os.environ.get("MOUSER_UI_CAPTURE_WIDTH", "1240")))
        window.setHeight(int(os.environ.get("MOUSER_UI_CAPTURE_HEIGHT", "800"))); settle()
        capture = os.environ.get("MOUSER_UI_CAPTURE_DIR")
        if capture:
            output = Path(capture); output.mkdir(parents=True, exist_ok=True)
            backend._connected_device_transport = "Bluetooth"
            backend.deviceInfoChanged.emit()
            backend._handleBatteryChange(95, False)
            haptic.setProperty("advancedExpanded", False)
            QTest.qWait(2100)
            for page, name in ((0, "buttons"), (1, "pointer-scroll"), (2, "haptics"), (3, "actions-ring"), (4, "app-settings")):
                invoke(window, "openPage", page)
                if page in content_names:
                    # Earlier keyboard edits may have scrolled the page.
                    # Capture the top of each view, rather than that test state.
                    scroller = find(content_names[page]).parentItem()
                    while scroller is not None and scroller.property("contentY") is None:
                        scroller = scroller.parentItem()
                    assert scroller is not None
                    scroller.setProperty("contentY", 0); settle()
                assert window.grabWindow().save(str(output / (name + ".png")))
        for width in (1040, 1240, 1500):
            window.setWidth(width); settle()
            window.setProperty("currentPage", 0); settle()
            assert find("mousePreview").property("width") > 200
            assert find("buttonEditor").property("width") >= 300
        assert not warnings, warnings
        print(json.dumps({"qml_warnings": warnings, "page_navigation": 5, "profile_isolation": True,
                          "shared_haptic_controls": True, "opening_pages_preserves_config": True,
                          "pointer_and_app_preferences": True, "ring_scope_and_custom_shortcuts": True,
                          "hotspot_outer_target_click": True, "wide_layout_and_restore": True,
                          "page_title_alignment_across_five_pages": True,
                          "desktop_control_sizes_and_form_widths": True,
                          "navigation_glyph_vertical_alignment": True,
                          "haptic_selection_preview": True, "all_slider_release_commits": True,
                          "wheel_and_force_gui_responsive_during_hardware_wait": True,
                          "global_device_status_states_and_sidebar_alignment": True}))
        window.deleteLater(); app.processEvents()


if __name__ == "__main__":
    if "--probe" in sys.argv: probe()
    else: unittest.main()

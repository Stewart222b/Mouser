import copy
import unittest

from scripts.configure_ctrl_click import configure_profiles


class CtrlClickProfileTests(unittest.TestCase):
    def setUp(self):
        self.config = {"version": 11, "settings": {"invert_hscroll": True}, "profiles": {
            "default": {"label": "Default", "apps": [], "mappings": {
                "actions_ring": "gesture_swipe", "middle": "mouse_middle_click"}},
            "existing": {"label": "Cursor", "apps": ["cursor.exe"], "mappings": {
                "actions_ring": "none", "xbutton1": "custom:ctrl+c"}},
            "browser": {"apps": ["msedge.exe"], "mappings": {"actions_ring": "activate_actions_ring"}},
        }}

    def test_existing_and_new_profiles_preserve_unrelated_values(self):
        original = copy.deepcopy(self.config)
        result, names = configure_profiles(self.config, {"Cursor.exe": "Cursor", "Code.exe": "VS Code"})
        self.assertEqual(self.config, original)
        self.assertEqual(result["settings"], original["settings"])
        self.assertEqual(result["version"], original["version"])
        for name in ("default", "browser"):
            self.assertEqual(result["profiles"][name], original["profiles"][name])
        self.assertEqual(result["profiles"]["existing"]["mappings"]["xbutton1"], "custom:ctrl+c")
        self.assertEqual(result["profiles"][names[-1]]["mappings"]["middle"], "mouse_middle_click")
        for name in names:
            self.assertEqual(result["profiles"][name]["mappings"]["actions_ring"], "ctrl_left_click")

    def test_repeated_configuration_is_idempotent(self):
        first, _ = configure_profiles(self.config, {"Code.exe": "VS Code"})
        second, _ = configure_profiles(first, {"Code.exe": "VS Code"})
        self.assertEqual(first, second)

    def test_full_path_existing_profile_is_reused(self):
        self.config["profiles"]["existing"]["apps"] = [r"C:\Programs\Cursor\Cursor.exe"]
        result, names = configure_profiles(self.config, {"Cursor.exe": "Cursor"})
        self.assertEqual(names, ["existing"])
        self.assertEqual(len(result["profiles"]), len(self.config["profiles"]))

    def test_configured_apps_match_and_edge_uses_unchanged_default(self):
        from core.config import get_profile_for_app_identity
        result, _ = configure_profiles(self.config, {"Code.exe": "VS Code", "ChatGPT.exe": "Codex"})
        for app in ("Code.exe", "ChatGPT.exe"):
            profile = get_profile_for_app_identity(result, (app,))
            self.assertEqual(result["profiles"][profile]["mappings"]["actions_ring"], "ctrl_left_click")
        self.assertEqual(get_profile_for_app_identity(result, ("msedge.exe",)), "browser")
        self.assertEqual(get_profile_for_app_identity(result, ("notepad.exe",)), "default")


if __name__ == "__main__":
    unittest.main()

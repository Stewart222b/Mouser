"""Configure discovered IDEs without changing defaults or global settings."""
import argparse
import copy
from datetime import datetime
import json
import os
from pathlib import Path
import tempfile


def configure_profiles(config, apps):
    result = copy.deepcopy(config)
    profiles = result.setdefault("profiles", {})
    default = profiles.get("default", {})
    updated = []
    for executable, label in apps.items():
        matching = [name for name, profile in profiles.items()
                    if name != "default" and any(
                        str(app).replace("\\", "/").rsplit("/", 1)[-1].casefold() == executable.casefold()
                        for app in profile.get("apps", []))]
        if not matching:
            name = "ctrlclick_" + executable.casefold().replace(".exe", "").replace(" ", "_").replace("-", "_")
            suffix = 2
            base = name
            while name in profiles:
                name = f"{base}_{suffix}"
                suffix += 1
            profile = copy.deepcopy(default)
            profile["label"] = label
            profile["apps"] = [executable]
            profiles[name] = profile
            matching = [name]
        for name in matching:
            profiles[name].setdefault("mappings", {})["actions_ring"] = "ctrl_left_click"
            updated.append(name)
    return result, updated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--apps", type=Path, required=True, help="JSON executable-to-label map")
    parser.add_argument("--apply", action="store_true", help="Otherwise print a preview only")
    args = parser.parse_args()
    original = args.config.read_bytes()
    config = json.loads(original.decode("utf-8-sig"))
    apps = json.loads(args.apps.read_text(encoding="utf-8-sig"))
    updated, names = configure_profiles(config, apps)
    backup = None
    if args.apply:
        backup = args.config.with_name("config.before-ctrlclick-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".json")
        with backup.open("xb") as stream:
            stream.write(original)
        fd, temp_name = tempfile.mkstemp(prefix="config.ctrlclick-", suffix=".tmp", dir=args.config.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as stream:
                json.dump(updated, stream, ensure_ascii=False, indent=2)
                stream.write("\n")
            os.replace(temp_name, args.config)
        finally:
            if os.path.exists(temp_name):
                os.unlink(temp_name)
    print(json.dumps({"applied": args.apply, "profiles": names, "apps": apps,
                      "backup": str(backup) if backup else None,
                      "default_preserved": updated.get("profiles", {}).get("default") == config.get("profiles", {}).get("default"),
                      "settings_preserved": updated.get("settings") == config.get("settings"),
                      "version_preserved": updated.get("version") == config.get("version")}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

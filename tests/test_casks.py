"""Run the real cask tasks/module against a local Brew fixture, without installs."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]


class Casks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-cask-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.log = self.base / "calls.jsonl"
        self.metadata = self.base / "casks.json"
        self.metadata.write_text('{"casks": []}')
        brew = self.bin / "brew"
        brew.write_text("#!/usr/bin/env python3\n" + '''
import json, os, sys
from pathlib import Path
base = Path(os.environ["CASK_FIXTURE"])
args = sys.argv[1:]
with (base / "calls.jsonl").open("a") as log:
    log.write(json.dumps(args) + "\\n")
if args == ["--version"]:
    print("Homebrew 5.0.0")
elif args[:3] == ["info", "--json=v2", "--cask"]:
    if (base / "bad-info").exists():
        sys.exit("metadata failure")
    print((base / "casks.json").read_text())
elif args[:2] == ["list", "--cask"]:
    sys.exit(0 if (base / ("installed-" + args[2].replace("/", "_"))).exists() else 1)
elif args[:2] == ["install", "--cask"]:
    name = args[2]
    if (base / "fail-install").exists():
        sys.exit("download failure")
    cask = next(c for c in json.loads((base / "casks.json").read_text())["casks"]
                if c["full_token"] == name)
    for artifact in cask["artifacts"]:
        if "app" in artifact and Path(artifact["target"]).exists():
            sys.exit(f"Error: {name}: It seems there is already an App at '{artifact['target']}'.")
    (base / ("installed-" + name.replace("/", "_"))).touch()
else:
    sys.exit("unexpected Brew command: " + repr(args))
''')
        brew.chmod(0o755)
        # Keep the production cask block and real Ansible modules; isolate only
        # OS facts, package manager and paths from the developer's Mac.
        source = (ROOT / "dependencies.yaml").read_text()
        start = source.index("    - name: Install missing macOS apps and fonts\n")
        end = source.index("\n    - name:", start + 1)
        tasks = self.base / "cask-tasks.yaml"
        tasks.write_text(textwrap.dedent(source[start:end]))
        self.play = {
            "hosts": "localhost", "connection": "local", "gather_facts": False,
            "vars": {"ansible_facts": {"system": "Darwin"},
                     "ansible_python_interpreter": "{{ ansible_playbook_python }}",
                     "home_dir": str(self.home)},
            "environment": {"PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                            "CASK_FIXTURE": str(self.base)},
            "module_defaults": {"community.general.homebrew_cask": {"path": str(self.bin)}},
            "tasks": [{"ansible.builtin.import_tasks": str(tasks)}],
        }
        self.env = dict(os.environ, ANSIBLE_HOME=str(self.base / "ansible"),
                        ANSIBLE_LOCAL_TEMP=str(self.base / "ansible-local"),
                        ANSIBLE_REMOTE_TEMP=str(self.base / "ansible-remote"),
                        ANSIBLE_NOCOLOR="1")

    def app(self, name, bundle, present=False, user_app=False):
        target = self.base / "Applications" / bundle
        if present:
            actual = self.home / "Applications" / bundle if user_app else target
            (actual / "Contents").mkdir(parents=True)
            (actual / "Contents/Info.plist").write_bytes(
                plistlib.dumps({"CFBundleIdentifier": "test." + name}))
        return {"full_token": name, "artifacts": [{"app": [bundle], "target": str(target)}]}

    def run_casks(self, casks, fail=False, check=False):
        self.metadata.write_text(json.dumps({"casks": casks}))
        self.play["vars"]["cask_packages"] = [c["full_token"] for c in casks]
        path = self.base / "play.yaml"
        path.write_text(json.dumps([self.play]))
        args = ["ansible-playbook", "-i", "localhost,", "-c", "local", str(path)]
        if check:
            args.append("--check")
        result = subprocess.run(args, env=self.env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=90)
        self.assertEqual(result.returncode != 0, fail, result.stdout[-8000:])
        return result.stdout

    def installs(self):
        if not self.log.exists():
            return []
        return [args for line in self.log.read_text().splitlines()
                if (args := json.loads(line))[:2] == ["install", "--cask"]]

    def test_manual_apps_missing_apps_fonts_and_repeat(self):
        iterm = self.app("iterm2", "iTerm.app", present=True)
        zen = self.app("zen", "Zen.app", present=True, user_app=True)
        missing = self.app("hammerspoon", "Hammerspoon.app")
        font = {"full_token": "font-test", "artifacts": [{"font": ["Test.ttf"]}]}
        casks = [iterm, zen, missing, font]
        plist = Path(iterm["artifacts"][0]["target"]) / "Contents/Info.plist"
        before = plist.read_bytes()
        self.run_casks(casks)
        self.assertEqual({args[2] for args in self.installs()}, {"hammerspoon", "font-test"})
        self.assertEqual(plist.read_bytes(), before)
        self.assertIn("changed=0", self.run_casks(casks))
        self.assertEqual(len(self.installs()), 2)

    def test_fonts_only_empty_selection_and_check_mode(self):
        font = {"full_token": "font-test", "artifacts": [{"font": ["Test.ttf"]}]}
        self.run_casks([font], check=True)
        self.assertEqual(self.installs(), [])
        self.run_casks([font])
        self.assertEqual(len(self.installs()), 1)
        self.run_casks([])
        self.assertEqual(len(self.installs()), 1)

    def test_real_errors_and_incomplete_bundles_are_not_ignored(self):
        app = self.app("iterm2", "iTerm.app")
        Path(app["artifacts"][0]["target"]).mkdir(parents=True)
        output = self.run_casks([app], fail=True)
        self.assertIn("already an App", output)
        self.assertFalse((self.base / "installed-iterm2").exists())
        (self.base / "bad-info").touch()
        self.assertIn("metadata failure", self.run_casks([app], fail=True))
        (self.base / "bad-info").unlink()
        (self.base / "fail-install").touch()
        self.assertIn("download failure", self.run_casks([app], fail=True))

    def test_all_bundles_of_a_cask_must_exist(self):
        cask = self.app("two-apps", "First.app", present=True)
        cask["artifacts"] += self.app("two-apps", "Second.app")["artifacts"]
        self.run_casks([cask], fail=True)
        self.assertEqual(len(self.installs()), 1)
        second = Path(cask["artifacts"][1]["target"]) / "Contents"
        second.mkdir(parents=True)
        (second / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "test.second"}))
        self.assertIn("changed=0", self.run_casks([cask]))
        self.assertEqual(len(self.installs()), 1)

    def test_arch_skips_homebrew(self):
        self.play["vars"]["ansible_facts"]["system"] = "Linux"
        self.run_casks([self.app("iterm2", "iTerm.app")])
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()

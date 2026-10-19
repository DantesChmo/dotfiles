"""Compile temporary native fixtures; never run binaries or start services."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.uname().sysname == "Darwin", "Apple toolchain integration")
class NativeBuilds(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-native-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.fakebin = self.base / "stale-toolchain"
        self.fakebin.mkdir()
        for name in ("clang", "ld"):
            tool = self.fakebin / name
            tool.write_text("#!/bin/sh\necho unexpected-stale-tool >&2\nexit 99\n")
            tool.chmod(0o755)
        self.env = dict(os.environ,
                        PATH=str(self.fakebin) + os.pathsep + os.environ["PATH"],
                        SDKROOT=str(self.base / "stale-sdk"),
                        TOOLCHAINS="invalid-test-toolchain",
                        ANSIBLE_HOME=str(self.base / "ansible"),
                        ANSIBLE_LOCAL_TEMP=str(self.base / "ansible-local"),
                        ANSIBLE_REMOTE_TEMP=str(self.base / "ansible-remote"))

    def task(self, name):
        source = (ROOT / "dependencies.yaml").read_text()
        start = source.index("    - name: " + name + "\n")
        boundaries = [source.find(marker, start + 1)
                      for marker in ("\n    - name:", "\n  tasks:")]
        end = min(value for value in boundaries if value != -1)
        return textwrap.dedent(source[start:end])

    def run_tasks(self, names, fail=False, env=None):
        tasks = self.base / "tasks.yaml"
        tasks.write_text("\n".join(self.task(name) for name in names))
        # Resolve ansible-playbook before exposing the poisoned build PATH.
        ansible = shutil.which("ansible-playbook")
        self.assertIsNotNone(ansible, "Install Ansible to run native build tests")
        play = [{"hosts": "localhost", "connection": "local", "gather_facts": False,
                 "vars": {"ansible_python_interpreter": "{{ ansible_playbook_python }}",
                          "ansible_facts": {"system": "Darwin"},
                          "swipe_source": str(self.base / "swipe")},
                 "tasks": [{"ansible.builtin.import_tasks": str(tasks)}]}]
        path = self.base / "play.json"
        path.write_text(json.dumps(play))
        result = subprocess.run([ansible, "-i", "localhost,", "-c", "local", str(path)],
                                env=dict(self.env, **(env or {})), stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=90)
        self.assertEqual(result.returncode != 0, fail, result.stdout[-8000:])
        return result.stdout

    def test_helper_and_upstream_cc_override_ignore_stale_tools_and_sdk(self):
        helper = self.base / "configs/.config/sketchybar/helper"
        shutil.copytree(ROOT / "configs/.config/sketchybar/helper", helper,
                        ignore=shutil.ignore_patterns("sketchybar_metrics", "*.o"))
        # Model the upstream makefile's unconditional CC=clang assignment.
        # A make environment variable alone would lose to that assignment.
        swipe = self.base / "swipe"
        swipe.mkdir()
        (swipe / "main.m").write_text("#import <Cocoa/Cocoa.h>\nint main(void) { return 0; }\n")
        (swipe / "Makefile").write_text("CC = clang\nbundle: main.m\n"
                                       "\t$(CC) main.m -o swipe -framework Cocoa\n")
        self.run_tasks(["Build SketchyBar helper for this Mac",
                        "Build AeroSpace Swipe app without starting it"])
        for binary in (helper / "sketchybar_metrics", swipe / "swipe"):
            self.assertTrue(binary.exists())
            result = subprocess.run(["/usr/bin/file", str(binary)], text=True,
                                    stdout=subprocess.PIPE, check=True)
            self.assertIn("Mach-O", result.stdout)

    def test_preflight_links_and_reports_broken_developer_tools(self):
        name = "Verify macOS compiler and SDK can link native programs"
        output = self.run_tasks([name])
        self.assertIn("changed=0", output)
        output = self.run_tasks([name], fail=True,
                                env={"DEVELOPER_DIR": str(self.base / "missing-developer")})
        self.assertIn("Update Xcode/Command Line Tools", output)
        self.assertIn("No dotfiles have been activated", output)


if __name__ == "__main__":
    unittest.main()

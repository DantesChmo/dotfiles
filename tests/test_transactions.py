"""Exercise the real YAML and GNU Stow without installing any OS packages."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import plistlib


ROOT = Path(__file__).resolve().parents[1]


class Transactions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-transaction-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / "repo"
        self.home = self.base / "home"
        self.state = self.base / "state"
        self.payload = self.repo / "configs/.config/demo"
        self.payload.mkdir(parents=True)
        self.home.mkdir()
        self.source = self.payload / "init.conf"
        self.source.write_text("version one\n")
        (self.payload / ".env").write_text("test-only private fixture\n")
        (self.repo / "configs/.demorc").write_text("root config\n")
        for name in ("Makefile", "dependencies.yaml"):
            shutil.copy(ROOT / name, self.repo / name)
        shutil.copy(ROOT / "configs/.stow-local-ignore", self.repo / "configs/.stow-local-ignore")
        self.env = dict(os.environ, TARGET=str(self.home), STATE_DIR=str(self.state),
                        DOTFILES_ROOT=str(self.repo), DOTFILES_STATE_DIR=str(self.state),
                        DOTFILES_CONFLICTS="backup", ANSIBLE_HOME=str(self.base / "ansible"),
                        ANSIBLE_LOCAL_TEMP=str(self.base / "ansible-local"),
                        ANSIBLE_REMOTE_TEMP=str(self.base / "ansible-remote"),
                        ANSIBLE_DISPLAY_OK_HOSTS="false", ANSIBLE_DISPLAY_SKIPPED_HOSTS="false")
        # Exercise the actual one-command Make workflow with an empty dependency
        # set; bootstrap tools must already exist in the test environment.
        self.env["ANSIBLE_FLAGS"] = "-e '{\"dependency_sets\":{\"stow\":{\"brew\":[],\"pacman\":[]}}}'"

    def command(self, argv, fail=False, env=None):
        result = subprocess.run(argv, cwd=self.repo, env=dict(self.env, **(env or {})),
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                timeout=180)
        self.assertEqual(result.returncode != 0, fail, result.stdout[-8000:])
        return result.stdout

    def action(self, name, fail=False, env=None, extra=None):
        variables = {"dotfiles_action": name, "dotfiles_owner_pid": os.getpid(),
                     "dotfiles_paths": [".config/demo", ".demorc"],
                     "dotfiles_configs": ["demo", "demorc"]}
        variables.update(extra or {})
        return self.command(["ansible-playbook", "-i", "localhost,", "-c", "local",
                             str(self.repo / "dependencies.yaml"), "--tags", "transaction",
                             "--extra-vars", json.dumps(variables)], fail=fail, env=env)

    def latest(self):
        return Path((self.state / "latest").read_text())

    def assert_unlocked(self):
        self.assertFalse((self.state / "pending").exists())
        self.assertFalse((self.state / "lock").exists())

    def test_one_command_versions_idempotence_failure_and_rollback(self):
        old = self.home / ".config/demo"
        old.mkdir(parents=True)
        (old / "original").write_text("preserve me\n")
        (self.home / ".demorc").symlink_to("missing-original")
        (self.home / ".config/unrelated").write_text("keep\n")

        self.command(["make", "install"])
        first = self.latest()
        first_link = (old / "init.conf").readlink()
        self.assertEqual((old / "init.conf").read_text(), "version one\n")
        self.assertFalse((old / ".env").exists())
        self.assertTrue((first / "originals/.demorc").is_symlink())
        self.assertEqual((first / "originals/.config/demo/original").read_text(), "preserve me\n")
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o700)

        count = len(list(self.state.glob("transaction-*")))
        self.command(["make", "install"])
        self.assertEqual(self.latest(), first)
        self.assertEqual((old / "init.conf").readlink(), first_link)
        self.assertEqual(len(list(self.state.glob("transaction-*"))), count)

        self.source.write_text("version two\n")
        self.assertEqual((old / "init.conf").read_text(), "version one\n")
        self.action("install", fail=True, env={"POST_INSTALL_demo": "false"})
        self.assertEqual((old / "init.conf").read_text(), "version one\n")
        self.assertEqual(self.latest(), first)
        self.assert_unlocked()

        self.action("install")
        second = self.latest()
        self.assertNotEqual(second, first)
        self.assertEqual((old / "init.conf").read_text(), "version two\n")
        (old / "local-note").write_text("keep later edits\n")
        self.command(["make", "rollback"])
        self.assertEqual((old / "init.conf").read_text(), "version one\n")
        self.assertEqual((second / "displaced/.config/demo/local-note").read_text(), "keep later edits\n")
        self.command(["make", "rollback"])
        self.assertEqual((old / "original").read_text(), "preserve me\n")
        self.assertEqual((self.home / ".demorc").readlink(), Path("missing-original"))
        self.assertEqual((self.home / ".config/unrelated").read_text(), "keep\n")
        self.assertFalse((self.state / "latest").exists())
        self.assert_unlocked()

    def test_empty_home_failure_and_parent_conflicts(self):
        self.action("install", fail=True, env={"POST_INSTALL_demo": "false"})
        self.assertEqual(list(self.home.iterdir()), [])
        self.assert_unlocked()
        (self.home / ".config").symlink_to("missing-parent")
        self.action("preflight", fail=True)
        self.assertEqual((self.home / ".config").readlink(), Path("missing-parent"))
        (self.home / ".config").unlink()
        (self.home / ".config").write_text("not a directory\n")
        self.action("preflight", fail=True)
        self.assertEqual((self.home / ".config").read_text(), "not a directory\n")

    def test_foreign_directory_symlink_and_strict_conflicts(self):
        external = self.base / "external"
        external.mkdir()
        (external / "untouched").write_text("external contents\n")
        (self.home / ".config").mkdir()
        (self.home / ".config/demo").symlink_to(external, target_is_directory=True)
        self.command(["make", "install", "CONFLICTS=abort"], fail=True)
        self.assertFalse(self.state.exists())
        self.action("install")
        self.assertEqual((external / "untouched").read_text(), "external contents\n")
        self.action("rollback")
        self.assertEqual((self.home / ".config/demo").readlink(), external)
        self.assert_unlocked()

    def test_dependency_failure_leaves_existing_configs_untouched(self):
        (self.home / ".demorc").write_text("existing config\n")
        playbook = self.repo / "dependencies.yaml"
        playbook.write_text(playbook.read_text().replace(
            "  tasks:\n", "  tasks:\n    - name: Simulated dependency failure\n"
            "      ansible.builtin.fail:\n        msg: test failure before activation\n"
            "      tags: deps\n", 1))
        self.command(["make", "install"], fail=True)
        self.assertEqual((self.home / ".demorc").read_text(), "existing config\n")
        self.assertEqual(list(self.home.iterdir()), [self.home / ".demorc"])
        self.assertFalse(self.state.exists())

    def test_permission_only_changes_create_a_restorable_release(self):
        self.source.chmod(0o644)
        self.action("install")
        first = self.latest()
        self.source.chmod(0o755)
        self.action("install")
        self.assertNotEqual(self.latest(), first)
        active = self.home / ".config/demo/init.conf"
        self.assertEqual(active.stat().st_mode & 0o777, 0o755)
        self.action("rollback")
        self.assertEqual(active.stat().st_mode & 0o777, 0o644)

    @unittest.skipUnless(os.uname().sysname == "Darwin", "macOS-specific generated config")
    def test_generated_desktop_config_drift_and_preference_rollback(self):
        # Mock only the macOS preferences CLI. Stow, Ansible, plist generation,
        # journal, backups and restore all run normally in the temporary HOME.
        fakebin = self.base / "bin"
        fakebin.mkdir()
        defaults = fakebin / "defaults"
        defaults.write_text("#!/usr/bin/env python3\n"
                            "import os,sys\nfrom pathlib import Path\n"
                            "p=Path(os.environ['HOME'])/'preferences-fixture'\n"
                            "if sys.argv[1]=='read':\n"
                            " if not p.exists(): sys.exit(1)\n"
                            " print(p.read_text())\n"
                            "elif sys.argv[1]=='write': p.write_text(sys.argv[4])\n"
                            "elif p.exists(): p.unlink()\n")
        defaults.chmod(0o755)
        self.env.update(HOME=str(self.home), PATH=str(fakebin) + os.pathsep + self.env["PATH"],
                        XDG_DATA_HOME=str(self.base / "data with & space"))
        for name in ("hammerspoon", "aerospace-swipe"):
            directory = self.repo / "configs/.config" / name
            directory.mkdir()
            (directory / "fixture.conf").write_text("test config\n")
        preference = self.home / "preferences-fixture"
        preference.write_text("original-config-path")
        agent = self.home / "Library/LaunchAgents/com.acsandmann.swipe.plist"
        agent.parent.mkdir(parents=True)
        agent.write_text("original agent\n")
        extra = {"dotfiles_paths": [".config/demo", ".demorc", ".config/hammerspoon", ".config/aerospace-swipe"],
                 "dotfiles_configs": ["demo", "demorc", "hammerspoon", "aerospace-swipe"]}
        self.action("install", extra=extra)
        first = self.latest()
        self.assertEqual(preference.read_text(), str(self.home / ".config/hammerspoon/init.lua"))
        args = plistlib.loads(agent.read_bytes())["ProgramArguments"]
        self.assertIn("data with & space", args[0])
        self.action("install", extra=extra)
        self.assertEqual(self.latest(), first)
        preference.write_text("later-preference")
        agent.write_text("later agent\n")
        self.action("install", extra=extra)
        self.assertNotEqual(self.latest(), first)
        self.action("rollback", extra=extra)
        self.assertEqual(preference.read_text(), "later-preference")
        self.assertEqual(agent.read_text(), "later agent\n")
        self.action("rollback", extra=extra)
        self.assertEqual(preference.read_text(), "original-config-path")
        self.assertEqual(agent.read_text(), "original agent\n")
        self.assert_unlocked()

    def test_interrupted_transaction_recovery_and_live_lock(self):
        self.action("install")
        first = self.latest()
        self.source.write_text("version two\n")
        self.action("install")
        interrupted = self.latest()
        manifest = json.loads((interrupted / "manifest.json").read_text())
        manifest["status"] = "pending"
        (interrupted / "manifest.json").write_text(json.dumps(manifest))
        (self.state / "pending").write_text(str(interrupted))
        (self.state / "latest").write_text(str(first))
        (self.state / "lock").mkdir()
        (self.state / "lock/owner").write_text(str(os.getpid()))
        self.action("recover", fail=True)
        self.action("install", fail=True)
        self.assertTrue((self.state / "lock").exists())
        # Simulate interruption in the middle of a rollback: one root is already
        # restored, the other still needs to be displaced/restored.
        (self.home / ".config/demo").rename(interrupted / "displaced/.config/demo")
        (interrupted / "originals/.config/demo").rename(self.home / ".config/demo")
        (self.state / "lock/owner").write_text("2147483647")
        self.action("recover")
        self.assertEqual(self.latest(), first)
        self.assertEqual((self.home / ".config/demo/init.conf").read_text(), "version one\n")
        self.assert_unlocked()
        self.action("recover")
        self.assertEqual(self.latest(), first)
        self.assert_unlocked()

        self.action("install")
        committed = self.latest()
        (self.state / "pending").write_text(str(committed))
        (self.state / "latest").write_text(str(first))
        (self.state / "lock").mkdir()
        (self.state / "lock/owner").write_text("2147483647")
        self.action("recover")
        self.assertEqual(self.latest(), committed)
        self.assertEqual((self.home / ".config/demo/init.conf").read_text(), "version two\n")
        self.assert_unlocked()


if __name__ == "__main__":
    unittest.main()

"""Verify sync and explicit startup without opening any real applications."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class Startup(unittest.TestCase):
    def test_sync_skips_startup_unless_explicitly_requested(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            makefile = fixture / "Makefile"
            makefile.write_text((ROOT / "Makefile").read_text() +
                                '\ninstall:\n\t@printf "startup=%s\\n" "$(START)"\n')
            for args, expected in (([], "startup=0"), (["START=1"], "startup=1")):
                result = subprocess.run(["make", "-s", "-o", "ansible", "-o", "stow", "sync", *args],
                                        cwd=fixture, text=True, capture_output=True, check=True)
                self.assertEqual(result.stdout.strip(), expected)

    @unittest.skipUnless(os.uname().sysname == "Darwin", "macOS app startup")
    def test_running_apps_are_not_reopened(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            for name in ("hammerspoon", "iterm2"):
                (fixture / "configs/.config" / name).mkdir(parents=True)
            shutil.copy(ROOT / "Makefile", fixture / "Makefile")
            bin_dir = fixture / "bin"
            bin_dir.mkdir()
            for name, content in {
                "pgrep": '#!/bin/sh\nexit "$TEST_APP_STATUS"\n',
                "open": '#!/bin/sh\nprintf "%s\\n" "$*"\n',
            }.items():
                path = bin_dir / name
                path.write_text(content)
                path.chmod(0o755)
            for status in ("0", "1"):
                result = subprocess.run(["make", "-s", "start-hammerspoon", "start-iterm2"],
                                        cwd=fixture, env=dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
                                                             TEST_APP_STATUS=status),
                                        capture_output=True, text=True, check=True)
                self.assertEqual(result.stdout, "" if status == "0" else "-gj -a Hammerspoon\n-a iTerm\n")


if __name__ == "__main__":
    unittest.main()

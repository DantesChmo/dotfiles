"""Check bootstrap recovery with real Neovim/libuv and temporary lock files."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("nvim"), "Neovim is required")
class NvimBootstrap(unittest.TestCase):
    def test_abandoned_live_and_invalid_mason_locks(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-mason-lock-test-") as directory:
            base = Path(directory)
            dead = subprocess.Popen(["/usr/bin/true"])
            dead.wait()
            script = base / "check.lua"
            script.write_text('''
local path = vim.env.TEST_LOCK
-- Only the Mason path provider is a fixture; ownership and signals use libuv.
package.preload["mason-core.installer.InstallLocation"] = function()
  return { global = function() return { lockfile = function() return path end } end }
end
local bootstrap = dofile(vim.env.TEST_BOOTSTRAP)
bootstrap.clear_stale_mason_lock("fixture")
vim.fn.writefile({ vim.env.TEST_DEAD_PID }, path)
bootstrap.clear_stale_mason_lock("fixture")
assert(vim.fn.filereadable(path) == 0, "Dead owner was not recovered")
vim.fn.writefile({ tostring(vim.fn.getpid()) }, path)
assert(not pcall(bootstrap.clear_stale_mason_lock, "fixture"))
assert(vim.fn.filereadable(path) == 1, "Live owner lock was removed")
vim.fn.writefile({ "" }, path)
assert(not pcall(bootstrap.clear_stale_mason_lock, "fixture"))
assert(vim.fn.filereadable(path) == 1, "Unidentified owner lock was removed")
vim.cmd("qa!")
''')
            env = dict(os.environ, HOME=str(base), XDG_CONFIG_HOME=str(base / "config"),
                       XDG_DATA_HOME=str(base / "data"), XDG_STATE_HOME=str(base / "state"),
                       XDG_CACHE_HOME=str(base / "cache"), TEST_SCRIPT=str(script),
                       TEST_LOCK=str(base / "fixture.lock"), TEST_DEAD_PID=str(dead.pid),
                       TEST_BOOTSTRAP=str(ROOT / "configs/.config/nvim/lua/config/bootstrap.lua"))
            result = subprocess.run([shutil.which("nvim"), "--clean", "--headless", "-i", "NONE",
                                     "+lua dofile(vim.env.TEST_SCRIPT)"], env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()

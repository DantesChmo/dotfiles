"""Workspace actions, without starting SketchyBar/AeroSpace."""
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "configs/.config/sketchybar"


class SketchyBar(unittest.TestCase):
    def plugin(self, *args, focused="1", layout="h_tiles", fullscreen="false", event_focus=""):
        # Bash functions take precedence over the real programs in plugin PATH.
        script = r'''
        aerospace() {
          printf 'aerospace %s\n' "$*" >&3
          case "$*" in
            'list-workspaces --focused') printf '%s\n' "$TEST_FOCUS" ;;
            *workspace-root-container-layout*) printf '%s\n' "$TEST_LAYOUT" ;;
            *window-is-fullscreen*) printf '%s\n' "$TEST_FULLSCREEN" ;;
          esac
        }
        sketchybar() { printf 'sketchybar %s\n' "$*" >&3; }
        export -f aerospace sketchybar
        /bin/bash "$@" 3>&2
        '''
        result = subprocess.run(["/bin/bash", "-c", script, "test",
                                 str(CONFIG / "plugins/aerospace.sh"), *args],
                                env=dict(os.environ, TEST_FOCUS=focused, TEST_LAYOUT=layout,
                                         TEST_FULLSCREEN=fullscreen, FOCUSED_WORKSPACE=event_focus),
                                text=True, capture_output=True, check=True)
        return result.stderr

    def test_startup_renders_current_workspace(self):
        output = self.plugin("render", focused="2", layout="v_tiles", fullscreen="true")
        self.assertIn("--set space.2 label.color=0xff000000", output)
        self.assertIn("--set space.2.mode label=\uf0c9", output)
        self.assertIn("--set space.2.fs label=\uf065", output)
        self.assertEqual(output.count("sketchybar "), 1)
        self.assertIn("--set ws.2 background.color=0xffffffff", output)
        patterns = [part.split("/", 1)[0] for part in output.split("--set /")[1:]
                    if "label=" in part.split("--set", 1)[0]]
        # Use a BRE engine like SketchyBar's, so a non-matching extended
        # alternation cannot silently leave icons on inactive workspaces.
        for suffix in ("mode", "fs"):
            for sid in range(1, 10):
                item = f"space.{sid}.{suffix}\n"
                self.assertTrue(any(subprocess.run(["grep", "-x", "-e", pattern],
                                                   input=item, text=True,
                                                   stdout=subprocess.DEVNULL).returncode == 0
                                    for pattern in patterns), item)

    def test_event_uses_supplied_focus(self):
        output = self.plugin("render", focused="2", event_focus="1")
        self.assertNotIn("aerospace list-workspaces --focused\n", output)
        self.assertIn("--set space.1 label.color=0xff000000", output)

    def test_inactive_zone_switches_workspace(self):
        for zone in ("num", "mode", "fs"):
            output = self.plugin("2", "click:" + zone)
            self.assertIn("aerospace workspace 2", output)
            self.assertNotIn("--trigger", output)

    def test_active_layout_cycle_and_fullscreen(self):
        for layout, next_layout in (("h_tiles", "v_tiles"), ("v_tiles", "h_accordion"),
                                    ("h_accordion", "h_tiles")):
            output = self.plugin("1", "click:mode", layout=layout)
            self.assertIn("aerospace layout " + next_layout, output)
            self.assertIn("--trigger aerospace_workspace_change FOCUSED_WORKSPACE=1", output)
        self.assertIn("aerospace fullscreen off", self.plugin("1", "click:fs"))
        self.assertEqual(self.plugin("1", "click:num").count("sketchybar "), 0)


if __name__ == "__main__":
    unittest.main()

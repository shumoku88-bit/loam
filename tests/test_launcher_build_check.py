#!/usr/bin/env python3
"""Launcher freshness regression; fake executables and Lake, no household data."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent


class LauncherBuildCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="loam-launcher-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for directory in ("tools", "Loam/Tui", "Loam/Tests", ".lake/build/bin", "fake-bin"):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO / "tools/loam", self.root / "tools/loam")
        self.source = self.root / "Loam/Cli.lean"
        self.source.write_text("import Loam.Tui.Main\n")
        (self.root / "Loam/Tui/Main.lean").write_text("-- dependency\n")
        (self.root / "Loam/Tui/terminal_native.c").write_text("/* native */\n")
        for name in ("lakefile.lean", "lean-toolchain", "lake-manifest.json"):
            (self.root / name).write_text("fixture\n")
        self.bin = self.root / ".lake/build/bin/loam"
        self.bin.write_text('#!/bin/sh\nprintf "ran:%s\\n" "$*"\n')
        self.bin.chmod(0o755)
        self.rsp = Path(str(self.bin) + ".rsp")
        self.rsp.write_text('"' + str(self.root / '.lake/build/ir/Loam/Cli.c.o.export') + '"\n'
                            '".lake/build/ir/Loam/Tui/Main.c.o.export"\n')
        for path in self.root.rglob("*"):
            if path.is_file():
                os.utime(path, (1000, 1000))
        os.utime(self.bin, (2000, 2000))
        lake = self.root / "fake-bin/lake"
        lake.write_text('#!/bin/sh\necho "$*" >> "$BUILD_LOG"\nexit "${BUILD_EXIT:-0}"\n')
        lake.chmod(0o755)
        self.log = self.root / "build.log"
        self.env = dict(os.environ, PATH=str(lake.parent) + os.pathsep + os.environ["PATH"],
                        BUILD_LOG=str(self.log), LOAM_FORCE_BUILD="0")

    def run_launcher(self, builds):
        result = subprocess.run(["bash", str(self.root / "tools/loam"), "doctor", "example"],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "ran:doctor example\n")
        self.assertEqual(self.log.exists(), builds)
        if builds:
            self.assertEqual(self.log.read_text(), "build loam\n")

    def test_current_binary_skips_lake(self):
        self.run_launcher(False)

    def test_unrelated_new_test_skips_lake(self):
        (self.root / "Loam/Tests/New.lean").write_text("-- not linked\n")
        self.run_launcher(False)

    def test_imported_sources_trigger_build(self):
        for path in (self.source, self.root / "Loam/Tui/Main.lean"):
            with self.subTest(path=path):
                os.utime(path, (3000, 3000))
                self.run_launcher(True)
                self.log.unlink()
                os.utime(path, (1000, 1000))

    def test_deleted_source_triggers_build(self):
        self.source.unlink()
        self.run_launcher(True)

    def test_missing_or_empty_inventory_triggers_build(self):
        self.rsp.unlink()
        self.run_launcher(True)
        self.log.unlink()
        self.rsp.write_text("")
        self.run_launcher(True)

    def test_build_inputs_trigger_build(self):
        for name in ("lakefile.lean", "lean-toolchain", "lake-manifest.json", "Loam/Tui/terminal_native.c"):
            with self.subTest(name=name):
                path = self.root / name
                os.utime(path, (3000, 3000))
                self.run_launcher(True)
                self.log.unlink()
                os.utime(path, (1000, 1000))

    def test_forced_build(self):
        self.env["LOAM_FORCE_BUILD"] = "1"
        self.run_launcher(True)

    def test_missing_binary_builds_and_propagates_failure(self):
        self.bin.unlink()
        self.env["BUILD_EXIT"] = "7"
        result = subprocess.run(["bash", str(self.root / "tools/loam")], env=self.env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.log.read_text(), "build loam\n")
        self.assertNotIn("ran:", result.stdout)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Launcher check convergence; fake boundaries plus real Lake, no household data."""
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent


class LauncherBuildCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="loam-launcher-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
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
        self.bin.write_text('#!/bin/sh\n# fixture\nprintf "ran:%s\\n" "$*"\n')
        self.bin.chmod(0o755)
        self.rsp = Path(str(self.bin) + ".rsp")
        self.rsp.write_text('"' + str(self.root / '.lake/build/ir/Loam/Cli.c.o.export') + '"\n'
                            '".lake/build/ir/Loam/Tui/Main.c.o.export"\n')
        for path in self.root.rglob("*"):
            if path.is_file():
                os.utime(path, (1000, 1000))
        os.utime(self.bin, (2000, 2000))
        lake = self.root / "fake-bin/lake"
        lake.write_text('#!/bin/sh\necho "$*" >> "$BUILD_LOG"\n'
                        'if [ -n "${BUILD_EDIT:-}" ]; then\n'
                        '  printf "%s" "$BUILD_EDIT_CONTENT" > "$BUILD_EDIT"\n'
                        'fi\nexit "${BUILD_EXIT:-0}"\n')
        lake.chmod(0o755)
        self.log = self.root / "build.log"
        self.env = dict(os.environ, PATH=str(lake.parent) + os.pathsep + os.environ["PATH"],
                        BUILD_LOG=str(self.log), LOAM_FORCE_BUILD="0")
        self.receipt = Path(str(self.bin) + ".launcher-check")
        self.run_launcher(True)
        self.log.unlink()

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

    def test_successful_noop_build_converges(self):
        self.receipt.unlink()
        os.utime(self.source, (3000, 3000))
        before = self.bin.stat().st_mtime_ns
        self.run_launcher(True)
        self.assertEqual(self.bin.stat().st_mtime_ns, before)
        self.log.unlink()
        self.run_launcher(False)

    def test_unrelated_new_test_skips_lake(self):
        (self.root / "Loam/Tests/New.lean").write_text("-- not linked\n")
        self.run_launcher(False)

    def test_imported_sources_trigger_build(self):
        for path in (self.source, self.root / "Loam/Tui/Main.lean"):
            with self.subTest(path=path):
                original = path.read_text()
                path.write_text(original + "-- changed\n")
                self.run_launcher(True)
                self.log.unlink()
                path.write_text(original)

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
                original = path.read_text()
                path.write_text(original + "changed\n")
                self.run_launcher(True)
                self.log.unlink()
                path.write_text(original)

    def test_timestamp_only_changes_skip_lake(self):
        for path in (self.source, self.root / "lakefile.lean", self.rsp):
            os.utime(path, None)
        self.run_launcher(False)

    def test_content_change_with_restored_mtime_triggers_build(self):
        stamp = self.source.stat()
        self.source.write_text("import Loam.Tui.Other\n")
        os.utime(self.source, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
        self.run_launcher(True)
        self.log.unlink()
        self.run_launcher(False)

    def test_binary_edit_with_restored_mtime_triggers_build(self):
        stamp = self.bin.stat()
        self.bin.write_text(self.bin.read_text().replace("# fixture", "# changed"))
        self.assertEqual(self.bin.stat().st_size, stamp.st_size)
        os.utime(self.bin, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
        self.run_launcher(True)
        self.log.unlink()
        self.run_launcher(False)

    def test_replaced_binary_triggers_build(self):
        replacement = self.bin.with_suffix(".replacement")
        shutil.copy2(self.bin, replacement)
        replacement.replace(self.bin)
        self.run_launcher(True)

    def test_changed_inventory_triggers_build(self):
        (self.root / "Loam/Tui/Other.lean").write_text("-- new dependency\n")
        with self.rsp.open("a") as output:
            output.write('\".lake/build/ir/Loam/Tui/Other.c.o.export\"\n')
        self.run_launcher(True)
        self.log.unlink()
        self.run_launcher(False)
        (self.root / "Loam/Tui/Other.lean").write_text("-- changed dependency\n")
        self.run_launcher(True)

    def test_changed_inputs_during_build_do_not_earn_receipt(self):
        self.source.write_text("-- trigger build\n")
        self.env.update(BUILD_EDIT=str(self.source), BUILD_EDIT_CONTENT="-- concurrent edit\n")
        self.run_launcher(True)
        self.assertFalse(self.receipt.exists())
        self.log.unlink()
        self.env.pop("BUILD_EDIT")
        self.env.pop("BUILD_EDIT_CONTENT")
        self.run_launcher(True)
        self.log.unlink()
        self.run_launcher(False)

    def test_failed_check_invalidates_receipt_and_retries(self):
        self.env.update(LOAM_FORCE_BUILD="1", BUILD_EXIT="7")
        result = subprocess.run(["bash", str(self.root / "tools/loam")], env=self.env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("ran:", result.stdout)
        self.assertFalse(self.receipt.exists())
        self.log.unlink()
        self.env.update(LOAM_FORCE_BUILD="0", BUILD_EXIT="0")
        self.run_launcher(True)
        self.log.unlink()
        self.run_launcher(False)

    def test_missing_hash_tool_falls_back_to_lake(self):
        fake_bin = self.root / "fake-bin"
        for command in ("bash", "dirname", "uname", "stat", "rm", "mktemp", "mv", "cat"):
            (fake_bin / command).symlink_to(shutil.which(command))
        self.env["PATH"] = str(fake_bin)
        self.run_launcher(True)
        self.assertFalse(self.receipt.exists())
        self.log.unlink()
        self.run_launcher(True)

    def test_corrupt_receipt_triggers_build(self):
        self.receipt.write_text("incomplete check\n")
        self.run_launcher(True)

    def test_forced_build(self):
        self.env["LOAM_FORCE_BUILD"] = "1"
        self.run_launcher(True)
        self.log.unlink()
        self.run_launcher(True)

    def test_missing_binary_builds_and_propagates_failure(self):
        self.bin.unlink()
        self.env["BUILD_EXIT"] = "7"
        result = subprocess.run(["bash", str(self.root / "tools/loam")], env=self.env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.log.read_text(), "build loam\n")
        self.assertNotIn("ran:", result.stdout)


@unittest.skipUnless(shutil.which("lake"), "real Lake integration needs the Lean toolchain")
class RealLakeLauncherBuildCheck(unittest.TestCase):
    def test_noop_then_content_edit_with_real_lake(self):
        with tempfile.TemporaryDirectory(prefix="loam-launcher-real-") as directory:
            root = Path(directory).resolve()
            (root / "tools").mkdir()
            (root / "Loam/Tui").mkdir(parents=True)
            shutil.copyfile(REPO / "tools/loam", root / "tools/loam")
            shutil.copyfile(REPO / "lean-toolchain", root / "lean-toolchain")
            (root / "lakefile.lean").write_text(
                'import Lake\nopen Lake DSL\npackage launcherFixture\n'
                'lean_exe loam where\n  root := `Loam.Cli\n')
            (root / "Loam/Tui/terminal_native.c").write_text("/* fixture */\n")
            source = root / "Loam/Cli.lean"
            source.write_text('def main : IO Unit := IO.println "fixture-v1"\n')
            real_lake = shutil.which("lake")
            subprocess.run([real_lake, "build", "loam"], cwd=root, check=True,
                           capture_output=True, text=True)
            binary = root / ".lake/build/bin/loam"
            stamp = binary.stat().st_mtime_ns
            # Reproduce checkout/save mtimes without changing any source content.
            os.utime(source, ns=(stamp + 10_000_000_000, stamp + 10_000_000_000))
            fake_bin = root / "fake-bin"
            fake_bin.mkdir()
            log = root / "lake-calls.log"
            wrapper = fake_bin / "lake"
            wrapper.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> '
                               + shlex.quote(str(log)) + '\nexec '
                               + shlex.quote(real_lake) + ' "$@"\n')
            wrapper.chmod(0o755)
            env = dict(os.environ, PATH=str(fake_bin) + os.pathsep + os.environ["PATH"],
                       LOAM_FORCE_BUILD="0")

            def launch(expected):
                result = subprocess.run(["bash", str(root / "tools/loam")], env=env,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)

            launch("fixture-v1")
            self.assertEqual(binary.stat().st_mtime_ns, stamp, "Lake should be a no-op")
            self.assertEqual(log.read_text(), "build loam\n")
            self.assertTrue(Path(str(binary) + ".launcher-check").exists(),
                            Path(str(binary) + ".rsp").read_text())
            log.unlink()
            launch("fixture-v1")
            self.assertFalse(log.exists(), "second launch must skip Lake")
            # A real content change with old mtime must still compile, then settle.
            source.write_text('def main : IO Unit := IO.println "fixture-v2"\n')
            os.utime(source, ns=(stamp, stamp))
            launch("fixture-v2")
            self.assertEqual(log.read_text(), "build loam\n")
            log.unlink()
            launch("fixture-v2")
            self.assertFalse(log.exists())


if __name__ == "__main__":
    unittest.main()

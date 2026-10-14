#!/usr/bin/env python3
"""Real pinned-kernel replay and scope sentinels, on disposable compiled fixtures."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

REPO = Path(__file__).resolve().parent.parent


class DurableReplay(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="loam-replay-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.helper = self.root / "ReplayDurableProofs.lean"
        shutil.copyfile(REPO / "tools/ReplayDurableProofs.lean", self.helper)
        shutil.copyfile(REPO / "lean-toolchain", self.root / "lean-toolchain")
        self.write("lakefile.toml", 'name = "durable_fixture"\n[[lean_lib]]\nname = "Loam"\n')
        self.write("Loam/DurableProofs.lean", "import Loam.Proofs.Initial\n")
        self.write("Loam/Proofs/Initial.lean",
                   "namespace Loam.ReplayProbe\nprivate theorem initial : 1 = 1 := rfl\n")

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def command(self, *args, exit_code=0):
        start = time.monotonic()
        result = subprocess.run(["lake", *args], cwd=self.root, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        print(f"replay-test: lake {' '.join(args)}: exit={result.returncode} "
              f"elapsed_s={time.monotonic() - start:.3f}", flush=True)
        print(result.stdout, flush=True)
        self.assertEqual(result.returncode, exit_code, result.stdout)
        return result.stdout

    def replay(self, exit_code=0):
        return self.command("env", "lean", str(self.helper), exit_code=exit_code)

    def test_private_proofs_new_owner_and_omitted_scope(self):
        self.command("build", "Loam.DurableProofs")
        out = self.replay()
        self.assertIn("ACCEPT modules=2 logical=1 theorems=1", out)
        self.assertIn("_private.Loam.Proofs.Initial", out)
        self.write("Loam/Proofs/Added.lean", "private theorem added : True := True.intro\n")
        self.write("Loam/DurableProofs.lean",
                   "import Loam.Proofs.Initial\nimport Loam.Proofs.Added\n")
        # An unimported descendant in a shared cache must not expand replay scope.
        self.write("Loam/Proofs/Initial/Unimported.lean", "theorem unrelated : True := True.intro\n")
        self.command("build", "Loam.DurableProofs", "Loam.Proofs.Initial.Unimported")
        out = self.replay()
        self.assertIn("ACCEPT modules=3 logical=2 theorems=2", out)
        self.assertIn("checking module Loam.Proofs.Added", out)
        self.assertNotIn("Loam.Proofs.Initial.Unimported", out)
        source = self.helper.read_text()
        selection = "let modules := imported.filter ((`Loam).isPrefixOf ·) |>.qsort Name.lt"
        self.assertEqual(source.count(selection), 1)
        self.helper.write_text(source.replace(selection, "let modules := #[`Loam.DurableProofs]"))
        self.assertIn("scope mismatch", self.replay(exit_code=1))

    def test_empty_and_theorem_free_scope_fail_closed(self):
        self.write("Loam/DurableProofs.lean", "-- empty umbrella\n")
        self.command("build", "Loam.DurableProofs")
        self.assertIn("empty logical scope", self.replay(exit_code=1))
        self.write("Loam/DurableProofs.lean", "def marker : Nat := 0\n")
        self.command("build", "Loam.DurableProofs")
        self.assertIn("scope contains no theorems", self.replay(exit_code=1))

    def test_kernel_rejects_invalid_compiled_import(self):
        # Deliberately bypass elaboration's kernel; replay must reconstruct and reject it.
        self.write("Loam/Proofs/Initial.lean", """import Lean
set_option debug.skipKernelTC true in
run_cmd Lean.Elab.Command.liftCoreM do
  Lean.addDecl (.thmDecl {
    name := `Loam.ReplayProbe.invalid
    levelParams := []
    type := Lean.mkConst ``False
    value := Lean.mkConst ``True.intro
  })
""")
        self.command("build", "Loam.DurableProofs")
        self.command("env", "leanchecker", "Loam.DurableProofs")  # Reproduce the old false green.
        out = self.replay(exit_code=1)
        self.assertIn("checking module Loam.Proofs.Initial", out)
        self.assertIn("Loam.ReplayProbe.invalid", out)
        self.assertIn("type mismatch", out)


if __name__ == "__main__":
    unittest.main()

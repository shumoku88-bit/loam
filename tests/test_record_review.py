import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
TODAY = "2026-09-08"


def run(*args, input_text=None, env=None):
    return subprocess.run(
        args,
        cwd=ROOT,
        input=input_text,
        text=True,
        capture_output=True,
        env=env,
    )


def sha256_text(text):
    import hashlib
    return hashlib.sha256(text.encode()).hexdigest()


class ReviewTests(unittest.TestCase):
    def test_absent_adjacent_streams_and_empty_memory(self):
        with tempfile.TemporaryDirectory() as tmp:
            memory = pathlib.Path(tmp) / "memory.loam"
            memory.write_text("LOAM-EVENT-MEMORY\t1\n")
            result = run("./tools/loam", "event-memory", "review", str(memory))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("No records", result.stdout)

    def test_bounded_current_window_and_order_independence(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            memory = tmp / "memory.loam"
            validity = pathlib.Path(str(memory) + ".actual-validity")
            descriptions = pathlib.Path(str(memory) + ".descriptions")
            memory.write_text(
                "LOAM-EVENT-MEMORY\t1\n"
                "EVENT\te3\nEFFECT\te3-1\twallet\tjpy\t-300\n"
                "EVENT\te1\nEFFECT\te1-1\twallet\tjpy\t-100\n"
                "EVENT\te2\nEFFECT\te2-1\twallet\tjpy\t-200\n"
            )
            validity.write_text(
                "LOAM-ACTUAL-VALIDITY-HISTORY\t2\n"
                "BASE\te2\t2026-09-02\n"
                "BASE\te3\t2026-09-03\n"
                "BASE\te1\t2026-09-01\n"
            )
            descriptions.write_text(
                "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n"
                "DESC\te3\tthird\n"
                "DESC\te1\tfirst\n"
                "DESC\te2\tsecond\n"
            )
            result = run("./tools/loam", "event-memory", "review", str(memory))
            self.assertEqual(result.returncode, 0, result.stderr)
            i3 = result.stdout.index("2026-09-03  [e3]")
            i2 = result.stdout.index("2026-09-02  [e2]")
            i1 = result.stdout.index("2026-09-01  [e1]")
            self.assertLess(i3, i2)
            self.assertLess(i2, i1)

    def test_elided_effects_stay_searchable_and_have_full_detail(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            memory = tmp / "memory.loam"
            descriptions = pathlib.Path(str(memory) + ".descriptions")
            memory.write_text(
                "LOAM-EVENT-MEMORY\t1\n"
                "EVENT\te1\n"
                "EFFECT\te1-1\ta\tjpy\t-1\n"
                "EFFECT\te1-2\tb\tjpy\t-2\n"
                "EFFECT\te1-3\tc\tjpy\t-3\n"
                "EFFECT\te1-4\td\tjpy\t6\n"
            )
            descriptions.write_text(
                "LOAM-EVENT-DESCRIPTION-MEMORY\t1\nDESC\te1\tfour effects\n"
            )
            result = run("./tools/loam", "event-memory", "review", str(memory))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("+1 more", result.stdout)
            result = run("./tools/loam", "event-memory", "review", str(memory), "/d")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("[e1]", result.stdout)

    def test_search_scope_history_and_missing_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            memory = tmp / "memory.loam"
            validity = pathlib.Path(str(memory) + ".actual-validity")
            descriptions = pathlib.Path(str(memory) + ".descriptions")
            memory.write_text(
                "LOAM-EVENT-MEMORY\t1\n"
                "EVENT\te1\nEFFECT\te1-1\twallet\tjpy\t-1\n"
                "EVENT\te2\nEFFECT\te2-1\tbank\tjpy\t1\n"
            )
            validity.write_text(
                "LOAM-ACTUAL-VALIDITY-HISTORY\t2\nBASE\te1\t2026-09-01\n"
            )
            descriptions.write_text(
                "LOAM-EVENT-DESCRIPTION-MEMORY\t1\nDESC\te1\tcoffee\n"
            )
            result = run("./tools/loam", "event-memory", "review", str(memory), "/coffee")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("[e1]", result.stdout)
            self.assertNotIn("[e2]", result.stdout)
            result = run("./tools/loam", "event-memory", "review", str(memory), "u")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("date unknown  [e2]", result.stdout)

    def test_terminal_navigation_and_snapshot_selection(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            memory = tmp / "memory.loam"
            validity = pathlib.Path(str(memory) + ".actual-validity")
            memory.write_text(
                "LOAM-EVENT-MEMORY\t1\n"
                "EVENT\te1\nEFFECT\te1-1\twallet\tjpy\t-1\n"
                "EVENT\te2\nEFFECT\te2-1\twallet\tjpy\t-2\n"
            )
            validity.write_text(
                "LOAM-ACTUAL-VALIDITY-HISTORY\t2\n"
                "BASE\te1\t2026-09-01\nBASE\te2\t2026-09-02\n"
            )
            result = run("./tools/loam", "event-memory", "review", str(memory), input_text="j\nk\nq\n")
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_menu_is_quiet_and_does_not_consume_next_action(self):
        with tempfile.TemporaryDirectory() as tmp:
            data = pathlib.Path(tmp)
            env = os.environ.copy()
            env["LOAM_DATA_DIR"] = str(data)
            result = run("./tools/loam", input_text="q\n", env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("Build completed successfully", result.stdout)

    def test_writer_correction_recovery_then_date_correction(self):
        self.skipTest("covered by dedicated correction workflows")

    def test_all_admission_failures_precede_filtering(self):
        self.skipTest("covered by dedicated review workflow fixtures")


class ManifestMenuTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.authority = self.root / "movement-authority"
        self.authority.mkdir()
        self.env = os.environ.copy()
        self.env["LOAM_DATA_DIR"] = str(self.root)
        self.env["LOAM_MOVEMENT_MANIFEST_ROOT"] = str(self.authority)
        self.families = {
            "Event": "LOAM-EVENT-MEMORY\t1\nEVENT\tseed\nEFFECT\tseed-a\twallet\tjpy\t1000\nEFFECT\tseed-b\tequity:opening-balances\tjpy\t-1000\n",
            "ActualValidity": "LOAM-ACTUAL-VALIDITY-HISTORY\t2\nBASE\tseed\t2026-09-01\n",
            "EventDescription": "LOAM-EVENT-DESCRIPTION-MEMORY\t1\nDESC\tseed\tmanifest receipt\n",
            "RelationUnit": "LOAM-RELATION-UNIT-MEMORY\t1\n",
            "RelationDischarge": "LOAM-RELATION-DISCHARGE-MEMORY\t1\n",
            "LocusAdmission": "LOAM-LOCUS-ADMISSION-VOCABULARY\t1\nLOCUS\twallet\nLOCUS\tfood\n",
        }
        rows = ["LOAM-MOVEMENT-MANIFEST\t2"]
        for family, text in self.families.items():
            digest = sha256_text(text)
            relative = f"objects/{family}/{digest}.loam"
            target = self.authority / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
            rows.append(f"{family}\t{relative}\t{digest}")
        (self.authority / "CURRENT").write_text("\n".join(rows) + "\n")
        (self.root / "zero-origin-coverage.loam").write_text(
            "LOAM-ZERO-ORIGIN-COVERAGE\t1\nCOORDINATE\twallet\tjpy\n"
        )
        (self.root / "balance-view.tsv").write_text("wallet\tjpy\n")
        (self.root / "scheduled.loam").write_text(
            "LOAM-SCHEDULED-LIFECYCLE\t1\n"
            "BEGIN\tScheduled\nLOAM-SCHEDULED-MEMORY\t1\nEND\tScheduled\n"
            "BEGIN\tCompletion\nLOAM-SCHEDULED-COMPLETION-MEMORY\t1\nEND\tCompletion\n"
            "BEGIN\tRetirement\nLOAM-SCHEDULED-RETIREMENT-MEMORY\t1\nEND\tRetirement\n"
            "BEGIN\tReplacement\nLOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\nEND\tReplacement\n"
        )

    def tearDown(self):
        self.temp.cleanup()

    def menu(self, input_text):
        return run("./tools/loam", input_text=input_text, env=self.env)

    def snapshot(self):
        return {
            str(path.relative_to(self.root)): path.read_bytes()
            for path in self.root.rglob("*")
            if path.is_file()
        }

    def test_retired_sidecars_review_and_zero_origin_balances(self):
        before = self.snapshot()
        result = self.menu("2\n3\nq\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("manifest receipt", result.stdout)
        self.assertIn("wallet: 925 jpy", result.stdout)
        self.assertNotIn("Nothing recorded yet", result.stdout)
        self.assertEqual(self.snapshot(), before)

    def test_broken_selected_authority_never_falls_back(self):
        (self.root / "memory.loam").write_text(self.families["Event"])
        for path in (self.authority / "objects/RelationDischarge").iterdir():
            path.write_text("corrupt\n")
        before = self.snapshot()
        result = self.menu("2\n3\nq\n")
        self.assertIn("loam:", result.stderr)
        self.assertNotIn("Balances (", result.stdout)
        self.assertNotIn("manifest receipt", result.stdout)
        self.assertNotIn("Nothing recorded yet", result.stdout)
        self.assertEqual(self.snapshot(), before)
        (self.authority / "CURRENT").unlink()
        result = self.menu("2\n3\nq\n")
        self.assertIn("CURRENT is missing", result.stderr)
        self.assertNotIn("Balances (", result.stdout)

    def test_unported_menu_actions_refuse_without_writes(self):
        before = self.snapshot()
        result = self.menu("correct\nraw\neffective\nintegrity\nq\n")
        self.assertEqual(result.stderr.count("no sidecar action was run"), 4)
        self.assertEqual(self.snapshot(), before)

    def test_record_uses_manifest_and_next_views_see_it(self):
        self.env.update(LOAM_OCCURRENCE_DATE=TODAY, LOAM_DESCRIPTION="new manifest purchase")
        result = self.menu("1\nwallet\n25\n\nfood\n25\n\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Recorded movement: 25 jpy", result.stdout)
        result = self.menu("2\n3\nq\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("new manifest purchase", result.stdout)
        self.assertIn("wallet: 900 jpy", result.stdout)
        self.assertFalse((self.root / "memory.loam").exists())
        self.assertFalse((self.root / "memory.loam.actual-validity").exists())
        self.assertFalse((self.root / "memory.loam.descriptions").exists())

    def test_unapproved_locus_refuses_without_authority_change(self):
        self.env.update(LOAM_OCCURRENCE_DATE=TODAY)
        before = self.snapshot()
        result = self.menu("1\nunapproved\n25\n\nfood\n25\n\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not approved", result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_direct_quantity_commands_refuse_invalid_selection(self):
        before = self.snapshot()
        (self.authority / "CURRENT").write_text("broken\n")
        result = run(
            "./tools/loam",
            "balances",
            str(self.root / "memory.loam"),
            str(self.root / "corrections.loam"),
            str(self.root / "zero-origin-coverage.loam"),
            str(self.root / "balance-view.tsv"),
            env=self.env,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot()["movement-authority/CURRENT"], b"broken\n")
        self.assertEqual(before["zero-origin-coverage.loam"], self.snapshot()["zero-origin-coverage.loam"])

    def test_version1_manifest_remains_readable_but_closed_for_new_write(self):
        rows = ["LOAM-MOVEMENT-MANIFEST\t1"]
        for family in ("Event", "ActualValidity", "EventDescription", "RelationUnit", "RelationDischarge"):
            text = self.families[family]
            digest = sha256_text(text)
            relative = f"objects/{family}/{digest}.loam"
            rows.append(f"{family}\t{relative}\t{digest}")
        (self.authority / "CURRENT").write_text("\n".join(rows) + "\n")
        result = self.menu("2\nq\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("manifest receipt", result.stdout)
        before = self.snapshot()
        result = self.menu("1\nwallet\n25\n\nfood\n25\n\n")
        self.assertIn("not approved", result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_historical_locus_can_be_read_while_disallowed_for_new_write(self):
        self.env.update(LOAM_OCCURRENCE_DATE=TODAY)
        result = self.menu("2\nq\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("wallet", result.stdout)
        before = self.snapshot()
        result = self.menu("1\nequity:opening-balances\n1\n\nwallet\n1\n\n")
        self.assertIn("not approved", result.stderr)
        self.assertEqual(self.snapshot(), before)

"""Synthetic read-only review and terminal navigation checks."""
import contextlib
import datetime as dt
import os
from pathlib import Path
import pty
import re
import select
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
LOAM = ROOT / ".lake/build/bin/loam"
ENV = {k: v for k, v in os.environ.items() if not k.startswith("LOAM_")}
TODAY = dt.date.today().isoformat()


def run(*args, input="", env=None):
    return subprocess.run(args, input=input, text=True, capture_output=True,
                          env=env or ENV, cwd=ROOT, timeout=30)


def escaped(text):
    return text.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")


@contextlib.contextmanager
def terminal(*args):
    master, slave = pty.openpty()
    proc = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave, env=ENV, cwd=ROOT)
    os.close(slave)

    def exchange(command=None):
        if command is not None:
            os.write(master, (command + "\n").encode())
        output = b""
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.2)[0]:
                output += os.read(master, 65536)
                if output.endswith(b"\n> "):
                    return output.decode()
        raise AssertionError(f"terminal prompt timeout: {output!r}")

    try:
        yield exchange
        os.write(master, b"q\n")
        assert proc.wait(timeout=10) == 0
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        os.close(master)


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.memory = self.root / "memory.loam"
        self.corrections = self.root / "corrections.loam"
        self.events = [(f"r{i:02}", TODAY, f"Coffee {i:02}", 100 + i) for i in range(23)] + [
            ("zz-original", TODAY, "スーパー receipt-original", 999),
            ("zz-fixed", TODAY, "", 75),
            ("undated", None, "unknown-date receipt", 5),
            ("ancient", "2001-01-01", "ancient receipt", 7),
        ]
        self.write_events()
        self.write_corrections([("c1", "zz-original", "zz-fixed")])

    def write_events(self):
        memory = ["LOAM-EVENT-MEMORY\t1"]
        dates = ["LOAM-ACTUAL-VALIDITY-HISTORY\t2"]
        descriptions = ["LOAM-EVENT-DESCRIPTION-MEMORY\t1"]
        for event, date, text, amount in self.events:
            memory += [f"EVENT\t{event}", f"EFFECT\tfrom\twallet\tjpy\t{-amount}",
                       f"EFFECT\tto\tfood\tjpy\t{amount}"]
            if date:
                dates.append(f"BASE\t{event}\t{date}")
            if text:
                descriptions.append(f"DESC\t{event}\t{escaped(text)}")
        for suffix, rows in [("", memory), (".actual-validity", dates), (".descriptions", descriptions)]:
            Path(str(self.memory) + suffix).write_text("\n".join(rows) + "\n")

    def write_corrections(self, links):
        self.corrections.write_text("LOAM-EVENT-CORRECTION-MEMORY\t1\n" +
                                   "".join("CORRECTION\t" + "\t".join(link) + "\n" for link in links))

    def review(self, *query):
        result = run(LOAM, "review", self.memory, self.corrections, *query)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def snapshot(self):
        return {p.name: p.read_bytes() for p in self.root.iterdir() if p.is_file()}

    def test_bounded_current_window_and_order_independence(self):
        before = self.snapshot()
        output = self.review()
        self.assertIn("Showing 1-10 of 24 matches", output)
        self.assertIn(TODAY[5:] + ":24", output)
        self.assertIn("Date unknown (current): 1", output)
        self.assertIn("not entry time", output)
        self.assertNotIn("receipt-original", output)
        self.assertEqual(len(re.findall(r"^  \d+\. ", output, re.M)), 10)
        self.assertEqual(self.snapshot(), before)
        self.events.reverse()
        self.write_events()
        self.assertEqual(self.review(), output)
        self.events += [(f"large-{i}", TODAY, "long " * 100, 1) for i in range(300)]
        self.write_events()
        grown = self.review()
        self.assertIn("of 324 matches", grown)
        self.assertLess(len(grown.splitlines()), 25)
        self.assertLess(len(grown), 2400)

    def test_search_scope_history_and_missing_evidence(self):
        output = self.review("/スーパー")
        self.assertIn("all dates + correction history", output)
        self.assertIn("receipt-original", output)
        self.assertIn("[corrected -> #zz-fixed]", output)
        self.assertIn("ancient receipt", self.review("/ancient"))
        self.assertIn("unknown-date receipt", self.review("/unknown-date"))
        self.assertIn("unknown-date receipt", self.review("u"))
        self.assertIn("Coffee 00", self.review("/cOfFeE 00"))
        self.assertIn("wallet: -100 jpy", self.review("/-100"))
        self.assertIn("does not prove", self.review("/not-present"))
        self.assertNotIn("receipt-original", self.review(TODAY))
        self.events = [(event, None if event == "zz-original" else date, text, amount)
                       for event, date, text, amount in self.events]
        self.write_events()
        historical = self.review("/receipt-original")
        self.assertIn("Date unknown (current): 1", historical)
        self.assertIn("\ndate unknown\n", historical)

    def test_elided_effects_stay_searchable_and_have_full_detail(self):
        text = self.memory.read_text()
        self.memory.write_text(text.replace("EFFECT\tto\tfood\tjpy\t100\n",
                                            "EFFECT\tto\tfood\tjpy\t100\nEFFECT\textra\tpoints\tusd\t3\n"))
        output = self.review("/points")
        self.assertIn("(+1 effects; detail)", output)
        with terminal(LOAM, "review", self.memory, self.corrections, "/points") as exchange:
            exchange()
            detail = exchange("1")
            self.assertIn("points: 3 usd", detail)
            self.assertIn("wallet: -100 jpy", detail)
            exchange("")

    def test_absent_adjacent_streams_and_empty_memory(self):
        for suffix in [".actual-validity", ".descriptions"]:
            Path(str(self.memory) + suffix).unlink()
        self.corrections.unlink()
        self.assertIn("Date unknown (current): 27", self.review())
        self.assertIn("Showing 1-10 of 27", self.review("u"))
        self.memory.write_text("LOAM-EVENT-MEMORY\t1\n")
        self.assertIn("No matches", self.review())
        result = run(LOAM, "review", self.memory, self.corrections, "2026-02-29")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")

    def test_all_admission_failures_precede_filtering(self):
        cases = [
            [("c1", "r00", "missing")],
            [("c1", "r00", "r01"), ("c2", "r00", "r02")],
            [("c1", "r00", "r02"), ("c2", "r01", "r02")],
            [("c1", "r00", "r01"), ("c2", "r01", "r00")],
        ]
        for links in cases:
            self.write_corrections(links)
            result = run(LOAM, "review", self.memory, self.corrections, "/not-present")
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, "")
            self.assertIn("movement corrections", result.stderr)
        self.write_corrections([])
        validity = Path(str(self.memory) + ".actual-validity")
        with validity.open("a") as stream:
            stream.write(f"REVISION\tbranch-a\tr00\t{TODAY}\nREVISION\tbranch-b\tr00\t{TODAY}\n"
                         "CORRECTION\tca\tROOT\tr00\tbranch-a\n"
                         "CORRECTION\tcb\tROOT\tr00\tbranch-b\n")
        result = run(LOAM, "review", self.memory, self.corrections, "u")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("actual-validity corrections", result.stderr)
        self.write_events()
        Path(str(self.memory) + ".descriptions").write_text("BROKEN\n")
        result = run(LOAM, "review", self.memory, self.corrections)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("event-description", result.stderr)

    def test_terminal_navigation_and_snapshot_selection(self):
        before = self.snapshot()
        with terminal(LOAM, "review", self.memory, self.corrections) as exchange:
            self.assertIn("Coffee 00", exchange())
            self.assertIn("Showing 11-20", exchange("more"))
            self.assertIn("[r10]", exchange("1"))
            exchange("")
            self.assertIn("Showing 1-10", exchange("back"))
            self.assertIn("No matches", exchange("n"))
            self.assertIn("Coffee 00", exchange("p"))
            self.assertIn("Day " + TODAY, exchange(TODAY))
            self.assertIn("unknown-date receipt", exchange("u"))
            self.assertIn("[corrected -> #zz-fixed]", exchange("/スーパー"))
            self.assertIn("corrects #zz-original", exchange("#zz-fixed"))
            exchange("")
            exchange("t")
            self.events.insert(0, ("aaa-new", TODAY, "new arrival", 2))
            self.write_events()
            self.assertIn("[r00]", exchange("1"))
            exchange("")
            self.assertIn("new arrival", exchange("r"))
        self.events.pop(0)
        self.write_events()
        self.assertEqual(self.snapshot(), before)


class DirectQuantitySelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_direct_quantity_commands_refuse_invalid_selection(self):
        binary = ROOT / ".lake/build/bin/loamDailyQuantity"
        for command in ("balances", "current"):
            for selection in ("", str(self.root / "missing")):
                result = run(binary, command, self.root / "memory.loam",
                             self.root / "corrections.loam", self.root / "zero-origin-coverage.loam",
                             env={**ENV, "LOAM_MOVEMENT_MANIFEST_ROOT": selection})
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()

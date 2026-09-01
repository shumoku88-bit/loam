#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys

TIMINGS = ("before", "same-day", "after")
DELTAS = ("exact", "same-shape-quantity-different", "shape-different")
MATRIX_LINE = re.compile(
    r"^  (before|same-day|after): "
    r"exact=(\d+) "
    r"same-shape-quantity-different=(\d+) "
    r"shape-different=(\d+)$"
)


def refuse(reason: str) -> None:
    print("LOAM private realization summary sufficiency: REFUSED")
    print(f"reason: {reason}")
    print("private identities/content: withheld")
    raise SystemExit(2)


def parse_matrix(output: str) -> list[list[int]]:
    rows: dict[str, list[int]] = {}
    for line in output.splitlines():
        match = MATRIX_LINE.match(line)
        if match:
            timing = match.group(1)
            if timing in rows:
                refuse("duplicate sanitized matrix row")
            rows[timing] = [int(match.group(i)) for i in range(2, 5)]

    if set(rows) != set(TIMINGS):
        refuse("sanitized matrix rows missing or unexpected")
    if "sources unchanged: yes" not in output:
        refuse("inner shadow did not confirm unchanged sources")
    if "private identities/content: withheld" not in output:
        refuse("inner shadow did not confirm privacy withholding")

    return [rows[timing] for timing in TIMINGS]


def margins(matrix: list[list[int]]) -> tuple[list[int], list[int]]:
    row_totals = [sum(row) for row in matrix]
    col_totals = [sum(matrix[r][c] for r in range(3)) for c in range(3)]
    return row_totals, col_totals


def bounded_compositions(total: int, bounds: tuple[int, int, int]):
    for first in range(min(total, bounds[0]) + 1):
        remaining = total - first
        for second in range(min(remaining, bounds[1]) + 1):
            third = remaining - second
            if third <= bounds[2]:
                yield [first, second, third]


def has_alternative(
    observed: list[list[int]],
    anchor: tuple[int, int] | None,
) -> bool:
    row_totals, col_totals = margins(observed)
    candidate = [[0, 0, 0] for _ in range(3)]

    def search(row: int, remaining_cols: list[int]) -> bool:
        if row == 2:
            if sum(remaining_cols) != row_totals[2]:
                return False
            candidate[2] = remaining_cols.copy()
            if anchor is not None:
                ar, ac = anchor
                if candidate[ar][ac] != observed[ar][ac]:
                    return False
            return candidate != observed

        for values in bounded_compositions(row_totals[row], tuple(remaining_cols)):
            if anchor is not None and anchor[0] == row:
                ar, ac = anchor
                if values[ac] != observed[ar][ac]:
                    continue
            candidate[row] = values
            next_cols = [remaining_cols[c] - values[c] for c in range(3)]
            if search(row + 1, next_cols):
                return True
        return False

    return search(0, col_totals.copy())


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: private-plan-realization-summary-sufficiency.py "
            "ACTUAL_JOURNAL PLAN_JOURNAL",
            file=sys.stderr,
        )
        return 2

    shadow = Path(__file__).with_name("private-plan-realization-shadow")
    if not shadow.is_file():
        refuse("private Plan realization shadow tool not found")

    completed = subprocess.run(
        [str(shadow), sys.argv[1], sys.argv[2]],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        refuse("inner Plan realization shadow refused or failed")

    observed = parse_matrix(completed.stdout)
    row_totals, col_totals = margins(observed)
    active_rows = sum(total > 0 for total in row_totals)
    active_cols = sum(total > 0 for total in col_totals)

    marginal_ambiguous = has_alternative(observed, None)
    sufficient_single_anchors = 0
    for row in range(3):
        for col in range(3):
            if not has_alternative(observed, (row, col)):
                sufficient_single_anchors += 1

    print("LOAM private realization summary sufficiency")
    print(f"active time buckets: {active_rows}")
    print(f"active physical-delta buckets: {active_cols}")
    print(f"marginals alone determine joint: {'no' if marginal_ambiguous else 'yes'}")
    print("single joint-cell anchors tested: 9")
    print(f"single joint-cell anchors sufficient: {sufficient_single_anchors}")
    print(
        "every single joint-cell anchor insufficient: "
        f"{'yes' if sufficient_single_anchors == 0 else 'no'}"
    )
    print("this is snapshot-specific sufficiency, not a universal summary law")
    print("private identities/content: withheld")
    print("sources unchanged: yes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

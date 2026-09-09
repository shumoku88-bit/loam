from pathlib import Path

# Branch-only fail-closed transformer; removed by the workflow after use.
# Re-triggered by the post-compression audit to finish the branch-local CI fold.

def replace_exact(path: Path, old: str, new: str, expected: int) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} matches, found {count}: {old!r}")
    path.write_text(text.replace(old, new))


tui = Path('.github/workflows/tui.yml')

replace_exact(
    tui,
    "      - 'Loam/CapacityPublisher.lean'\n",
    "      - 'Loam/CapacityPublisher.lean'\n"
    "      - 'Loam/ActualRoutingPublisher.lean'\n"
    "      - 'Loam/ActualRoutingReview.lean'\n",
    2,
)
replace_exact(
    tui,
    "      - 'Loam/Tests/TuiCapacityRebalance.lean'\n",
    "      - 'Loam/Tests/TuiCapacityRebalance.lean'\n"
    "      - 'Loam/Tests/ActualRoutingReview.lean'\n"
    "      - 'Loam/Tests/TuiActualRoutingAdministration.lean'\n",
    2,
)

needle = """      - name: Verify Capacity workspace
        run: lake env lean --run Loam/Tests/TuiCapacity.lean

"""
addition = needle + """      - name: Build shared Actual Purpose routing administration boundaries
        run: |
          lake build Loam.ActualRoutingPublisher
          lake build Loam.ActualRoutingReview

      - name: Verify current Expense Locus routing audit
        run: lake env lean --run Loam/Tests/ActualRoutingReview.lean "$(mktemp -d)/actual-routing-review"

      - name: Verify Actual Purpose routing administration interaction
        run: lake env lean --run Loam/Tests/TuiActualRoutingAdministration.lean "$(mktemp -d)/tui-actual-routing-administration"

"""
replace_exact(tui, needle, addition, 1)

Path('.github/workflows/purpose-routing-administration.yml').unlink()

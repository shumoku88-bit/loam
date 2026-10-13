# Frozen evidence for Issue 1963

Owner: [independent re-audit](../lean-435-independent-reaudit.md). These are
archival specimens/logs, **not maintained tools, dependencies or CI inputs**.
No binary, `.olean`, operational household data or giant NDJSON is included.
[manifest.json](manifest.json) records SHA-256 and bytes for every evidence file.

| File | Distinct obligation / contents |
| --- | --- |
| `prior-ubuntu24.zip` | Exact downloaded artifact 11822278176, run 38412938086: paired versions/caches, namespace failure |
| `prior-ubuntu22.zip` | Exact downloaded artifact 11823402508, run 38413883360: working sandbox, selected/full checking and timeout |
| `prior-sandbox.zip` | Exact downloaded artifact 11823438129, run 38415863123: corrected marker-only isolation assertions |
| `prior-local.zip` | Original rc3/formal local logs, commands, fixtures/inventories, baseline CI raw log, original unedited uncommitted report/checkpoint, exact experiment drivers/workflows from the three Git commits |
| `reaudit.zip` | Independent raw commands, timing/exit JSON, logs, source/pin receipts, inventories, one-shot specimen/selection code |
| `omissions.tsv` | All 153 original omissions, module ownership, semantic/compiler category, flags and selection cause |

Useful new archive entries:

- `results.json`, `driver.log`, `a-inventory.log`, `b-inventory.log`: paired build,
  warm timings, umbrella/explicit/fresh replay, module population and safety flags.
- `audit-results.json`: separately compiled pinned audits and Dormant/Used/Native
  counterexamples with both versions.
- `fixture-results.json`: unchanged statement/axiom fixtures, dormant/used/native
  official checks, strict-empty paranoid integration failure.
- `selection-results.json`, `selected-export-inventory.json`: explicit all-1,150
  candidate export; `selected-paranoid.log` identifies unsupported partial inputs.
- `final-probe-results.json`: 61 omitted theorem roots checked by Lean/Nanoda;
  research umbrella and production TUI executable builds on both versions.
- `normalized-results.json`, `normalized-inventory.json`,
  `normalized-paranoid.log`: all 1,138 eligible logical roots / 415 theorem
  entries and every bundled checker accepting the normalized artifact.
- `roots-cli-results.json`, `roots-cli-equivalence.json`: smaller roots-only
  scope adapter + compiled official exporter, byte-identical to that artifact.
- `SelectedRoots.lean`, `SelectedExport.lean`, `Inventory.lean`, `*.py`: one-shot
  reproduction code. Original absolute installation/work paths must be adapted;
  assertions target the exact baseline specimen, not a future repository census.
- `run_leanchecker.sh`: baseline action's script at
  `24581d74d674803a25a81b10b059c5c0cdd344c6` (not a newer floating action script).
- `unchanged-source-pins/`: byte-identical source configuration in both worktrees;
  native tool paths/PATH selected versions without editing revision pins.

Two new harness mistakes are intentionally retained: the first driver incorrectly
assumed no partial logical entries, and the first selection result writer tried
to serialize a `Path` after a successful checker run. `driver.log` and
`selection-driver-first.log` show these errors. Corrected scripts/reruns and
`selection-results.json` give definitive verdicts. They are not proof failures.

To inspect locally without writing into operational data:

```sh
python3 -m zipfile -e docs/experiments/lean-435-reaudit/reaudit.zip /tmp/loam-1963-evidence
```

The record's reproduction commands select only compiled proof artifacts and
synthetic/repository fixtures. Linux frontend replays require working stock
bubblewrap. macOS `--inadvisably-no-sandbox` runs and direct checker commands
qualify trusted-input logical behavior only, never hostile-code isolation.

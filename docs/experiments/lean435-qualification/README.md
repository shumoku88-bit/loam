# Issue 1963 — Lean 4.35.0 migration qualification

Status: **Draft qualification only; do not merge; #1963 remains open.**

Base: `c90511268eba2511c38158d35647b35d10cac8c4` (corrected replay landed).
Candidate compiler: official `leanprover/lean4:v4.35.0`,
`eb6cafb7290e8bd5f2937522d8d804f58f02bafc`.
Baseline: official 4.33.1, `819816b2e0a3bf405af45ae5c7af2491d8f5bee6`.
The candidate pin is branch-only. No operational data, revision pin, canonical
household files, production semantics or surface ownership changes are intended.

## Distinct qualification obligation

The existing PR lanes still own their ordinary path-sensitive checks. The manual
`qualify_435` input on Lean Proof Surfaces performs a one-shot paired migration
experiment, not another required gate: first/warm actual surfaces and CLI/TUI,
**full `lake test`**, corrected replay and sentinels, unchanged pinned audit,
and candidate-only explicit-root official export/replay/Comparator specimens.
The script reuses the frozen re-audit fixtures, official tools and current replay
tests; it implements neither a kernel nor an axiom traversal. Stock `lake update`
regenerates the manifest; compiler version is deliberately independent of package
manifest version. Setup/cache/sandbox installation are outside measured commands.
GNU time logs per-command wall/CPU/maximum RSS; concurrent job RSS is not summed.

Reproduce on Linux from this branch:

```sh
python3 docs/experiments/lean435-qualification/run.py
# Baseline: disposable checkout of the same source, with only lean-toolchain
# set to leanprover/lean4:v4.33.1, then run the same script.
gh workflow run selected-lean-observations.yml --ref qualify/lean-4.35.0 -f qualify_435=true
```

The inventory independently records dynamic owners and every declaration's name,
theorem kind and actual unsafe/partial status. It reconciles replay names and
checks normalized export membership including private roots. Baseline/candidate
inventories must be compared by owner/theorem name, not by generated-definition
count or axiom-audit count. Stock replay of the normalized export checks its
referenced upstream dependencies too; defining-module replay trusts loaded imports.

Sandbox failures are retained as environment/integration failures. A separately
labelled `--inadvisably-no-sandbox` fallback on these trusted specimens is only
logical evidence, **never hostile-input security acceptance**. No host userns or
AppArmor relaxation is performed. Scoped paranoid is optional, not a gate.

## Results / decision

Pending execution; no adoption or replacement qualification is claimed yet.
Compare A (4.33.1 + corrected replay/audit), B (4.35 + same), and C (4.35 + selected
official replay + unchanged audit). Retain the existing replay driver/CI until C's
scope and negative behavior are mechanically established and reviewed. Neither
Comparator nor kernel replay proves human intent/production correspondence.

Rollback: reject this Draft and keep main at A; no household conversion is needed.
If a later pin-only B upgrade is approved, revert its toolchain/manifest changes
and rebuild rather than loading cross-version `.olean` artifacts. The manual
experiment/input can be retired after review, with results here as its successor;
it is not proposed permanent CI. Release-platform/runtime coverage must be
explicitly enumerated before recommending adoption.

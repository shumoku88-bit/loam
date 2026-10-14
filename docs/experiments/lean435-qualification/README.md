# Issue 1963 — Lean 4.35.0 migration qualification

Status: **Draft qualification only; unmerged; #1963 remains open.**

Date: 2026-10-14. Base: `c90511268eba2511c38158d35647b35d10cac8c4`
(latest main at start; corrected replay landed). Candidate is branch-only.

| Compiler | Official pin | Compiler commit (recorded by `lean --version`) |
| --- | --- | --- |
| Baseline | `leanprover/lean4:v4.33.1` | `819816b2e0a3bf405af45ae5c7af2491d8f5bee6` |
| Candidate | `leanprover/lean4:v4.35.0` | `eb6cafb7290e8bd5f2937522d8d804f58f02bafc` |

No operational data, revision pin, canonical household files, runtime meaning,
product/durable/research ownership, axiom-audit pin or allowlist changed.
Observations 237–238's proof-to-production/human-intent limit remains unchanged.

## 1. Small repairs, not a source conversion

- Stock `lake update` generated manifest version 1.3.0, empty dependency set,
  `fixedToolchain: false`; no dependency replacement or compatibility wrapper.
- Lean 4.35 reserves `recall?` and `recall`. The non-household Memory example/CLI
  now quotes these identifiers (`«recall?»`, `«recall»`), preserving their actual
  names, types, implementation, file representation and command spelling.
  [Initial failure](https://github.com/shumoku88-bit/loam/actions/runs/38491908389)
  is retained; corrected non-household executable/probes pass in the PR lanes.
- Full application qualification exposed two cold-cache fixture omissions, not
  kernel/type failures: Settlement Publisher and Actual Authority Preservation
  imported an unbuilt `ActualWorldFixture`. Their existing manifest build arguments
  now explicitly build that fixture. No tests/triggers/ownership were removed.
  [Initial failure](https://github.com/shumoku88-bit/loam/actions/runs/38491984322),
  [all 15 cases pass after repair](https://github.com/shumoku88-bit/loam/actions/runs/38492670080).

## 2. Distinct experimental obligation and reproducibility

The manual-only `qualify_435` input on Lean Proof Surfaces performs a paired
migration experiment **instead of** its ordinary proof jobs. Default manual,
PR/push selection and all ordinary proof jobs are unchanged. It is not a new
workflow, required merge gate, kernel, custom axiom traversal or permanent CI
proposal. Retire this one-shot input/script after review; this record retains its
comparison obligation. The existing replay driver/tests and frozen re-audit
specimens supply the mechanics and positive/negative cases.

The archived runs below used the original per-version manual job. The input now
runs the bounded same-runner performance follow-up (§8); the qualification script
remains reproducible directly:

```sh
# Same source in disposable Linux checkouts, pin each version separately:
python3 docs/experiments/lean435-qualification/run.py
python3 docs/experiments/lean435-qualification/compare.py baseline.zip candidate.zip
```

`run.py` records every command, cwd, exit, wall time and GNU time CPU/maximum RSS.
Setup/toolchain install, cache restore and bwrap installation are separate Actions
steps. The inventory independently records owners/name/kind/unsafe/partial,
reconciles **every** replay name, and checks normalized official-export membership.
The comparison asserts the retained baseline 22 owners/415 theorem-owner names,
including both hand-written private correspondence proofs. A mutated candidate
inventory with one private proof removed is rejected (exit 1), not just counted. Compiler-generated
constant counts are not theorem counts or axiom-audit counts.

First paired run: [38491907677](https://github.com/shumoku88-bit/loam/actions/runs/38491907677),
source `76ac57be34f57644cee33cdbd94d09e41161f7c8`.
Final rerun after repairs/diagnostic correction: [38493144637](https://github.com/shumoku88-bit/loam/actions/runs/38493144637),
source `2951b707` (full commit in retained run metadata).
The final source additionally covers the syntax/fixture repairs; ordinary PR lanes
also pass on that implementation. Documentation/evidence-only succession does not
change the tested implementation.

## 3. Linux costs and exact scope

First run: Ubuntu 24.04.5 x64, image `20261004.327.1`, same version-keyed shared
cache mechanism as durable CI. **Both restores missed** (the candidate manifest
hash also differs from main), so first library builds are fresh. Targets run in
sequence; later targets share earlier prerequisites. Warm means one immediate
repeat, not an OS-cache eviction or statistical distribution. In particular,
`loam` already compiles most TUI object prerequisites; 1.8 s `loamTui` is not a
cold standalone TUI compilation. Samples run on separate hosted runners.

| Command / obligation | 4.33.1 wall s | 4.35.0 wall s |
| --- | ---: | ---: |
| `lake build Loam`, first / warm | 22.701 / 0.465 | 24.159 / 0.515 |
| `lake build Loam.DurableProofs`, first / warm | 1.869 / 0.466 | 2.022 / 0.515 |
| `lake build Loam.Observations`, first / warm | 19.371 / 0.465 | 20.519 / 0.515 |
| `lake build loam`, first / warm | 100.706 / 0.466 | 103.564 / 0.517 |
| `lake build loamTui`, first / warm | 1.770 / 0.465 | 1.821 / 0.515 |
| Full actual `lake test` driver | 258.438 | 282.013 |
| Corrected module replay, whole invocation | 10.546 | 10.492 |
| Scope/kernel sentinel suite | 15.557 | 17.059 |
| Declarative inventory | 3.324 | 3.322 |
| Pinned audit build (clone separate) | 3.275 | 3.475 |
| Pinned audit invocation | 0.967 | 1.117 |
| Explicit-root official export | — | 2.972 |
| Stock `leanchecker --from-export` | — | 7.834 |
| `lake check --from-export`, trusted logical fallback | — | 9.188 |

Maximum RSS (MiB, GNU time's per-invocation maximum, not summed concurrent
memory): full test driver 1318.8 / 1315.6; module replay 2577.3 / 2643.1;
audit 909.3 / 901.9; candidate export 1225.8; stock export replay 823.8.
Raw logs include each build's RSS and setup/cache times. The final corrected run also has **cache misses for both versions** on the same
image: full test 173.504 / 256.256 s; replay 6.679 / 10.188 s; sentinels
11.487 / 14.899 s; audit 0.815 / 0.917 s. Candidate inventory/export/stock replay
are 3.072 / 2.622 / 7.030 s; trusted Lake frontend 8.334 s. Complete first/warm
builds and RSS for both runs are retained in the ZIPs.

Both runs show a longer candidate test-driver sample, and the baseline itself
varies materially between runners. **Compiler performance parity is not
qualified**: no CPU-model matching, controlled host pairing, or statistical
attribution was performed. This is a CI-cost review risk, not a failed functional
test. Existing compiled TUI resource/latency thresholds pass. No profiling or
product algorithm changes were justified by these two hosted-runner samples.

Scope: both have **22 imported LOAM owners and identical 415 theorem-owner
names**. Baseline replay checks **1,139 logical** declarations; candidate checks
**1,138**. Only removed candidate is generated
`Loam.Observation046.ForkNode.toCtorIdx`; no theorem disappeared. Actual
ineligible entries are **12 partial runtime helpers, zero unsafe**, not skipped
proofs. The unchanged separate audit covers **1,151 / 1,150 candidates** with
`propext,Classical.choice,Quot.sound`, pinned v0.1.2 source
`46024e005996495c65ef609368e11ab39c4222e3`.

Official normalized export selects all 1,138 eligible roots explicitly, including
private theorems; its declarative membership check finds all 415 theorem entries,
8,281 total declarations (referenced upstream dependencies included), **no partial
exports**. Bytes/hash and the exact excluded-name inventory are in
`membership.json` inside candidate evidence. Replay exit alone is not membership
qualification. Imported upstream environments remain trusted by module replay;
export replay reconstructs the selected roots' actually referenced dependencies.

## 4. Positive/negative evidence and sandbox boundary

Corrected driver passes its 3-test suite on both versions: source-private proof;
automatic new imported owner (2→3 modules, 1→2 theorems); cached unimported
module excluded; deliberate owner omission refused; empty/theorem-free scope
refused; forged compiled False theorem with True.intro refused with named kernel
type mismatch (the old umbrella-only command still demonstrates false success).
The official explicit-root export of that same forged theorem also fails stock
replay with the expected type mismatch.

Built-in Comparator uses frozen Challenge/Solution fixtures: valid proof
(Observation165) accepts; changed statement (Observation166) rejects with
`Challenge and solution theorem statement do not match`. The Dormant specimen's
unused forbidden axiom is accepted by ordinary official check but rejected by
unchanged declaration audit. Used forbidden axiom must reject with the **specific**
`Axiom 'bad' is not permitted` diagnostic, and audit also rejects it.

**Harness correction:** initial run incorrectly matched `not permitted` in
`Operation not permitted` and therefore did not qualify the Used check. That
result is superseded, not counted as a proof/policy rejection. Final rerun uses
explicit fixture roots and the full named-axiom diagnostic; initial raw logs
remain available for review.

Ubuntu 24 stock sandbox attempts fail at `bwrap: loopback: Failed RTM_NEWADDR:
Operation not permitted` / `setting up uid map: Permission denied`. These are
**environment/integration failures**, regardless of Lake's "kernel rejected"
summary. Trusted-fixture retries labelled `*-trusted-logic` use
`--inadvisably-no-sandbox` solely for logical qualification. No host userns/AppArmor
policy is relaxed; **no hostile-input security acceptance is claimed**. Direct
stock replay similarly is a trusted-artifact path, not a sandbox guarantee.
Scoped/full paranoid was not rerun: optional diversity is not needed for this
pin-only decision and no all-PR paranoid gate is proposed.

## 5. Runtime, persistence, recovery, importer and release coverage

- Both compilers: all five requested surfaces and full actual `lake test` driver
  PASS: 91 printed `lean --run` invocations / 88 distinct test modules, including
  the MeasureScale concurrent first-use path. Exact args/test names are retained
  in `product-tests.log`, not inferred from library builds.
- Candidate [full Production TUI](https://github.com/shumoku88-bit/loam/actions/runs/38491942840)
  PASS: existing complete semantic/publication/persistence suite, 13 Python
  PTY/launcher/input suites, viewport/Record/reload/navigation/balances/daily pace,
  Scheduled bulk edit, Fava lifecycle, and bounded resource/scroll probes. Exact
  commands are in the raw log. The candidate source repairs do not touch these
  tested household/TUI modules.
- Candidate all 15 application qualification cases PASS, including deterministic
  Movement, Correction/Reversal, Settlement, and relation-first Scheduled recovery.
  [Final run](https://github.com/shumoku88-bit/loam/actions/runs/38493149555)
  encountered an elan download `curl (35) Connection reset by peer`; only the
  failed setup job was rerun, then passed. This is not a proof failure.
- [Operational Continuity](https://github.com/shumoku88-bit/loam/actions/runs/38491948874)
  and [Beancount/Fava interchange](https://github.com/shumoku88-bit/loam/actions/runs/38491951960)
  PASS on temporary synthetic households.
- [Final proof-surface lane](https://github.com/shumoku88-bit/loam/actions/runs/38493149586)
  PASS product/durable/research, source-private/new-owner sentinels, unchanged
  audit, PTA classifier **and pinned hledger 1.52.3 adapter**. Other selected PR
  lanes (routing, lifecycle, capacity, validity, scale, non-household Memory,
  foundation extraction and finite-keyed probes) also pass.
- [Standalone Distribution](https://github.com/shumoku88-bit/loam/actions/runs/38491945469)
  PASS independent-directory CLI smoke **and all four packaging/smoke platforms**:
  Linux x86_64/aarch64, macOS x86_64/arm64. No release assets were published.
- Local macOS x86_64: fresh combined requested build 242.19 s, full driver
  521.62 s, corrected `loamMemory` build, plus Scheduled replacement/cancellation/
  completion modal PTY tests omitted from the full Linux workflow, all PASS.
  Those three extra PTY tests are functional macOS evidence, not Linux idle-CPU
  or four-platform full-runtime evidence.

Not run: every unrelated research solver/workflow, every historical standalone
Lean test, full PTY/runtime matrix on all release platforms, every importer/input
corpus, cold-cache repetitions/statistical distribution, full/scoped paranoid,
expanded hostile-input sandbox audit, operational household-data replay. These
are not silently replaced with library-build success. No real household writes
were needed for this compiler migration qualification.

## 6. Decision and rollback

| Choice | Qualification / recommendation |
| --- | --- |
| A: 4.33.1 + corrected replay/audit | Sound reproducible baseline; no need to undo landed scope repair. |
| B: 4.35 + same replay/audit | **Recommend reviewed pin adoption with the tiny syntax/fixture repairs.** Requested product/runtime/release checks and existing fail-closed assurance survive; least new production machinery. This Draft is not rollout approval. |
| C: 4.35 + selected official export/replay + unchanged audit | Real durable theorem membership and invalid-proof rejection are qualified; referenced dependency replay adds coverage. Viable subsequent simplification, not a reason to remove the audit or install all-PR paranoid. |

Official C's measured inventory + export + stock replay costs **14.1 / 12.7 s**
versus B's **10.5 / 10.2 s** module replay on the respective candidate runners
(audit additional in both). This is neither
an equal-upstream-coverage speed comparison nor a proven recurring saving.
**Do not delete `ReplayDurableProofs.lean`/its scope reconciliation yet:** this PR
uses it to qualify C against the imported private module data. A replacement must
carry empty/theorem-free/new-owner/omitted-owner sentinels into the smaller scope
adapter and preserve path-selection/audit before removing that dependency. Once
that replacement is qualified, its stock export/replay can succeed the old
module replay loop; driver-specific tests then migrate to the new selector, not
vanish. No deletion is claimed now.

Rollback: reject the Draft and stay at A; no household conversion is needed. For
later B rollout, revert candidate pin/manifest, rebuild version-specific artifacts,
keep scope/audit gates, and retain the harmless quoted identifiers and explicit
fixture prerequisites. Never reuse cross-version `.olean`s. Retire the manual
qualification input/script after the decision, retaining this report/evidence.

Semantic-neighbor review: quotation preserves Memory correction/history behavior;
fixture setup preserves Settlement publisher/Actual-authority tests; product
persistence/recovery and private durable correspondence boundaries were exercised.
No evidence boundary, admission/correction frontier or stored representation is
weakened. Sandbox failures and proof-to-production limits remain explicit.

## 7. Retained evidence

Raw Actions ZIPs (`first-433.zip`, `first-435.zip`, `final-433.zip`,
`final-435.zip`) and a compressed raw-log/metadata bundle live in `evidence/`,
with SHA-256 manifest. They contain commands, stdout/stderr/exit/time/RSS,
compiler hashes, inventories, private theorem names, sentinels, setup/cache
conditions, exact executed tests and failure diagnostics. No `.olean`, toolchain
binary, real household data or 44 MB export is committed; export is reproducible
from explicit roots and its hash/membership is retained. ZIPs are frozen evidence,
not CI inputs. Inspect with Python zipfile on case-insensitive macOS: artifact
`first-Loam.log` and `first-loam.log` are intentionally distinct Linux names.

## 8. Same-runner performance follow-up (production preparation)

Pending measured results. The existing experimental manual input now runs one
Linux job, with identical source in separate toolchain worktrees and fresh `.lake`
directories. Setup and initial builds are timed separately. Both full test-module
caches are primed, then the **actual unchanged `lake test` driver** runs in ABBA
order. A PATH logger restored at the Bash-driver boundary records each child
Lake invocation's wall/CPU/RSS/exit without rewriting any test or production
source; builds are labelled separately from test execution. Its capture and
failure-exit propagation were self-checked before the run. No shared cross-version
artifact/cache, sandbox changes, production optimization, or permanent gate.

```sh
gh workflow run selected-lean-observations.yml --ref qualify/lean-4.35.0 -f qualify_435=true
# Disposable Linux checkout, no existing paired-source/workspace directories:
python3 docs/experiments/lean435-qualification/performance.py
```

The future production migration PR must exclude this input, scripts, inventory
helpers and archives. Only pin/manifest, quoted Memory identifiers, explicit
Settlement fixture prerequisites and minimal migration/rollback guidance belong
there. A large unexplained within-runner slowdown blocks that adoption decision.

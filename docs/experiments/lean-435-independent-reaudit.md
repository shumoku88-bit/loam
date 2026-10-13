# Issue 1963 — independent Lean 4.35 re-audit

Status: **AUDIT RECORD; no production switch; Issue #1963 stays OPEN**

Date: 2026-10-13 UTC (2026-10-14 JST). This is the current decision owner for
[#1963](https://github.com/shumoku88-bit/loam/issues/1963), succeeding the
[original spike](lean-435-checking-spike.md). Observations 165–168 and 237–238
remain qualified; their semantic correspondence question is not reopened.

## Summary

The original measurements are mostly reproducible, but **KEEP CURRENT was too
broad**. Export omissions and declaration policy do not argue against upgrading
Lean itself. More importantly, the baseline checker did not replay the imported
durable proofs it was being compared against. Neither the unchanged old stack
nor a bare new `lake check` is a correctly scoped replacement for that obligation.

**Recommended direction: D, narrowly scoped official replay plus the existing
small declaration/axiom audit, with 4.35 adoption qualified separately.** Export
module-owned safe/non-partial logical declarations using the official exporter,
replay that artifact with bundled `leanchecker --from-export`, and retain the
pinned audit over *all* module-owned candidates. Use built-in Comparator and
selected independent kernels only for research/artifacts needing those distinct
obligations. Do not add an all-PR paranoid gate or hostile-proof sandbox policy.
The one-shot scope adapter below is evidence, not a new maintained framework.

A still smaller-code alternative is the bundled `leanchecker --fresh
Loam.DurableProofs`: it needs no selector/export adapter, passed on both versions,
but replays the entire imported standard library and cost about 152 seconds here.
The restricted official export gives the same LOAM theorem population with a
much smaller dependency closure. Production adoption needs a separate small PR,
full migration qualification and an explicit checked-scope diagnostic; nothing
is added or removed permanently in this audit.

## 1. Provenance and recovery

Baseline source: `2f213d0b947e43b86acd26774d46c83c5124011d`.

| Toolchain | Compiler commit | Location used |
| --- | --- | --- |
| Lean 4.33.1 | `819816b2e0a3bf405af45ae5c7af2491d8f5bee6` | Existing normal elan installation |
| Lean 4.35.0 | `eb6cafb7290e8bd5f2937522d8d804f58f02bafc` | Existing isolated `/tmp/loam-1963-formal/elan` installation |
| Earlier preview 4.35.0-rc3 | `470d5ce` prefix | Historical evidence only, not used for new verdicts |
| axiom-audit v0.1.2 | `46024e005996495c65ef609368e11ab39c4222e3` | Unmodified source, separately compiled with each toolchain |

The original spike was **untracked on main**, and its checkpoint cross-reference
was an uncommitted change. No main commit contained that report. Both have been
saved on this documentation-only branch; the old report's measurements remain,
with a supersession notice rather than rewritten history. Main's pre-existing
working-tree edits are left untouched.

The earlier experiment commits still exist locally and match GitHub run metadata:

- Ubuntu 24.04: `e0ef53a5ea21eb5a6c0625c637b8edf5db8a191d`,
  [run 38412938086](https://github.com/shumoku88-bit/loam/actions/runs/38412938086).
- Ubuntu 22.04: `69aec49bed4f3f44850ad7f8c9c5de151586022a`,
  [run 38413883360](https://github.com/shumoku88-bit/loam/actions/runs/38413883360).
- Corrected marker probe: `eb379ecb84483ef6597294bf7c11fa18c4efc978`,
  [run 38415863123](https://github.com/shumoku88-bit/loam/actions/runs/38415863123).

All three raw artifact ZIPs were downloaded again. SHA-256 comparisons matched
69 / 58 / 9 corresponding local files respectively. The
[evidence directory](lean-435-reaudit/) preserves these exact ZIPs, original
local drivers/logs, the original unedited report, and this audit's raw evidence.
It avoids depending on `/tmp`, a deleted remote experiment branch, dangling Git
objects, or GitHub's 30-day Actions artifact retention. ZIPs are frozen evidence,
not dependencies or CI inputs. No `.olean`, toolchain binary or giant NDJSON is
committed; exports are reproducible and their metadata/hashes are retained.

New work used detached source worktrees `a` and `b` and a documentation worktree
under `/tmp/loam-1963-reaudit/`. All native Lake commands put the corresponding
binary directory first on PATH; `lean --version` was recorded. No revision pin,
main toolchain, main CI, canonical data or operational data was modified. No new
workflow was dispatched and no software/toolchain was installed for this audit.

## 2. What the earlier numbers actually meant

| Earlier result | Re-audit classification |
| --- | --- |
| Durable CI about 38 s; 1,151 declarations | A cached **job span**, including setup; 1,151 is the axiom audit's module-owned candidate population, not the independently replayed theorem population. Product/research run in parallel; not whole-CI CPU time. |
| 4.35 product/durable builds pass | Confirmed at the same source revision with fresh `.lake` directories, without source repairs. Separate evidence for version compatibility, not checker equivalence. |
| Normal check accepts unused custom axiom | Confirmed and consistent with documented *used*-axiom policy. Not kernel unsoundness. It does not implement a declaration prohibition. |
| 153 omissions / 61 theorem entries | Counts confirmed. Default root selection, **not intrinsically unexportable proofs**; all are recoverable by explicit official roots. Twelve omissions are partial runtime helpers, not proof obligations. |
| Comparator positive/negative results | Replayed on release binaries. Distinct statement and proof-axiom checks; not a production gate today. Observation 238 is still accepted, as expected. |
| Paranoid stopped at 180 s | A harness timeout for a full imported-environment specimen, not a proof rejection or a fair speed comparison with axiom-audit. Whole-project completion remains unqualified. |
| Ubuntu 22/24 differ | Raw logs match. Different namespace/AppArmor environments; not evidence that 4.35 or its logical checking fails on Ubuntu 24. |

The original roughly 6.9 s checker+audit versus 174.2 s export+check comparison
was **not equal coverage**: the former's checker replayed the empty umbrella;
the latter rechecked 133,531 exported declarations, mostly standard library,
while excluding some private LOAM roots. Those timings remain real but cannot
rank equivalent verification configurations.

## 3. Baseline replay scope: a material finding

Both release sources' `LeanChecker.lean` select `.olean` modules by the supplied
module-name prefix. Without `--fresh`, `replayFromImports` loads their imports
as the starting environment and replays only the selected module's declarations.
Import loading assembles constant maps; it is not recursive kernel replay.

`Loam.DurableProofs` is an import-only selection module. The defining-module
inventory found **zero declarations owned by that module**. Verbose commands on
both versions print only:

```text
replaying Loam.DurableProofs
```

The actual baseline action commit was
`24581d74d674803a25a81b10b059c5c0cdd344c6`; its preserved `run_leanchecker.sh`
invokes `lake env leanchecker ${LEANCHECKER_ARGS}` without adding `--fresh`.
The raw baseline CI inputs explicitly supply only `Loam.DurableProofs`.
Thus there is no hidden recursive/fresh mode behind the measured job.

This **does not invalidate the existing proofs**: the original source builds
kernel-checked them, and axiom-audit walks their dependency graphs. It does mean
the named durable replay gate does not provide the claimed additional replay.
It also is **not an independently implemented kernel**; the tool's own source
says it is a tool to detect environment hacking, not an external verifier.

Two repairs were experimentally qualified, without modifying CI:

1. Explicitly pass all 22 module-owned import-closure modules: verbose output
   names every module, including private proof owners. This checks their own
   eligible constants against imported environments, not every upstream constant.
2. `leanchecker --fresh Loam.DurableProofs`: replay the whole imported logical
   environment from empty. More direct and stronger upstream replay, but larger.

The selected official export offers a third scoped path: same LOAM logical
population, with its actually referenced upstream dependencies replayed too.
No claim of 1,151 independent replayed proofs is made: there are 415 theorem
entries, plus definitions/types/generated constants, and 12 partial helpers.

## 4. Axiom guarantees are different obligations

| Obligation | What establishes it | What it does not establish |
| --- | --- | --- |
| Well-typed proof under its assumptions | Lean build/kernel replay; optionally a distinct kernel | That assumptions are permitted, or statement means what a human intended |
| Proof dependency allowlist | Comparator's selected dependency traversal; normal check's incoming references in the exported environment | Absence of unused prohibited declarations; absent export roots |
| Module-owned declaration policy | Current axiom-audit, including an axiom's own name in its axiom set | Whole-repository prohibition outside the imported durable closure; proof validity of forged `.olean`s |
| Repository-wide source/declaration prohibition | A separately defined repository policy/scope | Not supplied automatically by either existing durable audit or `lake check` |
| Statement preservation | Comparator against independently reviewed Challenge | Human intent or connection to production; Observations 237–238 still apply |

The normal `lake check` implementation explicitly excludes an axiom's
self-reference from `usedAxioms`. An unused `axiom unused_fact : False` is a
well-formed axiom declaration; the kernel is right to accept it as an assumption.
`Uses no axioms` means no *other exported constant* references an axiom, not that
there are no axiom declarations. If a theorem uses it, normal check rejects it.

New release replays confirm: both pinned audits reject Dormant and Used;
normal official check accepts Dormant and rejects Used. Both also reject a
`native_decide` theorem through `Lean.ofReduceBool`. No durable theorem here
uses that axiom. Paranoid rejects the exported dormant axiom through con-leche /
con-ron; Nanoda's policy/configuration differs. That is an external policy verdict,
not evidence that normal kernel acceptance was unsound.

For **dependency-only proof assurance**, the dormant-axiom discrepancy is a
scope/purpose difference, not a lost soundness guarantee. For **today's stronger
durable declaration policy**, it is a real policy gap requiring either retention
of the audit, a tiny declaration guard, or an explicit reviewed policy change.
The existing policy is not sacred: banning unused assumptions is conservative
hygiene against latent proof shortcuts, rather than a requirement of kernel
soundness. Here the pinned audit is already small, catches generated/private and
import-mediated violations, and costs little once built. No measured benefit
justifies weakening it or rewriting its maintained traversal in LOAM. Its trusted
import and documented cyclic-cluster/per-declaration limitations remain visible;
this audit does not promote it into a second proof checker.

## 5. Every one of the 153 omissions

The complete name/module/kind/cause table is [omissions.tsv](lean-435-reaudit/omissions.tsv).
All 153 names are `Name.isInternal`; zero have `ConstantInfo.isUnsafe = true` in
this logical environment. An internal name is any name with an underscore-led
component, not just a source `private` declaration.

| Omitted category | Count | Meaning |
| --- | ---: | --- |
| Source-written private theorem | 2 | `admitAll?_isSome_eq_currentUnitsAdmissible`; `buildCoverageIndex_getD_eq_currentCoverageFor` |
| Generated equation theorem | 43 | Equations/match equations/sparse-case equation |
| Generated structure theorem | 13 | Injectivity, size and structure congruence lemmas |
| Generated simplification theorem | 3 | Simp/congruence auxiliary results |
| Source-written private definition | 1 | `currentUnitsAdmissible` |
| Generated safe definition | 79 | Constructors/recursor helpers, splitters, unfolding and proof helpers |
| Partial compiler runtime helper | 12 | `_unsafe_rec` names, **partial**, not unsafe logical constants |
| **Total** | **153** | **61 theorem entries + 92 definition entries** |

The exporter `LeanExport.Basic.dumpEnv` defaults to non-internal roots and then
recursively dumps dependencies. Internal constants reached from a public root
*are* included; 247 of the 400 internal LOAM candidates were present already.
A standalone private theorem not used by public proofs will not become a root
merely because its module was imported. This is specified selection behavior,
not failure to typecheck/export its proof. Neither source privacy nor safety is
an inherent obstacle to explicit selection.

Using the official `leanexport Loam.DurableProofs -- <all 1150 names>` recovered
**all 153**, including all 61 theorems. The result contains 8,293 declarations,
44,258,949 bytes (about 42.2 MiB), rather than the original 133,531 declarations /
651,450,052 bytes. SHA-256:
`364d8ae3e7578c2d3b67d4624e6eae6bb0943404415771c9f3785dae968a9756`.
Normal check accepted it. Export membership alone is not a checker verdict:
Lean replay deliberately skips unsafe and partial definitions. So the eligible
LOAM logical population is **1,138**, including **all 415 theorem entries**.

Selecting the 61 formerly omitted theorem entries and their dependencies alone
also passed normal Lean replay **and the bundled independent Nanoda checker**,
with `unpermitted_axiom_hard_error: true` and only the original three standard
axioms permitted. This includes the two source-written private proofs. Thus those
proofs are build-kernel-checked and independently checked in this audit; the
unfiltered original artifact did not independently check them.

Forcing all 1,150 declarations through paranoid is the wrong obligation:
Nanoda panics on `partial`, while con-leche/con-ron decline it. Lean default,
Lean paranoid and lean4lean accept that artifact; Lake returns 1 after collecting
all checker verdicts. This is an unsupported **runtime-definition input class**,
not rejection of a LOAM theorem. Partial compiler execution helpers are not
logical proof terms and need not be forced through every proof checker.

The experimental `SelectedExport.lean` uses the same defining-module ownership
as the audit, filters only unsafe/partial logical constants, and calls **official**
`LeanExport.dumpEnv`. A smaller-cost variant, the 15-line `SelectedRoots.lean`,
emits only the root names and lets the compiled official `leanexport` serialize
those roots. Both produced **byte-identical** normalized exports. Assertions are
tied to this exact specimen, not a proposed permanent declaration count.

The normalized export contains 8,281 declarations / 44,229,640 bytes, retains
**all 1,138 eligible LOAM candidates and all 415 theorem entries**, and contains
no partial definitions. **All six paranoid checker invocations accepted it**:
Lean paranoid, lean4lean, Nanoda, con-leche, con-ron and Lean default. Per-checker
reported totals (e.g. lean4lean 7,701; con-leche/con-ron 7,704) use different
counting units, not a LOAM theorem-coverage denominator. The inventory separately
qualifies LOAM membership. Normalized export SHA-256:
`dfc3b589c42500998ba0577bdc716360a4c33dcd0e08a22f2946d36ce2c89611`.

Practical impact: the omitted private correspondence theorem is important retained
production evidence, but it was never rendered invalid by omission from a second
checker. The replay scope should be corrected. It is unjustified to characterize
the official tools as intrinsically weaker/unusable because of default-root
selection, or to equate runtime helper exclusion with an unverified theorem.
Supported alternate paths are explicit exporter roots, `--from-export`, and
`leanchecker --fresh`; see the version-pinned sources and official release notes.

## 6. Measurements and comparison conditions

Host: macOS 15.7.9 / Darwin 24.6.0, x86_64 Intel i5-8259U, eight logical CPUs,
16 GiB RAM. Same source revision and host for A/B. Fresh per-version `.lake` for
builds; durable build follows product build. Warm repetitions alternate A/B order.
No OS-page-cache eviction, thermal control or randomized cold ordering; no
statistical compiler speedup/regression claim. Native commands include Lake
startup. Inventory and checker work are not mixed with toolchain installation.
New fixture replays are single samples; earlier three-run Linux medians remain
historical evidence, not pooled with these macOS measurements.

| Workload | 4.33.1 | 4.35.0 | Scope / cache |
| --- | ---: | ---: | --- |
| Product `Loam` build | 33.573 s | 35.280 s | Fresh `.lake`; one sample |
| Durable after product | 5.025 s | 5.109 s | Shared product prerequisites within each version |
| Product warm | 1.165 s | 1.139 s | Median of 3 |
| Durable warm | 1.123 s | 1.137 s | Median of 3 |
| Existing umbrella-only replay | 3.196 s | 3.157 s | Median of 3; **zero own declarations** |
| All 22 LOAM modules, explicit replay | 30.514 s | 37.001 s | One sample; upstream imports trusted |
| Whole imported environment `--fresh` | 151.304 s | 152.998 s | One sample; includes unrelated standard-library declarations |
| Audit setup/build | 17.952 s | 17.724 s | Fresh audit `.lake`; excludes clone and toolchain install |
| Compiled axiom-audit | 2.780 s | 2.703 s | Median of 3; 1,151 / 1,150 candidates |

Pinned audits pass their unchanged allowlist. Counts differ by one generated
`Observation046.ForkNode.toCtorIdx`; both have 22 modules, 415 theorem entries,
12 partial definitions. Representative PtaMigrationClassifier and
CurrentCoverageInspection execution, and RelationDischargeFrontier proof
elaboration, pass on both versions. The latter is not invoked with `--run`.
`Loam.Observations` builds also passed (28.790 / 29.511 s), as did production
`loamTui` executable builds (134.184 / 132.278 s), with no source repairs. These
follow the preceding library builds and have fresh research/executable artifacts,
not cold entire-project caches. They are build compatibility, not a full TUI
runtime, release-platform or product test-suite qualification.

Official selected export of all 1,150 candidates took 5.408 s and normal
`lake check --from-export` took 11.956 s; an earlier successful check took 12.70 s
in `/usr/bin/time` but its Python result serialization failed. The corrected
rerun supplies the explicit exit/command record. All-candidate paranoid took
36.286 s and rejected only its partial definition input class. Export of the
61 omitted theorem roots took 3.714 s, normal check 3.839 s, direct Nanoda 0.555 s.
These are different tasks; none is compared to an axiom-only traversal as though
they gave the same guarantee.

The normalized, scoped workload is reproducible without a custom checker:

| 4.35 operation | Result | Wall time |
| --- | --- | ---: |
| Roots-only adapter | 1,138 names | 6.136 s |
| Compiled official exporter with those roots | Byte-identical normalized artifact | 5.360 s |
| Bundled `leanchecker --from-export` | Accept / 0 | 11.473 s, median of 3 (11.368 / 11.538 / 11.473) |
| All-candidate policy audit, separately | Accept / 0 | 2.703 s, median of 3 |
| Scoped `lake check --paranoid` | Every checker accepts / 0 | 47.812 s, one sample, 180 s budget |

The trusted scoped replay recipe is about 23.0 s plus the existing audit, without
installation/build costs. This is **not** a speedup over the old no-op gate;
it supplies a missing obligation. It is smaller than full `--fresh` here, but
not a claim about Linux recurring-job cost. The interpreted `dumpEnv` variant
alone took 34.601 s, so use the official compiled exporter rather than copying
serialization into an interpreted helper. No production helper was installed.
RSS for the normalized paranoid process group measurement was about 315.6 MiB
(`/usr/bin/time -l` maximum, not summed concurrent memory). Whole-project/default
paranoid completion remains unknown; scoped completion is now qualified.

No new initial toolchain-install measurement: installed versions were reused.
Earlier official Linux same-run setup samples were 10.83 / 11.49 s (4.33/4.35,
Ubuntu 24) and 10.92 / 12.54 s (Ubuntu 22); bwrap installation 8.48 / 12.38 s.
Earlier macOS formal install took 140.45 s and about 2.8 GiB. They are historical
setup observations, not universal cache costs. No persistent audit/export cache
was introduced. The existing Actions cache is keyed by toolchain and manifest;
a version update invalidates its old-toolchain artifacts.

## 7. Four candidates, without conflating decisions

| Candidate | Guarantees / uncovered boundary | Maintenance | Performance / migration |
| --- | --- | --- | --- |
| **A: 4.33.1 + current stack** | Build proof checking and full durable axiom policy; umbrella replay adds no imported-proof replay; no mandatory diverse kernel or statement comparison | Lean + one pinned audit dependency; no exporter selector/bwrap requirement | Lowest change risk, but unchanged replay scope/wording is not justified |
| **B: 4.35 + unchanged stack** | Same scope limitation/policy; no theorem loss observed | Same machinery; new bundled tools need not become gates | Comparable paired builds/audits; version itself is viable independently of replacing audit; full migration suite still required |
| **C: 4.35 + standard `lake check` / Comparator** | Correct exported proof checking and used-axiom policy; bare check selects product, not durable; misses unselected private roots and dormant declaration prohibition; Comparator gives separate statement guarantee only for configured artifacts | Removes separately cloned audit **only if** declaration policy is intentionally abandoned; introduces Linux sandbox environment dependency for Lake frontend | Bare whole-environment cost/OS constraints are poor recurring fit, but not intrinsic limits of scoped official export/checkers |
| **D: 4.35 + scoped official replay + minimal audit** | All durable logical roots and dependency closure replayed; retain all-candidate audit; independent statement/diverse-kernel checks remain selective | One small scope adapter + existing audit; no external exporter/Comparator Git pins for new trials; trusted replay CLI needs no bwrap | **Recommended direction**: supported, bounded path with honest coverage; qualify selector diagnostic/whole migration in separate PR; do not inherit bare-check target/sandbox costs |

A reasonable fifth option is **4.33.1 + corrected replay scope** (explicit modules
or `--fresh`), retaining audit. It decouples the necessary scope repair from an
upgrade and is a sound interim option. It is not a reason to reject 4.35.

D does not need the high-level `lake check` frontend on trusted LOAM-owned build
artifacts. Bundled `leanchecker --from-export` plus the existing policy audit is
smaller than duplicating used-axiom auditing in a new LOAM checker or requiring
bubblewrap solely to run trusted repository proofs. If genuinely hostile proof
submissions appear, use the official Linux sandbox path and qualify its producer
as well; an externally supplied export alone cannot establish source provenance.

4.35 also ships runtime/kernel hardening fixes documented in release notes
(#15241, #15289, #15288), independent of the new verification frontends. These
are a legitimate maintenance benefit, not proof of a vulnerability exploitable
in LOAM or a mandate to upgrade unqualified household software immediately.
This audit recommends moving toward 4.35 after full qualification, **not**
freezing the compiler because an audit cannot be directly replaced.

## 8. Overlap, diagnostics, sandbox and stopping decisions

Live topology was inspected with `tools/audit-ci-topology` and the owning
[CI map](../CI_OBLIGATION_MAP.md). There is **no live Comparator/Nanoda workflow**
to retire. Five historical fixture packages each retain Comparator/lean4export
requirements; built-in Comparator can remove those requirements in a future
on-demand trial, but that is not a saving in current recurring CI.

- Build vs correctly scoped replay have related but distinct trust boundaries
  (elaboration versus reconstruction from compiled/exported constants).
- Current umbrella-only replay is unnecessary complexity **as currently wired**;
  remove/replace that no-op obligation, not the durable proof boundary.
- Kernel checking vs axiom policy are not duplicates. Normal check's used-axiom
  guard overlaps part of audit; it cannot replace the complete declaration policy.
- Comparator's statement comparison is distinct; it cannot replace proof-to-
  production review. Keep Observations 237–238 closed and their small human bridge.
- Hardened Lean kernel is not another independent implementation. The extra
  bundled kernels add diversity and different input constraints; selected use
  earns its place, mandatory all-project replay has not.
- The explicit Nanoda config plus `--paranoid` runs Nanoda twice in fixture 168.
  That is fixture integration duplication, not a reason for a recurring gate.
- Nearby live lanes are not all independent workloads: Observation 080 rebuilds
  product Lean and directly elaborates 043/044, which also belong to durable and
  research surfaces on matching source-change PRs. The **paired Alloy/Lean receipt
  and bounded/unbounded interpretation** is distinct, so the whole job cannot
  simply be deleted. Its repeated broad Lean setup/replay is a consolidation
  candidate only after matching scope/triggers/manual-dispatch obligations and
  measuring runner cost; no such saving was measured or claimed here.
- Observation 078's separate axiom policy is not redundant with the broader
  native-decide-permitting research build. Its default-prefix replay occurs
  **before** its explicit Observation078 build, so it does not by itself promise
  fresh Observation078 replay. Direct source checking and the targeted audit
  remain real evidence. This adjacent ordering seam belongs in the narrow scope
  correction, not in a whole-repository CI retirement project.
- Product, durable and research surfaces have independently observable policies.
  Shared imported prerequisites/build caches are not a reason to merge them.
  No new job/frequency/shard is proposed; existing presentation-local skips stay.

Failure diagnostics distinguish statement mismatch, named forbidden proof axiom,
module/name absence, unsupported `partial`, Nanoda's strict-empty `propext`
integration panic, namespace startup failure, and harness timeout. Exit 1 is not
uniformly a proof rejection. In new fixture replay normal 165/168/238 accept;
166/167 reject at comparison before kernels. Paranoid strict-empty 165 fails
without broadening policy; 168 passes with its already-qualified `propext` rule.

The downloaded Ubuntu 24 logs show uid-map/loopback namespace permission failure
with AppArmor userns restriction enabled. Ubuntu 22 without that restriction
runs the stock sandbox. No sole-cause experiment or host policy relaxation was
performed. The corrected marker probe qualifies hidden home/tmp/env, read-only
source/root, writable `.lake`, and no external network during build; the public
`/opt` marker remains readable. Dependency resolution deliberately has network.
These are bounded integration results, not confidentiality/DoS/security proofs.
No Linux re-run or broad security audit is needed to infer this environment
classification; no sandbox bypass is claimed as Linux isolation evidence.

### Now, later, unchanged

1. **Now worth acting on, in a separate small production PR:** correct the
   durable replay scope and its misleading independent-check wording; preserve
   private logical roots and all-candidate audit. A docs-only result cannot fix CI.
2. **Version adoption:** favor a separately qualified 4.35 update; product,
   durable and selected builds/tests are evidence, not full platform/release/runtime
   migration approval. Main is unchanged here.
3. **Simplification worth retaining:** use official export/replay/Comparator and
   bundled kernels rather than reviving separate fixture toolchain installations;
   avoid a duplicate custom used-axiom checker or mandatory paranoid lane.
4. **Unchanged:** durable declaration policy, three proof surfaces, path-sensitive
   CI frequency, human intent/production correspondence review, operational data.
5. **Deferred:** complete migration/test/release matrix; Linux timings of the
   corrected scoped path; hostile-proof sandbox security; whole-project paranoid
   completion; repeated cold setup/OS-cache-controlled performance; final
   production packaging/diagnostics of the tiny scope adapter; any measured consolidation of repeated Lean work in the paired
   Observation080 lane. Do not close the issue merely because the original KEEP
   recommendation was written.

## 9. Reproduction and sources

Use a fresh directory and the exact baseline commit for each version. Use
explicit native binary paths and PATH, not edits to `lean-toolchain` or pins.
Extract the frozen evidence locally to inspect drivers, command arrays, expected
exits, raw logs and inventories. Drivers contain original absolute paths; adapt
those installation/work-directory prefixes only. All code is one-shot evidence,
not a repository tool or proposed CI input.

```sh
# In isolated baseline worktrees, with the chosen bin directory first on PATH:
lake build Loam
lake build Loam.DurableProofs
lake env leanchecker --verbose Loam.DurableProofs       # only umbrella
lake env leanchecker --fresh --verbose Loam.DurableProofs
lake env lean --run Inventory.lean                    # inspect module ownership
# Official scoped export, excluding partial/unsafe runtime helpers:
lake env lean --run SelectedRoots.lean > roots.txt
# Bash on Linux, preserving each full internal name as one argument:
mapfile -t roots < roots.txt
lake env leanexport Loam.DurableProofs -- "${roots[@]}" > normalized.ndjson
lake env leanchecker --silent --from-export normalized.ndjson
# Independently retain the current policy over ALL owned declarations:
lake env /path/to/pinned/axiom-audit --root Loam \
  --modules Loam.DurableProofs --allow propext,Classical.choice,Quot.sound --json
# Linux with working stock bwrap; all-kernel experiment, 180 s budget:
lake check --from-export normalized.ndjson --paranoid
# Existing copied Challenge/Solution/config in dependency-free fixture package:
lake build Challenge Solution
lake comparator --config config.json
```

MacOS Lake frontend experiments used `--inadvisably-no-sandbox` **only on trusted
specimens**, and record its warning. They qualify logical checking/integration,
not hostile-code isolation. Direct Nanoda and bundled replay likewise make no
sandbox claim. The original marker Linux experiments never use this flag.

Authoritative version-specific sources inspected:

- [Official 4.35 release notes](https://lean-lang.org/doc/reference/latest/releases/v4.35.0/),
  checking and kernel/runtime fixes; [Lake reference](https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Lake/).
- [v4.35 LeanExport/Basic.lean](https://github.com/leanprover/lean4/blob/v4.35.0/src/LeanExport/Basic.lean):
  `dumpEnv` non-internal roots, `dumpConstant` unsafe guard and dependency closure.
- [v4.35 Lake/CLI/Check.lean](https://github.com/leanprover/lean4/blob/v4.35.0/src/lake/Lake/CLI/Check.lean),
  [Check/Axioms.lean](https://github.com/leanprover/lean4/blob/v4.35.0/src/lake/Lake/Check/Axioms.lean),
  [CLI/Main.lean](https://github.com/leanprover/lean4/blob/v4.35.0/src/lake/Lake/CLI/Main.lean):
  default modules, policy, external kernels, sandbox and export-input handling.
- `src/LeanChecker.lean`, `src/Lean/Replay.lean`, `src/Lean/Environment.lean`
  in both pinned toolchains: prefix selection, imported maps, `--fresh`, and
  partial/unsafe replay exclusions.
- Pinned axiom-audit `AxiomAudit.lean`: module ownership, self-axiom policy,
  trusted imports, empty-audit refusal and documented traversal limitations.

The evidence manifest names all retained files and their hashes. Successful
measurement collection is never substituted for individual checker verdicts.

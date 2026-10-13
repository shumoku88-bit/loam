# Issue 1963 — built-in Lean checking spike

Status: **HISTORICAL INVESTIGATION — conclusion superseded by the [independent re-audit](lean-435-independent-reaudit.md)**

The measurements below are retained, not silently rewritten. The re-audit corrects
both the interpretation of internal export omissions and the claimed scope of the
baseline `leanchecker` invocation. The earlier KEEP CURRENT / issue-close advice
is historical, not the current recommendation. Issue #1963 remains open.

Measured on 2026-10-13. This record owns the version-specific cost and coverage
comparison requested by [#1963](https://github.com/shumoku88-bit/loam/issues/1963).
It does not supersede the [verification boundary checkpoint](verification-boundary-checkpoint.md)
or change the [evidence ledger](../verification/EVIDENCE_LEDGER.md).

## Qualification boundary

- Baseline main: `2f213d0b947e43b86acd26774d46c83c5124011d`.
- Baseline Lean: `v4.33.1`, commit `819816b2e0a3bf405af45ae5c7af2491d8f5bee6`.
- **Preview only:** already-installed `v4.35.0-rc3`, commit prefix `470d5ce`.
  Formal `v4.35.0` was not installed; installation permission was requested.
- Formal upstream tag exists at `eb6cafb7290e8bd5f2937522d8d804f58f02bafc`.
  `src/lake/Lake/CLI/Check.lean` is byte-identical to installed rc3 source, but
  the intervening seven commits include changes to `LeanExport.Json` and
  `LeanExport.Parse`. **Source agreement is not formal-release qualification.**
- Local host: macOS 15.7.9, x86_64, Intel i5-8259U 2.30 GHz, eight logical CPUs,
  16 GiB RAM. No Linux runtime, Docker or bubblewrap was available.
- All rc3 successful checker runs used **`--inadvisably-no-sandbox`**, only on
  trusted repository specimens or tiny synthetic code under `/tmp`.
  They do not qualify adversarial isolation. Normal sandboxed invocations
  refused to start on macOS with exit **2**, not proof rejection.
- No operational data was read or changed. Product sources, toolchain and
  dependency pins, default targets and CI policy were not changed.

## Baseline: live CI and local replay

[Main CI run 38397420235](https://github.com/shumoku88-bit/loam/actions/runs/38397420235),
first attempt, succeeded for all three proof surfaces on Ubuntu x64.
The workflow elapsed approximately 59 seconds; individual job spans were:

| Job | Span | Result |
| --- | ---: | --- |
| Scope selection | 7 s | success |
| Product | 31 s | success |
| Durable | 38 s | success |
| Research observations | 47 s | success |

These are timestamp spans, not billed cost or exclusive CPU time. Jobs run in
parallel. Durable restored a previous-main `.lake` cache; its costs were:

| Durable operation | Measured duration |
| --- | ---: |
| Restore shared cache | about 5 s |
| Install elan / Lean | 19.823 s |
| Cached durable build | 0.680 s |
| Bundled `leanchecker` step | 1.194 s |
| Clone pinned axiom-audit, build and audit | about 5.28 s |

The axiom-audit source remains pinned to `v0.1.2` /
`46024e005996495c65ef609368e11ab39c4222e3`. Its CI output was:

```text
axiom-audit: audited 1151 declaration(s) under 'Loam'; all within the allowlist [propext, Classical.choice, Quot.sound].
```

Baseline `leanchecker` is already bundled with Lean: this is not a separate
checker dependency that 4.35 newly eliminates. The separately cloned/built
axiom-audit is the identifiable maintenance/setup simplification candidate.

Locally, `lake build Loam Loam.DurableProofs` succeeded in 2.82 s using existing
build artifacts. It replayed existing unused-section-variable, unused-simp and
unnecessary-simpa warnings; it was **not a clean build**. After that build,
three `lake env leanchecker --silent Loam.DurableProofs` runs succeeded:
2.89 / 2.80 / 2.84 s, median **2.84 s**, maximum RSS about **441.8 MiB**.
These include `lake env` startup, unlike the narrower CI checker measurement.

## Actual coverage, not a percentage

A read-only Lean inventory imported each compiled root and selected declarations
by their **defining module** under `Loam`, matching axiom-audit's candidate rule.
It includes private/generated declarations, not just theorem names with a
`Loam` namespace prefix. `trustLevel := 1024` was used for this inventory only;
the inventory is not another proof checker.

| v4.33.1 root | LOAM modules | LOAM declarations | `.thmInfo` entries |
| --- | ---: | ---: | ---: |
| Product `Loam` | 102 | 6,338 | 1,621 |
| Durable `Loam.DurableProofs` | 22 | 1,151 | 415 |

`.thmInfo` includes generated theorem entries; it is not a count of independent
household claims. The durable count independently matches the CI audit.
The kernel replay imports more than these LOAM candidates, including Lean's
standard library; the audit separately restricts candidates by module ownership.

The six durable modules absent from the product import closure are:

```text
Loam.Application.ScheduledOccurrenceConstruction
Loam.DurableProofs
Loam.Observations.Observation043
Loam.Observations.Observation044
Loam.Observations.Observation045
Loam.Observations.Observation046
```

`lakefile.lean` selects only `lean_lib Loam` as the default target. Its default
globs select the root, not every `Loam/**` source file. Research
`Loam.Observations` remains a separate surface that can use `native_decide`.

The built-in check path builds default targets, obtains `root.defaultModules`,
imports those modules and dumps the environment. It has no target-selection
argument analogous to `leanchecker Loam.DurableProofs`. **Bare `lake check`
is not the existing durable gate.**

A synthetic package with default `Product` and non-default `Durable` confirmed
this experimentally: both were built first; `Durable` contained an axiom proving
`False`. Default `lake check` still accepted `Product`. Exporting the selected
`Durable` theorem and passing it to `check --from-export` rejected the forbidden
axiom (exit 1). Merely building a non-default target does not include it in check.

## rc3 preview measurements

Original fixture `.lean` files and axiom policies were copied unchanged into
separate dependency-free TOML packages. This removes the old Comparator /
lean4export dependencies for the preview without migrating the retained fixtures.
Each normal measurement below is the median of three warm-build runs, including
Lake startup, export, comparison and selected kernels. Times are host-specific.

| Preview workload | Outcome / exit | Median wall time | Max RSS |
| --- | --- | ---: | ---: |
| Observation 165, empty axiom list | accept / 0 | 2.569 s | 731.2 MiB |
| Observation 166, statement drift | reject / 1, statement mismatch | 2.365 s | 731.3 MiB |
| Observation 167, forbidden axiom | reject / 1, `unpermitted_fact` | 2.572 s | 731.4 MiB |
| Observation 168, existing `propext` allowance + Nanoda | accept / 0 | 2.711 s | 731.3 MiB |
| Observation 238, production-free proof | accept / 0 | 2.646 s | 731.4 MiB |
| Synthetic default `Product`, full `lake check` | accept / 0 | 128.199 s | 1,102.7 MiB |

The three full default-check times were 135.501 / 125.709 / 128.199 s. The
synthetic source was only `theorem product_claim : 1 = 1 := rfl`; full checking
exports the imported environment, not just that theorem. This is not a LOAM
4.35 build or an equivalent-workload speed comparison with durable CI.

The targeted synthetic `Durable` export was rejected in 0.236 s, after kernel
acceptance, for its non-standard axiom. This is a deliberately tiny exported
artifact, **not** a measured LOAM durable replacement. An unused custom-axiom
export was also tested and **accepted**; see the policy mismatch below.

### Axiom-policy mismatch: unused custom axioms

A second synthetic specimen retained only an unused custom axiom:

```lean
namespace ScopeProbe
axiom unused_fact : False
end ScopeProbe
```

`leanexport Dormant -- ScopeProbe.unused_fact` included that axiom declaration
in the NDJSON. The rc3 `lake check --from-export dormant.ndjson` accepted it
(exit **0**, 0.18 s native time) and printed **`Uses no axioms`**.

In a separate v4.33.1 temporary package, the unchanged pinned `AxiomAudit.lean`
source was replayed with a tiny main calling its own `withImportedEnv` / `audit`
functions, selecting the specimen's defining module `Dormant` and the production
three-axiom allowlist. It audited one declaration, returned **`ok: false`** and
reported `ScopeProbe.unused_fact` as forbidden (exit **1**). This calls the pinned
audit implementation directly; its interpreter startup time is not compared with
the compiled CI executable.

The implementation distinction is concrete: baseline `axiomsOf` includes an
axiom declaration itself in its dependency set; built-in `usedAxioms` excludes
self-references and reports only axioms referenced by other exported constants.
That is a meaningful policy difference, even though both reject the separately
tested theorem which *uses* a forbidden axiom. An actual durable selection export
alone therefore does **not** establish equivalence to today's full declaration
audit. The formal release's checking source has this same traversal; formal
binary replay is still outstanding.

### Paranoid and integration failures

`--paranoid` adds `leanchecker-paranoid`, `lean4lean`, `nanoda_bin`, `con-leche`
and `con-ron`, as well as normal Lean kernel replay.

- Observation 165 with the unchanged **empty** axiom list failed in 18.946 s:
  Nanoda panicked because `propext` was absent (`nanoda exited with 101`);
  Lake returned 1. The other five checkers accepted. This is an integration
  failure on an otherwise accepted proof, not a forbidden-axiom specimen.
  Do not silently add `propext` to turn the strict-empty policy green.
- Observation 168 with its already-qualified `propext` allowance passed all
  checkers in **17.772 s**, about 731.4 MiB maximum RSS (one run).
  Its explicit Nanoda entry also runs Nanoda, so this particular command runs
  Nanoda twice; do not use it as a deduplicated cost measurement.
- The legacy `enable_nanoda: true` fixture initially could not start (exit 2):
  `nanoda_bin` was installed but not on the invoking PATH. Only the temporary
  config was adapted to `external_kernels` with the installed binary's absolute
  path; the permitted-axiom list was unchanged.
- Full synthetic `lake check --paranoid` was explicitly stopped at **180 s**.
  Lean paranoid accepted; the log had reached `lean4lean`, with no verdict yet.
  Exit 124 is the measurement harness's timeout marker, **not a Lake exit code**.
  The first combined batch also exceeded its 600 s wall budget; this bounded
  rerun retained streaming output. Full paranoid success/cost remains unknown.

RSS is `/usr/bin/time -l`'s reported maximum, not a sum of concurrent process
memory or a long-duration leak claim. Cold specimen builds were separate from
these warm measurements. Formal-release installation/setup cost was not measured.

## Reproduction and retained local evidence

Raw logs, command arrays, exit codes, durations, temporary packages and the Lean
inventory are under `/tmp/loam-1963-probe/`; live CI raw logs are additionally at
`/tmp/loam-1963-baseline-ci.log`. These are local, ephemeral artifacts, not CI
attachments. The tables and failure diagnoses above retain the useful findings.

For each `verification/observation{165,166,167,168,238}` specimen, copy only
`Challenge.lean`, `Solution.lean` and `config.json` to a fresh temporary directory;
create a TOML package with `Challenge` and `Solution` lean libraries and no
requirements. Set the preview toolchain there to `leanprover/lean4:v4.35.0-rc3`:

```sh
lake build Challenge Solution
# macOS: expected exit 2, no Linux namespaces
lake comparator --config config.json
# Trusted-input preview only; never an adversarial-proof CI setting
/usr/bin/time -l lake comparator --config config.json --inadvisably-no-sandbox
/usr/bin/time -l lake comparator --config config.json --paranoid --inadvisably-no-sandbox
```

For Observation 168, put the bundled Nanoda directory on PATH, or replace the
legacy enable flag with `external_kernels: {"nanoda": ["/absolute/path/nanoda_bin"]}`.
Keep its existing `["propext"]` policy. For the coverage sentinel use two lean
libraries, `defaultTargets = ["Product"]`, and these independent files:

```lean
-- Product.lean
namespace ScopeProbe
theorem product_claim : 1 = 1 := rfl
end ScopeProbe
```

```lean
-- Durable.lean
namespace ScopeProbe
axiom forbidden_fact : False
theorem durable_claim : False := forbidden_fact
end ScopeProbe
```

```sh
lake build Product Durable
/usr/bin/time -l lake check --inadvisably-no-sandbox
lake env leanexport Durable -- ScopeProbe.durable_claim > durable.ndjson
# Expected exit 1, naming ScopeProbe.forbidden_fact
lake check --from-export durable.ndjson --inadvisably-no-sandbox
```

## Preview decision and remaining obligations (superseded below)

**KEEP CURRENT production CI and all surface boundaries.** A direct replacement
is not equivalent: target coverage differs and the unused-custom-axiom specimen
weakens today's declaration-level audit. Built-in Comparator remains a plausible
fixture-dependency simplification, but there is no qualified production
replacement or measured speedup yet. Further experimentation should address
these concrete differences, not assume that matching allowlist names suffice.

The new export/comparison/kernel pipeline still does not establish human intent
or proof-to-production correspondence: Observation 238 continues to be accepted.
The exporter, comparator/axiom traversal, checked statement, selected modules and
kernel implementations remain explicit trust edges. A targeted `--from-export`
check says nothing by itself about the repository that purportedly produced it.

Before recommending a separate production PR:

1. With permission, install formal `v4.35.0` and use a disposable detached worktree.
   Build product and durable separately; run representative product tests and
   record language/library failures separately from checker failures.
2. Qualify an actual durable export or isolated selection package, including
   private/generated declarations, against the current 1,151-declaration audit.
   Preserve rejection of unused custom axiom declarations as well as reachable
   forbidden axioms. Do not alter main's default product target to obtain coverage.
3. Repeat positive/negative fixtures on the formal release; preserve the strict
   empty-policy paranoid failure and Observation 238 boundary.
4. Measure on Linux with real bubblewrap, user-namespace availability and network/
   filesystem isolation. macOS refusal is not Linux sandbox qualification.
   Any GitHub Actions experiment needs separate approval; no workflow was added
   or dispatched. Compare equal workloads and cache/setup conditions there.
5. Bound full paranoid work before expanding it; do not make it an all-PR gate.

Current rollback is trivial: no production switch occurred. Discard the temporary
packages when no longer needed. A future replacement PR must retain a small way
to restore the existing durable `leanchecker` and pinned axiom-audit steps; its
measured evidence must justify removing those steps rather than adding a duplicate
mandatory gate.

## Formal v4.35.0 follow-up — 2026-10-13

### Isolation, evidence and build compatibility

The authorized follow-up used official `v4.35.0`, commit
`eb6cafb7290e8bd5f2937522d8d804f58f02bafc`, in a separate local `ELAN_HOME`.
Download/install took **140.45 s**, occupying about **2.8 GiB** locally. The
ordinary elan installation still lists only 4.33.1 and rc3; ordinary `lean`
remains 4.33.1. Both version builds used fresh detached worktrees of the same
`2f213d0b947e43b86acd26774d46c83c5124011d` source, explicit native Lake paths,
no shared `.lake` artifacts and **unchanged repository revision pins**.

Linux measurements used a disposable branch, changing only the existing
`selected-lean-observations.yml` and an experiment-only driver. No PR or
permanent workflow was created. The following manual runs retain raw evidence
as `issue1963-lean435-evidence` artifacts (30-day retention):

| Run | Scope | Job span |
| --- | --- | ---: |
| [38412938086](https://github.com/shumoku88-bit/loam/actions/runs/38412938086), `e0ef53a5ea21eb5a6c0625c637b8edf5db8a191d` | Ubuntu 24.04 paired builds/audit; namespace refusal | 167 s |
| [38413883360](https://github.com/shumoku88-bit/loam/actions/runs/38413883360), `69aec49b` | Ubuntu 22.04 official sandbox/checker replay | 659 s |
| [38415863123](https://github.com/shumoku88-bit/loam/actions/runs/38415863123), `eb379ecb` | Corrected, marker-only sandbox assertions | 36 s |

A green *measurement workflow* means collection completed, not that every
checker accepted. The record below distinguishes expected rejections,
environment failures and bounded timeouts. Total successful-run job spans were
862 runner-seconds, **not** a proposed recurring gate cost or billed-price claim.

Product and durable builds succeeded without source repair:

| Operation (one sample per cell) | macOS 4.33.1 | macOS 4.35.0 | Ubuntu 24.04 4.33.1 | Ubuntu 24.04 4.35.0 |
| --- | ---: | ---: | ---: | ---: |
| Product `Loam`, fresh `.lake` | 33.533 s | 45.266 s | 26.630 s | 25.602 s |
| Durable, after product build | 5.098 s | 5.448 s | 2.171 s | 2.174 s |
| Product, warm | 1.080 s | 1.108 s | 0.566 s | 0.566 s |
| Durable, warm | 1.081 s | 1.091 s | 0.566 s | 0.565 s |
| Existing durable `leanchecker` | 3.259 s | 3.528 s | 1.419 s | 1.418 s |
| Pinned compiled durable axiom-audit | not timed | not timed | 1.167 s | 1.167 s |

Versions were measured sequentially, not randomized, with no cold-OS-cache or
thermal control. These are bounded build-compatibility/cost observations, not
statistically established compiler regressions or speedups. Existing warnings
remain; 4.35 changes the two durable `unnecessarySimpa` hints to “`simp` already
closes the goal.” No language/tactic/library build failure occurred in these roots.

`PtaMigrationClassifier` and `CurrentCoverageInspection` executable tests passed
on both versions and on macOS/Ubuntu 24.04. The discharge frontier's
`native_decide` examples elaborated successfully on both versions locally.
The initial driver incorrectly used `--run` on that proof-only file and logged
`unknown declaration 'main'` on both versions; the proper plain `lake env lean
Loam/Tests/RelationDischargeFrontier.lean` replay passed. This was an invocation
mistake, not a product/test regression. Full research/TUI/executable migration
and a complete product test suite were not undertaken.

The version inventories retained the same module surfaces and theorem-entry counts:

| Root | Modules | 4.33.1 declarations / `.thmInfo` | 4.35.0 declarations / `.thmInfo` |
| --- | ---: | ---: | ---: |
| Product `Loam` | 102 | 6,338 / 1,621 | 6,331 / 1,621 |
| Durable | 22 | 1,151 / 415 | 1,150 / 415 |

The durable difference is the compiler-generated
`Loam.Observation046.ForkNode.toCtorIdx`, absent in 4.35. Product differences
are seven removed `toCtorIdx` helpers and four shifted generated hygiene names.
No theorem-entry loss was observed. Both compiled audits passed their original
three-axiom policy; no allowance was added.

### Formal checker results and declaration-coverage counterexample

The same five fixture sources and axiom lists were replayed unchanged. Only the
temporary Observation-168 Nanoda command was given an explicit installed path.
Ubuntu 22.04 used **ordinary sandboxed `lake comparator`**, never the bypass flag.

| Fixture | Normal result | macOS median, 3 warm runs | Linux median, 3 warm runs |
| --- | --- | ---: | ---: |
| 165, valid, empty allowance | accept / 0 | 2.673 s | 1.720 s |
| 166, statement drift | reject / 1, statement mismatch | 2.419 s | 1.568 s |
| 167, forbidden proof axiom | reject / 1, `unpermitted_fact` | 2.403 s | 1.568 s |
| 168, existing `propext` allowance + Nanoda | accept / 0 | 2.587 s | 1.768 s |
| 238, production-free proof | accept / 0 | 2.578 s | 1.719 s |

Formal paranoid replay also preserves the integration boundary: strict-empty
165 fails because Nanoda cannot find `propext` (exit 101 from Nanoda, **1 from
Lake**); 168 accepts in 4.694 s locally / 3.274 s on Linux. Its explicit Nanoda
entry still duplicates the bundled Nanoda run. Paranoid 166/167 reject at
statement/axiom comparison before kernels; no claim that all kernels ran on
those rejected artifacts is made.

Default `lake check` accepts the synthetic Product while excluding the already
built non-default Durable: **143.183 s** locally, **94.572 s** on Ubuntu 22.04.
A tiny selected Product export accepts under both normal and paranoid check;
Linux times are 0.115 / 0.265 s. Full default `--paranoid` was stopped at **180 s**
on each host: on Linux, Lean paranoid and lean4lean accepted, and Nanoda was
running; not all six checkers completed. Exit 124 is the harness timeout marker.
A small successful paranoid export is not evidence of whole-project paranoid
success, and neither outcome justifies a mandatory all-PR job.

**Actual durable export is not the audit candidate set.** An unfiltered
`leanexport Loam.DurableProofs` produced **651,450,052 bytes** (~621.3 MiB),
SHA-256 `d2f770330f58023706b7f90444a8a44ae9cefc0d75bf53c0e69ba59003e8f4d6`.
Linux and local exports were byte-identical. Resolving the NDJSON name/declaration
records against the defining-module inventory found **997 of 1,150** audited
LOAM candidates in the export: **153 omitted**, including **61 theorem entries**.
All omitted names are internal; none of the 1,150 candidates is unsafe.

The exporter defaults to non-internal roots, then recursively includes their
dependencies; importing a module does not independently select every private
proof in it. One omitted retained production-correspondence theorem is:

```text
_private.Loam.Application.OpenRelationFrontier.0.Loam.Application.buildCoverageIndex_getD_eq_currentCoverageFor
```

This export contained 133,531 declarations overall, mostly imported libraries.
The formal Linux `check --from-export` accepted it, using only the three standard
axioms, in **141.034 s**. Acceptance does **not** recover the omitted private
proofs. Selecting durable instead of product alone therefore does not establish
baseline coverage. No new selector/framework was built to conceal this gap.

### Unused axiom: normal and paranoid differ

The compiled pinned audit, on **both** 4.33.1 and 4.35.0, rejects the unchanged
Dormant specimen: one candidate, `ScopeProbe.unused_fact`, `ok: false`, exit 1.
Formal **normal** `check --from-export` still accepts it and reports `Uses no
axioms`; on Linux even a package whose **default target is Dormant** accepts
under ordinary `lake check` (95.074 s). The difference is not manufactured by
exporting the wrong module or dropping the axiom from the artifact.

A theorem which uses the forbidden axiom is rejected by normal check (exit 1).
Additional local formal `--paranoid` probes show a distinct result: an exported
unused custom axiom is **rejected**, because con-leche/con-ron decline a
non-standard axiom; Nanoda skips that unpermitted unused declaration and accepts.
The used-axiom artifact is also rejected (Nanoda fails; con-leche/con-ron decline).
These are external-checker verdicts, not a change to normal `usedAxioms` policy.
Paranoid thus catches this particular **exported** dormant axiom, but it does
not fix declarations omitted from the export or make normal check equivalent to
the targeted audit. Their differences must not be flattened into one “clean” flag.

### Official Linux sandbox: established behavior and limits

Ubuntu 24.04.5 / kernel 6.17 / bubblewrap 0.9.0 had
`unprivileged_userns_clone=1`, `apparmor_restrict_unprivileged_userns=1`.
The ordinary comparator failed at `setting up uid map: Permission denied`;
a bare bwrap smoke failed at loopback `RTM_NEWADDR: Operation not permitted`.
Lake returned **1**, although no proof comparison had occurred. Installing the
binary is not sufficient on this runner. These observations identify a namespace
permission/environment failure; the experiment did not prove its sole cause or
change AppArmor/sysctl/setuid policy to force acceptance.

Ubuntu 22.04.5 / kernel 6.8 / bubblewrap 0.6.1 had the same userns switch enabled
and the AppArmor userns restriction switch at 0. The standard smoke and ordinary
Lake commands succeeded. The marker-only final replay builds the Solution **inside
Lake's own sandbox**, then checks its original fixture theorem. Assertions passed:

- Synthetic files in the invoking user's home and host `/tmp` were hidden.
- A synthetic host environment variable was not inherited.
- Writes to project source and an otherwise host-writable `/opt` marker failed
  with `EROFS`; writing `.lake/sandbox-write` succeeded and was verified on host.
- `/proc/net/dev` exposed only loopback; external TCP connect failed with errno
  101 (`ENETUNREACH`).
- The synthetic public `/opt` marker remained **readable**, deliberately testing
  a limit of read-only root binding rather than pretending all host files vanish.

The initial marker helper omitted Python's `-c` argument and failed to execute
its assertions; only the corrected marker-only run (2.120 s) qualifies them.
An earlier workflow dispatch also failed YAML validation before a job started.
Neither harness failure is presented as proof rejection or isolation evidence.

This is bounded integration evidence, **not** a general hostile-proof sandbox
security audit. Dependency resolution intentionally has network access; build,
export and checker processes have a fresh network namespace. Read-only root
visibility is not complete host confidentiality, and CPU/RAM/disk exhaustion is
not eliminated by these namespace checks. Those limitations still require an
explicit threat model and runtime budgets if adversarial submissions ever appear.
No fake bwrap/landrun shim, custom sandbox, privileged Lake execution or host
security-policy relaxation was used.

### Cost, maintenance and closure decision

On Ubuntu 24.04, isolated official toolchain installation cost 10.83 s for
4.33.1 / 11.49 s for 4.35.0; distro bubblewrap setup cost 8.48 s. On Ubuntu 22.04
those costs were 10.92 / 12.54 / 12.38 s. These are setup samples, not permanent
cache assumptions. Bare standard-library-heavy exports are a material cost:
on the same Ubuntu-22.04 runner, existing 4.33.1 durable checker + audit
clone/build/run totaled **6.876 s** after the durable build. Formal durable
export + normal check totaled **174.229 s** (33.195 + 141.034), while omitting
153 candidates. These workloads have different guarantee sets; no equivalent
coverage speedup is claimed. Reported maximum RSS was 606.1 MiB for the Linux
synthetic default check and 1,036.3 MiB for the actual durable export check;
the local synthetic default check reported 1,100.8 MiB. These `/usr/bin/time`
figures are not a sum of simultaneous sandbox processes or leak qualification.

Built-in Comparator removes the two fixture-local Comparator/lean4export Git
requirements in this isolated replay. Those historical fixtures are not a
mandatory live production gate, so that simplification does not itself save
recurring product CI work. The normal checker was already bundled in 4.33.1.
Replacing the separately maintained audit would require explicit selection,
declaration-level policy, runtime/sandbox qualification and new glue; the
measured built-in path does not earn that maintenance trade-off.

**Final recommendation: KEEP CURRENT. Issue #1963 can close as a qualified
no-change investigation, without upgrading main or proposing a replacement PR.**
Formal release results do not change the preview decision. The normal unused-
axiom mismatch, actual internal-proof omissions, default-target mismatch,
paranoid integration/resource limits and Ubuntu-24.04 namespace refusal are
concrete reasons, not merely a preference for older tooling.

The three proof surfaces remain separate. Observation 238 still qualifies only
statement identity, axiom policy and kernel replay—not human intent or
production correspondence. Intent/statement review and the small production
bridge remain human trust edges. The new sandbox evidence does not erase them.

Full-project paranoid completion, whole-repository/toolchain migration, broader
adversarial security review and statistically controlled performance comparisons
are intentionally not required for this **KEEP** decision. Reopen only for a
concrete need with a smaller equivalently scoped replacement, or genuinely
adversarial proof pressure; do not expand CI merely because bundled tools exist.

Evidence is retained locally under `/tmp/loam-1963-formal/` and in the linked
manual-run artifacts. Experiment scripts/workflows exist only in the disposable
commit history, not the maintained repository surface. The temporary remote
branch is removed after evidence collection; no mainline workflow or toolchain
change needs rollback. Reproduction uses the same copied fixtures/sentinel and
explicit 4.35 native Lake, with **no bypass flag on a Linux host whose standard
bubblewrap works**. The issue itself is left open for the maintainer's close
decision; no issue-close operation was performed.

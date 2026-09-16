# MGA-021 — Module Granularity First-Pass Closure

Status: **CLOSED — no unexplained structural candidate remains strong enough to justify another first-pass implementation experiment**

Base observed before closure: `813425b1ef4a115b8b419936a9cc95bc530d1857`

This checkpoint closes the first repository-wide Module Granularity Audit. The conclusion is deliberately narrower than “the module structure is perfect.” It says that the current whole-repository evidence no longer supports continuing a broad hunt for merges, splits, moves, or retirements.

## Governing principle

> Keep only distinctions with independent reasons to change, reuse, prove, qualify, or own; derive what can be derived; do not make physical module count itself a target.

The first pass used module dependency topology, recent co-change history, source responsibility inspection, DRAKON for suspicious clusters, and Lean/production qualification after actual boundary changes.

## Fresh whole-repository rerank

MGA-021 reran `tools/module_granularity_audit.py` on latest main after MGA-020 and CSA-002 had merged.

```text
Lean modules: 337
Modules <= 80 lines: 92
Modules with exactly one local consumer: 56
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 0
Recent commit change sets observed: 175
```

These counts remain candidate signals only. In particular, 56 one-consumer modules do not imply 56 merge opportunities.

Largest reachable production modules at closure included:

```text
Loam.Tui.Cli                              1067 lines / 30 declarations / fan-out 58
Loam.Tui.Reports                           892 lines / 78 declarations / fan-in 3 / fan-out 15
Loam.Application.ScheduledCommitmentInspection
                                                600 / 36 / fan-in 7
Loam.Tui.RoleBalances                      418 / 39 / fan-in 2
Loam.RoleBalanceReview                     413 / 30 / fan-in 9
Loam.Persistence.NormalizedActualPersistence
                                                385 / 10 / fan-in 4
Loam.Tui.ActualRoutingAdministration       379 / 22 / fan-in 3
Loam.Tui.SelectedDay                       378 / 32 / fan-in 5
Loam.Tui.HraScheduled                      350 / 36 / fan-in 3
```

No size-only case above creates a new split verdict. `Tui.Cli` has already been calibrated through focused session extractions; `Reports` has just passed the ReportWindow and TransactionsFlowPane experiments; the remaining large semantic/persistence modules have multiple independent consumers or authority responsibilities.

## Residual one-consumer review

After excluding historical `Observations` modules and already-qualified MGA boundaries, the largest remaining one-consumer production examples were mostly CLI input/command boundaries:

```text
Loam.Cli.Movement.RelationEntry       188 lines -> MovementCli
Loam.Cli.Movement.DischargeEntry      115 lines -> MovementCli
Loam.Cli.EffectiveCli                 110 lines -> Cli
Loam.Persistence.ScheduledPersistence 107 lines -> ScheduledLifecyclePersistence
Loam.Tui.LocusAdmissionAdministrationSession
                                      96 lines -> Tui.Cli
Loam.Cli.Movement.Entry                88 lines -> MovementCli
Loam.Persistence.LocusAdmissionPersistence
                                      84 lines -> LocusAdmissionAuthority
Loam.Tui.AttentionAdministrationSession
                                      76 lines -> AttentionCli
Loam.Cli.ScheduledDayEvidenceCli       75 lines -> OpenScheduledCli
Loam.Cli.CorrectionIntegrityCli        73 lines -> Cli
```

The strongest previously unexplained family was the Movement CLI cluster. Source and history inspection does not support collapse:

- `RelationEntry` owns an explicit relation-entry grammar, `LOAM_RELATIONS` scripted contract, interactive endpoint/direction/quantity collection, and validation before writer-owned admission;
- `DischargeEntry` owns a different discharge grammar, `LOAM_DISCHARGES` contract, target/quantity collection, and its own refusal surface;
- `MovementCli` composes occurrence date, description, Movement effects, relation evidence, discharge evidence, and the authoritative `HouseholdCommand.record` call rather than duplicating those input grammars;
- PR #679 explicitly narrowed the Movement entry dependencies independently, positive evidence that these physical seams have their own dependency reasons to change.

Representative residual command modules show the same pattern rather than arbitrary file slicing. `EffectiveCli` is a read-only human projection over Application quantity inspection and correction-frontier admission. `ScheduledDayEvidenceCli` is a machine/AI-facing open-world exact-day evidence command with distinct `DUE` / `UNKNOWN` semantics. Folding those surfaces into broad CLI roots would reduce file count while making command ownership less explicit.

## What the first pass actually found

The audit did produce real structural changes, so closure is not a declaration that every existing file was automatically acceptable.

Important positive findings included:

- **MGA-001** retired unreachable historical `Loam.Sha256`;
- calibrated small shared semantic/mechanical modules as valid boundaries rather than false-positive merge targets;
- **MGA-010 / 011 / 014 / 015 / 016** extracted qualified TUI session/effect owners where object-local loops had independent responsibility;
- **MGA-012 / 013** supplied negative controls showing that naming or shape symmetry does not justify extraction;
- **MGA-017** located real responsibility density in `Loam.Tui.Reports`;
- **MGA-018** qualified canonical `ReportWindow` ownership;
- **MGA-019 / 020** qualified `TransactionsFlowPane` while preserving ReportWindow, query, stale-result invalidation, scroll, paging, and `TransactionsFlowReview` semantics outside the pane.

The net lesson is not “more modules are better.” It is:

```text
file count is a consequence;
independent ownership is the criterion.
```

The first pass both removed a stale file and added small modules. Those are compatible outcomes because the audit is measuring reasons to change, not chasing a numerical minimum.

## Closure verdict

**FIRST PASS CLOSED.**

Current evidence does not support the diagnosis that LOAM is generally fragmented because of Lean, formal methods, or pure-functional style. The module structure is intentionally fine-grained in places, but the investigated boundaries mostly correspond to semantic laws, authority/persistence seams, command grammars, presentation owners, reusable effect shells, or independently changing policies.

There is also no remaining production-like unreachable module at this checkpoint.

The broad audit should therefore stop here rather than scanning all 337 modules mechanically.

## Reopening rule

Open a new scoped Module Granularity campaign only when concrete pressure appears, for example:

- a reachable module loses all meaningful consumers;
- two modules repeatedly co-change and no longer have independent ownership;
- duplicated state or adapter plumbing appears across a physical seam;
- a composition root accumulates another object-local loop or presentation engine;
- navigation burden becomes materially worse than the distinction it preserves;
- a persistence/versioning boundary ceases to have an independent compatibility or authority reason;
- DRAKON, dependency topology, or source inspection exposes a new responsibility fanout.

A future campaign should start from that concrete pressure, not from raw LOC, file count, suffix symmetry, or the current count of one-consumer modules.

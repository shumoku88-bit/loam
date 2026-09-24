# Post-Generation-2 Development Delta Audit — 2026-09-24

Status: **AUDIT CLOSED / REMEDIATION COMPLETE**

## Audit window

Previous full-audit closure:

```text
024a76cbe8f1f9e74a4dff2b45359e8625397447
Generation 2 closure baseline
```

Initial audited main:

```text
993654ac0592d8e7e89410a0ad219aebbef2458e
experiment: test interpretation attributed time (#1229)
```

Remediation closure main:

```text
9de34e0ee09ef5a75dda471761b855da5eb77aad
fix(home): disclose reconstructed pace history (#1260)
```

The original audited delta contains:

```text
242 commits
451 changed repository files
```

The 451-file count is derived from recursive Git tree comparison. GitHub's normal
compare response truncates the changed-file listing at 300 files, so that listing
was not used as the complete inventory.

The audit also includes the subsequently merged interpretation experiments
#1226–#1229 (Observations 320–323). They add only Alloy models, research notes,
and qualification workflows; no production Core, persistence, writer, Review,
TUI, Web, or CLI semantics are changed.

## Purpose

Generation 2 closed a repository-wide audit and explicitly asked that broad audit
work reopen only under concrete new pressure.

Since that closure, LOAM gained substantial new production and research surface:

- Merchant / ExternalParty evidence;
- normalized single-file Capacity authority;
- admitted normalized Actual read images;
- structured Actual persistence diagnostics;
- Movement proposal transport and idempotent operation evidence;
- relation / discharge / Scheduled / replacement / Correction performance indexes;
- arbitrary single-Measure recording and exact decimal presentation;
- Plain Text Accounting and Beancount/Fava projections;
- Scheduled generation, monitoring, coverage, and continuation handling;
- Attention administration and Home Attention glance;
- lightweight Web frontend;
- unresolved-recording support through the ordinary `suspense` Locus;
- standalone distribution and tagged artifacts;
- Daily Pace and reconstructed recent pace;
- non-household Core probes and personal semantic-memory experiments;
- interpretation-history / subject / recorded-time / attributed-time Alloy probes.

This audit therefore asks:

> Did the post-G2 growth preserve semantic authority, fail-closed boundaries,
> historical meaning, read coherence, and escape/export safety?

## Overall verdict

The post-G2 development is **substantially coherent**.

The audit did **not** find evidence that LOAM accidentally created a second
household accounting authority, bypassed normalized Actual/Capacity admission in
ordinary writers, or persisted Scheduled recurrence/cadence semantics that the
design intended to keep construction-only.

Several major changes are especially well bounded:

- normalized Actual and Capacity complete-image publication;
- admitted Actual read images;
- Scheduled lifecycle complete-image staging;
- unresolved recording as an ordinary admitted Locus rather than a new semantic
  family;
- single-Measure multi-currency recording while cross-Measure exchange remains
  refused;
- conservative PTA / Beancount export;
- standalone distribution outside the source tree;
- indexed Correction and Replacement semantics with strong correspondence;
- Scheduled generation with non-persisted cadence;
- Merchant evidence and exact-query boundary;
- Attention / Scheduled continuation work qualified during the Generation-3
  follow-up audit.

The audit originally found **two concrete canonical overwrite hazards**, one
historical-meaning stability gap, and several read/presentation or qualification
gaps. All ten findings now have explicit dispositions: D1-D6, D8 and D10 were
repaired and qualified; D7 was strengthened proportionally and then closed at a
documented stop point; D9 was classified as an intentionally research-only
executable. No finding remains open at remediation closure.

## Finding summary

| ID | Priority | Finding | Current disposition |
|---|---|---|---|
| D1 | HIGH | Web HTML output can overwrite canonical household files | FIXED #1235 |
| D2 | HIGH | Journal export alias guard can miss the Actual authority path | FIXED #1236 |
| D3 | HIGH semantic | Measure decimal scale can reinterpret retained history | FIXED / QUALIFIED #1239 |
| D4 | MEDIUM | One Home snapshot can mix several generations of `actual.loam` | FIXED / QUALIFIED #1240 |
| D5 | MEDIUM | Idempotent proposal replay can display retry payload beside the original EventId | FIXED / QUALIFIED #1254 |
| D6 | MEDIUM | An unrelated external Fava server can be mistaken for LOAM's current projection | FIXED / QUALIFIED #1255 |
| D7 | LOW-MEDIUM | Relation/discharge indexed paths have weaker general correspondence evidence than Correction/Replacement | CLOSED PROPORTIONALLY #1256-#1258 |
| D8 | LOW | Scheduled coverage config update has no writer ownership | FIXED #1259 |
| D9 | LOW | `loamMemory` is an experiment executable registered beside product executables | CLASSIFIED / KEEP |
| D10 | LOW | Home label `Recent pace` does not state that values are retrospective current-truth reconstruction | FIXED #1260 |

---

# Detailed findings

## D1 — Web snapshot output can overwrite canonical household files

Priority: **HIGH**

`Loam.Web.Cli` describes the Web frontend as read-only, but its explicit output
path is passed directly to:

```text
IO.FS.writeFile output html
```

No source/output conflict check is performed.

Therefore a command such as:

```text
loamWeb /household /household/actual.loam
```

can replace normalized Actual authority with HTML.

The same class of mistake could target another household file because the Web
renderer treats its destination as an unrestricted filesystem path.

This is stronger than an ordinary projection bug: it can destroy canonical
evidence through a command advertised as read-only.

### Expected boundary

Web output must refuse any destination that aliases protected household inputs.
At minimum it should protect the data root's canonical/configured source files,
and should preferably use the same path-alias discipline already qualified for
PTA / Beancount exports.

### Evidence that a stronger pattern already exists

PTA and Beancount export compare resolved filesystem paths and refuse source
overwrite. The Web output path did not receive that qualification.

**Final disposition: FIXED / QUALIFIED in #1235.**

---

## D2 — Journal export protects only lexical path equality

Priority: **HIGH**

`Loam.JournalExportCli` attempts to protect Actual authority with:

```text
outputPath == actualPath
```

This rejects only the same input string.

Filesystem aliases such as:

```text
actual.loam
./actual.loam
dir/../actual.loam
```

can identify the same canonical file while comparing as different strings.

The journal then publishes through sibling staging to the supplied output path.
A path alias that resolves to the canonical Actual directory entry can therefore
replace the authority with the human-readable journal projection.

PTA and Beancount already use `realPath`-aware conflict checks, so this is an
inconsistent older export boundary rather than an unknown design problem.

**Final disposition: FIXED / QUALIFIED in #1236.**

---

## D3 — Measure presentation scale is mutable after retained use

Priority: **HIGH semantic**

Operational multi-currency deliberately keeps:

```text
MeasureId
+
exact integral Quantity quanta
+
optional decimal presentation scale
```

separate.

The documentation correctly states that once a Measure has retained household
quantities, its scale becomes historically stable. For example:

```text
usd -> scale 2
1234 quanta -> 12.34 USD
```

Changing the configuration to scale 0 would reinterpret the same retained quanta
as 1234 USD.

Current production loading treats
`config/measure-presentation.tsv` as replaceable optional metadata. The audit
found no production boundary that can detect or refuse a scale change after a
Measure has retained evidence.

Deleting the file can likewise fall back to scale 0 compatibility.

### Why this differs from other replaceable configuration

Changing Daily Pace selection or a Scheduled coverage monitor changes a current
query.

Changing a used Measure's scale changes the human interpretation and exported
representation of already-retained quantities.

That is historical meaning, not merely query preference.

### Design pressure

LOAM needs an explicit answer for one of these shapes:

- scale becomes retained evidence once the Measure is used;
- a separate qualified migration changes the scale and retained quantities
  together;
- another mechanism proves that current config remains consistent with the
  original retained interpretation.

Git history alone is useful provenance but is not a runtime semantic guard.

**Final disposition: FIXED / QUALIFIED in #1239. Used Measures now refuse scale changes under the qualified `Scheduled -> Actual -> CurrentQuantityAnchor -> Capacity` ownership and re-read protocol; explicit migration remains separate.**

---

## D4 — Root Home snapshot can mix Actual generations

Priority: **MEDIUM**

`Tui.Cli.loadSnapshot` currently assembles one root Home snapshot by performing
separate reads:

```text
ActualReview.loadRecordsFromActual
ScheduledReview.loadHouseholdEvidence
AttentionReview.loadEvidence
CycleSpendingPaceReview.loadSnapshotAt
CycleSpendingPaceReview.loadHistoryAt
```

The Actual, Scheduled, current Daily Pace, and reconstructed pace history paths
can independently reopen `actual.loam`.

If a writer publishes between those reads, one displayed Home frame can contain:

```text
Actual rows       from generation A
Scheduled answer  evaluated against generation B
Daily Pace        from generation C
Recent pace       reconstructed from generation D
```

### Existing good precedent

`CycleBudgetReview.loadSnapshotAt` explicitly takes Actual writer ownership
while composing its internal Actual-dependent answers so one Cycle Budget answer
cannot mix two generations of `actual.loam`.

`CycleSpendingPaceReview.loadSnapshotAt` also correctly passes the Balance
read's EventMemory into Scheduled loading, keeping that single Review answer
generation-consistent.

The gap is therefore the **root Home composition**, not Daily Pace arithmetic.

### Web distinction

The Web frontend also reads several independent Review answers per request, but
its documentation describes a page of independently refreshed shared Review
cards and does not claim cross-file atomicity.

Home presents a stronger single-snapshot / "known through" experience, so the
same-generation expectation is more material there.

**Final disposition: FIXED / QUALIFIED in #1240. Home now composes Actual-dependent answers from one admitted `ActualAuthority.Image`.**

---

## D5 — Idempotent replay response can describe a payload that was not published

Priority: **MEDIUM**

Movement proposal v2 retains:

```text
MovementOperationId -> EventId
```

as semantic operation identity.

On retry, `MovementPublisher.publishDraftIdempotent` intentionally returns the
original EventId without re-admitting or re-publishing the caller's retry draft.

That is coherent with the qualified operation-identity model.

The response path, however, renders the **current retry draft** together with the
**original EventId**.

If a caller accidentally reuses an operation ID with a changed date, description,
or effects, the command can report:

```text
date/effects/description from retry payload
event = original retained Event
[ok] operation already applied; original Event reused
```

The displayed payload may therefore not describe the Event that was actually
retained.

The existing qualification covers retry of the exact same v2 proposal but not
operation-ID reuse with a different payload.

### Corrective choices

The operation identity should remain independent of content equality. A repair
need not turn hashes into identity.

Possible qualified responses include:

- on replay, display only retained/original Event evidence;
- explicitly report payload drift separately;
- refuse a mismatching replay while keeping operation identity authoritative.

**Final disposition: FIXED / QUALIFIED in #1254. Replay preserves operation identity without presenting a changed retry payload as retained Event evidence.**

---

## D6 — Existing external Fava is identified only as "some Fava"

Priority: **MEDIUM**

`FavaLaunch.ensureFavaRunning` checks whether the configured port already
responds with characteristic Fava content.

If so, an external Fava process is reused.

The health check does not establish that the external process is serving the
Beancount file LOAM just regenerated.

LOAM may therefore regenerate:

```text
/tmp/loam-fava-household.beancount
```

then detect an unrelated Fava on the port and report a refreshed projection even
though that server is presenting another ledger.

The existing lifecycle tests qualify:

- LOAM-owned spawn;
- owned-session reuse;
- shutdown;
- process-group cleanup.

They do not qualify reuse of an independently started Fava instance.

This cannot mutate LOAM authority, but it can present the wrong household view.

**Final disposition: FIXED / QUALIFIED in #1255. Only the current TUI-owned Fava process is reused; an unowned responder is refused.**

---

## D7 — Relation/discharge performance refactors have weaker universal correspondence evidence

Priority: **LOW-MEDIUM**

Post-G2 performance work replaced repeated scans with transient indexes across
several semantic families.

The strongest examples have universal semantic correspondence:

- Replacement:
  `acyclicIndexedBy_eq_acyclic`;
- Correction:
  indexed frontier/admissibility/reference-closure correspondence and
  production = legacy theorems.

Scheduled inspection has a broad 19-case reference-equivalence regression suite.

Open Relation and Relation Discharge frontiers have extensive semantic boundary
tests and strong benchmark qualification, and their PRs explicitly preserve
canonical list representation/order. No semantic regression was found.

The audit did not find an equally general indexed-vs-reference theorem for the
Relation / Discharge whole-frontier paths.

This is a verification-density asymmetry, not evidence of a current bug.

**Final disposition: CLOSED PROPORTIONALLY in #1256-#1258. Discharge lookup/buckets and Relation coverage received general correspondence evidence; shared one-dimensional Event indexing moved into `FiniteKeyed` with net source reduction. The remaining two-coordinate source-Effect index has no observed defect or second reuse site, so dedicated proof machinery was not added.**

---

## D8 — Scheduled coverage config has no writer ownership

Priority: **LOW**

`ScheduledCoverageConfig.upsertAt` performs:

```text
load current config
-> modify
-> stage
-> typed re-decode
-> rename
```

but does not take writer ownership.

Two concurrent TUI/process updates can therefore race, lose one update, or
collide on the fixed sibling stage path.

This file is replaceable monitoring configuration, not canonical Scheduled fact
authority, so the impact is substantially lower than an Actual/Capacity writer
race.

**Final disposition: FIXED in #1259. The full read/modify/stage/replace update now runs under existing `WriterOwnership`.**

---

## D9 — Personal semantic memory remains an executable research probe

Priority: **LOW**

Non-household semantic-memory work is correctly kept in `Loam.Examples` and its
own qualification workflow.

One exception is deliberately practical:

```text
lean_exe loamMemory
  -> Loam.Cli.PersonalMemoryCli
  -> Loam.Examples.PersonalSemanticMemoryPersistence
```

It is not dispatched by the primary `loam` binary and is not included in the
standalone release artifacts.

Therefore it is not household production authority leakage.

It is, however, an experiment executable registered beside production
executables. The repository should eventually decide whether this remains a
supported research tool, moves to a separate project, or is retired.

**Final disposition: CLASSIFIED / KEEP. `loamMemory` remains an explicit research-only executable qualified by the Non-household Core probe and is not dispatched by household production surfaces.**

---

## D10 — `Recent pace` can be read as historical observation rather than current-truth reconstruction

Priority: **LOW**

The Daily Pace history implementation is deliberately retrospective
current-truth reconstruction.

It does **not** answer:

> What value did LOAM display on that day?

It answers:

> Given facts admitted now, what pace is reconstructed for that past date?

The PR qualification states this clearly.

Home labels the rows only:

```text
Recent pace
```

which can be read as retained historical observations.

No wrong arithmetic was found, and no pace snapshots are persisted.

**Final disposition: FIXED in #1260. Home now labels the series `Recent pace (recomputed current truth)`, preserving the distinction from retained historical observations.**

---

# Major areas reviewed with no blocking finding

## Normalized Actual authority

Result: **PASS**

- one canonical `actual.loam`;
- staged byte verification;
- typed staged decode;
- atomic rename;
- admitted read image;
- raw retained evidence preserved for writers;
- structured decode diagnostics;
- publishers re-read under ownership.

New fact families are preserved by writers through `{ evidence with ... }`
updates rather than rebuilding incomplete aggregates.

## Normalized Capacity authority

Result: **PASS**

- one canonical `capacity.loam`;
- complete cross-family image;
- typed staged publication;
- legacy two-file production path retired.

## Scheduled lifecycle

Result: **PASS**

- one complete lifecycle image;
- typed staged decode before rename;
- fixed Scheduled -> Actual ownership order;
- interrupted completion remains inert and retryable;
- construction cadence/horizon remain non-persistent.

## Merchant evidence

Result: **PASS / already re-audited**

The Merchant production promotion was qualified through explicit research,
persistence, publisher and exact query boundaries.

Generation-3 follow-up classified `MerchantExpenseReview` as
`KEEP_BOUNDARY / DEFER_SURFACE`.

## Unresolved recording

Result: **PASS**

- `suspense` is an ordinary Locus;
- activation is explicit;
- activation uses ordinary Locus admission;
- world is re-read after activation;
- activation does not modify Actual authority;
- final Movement uses ordinary admission/publication.

No new suspense Core type or alternate accounting authority was introduced.

## Operational multi-Measure recording

Result: **PASS / D3 REMEDIATED**

- ordinary recording remains one balanced Measure;
- arbitrary Measure identity is supported;
- cross-Measure exchange remains refused;
- decimal parsing is exact fixed-point;
- no FX / valuation / rounding semantics are inferred;
- PTA / Beancount use the same presentation convention.

Historical scale stability is now enforced by the qualified administration boundary from #1239.

## Scheduled generation and coverage

Result: **PASS / D8 REMEDIATED**

- cadence and fill horizon are construction-only;
- nonexistent calendar dates remain explicit `needsDate`;
- drafts are reviewed before publication;
- retained-plan awareness is advisory;
- ordinary Scheduled publisher remains authoritative;
- monitoring config does not become recurrence authority;
- signed-Locus selector identity was centralized in #1219.

## Correction / Replacement / Scheduled performance work

Result: **PASS**

- transient indexes remain derived;
- canonical list evidence remains authoritative;
- Correction has strong production/reference correspondence;
- Replacement has universal indexed/direct cycle equivalence;
- Scheduled has broad reference regression.

Relation/discharge proof-density asymmetry was strengthened proportionally in #1256-#1258 and then closed at the documented stop point.

## PTA / Beancount export

Result: **PASS**

- disposable one-way projections;
- explicit AccountingRole / suspense behavior;
- per-Measure balance required;
- no valuation evidence invented;
- resolved source/output alias protection;
- sibling-stage output.

Journal export is separately affected by D2.

## Standalone distribution

Result: **PASS**

Qualification includes:

- primary binary outside the repository;
- no Lean toolchain on PATH;
- Linux/macOS x86_64 + arm64 packages;
- extracted archive re-run;
- portability metadata;
- SHA-256 checksums;
- verified release asset set;
- tag-gated release publication.

## Attention and Home continuation

Result: **PASS / recently re-audited**

#1224 and #1225 now provide:

```text
Scheduled completion
-> Done / Defer / Add next
-> Defer publishes ordinary Attention
-> dueUndetermined
-> Home rediscovery
```

No recurrence, cadence, series identity, or machine-readable continuation
relation was inferred.

## Web semantic renderer

Result: **PASS / D1 REMEDIATED**

The HTML renderer consumes shared Review boundaries and does not reconstruct
accounting semantics.

Its output alias hazard was repaired in #1235.

## Non-household Core probes

Result: **CONTAINED / D9 CLASSIFIED**

Scientific, inventory, document-provenance and future-context probes remain in
Examples / Observations and do not enter household production semantics.

## Interpretation / Reflection observations 320–323

Result: **CONTAINED / RESEARCH-ONLY**

The latest main also contains four bounded Alloy observations added after the
initial audit pass:

- Observation 320: interpretation history without rewriting Facts;
- Observation 321: explicit subject attribution sufficiency;
- Observation 322: interpretation recording time as an independent coordinate;
- Observation 323: attributed interpretation time as distinct from recording time.

Each experiment explicitly refuses production promotion. The sequence separates
one information distinction at a time and does not add:

- a production Reflection type;
- a canonical interpretation file;
- Attention or Actual persistence integration;
- automatic language parsing;
- psychological-causation semantics.

The current surviving research shape is still only a candidate:

```text
interpretive text
+ subject -> Fact
+ recordedAt
+ attributedAt
```

and the latest observation explicitly asks for compression before adding more
coordinates.

No new audit finding is opened for these experiments at this stage.

---

# Remediation closure

The audit was repaired through small independent PRs rather than a broad
repository-wide abstraction pass:

1. D1 Web output overwrite protection — #1235
2. D2 Journal resolved-path protection — #1236
3. D3 Measure scale historical-stability administration — #1239
4. D4 Home same-Actual-generation composition — #1240
5. D5 idempotent replay payload-drift presentation — #1254
6. D6 TUI-owned Fava identity boundary — #1255
7. D7 proportional Relation/Discharge correspondence and keyed-index compression — #1256, #1257, #1258
8. D8 Scheduled coverage writer ownership — #1259
9. D9 research executable classification — no production change
10. D10 reconstructed Daily Pace disclosure — #1260

## Stop condition

**Met at remediation closure main `9de34e0ee09ef5a75dda471761b855da5eb77aad`.**

- D1-D6 are fixed and qualified.
- D7 received the proportional proof work that paid for itself and has an
  explicit stop point rather than a new Relation-specific framework.
- D8 is fixed using the existing ownership primitive.
- D9 is explicitly classified as research-only.
- D10 now discloses the reconstructed current-truth meaning in Home.
- No evidence from the completed remediation justifies another
  repository-wide abstraction sweep.

The audit can therefore close without carrying a compatibility layer, a generic
currency migration framework, a second source-Effect indexing framework, or a
new research-tool packaging hierarchy.

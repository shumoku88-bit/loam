# LOAM Audit Generation 3 — Semantic Fanout Checkpoint

Status: **CHECKPOINT / BROAD FANOUT SCAN PAUSED**

Checkpoint baseline:

```text
b257570e87038c4f716614f0658425cbf778b4c1
audit: qualify Scheduled day refusal in Review (#1222)
```

Generation 3 reopened after Generation 2 closure because new implementation
pressure had accumulated around optimized Correction reads, complete-image
publication, module reachability, and rapidly growing TUI/Web/CLI surfaces.

The useful question that emerged was narrower than "find duplicate code":

> When the same household meaning appears in several paths, is there one semantic
> owner that should answer once, or are the differences intentional?

This checkpoint pauses the broad semantic-fanout scan because the current pass has
produced a stable decision rule and the concrete candidates found so far are
explained. It is not a claim that LOAM has no future structural work.

## Campaign shape

```text
G3 structural reopening
|
+-- Correction topology
|     -> separate reference semantics from indexed implementation
|     -> KEEP stable import entrance
|
+-- staged publication
|     -> add local typed re-decode to Scheduled lifecycle
|     -> KEEP SiblingStage minimal
|     -> DO NOT add generic verified-publisher framework
|
+-- reachability / lifecycle
|     +-- old Attention read-only surface -> RETIRE
|     +-- MerchantExpenseReview          -> KEEP_BOUNDARY / DEFER_SURFACE
|     +-- Examples counted as production -> repair audit instrument
|
+-- semantic fanout
      +-- Scheduled coverage identity -> one shared selector
      +-- Actual authority identity   -> one path resolver
      +-- Scheduled read order        -> one deterministic Review order
      +-- Scheduled day refusal       -> qualify once in Review
```

The accompanying D2 map is
`docs/d2/generation_3_semantic_fanout_checkpoint.d2`.

## What Generation 3 changed

### Correction Frontier — split by independent responsibility

Phase 3H had made `CorrectionFrontier.lean` physically large, but line count was
not itself the reason to split it.

The successful boundary was:

```text
reference/list semantics
        |
        v
indexed implementation + correspondence
        |
        v
stable CorrectionFrontier import entrance
        |
        v
production consumers
```

The indexed implementation and the proofs preserving the reference semantics still
share private scan machinery, so a further proof-only split was rejected.

**Decision:** split only where an independent reason to change was demonstrated.
Do not continue splitting by LOC.

### staged publication — local strengthening, no framework

Actual, Capacity, and Scheduled Coverage already used:

```text
encode
-> stage write
-> readback
-> byte equality
-> typed staged decode
-> rename
```

Scheduled lifecycle stopped after byte equality.

The qualified change added the missing local typed re-decode before rename.

The result did **not** justify a generic Publisher/Authority/transaction framework.
`SiblingStage` remains the small physical write+rename mechanic; stronger
authority protocols remain explicit.

**Decision:** share mechanics only after the semantic protocols have actually
converged.

### reachability — three different meanings of "unreachable"

The module-granularity inventory surfaced five production-like unreachable modules.
They did not have one answer.

#### `Loam.Tui.Attention` — RETIRE

The original read-only Attention workspace had been replaced at both production
entrances by `AttentionAdministration`.

Its unique responsibility no longer existed. Still-relevant
unavailable/configured-empty and due distinctions remained in
`AttentionReview` and the production administration surface.

**Decision:** RETIRE superseded surface.

#### `Loam.MerchantExpenseReview` — KEEP_BOUNDARY / DEFER_SURFACE

The Merchant exact-query seam was intentionally promoted through Observations
266–269 and had no semantic replacement.

Issue #1095 deferred a presentation/report surface, not the already-qualified
shared answer.

**Decision:** KEEP exact shared library answer; DEFER TUI/Web report.

#### `Loam.Examples.*` — repair the observer

Three explicit non-household examples were being counted as
"production-like unreachable".

The source modules were not stale. The audit population was wrong.

**Decision:** keep Examples visible in the full inventory, but exclude them from
the production-like unreachable summary.

This produced a durable reachability rule:

```text
unreachable
  != automatically stale

ask instead:
  superseded responsibility?     -> RETIRE
  intentional shared library?    -> KEEP
  explicitly non-production?     -> fix classification
```

## Semantic fanout findings

### Scheduled Coverage selector — SHARE semantic identity

Monitoring-rule creation and later coverage matching independently reconstructed
the same canonical signed-Locus shape.

Those two copies sat on opposite sides of one protocol:

```text
Scheduled occurrence
       |
       v
signed-Locus selector
       |
       +--> monitoring rule producer
       |
       +--> monitoring rule matcher
```

A drift could have allowed LOAM to create a rule that its own report did not
recognize.

`ScheduledCoverageSelector` now owns the canonical selector and matching.

**Decision:** when producer and matcher depend on the same identity law, share the
law rather than merely testing two copies for similarity.

### Actual authority path — SHARE authority identity

Eleven read paths independently decided whether a supplied Actual location meant:

```text
household root -> root/actual.loam
actual.loam    -> actual.loam
```

Several of those paths also used the result for the Actual observation lock, so
this was authority identity selection, not formatting.

`ActualAuthority.actualPathFromRootOrFile` now owns the lexical choice.

**Decision:** Reviews own household questions; ActualAuthority owns which physical
path identifies the Actual authority.

### Scheduled current-open order — SHARE observable read order

HraScheduled and Web used date + Scheduled identity ordering while the CLI used
date only. `earliestCurrentOpenRecord` separately used date + id.

`ScheduledReview.orderedCurrentOpenRecords` now owns:

```text
scheduledOn ascending
then ScheduledId.token ascending
```

The order is explicitly a deterministic read convention, not priority, recurrence,
publication order, or storage order.

**Decision:** share an observable order when several surfaces expose "first",
bounded pages, or sequential output from the same answer.

### Scheduled exact-day refusal — QUALIFY once at Review

The low-level Application inspection intentionally preserves:

```text
Due
Unknown
unknown completion endpoint
unknown retirement endpoint
unknown replacement endpoint
invalid replacement graph
conflicting terminal evidence
```

That detailed vocabulary remains valuable for qualification.

The problem was that `ScheduledReview.dayEvidence` re-exported all seven states,
forcing Home, HraScheduled, SelectedDay, and CLI to repeat the same five
fail-closed translations.

The current boundary is:

```text
Application
  detailed diagnostic result
        |
        v
ScheduledReview
  Except String (Due | Unknown)
        |
        v
TUI / CLI presentation
```

Application keeps diagnostic resolution; Review decides whether a household day
answer is justified.

**Decision:** preserve detail below the qualification boundary while exposing only
the distinctions that ordinary consumers can act on correctly.

## What was deliberately NOT centralized

Generation 3 is not a campaign to maximize shared helpers.

The following kinds of differences remain intentionally local:

- display formatting and labels;
- pure presentation ordering when it does not define a shared observable answer;
- diagnostic detail that is useful below a qualified household-facing Review;
- family-specific admission and publication refusal order;
- Merchant projection without an earned presentation surface;
- indexed Correction mechanics and correspondence proofs that still share one
  private implementation reason;
- explicit examples/probes that are not production roots.

A shared abstraction is not earned merely because two pieces of code can be made
to look alike.

## Tool-selection result

Generation 3 also sharpened the AI Workbench routing rule.

```text
ownership / dependency / fanout
  -> search + history + D2

execution / refusal order
  -> DRAKON

new bounded structural possibility
  -> Alloy

temporal / crash / interleaving residual
  -> TLA+ or SPIN

new algebraic law or proof obligation
  -> Lean

already-qualified semantic law, duplicated implementation ownership
  -> reuse prior proof/model + focused regression
```

This avoided re-formalizing questions whose semantic choice was already qualified.

## Current structural principle

The strongest reusable observation from this pass is:

> Share the answer at the narrowest layer that genuinely owns its meaning, while
> preserving richer evidence below that layer and presentation freedom above it.

In current LOAM terms:

```text
Core / Application
  preserve exact evidence and diagnostic distinctions
        |
        v
Authority / Review / Selector
  own qualified identity, refusal, ordering, or household answer
        |
        v
TUI / Web / CLI
  present or collect intent without reconstructing that meaning
```

This is not a universal layering law. It is the current pattern supported by the
observed production paths.

## Stop verdict

The broad semantic-fanout scan pauses here.

The recent pass examined several plausible families and found a useful separation:

- actual semantic duplication was centralized;
- presentation-only differences were left alone;
- intentionally dormant library boundaries were kept;
- superseded surfaces were retired;
- audit noise was corrected at the observer.

Continuing repository-wide searches without new pressure now risks producing
abstractions because patterns are searchable rather than because users or
production paths need them.

**CHECKPOINT / STOP BROAD SCAN.**

## Reopen triggers

Reopen this fanout campaign only with concrete evidence such as:

1. a new TUI/Web/CLI/AI surface independently reconstructs a Review identity,
   refusal, completeness, or ordering law;
2. one producer can create data/configuration that its corresponding matcher no
   longer recognizes;
3. two production surfaces answer the same household question differently from
   the same canonical evidence;
4. a shared helper accumulates incompatible policy branches, showing that the
   earlier centralization merged distinct meanings;
5. an authority path, snapshot, or lock identity is selected independently in a
   new production boundary;
6. a module becomes unreachable because its responsibility was actually
   superseded, not merely because presentation is deferred;
7. new profiling, crash, or concurrency evidence introduces a question that
   requires Alloy, TLA+, SPIN, or additional Lean proof rather than another
   structural refactor.

Until one of those appears, prefer household use, missing capabilities, and
concrete correctness pressure over another broad abstraction sweep.

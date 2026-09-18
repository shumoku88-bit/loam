# Scheduled Coverage — Trivet-style obligation scaffold

Status: **qualified adoption example — residual policy only**

Baseline:

```text
fd798de2878e4fefac8fe349c30463e2a3ec3714
docs(audit): qualify Admitted type integrity (#1081)
```

Target feature:

```text
Scheduled future coverage grid (#1068)
```

Method:

```text
semantic question
    |
    v
deterministic scaffold
    |
    +--> D  mechanically closed from code / reachability
    +--> P  already earned by existing semantic boundary
    +--> R  genuinely residual policy or proof question
```

This audit began as a small experiment in proof-work allocation. Its result
qualified the D / P / R obligation scaffold for adoption as the default LOAM
method for non-trivial semantic audits. The reusable method is documented in
[`../OBLIGATION_SCAFFOLD_METHOD.md`](../OBLIGATION_SCAFFOLD_METHOD.md).

It does not introduce a dependency on Trivet, AXLE, or another proof orchestrator.

## Root question

Does Scheduled Coverage remain a read-only advisory projection of explicit
current-open Scheduled evidence, or did the new coverage configuration quietly
acquire authority that can create, suppress, or reinterpret Scheduled facts?

The root decomposes into these obligations:

```text
Scheduled Coverage
    |
    +--> O1 configuration is structurally admitted
    |
    +--> O2 missing / malformed configuration does not become semantic absence
    |
    +--> O3 calendar expectation arithmetic is finite and anchor-relative
    |
    +--> O4 compared records are already current-open Scheduled evidence
    |
    +--> O5 matching uses the documented exact signed-Locus shape
    |
    +--> O6 amount differences do not change coverage identity
    |
    +--> O7 first-gap is derived only from the finite displayed grid
    |
    +--> O8 off-pattern explicit evidence remains visible rather than erased
    |
    +--> O9 coverage configuration cannot reach a Scheduled writer
```

## Deterministic scaffold

### D1 — configuration shape: CLOSED

`ScheduledCoverageConfig.decode?` admits a row only when:

- rule name is a valid token;
- anchor is a real ISO calendar date;
- `everyMonths > 0`;
- negative and positive Locus lists are both non-empty;
- every Locus token is valid;
- neither signed list contains duplicates.

The complete configuration additionally rejects duplicate rule names and
duplicate signed-Locus selectors.

No AI proof search is needed for this classification.

### D2 — missing configuration: CLOSED

`ScheduledCoverageConfig.load?` maps a missing file to `some []`.

The empty-report presentation states that no rules are configured and explicitly
does not claim that an obligation is absent. Therefore "no monitoring rule" does
not become "not due".

Malformed or unreadable configuration fails the report instead of silently
becoming an empty authoritative state.

### D3 — finite calendar projection: CLOSED

`ScheduledCoverageReview.projectRecords` validates `observedAt` and every
retained Scheduled date before projection.

The displayed month indices are constructed as:

```text
observed month + 1 + finite List.range offset
```

Expectation for a rule is:

```text
anchorMonth <= targetMonth
&&
(targetMonth - anchorMonth) % everyMonths == 0
```

The zero-step case is rejected by configuration admission and also fails closed
inside `expectedAt`.

### D4 — first-gap derivation: CLOSED

`rowFor` constructs cells in the same ordered finite index list and defines
`firstMissing` as the first cell satisfying:

```text
expected && explicitCount == 0
```

No independent "covered through" authority is retained. The TUI derives the
visible "through" value from cells before that first gap.

### D5 — reachability of coverage vocabulary: CLOSED

Repository code search at the baseline found:

```text
ScheduledCoverageConfig
    -> ScheduledCoverageReview
    -> ScheduledCoveragePane / Reports / CLI / tests

ScheduledCoverageReview
    -> ScheduledCoveragePane / Reports / CLI / tests
```

No Scheduled creation, replacement, terminal, correction, or publication module
imports the coverage vocabulary.

Therefore the replaceable monitoring configuration has no production write path
into canonical Scheduled evidence.

## Previously earned semantic obligations

### P1 — current-open record semantics: REUSED

Coverage does not independently reconstruct Scheduled lifecycle state.

`loadSnapshot` obtains canonical evidence through `ScheduledReview` and then
calls `ScheduledReview.currentOpenRecords`.

Consequently lifecycle resolution, terminal handling, retained date validation,
and the existing definition of "current-open" remain owned by the established
Scheduled Review boundary.

Coverage receives selected records; it does not redefine currentness.

### P2 — ordinary Scheduled authority remains unchanged: REUSED

The feature adds no publisher and no publication path.

The existing Scheduled write boundaries remain the sole authority for creating
and changing retained Scheduled evidence. Coverage is downstream observation
only.

## Residual policy questions

After deterministic and previously-earned obligations are removed, two questions
remain. Neither is currently a production semantic gap.

### R1 — month-granularity matching

Coverage deliberately compares the calendar **month**, not the exact day.

Therefore a rule anchored on the 15th and an explicit Scheduled occurrence on
another day in the same expected month can count as covered when the signed Locus
shape matches.

This is consistent with the documented feature contract, which describes a
future **month grid** rather than recurrence identity or exact due-date identity.

It is not something Lean can prove "correct" without first choosing a stronger
product meaning.

Decision boundary:

```text
month-level monitoring desired
    -> current semantics are coherent

exact due-date monitoring desired
    -> new semantic input is required
```

Do not infer a recurrence or series identity merely to close this question.

### R2 — current-month exclusion

The grid begins with the month after `observedAt`.

This conservatively avoids interpreting a current-month occurrence that may
already have terminal evidence as a future coverage gap. The tradeoff is that a
still-future missing slot later in the current month is intentionally outside the
lens.

Again, this is a presentation-policy choice, not a proof hole.

If current-month coverage becomes necessary, the feature would need a more
precise intra-month notion of expectation rather than simply extending the grid
backward.

## Trivet-style result

The broad question:

> "Did Scheduled Coverage add unsafe recurrence-like semantics?"

reduces to:

```text
D — deterministic
    config admission
    finite month arithmetic
    first-gap derivation
    read-only reachability

P — previously earned
    current-open Scheduled semantics
    canonical Scheduled write authority

R — residual policy
    month-granularity matching
    current-month exclusion
```

No residual theorem currently requires LLM proof search.

The useful outcome is therefore not a new proof. It is that deterministic
scaffolding prevents the AI from reopening the Scheduled subsystem, recurrence
identity, lifecycle semantics, or publication authority.

## Comparison with the earlier cycle-fill audit

The post-G2 cycle-fill audit already used deterministic obligation decomposition
and reduced O1-O8 to one narrow awareness question before PR #1065.

This experiment generalizes that lesson:

```text
obligation DAG node
    |
    +--> D  close by computation / reachability
    |
    +--> P  discharge by existing theorem or admitted boundary
    |
    +--> R  send only the genuinely new question to AI / human review
```

For Scheduled Coverage, the residual set contains policy choices rather than
Lean proof obligations. That is a successful result: the scaffold identifies
that more theorem generation would currently add proof surface without removing
a real production check.

## Stop point

Do not:

- add recurrence or Series identity to explain coverage;
- promote `scheduled-coverage.tsv` into canonical Scheduled evidence;
- add proof-carrying types merely to certify presentation configuration;
- use absence of a matching rule or cell as a canonical NotDue claim;
- ask an LLM to re-prove current-open Scheduled semantics already owned by
  `ScheduledReview`.

Reopen this scaffold only if coverage begins to influence publication, automatic
suppression, routing, or another authoritative write decision.

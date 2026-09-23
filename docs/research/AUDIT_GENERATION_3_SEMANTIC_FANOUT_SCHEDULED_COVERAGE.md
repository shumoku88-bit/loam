# Generation 3 — cross-frontend semantic fanout: Scheduled coverage selector

Status: **SHARED SELECTOR EXPERIMENT**

## Question

Can one household/read-side meaning be reconstructed independently by more than
one path even when all paths consume the same shared Review evidence?

The first concrete case is Scheduled coverage monitoring identity.

## Discovery

The current implementation had two independent copies of the same transformation:

```text
Scheduled occurrence
  -> deduplicate negative Locus tokens
  -> sort
  -> deduplicate positive Locus tokens
  -> sort
```

They lived in:

- `Loam.Tui.ScheduledCoverageSetup.signedLoci`, used when creating a monitoring rule;
- `Loam.ScheduledCoverageReview.signedLocusTokens`, used when matching later
  Scheduled occurrences against that rule.

The algorithms were equivalent at this checkpoint, but they owned opposite sides
of one protocol:

```text
producer -> Rule selector <- matcher
```

If either copy drifted, LOAM could create a monitoring rule that its own report no
longer recognized.

## History

PR #1068 introduced exact negative/positive Locus shape as Scheduled coverage
identity.

PR #1090 later added friendly monitoring setup that derives the same shape from a
selected occurrence. The duplicate arose naturally when the writer-side convenience
was added after the matcher existed.

## Existing qualification

No new domain law is proposed here. #1068 already established that exact signed
Locus shape is the coverage selector and that amounts are deliberately ignored.

Therefore this slice does not reopen the question with Alloy. The residual is
implementation ownership.

## Experiment

Introduce `Loam.ScheduledCoverageSelector` as the one presentation-neutral owner of:

- canonical signed-Locus shape extraction;
- usability of a shape for monitoring;
- record-to-rule matching.

Then:

- `ScheduledCoverageSetup.ruleFor?` derives its Rule from `ofRecord`;
- `ScheduledCoverageReview` uses `matchesRule`;
- a regression asserts that a Rule generated from one Scheduled occurrence matches
  that same occurrence through the shared matcher.

No Scheduled authority, recurrence claim, monitoring configuration format, or amount
semantics change.

## Tool choice

- dependency/history search found the duplicated ownership;
- D2 records producer/matcher topology;
- Lean build and executable tests qualify the mechanical refactor;
- Alloy is intentionally not rerun because the signed-selector semantic choice was
  already qualified by #1068.

## Decision rule

Keep the shared selector only if existing Scheduled Coverage and production TUI
qualification remain green.

If the extraction creates disproportionate dependency or proof cost, prefer the
existing duplication plus an explicit correspondence test rather than forcing an
abstraction.

## Next scan

After this slice, continue the same method across:

```text
Review answer
  -> TUI interpretation
  -> Web interpretation
  -> CLI interpretation
```

and distinguish:

- formatting/order differences: presentation;
- derived labels that do not affect action/refusal: usually presentation;
- repeated query/refusal/identity rules: shared semantic candidate.

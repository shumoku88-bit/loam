# Post-G2 Scheduled Cycle Fill obligation DAG

Status: **Post-Generation-2 semantic delta audit — RESIDUAL AWARENESS PRESSURE**

Baseline:

```text
46fd0b740f27d6aed7379ef7899c64185c33f16c
feat(export): add Plain Text Accounting journal projection (#1063)
```

Generation 2 closed at:

```text
024a76cbe8f1f9e74a4dff2b45359e8625397447
refactor(tui): isolate Scheduled continuation session (#977)
```

Primary instrument for this pass: **deterministic obligation decomposition + Lean witness**.

This is a scoped post-G2 delta audit. It does not reopen Generation 2 wholesale.

## Question

PRs #1060 and #1061 added construction-only current-cycle Scheduled fill.
PR #1062 then added post-completion awareness of already-existing later
Scheduled plans.

The audit asks:

> Does current-cycle fill already account for a later current-open Scheduled
> occurrence that looks like an already-planned slot, or can generation and
> existing-plan awareness independently produce the same calendar opportunity?

No recurrence, series, contract, or duplicate identity is assumed.

## Root claim

A current-cycle fill should preserve the semantics already established by the
Scheduled subsystem while adding only construction convenience.

The root decomposes into these obligations:

```text
current-cycle fill
    |
    +--> O1 valid explicit window / observation / anchor
    |
    +--> O2 cadence is construction-only, never retained
    |
    +--> O3 nonexistent nominal calendar days remain unresolved
    |
    +--> O4 edited concrete dates are revalidated before publication
    |
    +--> O5 every created occurrence uses ordinary Scheduled publication
    |
    +--> O6 inherited routing remains independent evidence
    |
    +--> O7 existing later plan awareness before adding another occurrence
    |
    +--> O8 partial multi-create failure remains recoverable without
             silently multiplying already-created plans on retry
```

## Deterministically closed obligations

### O1 — current-window clipping: CLOSED

`ScheduledCycleFill.planCandidatesAfter` rejects invalid dates, requires the
observation and anchor to lie inside the explicit current window, and admits
generated resolved dates only when:

```text
window.start <= date
observedAt   <= date
date         < window.endExclusive
```

The exclusive end matches the existing cycle-window semantics.

### O2 — cadence persistence: CLOSED

`GenerationCadence` is input to construction only. Generated values are ordinary
`ScheduledCreationPublisher.Draft` values. The Scheduled publisher persists no
cadence, series, or recurrence evidence.

### O3 — missing calendar day policy: CLOSED

A nominal day that does not exist, such as February 31, becomes
`Candidate.needsDate`. Interactive callers must obtain an explicit concrete
date. Headless `planAfter` fails closed instead of clamping or skipping silently.

### O4 — edited date revalidation: CLOSED

`ScheduledCycleFillSession.reviewAndPublish` checks every edited draft with
`validResolvedDate` immediately before publication begins.

### O5 — publication authority: CLOSED

Cycle fill does not own a second Scheduled writer. Each draft delegates through:

```text
HouseholdCommand.createScheduled
    -> ScheduledCreationPublisher.publishCreation
```

The ordinary publisher re-reads lifecycle / Actual / Locus admission under the
existing Scheduled ownership boundary and derives a fresh Scheduled identity.

### O6 — routing authority: CLOSED, with explicit partial outcomes

After each created occurrence, cycle fill calls
`HouseholdCommand.inheritScheduledRouting`.
`ScheduledContinuationRouting` keeps routing as independent historical evidence
and explicitly permits per-route success/refusal rather than inventing batch
atomicity.

The cycle-fill session also reports if creation or routing inheritance stops the
remaining sequence.

## Residual obligation

### O7 — existing-plan awareness: OPEN

The generation path receives only:

```text
CurrentWindow
observedAt
anchor
GenerationCadence
```

It does not read the admitted Scheduled lifecycle.

The cycle-fill session then collects and reviews the generated drafts, but it
still does not reload current-open Scheduled evidence before publication.

By contrast, the post-completion continuation path added in PR #1062 explicitly
reloads `ScheduledReview` evidence and calls
`laterSimilarOpenRecords` before offering another creation. That match is
deliberately advisory only:

```text
same positive Locus set + later explicit date
    -> ask the user
    -> never assert same series / recurrence / contract
```

Observation 272 fixes a concrete overlap:

```text
source Scheduled:       2026-09-08, positive Locus = gpt-plus
observedAt:             2026-09-18
monthly cycle fill:     proposes 2026-10-08

admitted open Scheduled:
                        2026-10-08, positive Locus = gpt-plus
```

Both answers are simultaneously valid:

- cycle-fill generation proposes `2026-10-08`;
- Scheduled Review surfaces the already-retained `2026-10-08` plan as a later
  similar open occurrence.

Therefore current production has **awareness pressure**, not a proved duplicate
identity bug.

The important distinction is:

```text
same date + same positive Locus
        !=
proved same series / same obligation

but

same date + same positive Locus
        ->
useful reason to ask before creating another explicit plan
```

### O8 — retry after partial publication: CONDITIONAL PRESSURE

Cycle fill intentionally publishes ordinary independent Scheduled occurrences one
at a time. A later publication or routing failure can therefore leave an explicit
prefix already committed.

That is not by itself a semantic defect: the session reports the committed count
and does not claim batch atomicity.

However, because O7 is currently open, retrying the fill has no deterministic
awareness step that distinguishes the already-created prefix from still-missing
calendar slots. O8 therefore depends on how O7 is resolved.

## Scaffold result

The post-G2 delta audit reduced the initial broad question to one residual semantic
choice:

```text
CLOSED mechanically
    O1 window
    O2 construction-only cadence
    O3 unresolved nominal dates
    O4 final concrete-date validation
    O5 canonical Scheduled publication
    O6 independent routing semantics

RESIDUAL
    O7 existing-plan awareness

DEPENDENT
    O8 retry after partial publication
```

No new Scheduled authority, recurrence model, series identity, batch publisher,
or persisted cadence is justified by this audit.

## Next decision boundary

A production change is justified only if existing-plan awareness can be added as
presentation/read guidance without claiming semantic identity.

The smallest candidate should reuse the already-earned `ScheduledReview`
vocabulary rather than create a recurrence engine. Useful possibilities to test
are:

1. surface already-existing later similar current-open plans before cycle-fill
   publication; or
2. classify generated/edited dates against a fresh Scheduled snapshot and ask the
   user only where an awareness overlap exists.

Any implementation must preserve explicit user choice. A same-date/same-positive-
Locus match is evidence to **ask**, not evidence to silently suppress publication.

## Production candidate — PR #1065

Status: **UNDER QUALIFICATION**

The smallest production candidate reuses the existing Scheduled Review boundary
instead of introducing recurrence or series semantics.

Immediately after the final edited-draft review and before publication, the TUI
loads one fresh current-open Scheduled snapshot. Each edited draft is compared
against retained open plans using only:

```text
same explicit date
+
same positive Locus set
```

A match remains advisory. The user receives three choices:

```text
Keep existing  -> omit this draft from the pending fill
Add another    -> retain this draft for ordinary publication
Review         -> inspect the retained Scheduled evidence, then choose
```

`Keep existing` is the default and Escape action. Amount equality is
deliberately not required, matching the post-completion awareness semantics.

The write path is unchanged:

```text
approved draft
    -> HouseholdCommand.createScheduled
    -> ScheduledCreationPublisher
    -> optional routing inheritance
```

Therefore the candidate adds no second writer, recurrence authority, batch
transaction, or persisted cadence.

The candidate also improves retry behavior after a partially published fill:
already-retained same-date/same-positive-Locus occurrences become visible before
the corresponding regenerated draft can be published again. A routing failure
after creation remains an explicit independent-routing outcome; the awareness
match does not claim enough identity to repair routing automatically.

## Verdict

**RESIDUAL AWARENESS PRESSURE CONFIRMED; MINIMAL FIX UNDER QUALIFICATION.**

The Trivet-style decomposition was useful: most apparent risk closed
deterministically from existing code and types, leaving one narrow semantic
question instead of reopening the whole Scheduled subsystem.

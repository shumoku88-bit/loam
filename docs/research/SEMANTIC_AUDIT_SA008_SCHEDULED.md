# Semantic audit SA-008 - Scheduled semantic amplification

Status: **AUDIT VERDICT COMPLETE - implementation intentionally deferred**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`

Audit checkpoint: `66e4b4186b4d1798b04c7b82fbecc7b50ee12ca0`

This record asks whether Scheduled has accumulated too many independent concepts as its production surface grew, or whether a small retained basis is generating many legitimate derived questions and adapters.

The target is not minimum file count. Scheduled should be allowed to have rich porcelain if it is derived from a small stable basis. The audit target is repeated semantic law, duplicated publication mechanics, or derived state accidentally promoted into retained authority.

## 1. Retained semantic basis

The current Scheduled basis is small.

```text
ScheduledOccurrence
  ScheduledId
  scheduledOn
  BalancedMovement LocusId

ScheduledTerminal
  ScheduledId -> Actual Event
  ScheduledId -> Scheduled successor
  ScheduledId -> no target

ScheduledRouting
  ScheduledId x LocusId
  historical Purpose assertion
```

`ScheduledMemory` is the finite unique-key carrier for occurrences rather than a fourth household meaning.

The current occurrence does not retain recurrence, status, completion flags, commitment, headroom, balance effects, scenario identity, continuation identity, or a plan object.

The terminal relation already recompresses completion, retirement, and replacement while preserving their target meaning and malformed cross-kind conflict for fail-closed Application review.

Verdict: **KEEP the three retained semantic families.**

## 2. Direct production surface

The directly named Scheduled surface currently includes:

### Core

```text
Scheduled
ScheduledMemory
ScheduledTerminal
ScheduledRouting
```

### Application

```text
ScheduledInspection
ScheduledOpenWorldInspection
ScheduledCommitmentInspection
ScheduledBalanceInspection
ScheduledBalanceHypothetical
```

### Persistence

```text
ScheduledPersistence
ScheduledLifecyclePersistence
ScheduledRoutingPersistence
```

### Root orchestration / porcelain

Representative direct boundaries include:

```text
ScheduledReview
ScheduledCreationPublisher
ScheduledTerminalPublisher
ScheduledReplacementPublisher
ScheduledRoutingPublisher
ScheduledContinuationRouting
```

CLI and TUI modules consume these boundaries for day evidence, creation, replacement, routing, and presentation.

This is substantial physical fanout, but it is not the same thing as an equal number of independent Scheduled concepts.

## 3. Dependency graph

The current production graph is approximately:

```text
ScheduledOccurrence + ScheduledTerminal + EventMemory
                    |
                    v
          currentOpenScheduled
             /      |       \
            v       v        v
        day/open   balance   commitment
                            + ScheduledRouting
             \      |       /
                    v
            Reviews / reports /
             write admission
                    |
                    v
                 CLI / TUI
```

Publication runs in the opposite direction through authority-specific publishers.

The important result is that current-open, due, balance, commitment, headroom, and hypothetical suppression are projections. They are not stored Scheduled state.

## 4. Application does not contain a second Scheduled engine

`ScheduledInspection.currentOpenScheduled` owns the lifecycle interpretation boundary.

The other Application modules delegate to it rather than independently deciding completion, retirement, replacement, replacement cycles, or cross-kind terminal conflicts.

Examples:

- `ScheduledOpenWorldInspection` derives exact-day open-world evidence;
- `ScheduledBalanceInspection` projects effects from already-qualified current-open occurrences;
- `ScheduledCommitmentInspection` combines current-open evidence with Scheduled routing and AccountingRole evidence;
- `ScheduledBalanceHypothetical` applies one typed read-only suppression hypothesis to a qualified baseline.

`ScheduledCommitmentInspection` is physically large, but it already shares its internal pressure classification and selected-coordinate enumeration and retains Lean evidence relating row and aggregate views.

Verdict: **KEEP the query boundaries. Large module size alone does not show a second domain model.**

## 5. Review / CLI / TUI are mostly porcelain

`ScheduledReview` explicitly owns a read-only projection boundary rather than a repository or lifecycle authority. It delegates lifecycle meaning to Application and adds date-oriented review conveniences such as pending-before-date ordering and human summaries.

CLI and TUI day views consume `ScheduledReview.dayEvidence` rather than re-deriving lifecycle state from raw Core memories.

TUI creation and replacement surfaces emit publisher drafts and delegate publication authority to `ScheduledCreationPublisher` and `ScheduledReplacementPublisher`.

This is the desired direction:

```text
small retained facts
-> shared Application law
-> review / publisher boundary
-> interface state and wording
```

Verdict: **no evidence of a TUI-private Scheduled semantic engine.**

## 6. Refusal vocabulary echo is real but currently acceptable

Several root modules translate the typed result of `currentOpenScheduled` into `Except String`:

```text
ScheduledReview
ScheduledCreationPublisher
ScheduledReplacementPublisher
ScheduledTerminalPublisher
ConditionalBalancePathReview
```

The repeated semantic cases include:

```text
unknownCompletionScheduled
unknownRetirementScheduled
unknownReplacementScheduled
invalidReplacementGraph
conflictingTerminalEvidence
```

This is semantic amplification at the adapter boundary, but the semantic decision itself is still centralized in `currentOpenScheduled`.

A generic string-error helper is not justified yet. Moving textual error policy into Application would push presentation concerns inward, while making publishers depend on `ScheduledReview` would invert the current layering.

The existing typed Application result is already the important shared boundary.

Decision: **KEEP local translation for now. Reopen only if a structured non-string error type earns multiple independent consumers and produces a net-negative adapter surface.**

## 7. Strong residual candidate: Creation / Replacement occurrence construction

The clearest Scheduled duplication is not semantic meaning. It is pure publication plumbing shared by creation and replacement.

Both publishers independently define near-identical mechanics for:

```text
loadLifecycle?
freshScheduledId?
valid real scheduled date
valid nonzero JPY effects
BalancedMovement reconstruction
positive total matching draft
occurrenceFromDraft?
Scheduled lifecycle -> Movement CURRENT ownership order
```

The operation-specific meaning is different and must remain separate:

```text
Creation
  adds a fresh independent Scheduled occurrence

Replacement
  requires one current-open source
  adds a fresh successor occurrence
  adds Scheduled -> Scheduled terminal provenance
  proves source closed and successor exposed
```

Therefore the correct candidate is **not** one generic Scheduled publisher.

The candidate is a small presentation-neutral helper for creating one admitted fresh Scheduled occurrence from common draft fields, while leaving source selection, terminal provenance, transition checks, publication error wording, and operation-specific receipts local.

## 8. Positive precedent: ScheduledContinuationRouting

`ScheduledContinuationRouting` already demonstrates the desired compression style.

A TUI-specific continuation-routing orchestration was promoted to a presentation-neutral shared boundary, while actual routing publication remains delegated to `ScheduledRoutingPublisher`.

This shares orchestration without creating a second routing authority or generic command framework.

The Creation / Replacement candidate should follow the same discipline:

```text
share pure mechanics
keep semantic operation ownership explicit
```

## 9. Formal promotion gate for Creation / Replacement extraction

This candidate is mechanical equivalence, so Lean is the preferred instrument. A new Alloy model is unnecessary unless the proposed refactor changes admission semantics.

Before implementation, prove or regression-lock at least:

1. identical fresh-id choice for the same ScheduledMemory;
2. identical BalancedMovement reconstructed from the same draft Effects;
3. identical ScheduledOccurrence id, date, measure, and changes;
4. identical acceptance/refusal of malformed movement content at the shared boundary;
5. Creation still adds no terminal relation;
6. Replacement still adds exactly one source-to-successor terminal relation and retains its current-open transition checks;
7. lifecycle wire bytes are unchanged for accepted operations;
8. writer ownership order and publication order are unchanged.

If extraction requires a callback-heavy generic publisher, a new public ontology, or more adapter code than it removes, reject it.

## 10. Rejected abstractions

This audit does not support:

```text
NO generic Lifecycle framework
NO generic Scheduled command bus
NO canonical Scheduled status field
NO stored current-open state
NO stored Commitment or Headroom
NO generic Scenario object
NO universal Publisher<T> framework
NO moving UI error strings into Application
NO merging Creation, Replacement, Terminal, and Routing operations merely because they touch one lifecycle image
```

## 11. SA-008 verdict

The main hypothesis that Scheduled has become semantically overgrown is not supported.

The more accurate picture is:

```text
small retained basis
+ centralized lifecycle interpretation
+ several legitimate derived household questions
+ explicit operation-specific writers
+ interface porcelain
```

The current fanout is therefore mostly **healthy semantic amplification** rather than concept proliferation.

The strongest residual subtraction candidate is narrow:

```text
ScheduledCreationPublisher
ScheduledReplacementPublisher
        |
        +-- share fresh occurrence construction mechanics
```

The repeated current-open refusal-to-string mapping is observable code duplication but is lower priority and currently preferable to contaminating Application or reversing dependencies.

### Promotion state

SA-008 is **audit-complete** at this checkpoint.

No production implementation is authorized by this file alone.

If implementation is batched later, first attempt the smallest Creation / Replacement pure-mechanics extraction with Lean equivalence and unchanged lifecycle bytes/protocol. If that is not net-negative, keep the current explicit publishers.

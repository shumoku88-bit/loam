import Loam.Application.ScheduledInspection

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Open-world Scheduled evidence

Observation 211 qualified a narrow but important read-side boundary:

```text
explicit Scheduled evidence exists -> Due
explicit Scheduled evidence absent -> Unknown
```

Finite retained Scheduled occurrences are not a closed-world description of all
future household obligations. In particular, absence of a retained occurrence
must not be reinterpreted as `NotDue` unless a separately qualified completeness
claim covers the query.

This module adds no canonical state and no recurrence semantics. It only projects
already-qualified current-open Scheduled evidence into a result that cannot
silently turn missing retained evidence into a negative household claim.
-/

/--
Open-world answer for one exact Scheduled day through the replacement-aware
current lifecycle frontier.

`due` is structurally non-empty: one explicit current-open occurrence is carried
separately from any additional same-day occurrences. `unknown` means that no
explicit current-open occurrence is retained for the queried day. It does **not**
mean that no household obligation is due on that day.

The remaining constructors preserve the fail-closed refusal vocabulary of
`currentOpenScheduledWithReplacement` rather than collapsing malformed lifecycle
or replacement evidence into ordinary `unknown`.
-/
inductive CurrentScheduledDayEvidenceResult (Time : Type) where
  | due
      (first : ScheduledOccurrence Time)
      (rest : List (ScheduledOccurrence Time))
  | unknown
  | unknownCompletionScheduled
  | unknownRetirementScheduled
  | unknownReplacementScheduled
  | invalidReplacementGraph
  | conflictingTerminalEvidence

private def explicitDayEvidence {Time : Type} [DecidableEq Time]
    (day : Time)
    (occurrences : List (ScheduledOccurrence Time)) :
    CurrentScheduledDayEvidenceResult Time :=
  match occurrences.filter fun occurrence => decide (occurrence.scheduledOn = day) with
  | [] => .unknown
  | first :: rest => .due first rest

/--
Query one exact day without inventing closed-world Scheduled semantics.

The operation first obtains the complete *retained current-open Scheduled set*
through the existing replacement-aware lifecycle frontier. It then asks only
whether that retained evidence contains one or more occurrences on `day`.

No recurrence, Series, generation policy, completeness horizon, or future
materialization policy is inferred from a missing row.
-/
def currentScheduledDayEvidenceWithReplacement {Time : Type} [DecidableEq Time]
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (replacements : ScheduledReplacementMemory)
    (events : EventMemory)
    (day : Time) : CurrentScheduledDayEvidenceResult Time :=
  match currentOpenScheduledWithReplacement
      scheduled completions retirements replacements events with
  | .open occurrences => explicitDayEvidence day occurrences
  | .unknownCompletionScheduled => .unknownCompletionScheduled
  | .unknownRetirementScheduled => .unknownRetirementScheduled
  | .unknownReplacementScheduled => .unknownReplacementScheduled
  | .invalidReplacementGraph => .invalidReplacementGraph
  | .conflictingTerminalEvidence => .conflictingTerminalEvidence

end Loam.Application

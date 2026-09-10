import Loam.Core.EventMemory
import Loam.Core.ScheduledMemory
import Loam.Core.ScheduledTerminal
import Loam.Application.ReplacementFrontier

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Current Scheduled inspection

The current-open answer is derived from retained Scheduled occurrences plus one
Scheduled-terminal relation. Terminal target meaning remains explicit:

```text
Actual target       completion
Scheduled target    replacement
no target           retirement
```

A completion closes its source only when the referenced Actual Event is present.
A retained completion whose Actual endpoint has not yet appeared therefore stays
inert to readers and remains retryable by the writer.

Unknown references, replacement cycles, and cross-kind terminal conflicts remain
separate fail-closed results. Raw terminal memory intentionally permits such a
cross-kind conflict so review can identify it rather than reducing it to a generic
codec failure.

The practical core does not retain when terminal evidence became known, so this
module does not invent historical as-of lifecycle answers.
-/

inductive CurrentOpenScheduledResult (Time : Type) where
  | open (occurrences : List (ScheduledOccurrence Time))
  | unknownCompletionScheduled
  | unknownRetirementScheduled
  | unknownReplacementScheduled
  | invalidReplacementGraph
  | conflictingTerminalEvidence

private def scheduledPresent {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (id : ScheduledId) : Bool :=
  (ScheduledMemory.findById? scheduledMemory id).isSome

private def completionSourcesKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  terminalMemory.terminals.all fun terminal =>
    match terminal.target with
    | some (.actual _) => scheduledPresent scheduledMemory terminal.source
    | _ => true

private def retirementSourcesKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  terminalMemory.terminals.all fun terminal =>
    match terminal.target with
    | none => scheduledPresent scheduledMemory terminal.source
    | _ => true

private def replacementEdges
    (terminalMemory : ScheduledTerminalMemory) :
    List (ReplacementFrontier.Edge ScheduledId) :=
  terminalMemory.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.scheduled successor) =>
        some { source := terminal.source, successor := successor }
    | _ => none

private def replacementEndpointsKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  ReplacementFrontier.referencesClosed
    (scheduledPresent scheduledMemory)
    (replacementEdges terminalMemory)

private def hasEffectiveCompletion
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory)
    (scheduled : ScheduledId) : Bool :=
  match ScheduledTerminalMemory.completionActualFor? terminalMemory scheduled with
  | none => false
  | some actual => (EventMemory.findById? eventMemory actual).isSome

private def isCurrentOpen {Time : Type}
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory)
    (occurrence : ScheduledOccurrence Time) : Bool :=
  (ScheduledTerminalMemory.retirementFor?
      terminalMemory occurrence.id).isNone &&
    (ScheduledTerminalMemory.replacementFor?
      terminalMemory occurrence.id).isNone &&
    !hasEffectiveCompletion terminalMemory eventMemory occurrence.id

/--
Project the complete current-open Scheduled set, or refuse the whole answer when
retained terminal evidence is structurally inconsistent.

The admitted terminal shape must satisfy all current semantic checks before any
terminal claim can close a source:

- every completion source is retained;
- every retirement source is retained;
- every replacement source and successor is retained;
- replacement provenance is acyclic;
- one source cannot simultaneously carry competing terminal meanings.

Representation order is preserved. Consumers that sort for presentation do not
give storage order chronological meaning.
-/
def currentOpenScheduled {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory) : CurrentOpenScheduledResult Time :=
  let edges := replacementEdges terminalMemory
  if !completionSourcesKnown scheduledMemory terminalMemory then
    .unknownCompletionScheduled
  else if !retirementSourcesKnown scheduledMemory terminalMemory then
    .unknownRetirementScheduled
  else if !replacementEndpointsKnown scheduledMemory terminalMemory then
    .unknownReplacementScheduled
  else if !ReplacementFrontier.acyclic edges then
    .invalidReplacementGraph
  else if terminalMemory.hasCrossKindConflict then
    .conflictingTerminalEvidence
  else
    .open <|
      scheduledMemory.occurrences.filter
        (isCurrentOpen terminalMemory eventMemory)

end Loam.Application

import Loam.Core.EventMemory
import Loam.Core.ScheduledMemory
import Loam.Core.ScheduledTerminal
import Loam.Application.ReplacementFrontier
import Std.Data.HashMap
import Std.Data.HashSet

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

/--
Transient lookup set for remembered Scheduled occurrence identities.
-/
private def buildScheduledIdSet {Time : Type}
    (scheduledMemory : ScheduledMemory Time) : Std.HashSet String :=
  scheduledMemory.occurrences.foldl
    (fun set occ => set.insert occ.id.token)
    {}

/--
Transient lookup set for remembered Actual Event identities.
Existence is sufficient for completion activation; no Event values are cached.
-/
private def buildEventIdSet
    (eventMemory : EventMemory) : Std.HashSet String :=
  eventMemory.events.foldl
    (fun set event => set.insert event.id.token)
    {}

/--
Transient scan state accumulated during the single pass over
`ScheduledTerminalMemory.terminals`.
-/
private structure TerminalScanState where
  seenTargetBySource : Std.HashMap String (Option ScheduledTerminalTarget)
  completionBySource : Std.HashMap String EventId
  retiredSources : Std.HashSet String
  replacementBySource : Std.HashMap String ScheduledId
  replacementEdgesRev : List (ReplacementFrontier.Edge ScheduledId)
  hasUnknownCompletionSource : Bool
  hasUnknownRetirementSource : Bool
  hasUnknownReplacementEndpoint : Bool
  hasCrossKindConflict : Bool

/--
Traverse raw terminals in one pass, collecting derived lookup structures and
evaluating reference closure and cross-kind conflict without repeated scanning.
-/
private def scanTerminals
    (scheduledIds : Std.HashSet String)
    (terminals : List ScheduledTerminal) : TerminalScanState :=
  terminals.foldl
    (fun state terminal =>
      let sourceToken := terminal.source.token
      let sourceKnown := scheduledIds.contains sourceToken
      let crossKind :=
        match state.seenTargetBySource[sourceToken]? with
        | some prevTarget =>
            state.hasCrossKindConflict || decide (prevTarget != terminal.target)
        | none => state.hasCrossKindConflict
      let seenTargets := state.seenTargetBySource.insert sourceToken terminal.target
      match terminal.target with
      | some (.actual event) =>
          { state with
            seenTargetBySource := seenTargets
            completionBySource := state.completionBySource.insert sourceToken event
            hasUnknownCompletionSource := state.hasUnknownCompletionSource || !sourceKnown
            hasCrossKindConflict := crossKind
          }
      | none =>
          { state with
            seenTargetBySource := seenTargets
            retiredSources := state.retiredSources.insert sourceToken
            hasUnknownRetirementSource := state.hasUnknownRetirementSource || !sourceKnown
            hasCrossKindConflict := crossKind
          }
      | some (.scheduled successor) =>
          let successorKnown := scheduledIds.contains successor.token
          let edge : ReplacementFrontier.Edge ScheduledId :=
            { source := terminal.source, successor := successor }
          { state with
            seenTargetBySource := seenTargets
            replacementBySource := state.replacementBySource.insert sourceToken successor
            replacementEdgesRev := edge :: state.replacementEdgesRev
            hasUnknownReplacementEndpoint :=
              state.hasUnknownReplacementEndpoint || !sourceKnown || !successorKnown
            hasCrossKindConflict := crossKind
          })
    {
      seenTargetBySource := {}
      completionBySource := {}
      retiredSources := {}
      replacementBySource := {}
      replacementEdgesRev := []
      hasUnknownCompletionSource := false
      hasUnknownRetirementSource := false
      hasUnknownReplacementEndpoint := false
      hasCrossKindConflict := false
    }

/--
Transient lookup index and validation summary constructed once per
`currentOpenScheduled` inspection pass.
-/
private structure ScheduledLifecycleIndex where
  eventIds : Std.HashSet String
  completionBySource : Std.HashMap String EventId
  retiredSources : Std.HashSet String
  replacementBySource : Std.HashMap String ScheduledId
  replacementEdges : List (ReplacementFrontier.Edge ScheduledId)
  hasUnknownCompletionSource : Bool
  hasUnknownRetirementSource : Bool
  hasUnknownReplacementEndpoint : Bool
  hasCrossKindConflict : Bool

private def buildScheduledLifecycleIndex {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory) : ScheduledLifecycleIndex :=
  let scheduledIds := buildScheduledIdSet scheduledMemory
  let eventIds := buildEventIdSet eventMemory
  let scan := scanTerminals scheduledIds terminalMemory.terminals
  {
    eventIds := eventIds
    completionBySource := scan.completionBySource
    retiredSources := scan.retiredSources
    replacementBySource := scan.replacementBySource
    replacementEdges := scan.replacementEdgesRev.reverse
    hasUnknownCompletionSource := scan.hasUnknownCompletionSource
    hasUnknownRetirementSource := scan.hasUnknownRetirementSource
    hasUnknownReplacementEndpoint := scan.hasUnknownReplacementEndpoint
    hasCrossKindConflict := scan.hasCrossKindConflict
  }

private def isCurrentOpenIndexed {Time : Type}
    (index : ScheduledLifecycleIndex)
    (occurrence : ScheduledOccurrence Time) : Bool :=
  let idToken := occurrence.id.token
  !index.retiredSources.contains idToken &&
    !index.replacementBySource.contains idToken &&
    !(match index.completionBySource[idToken]? with
      | some actual => index.eventIds.contains actual.token
      | none => false)

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
  let index := buildScheduledLifecycleIndex scheduledMemory terminalMemory eventMemory
  if index.hasUnknownCompletionSource then
    .unknownCompletionScheduled
  else if index.hasUnknownRetirementSource then
    .unknownRetirementScheduled
  else if index.hasUnknownReplacementEndpoint then
    .unknownReplacementScheduled
  else if !ReplacementFrontier.acyclic index.replacementEdges then
    .invalidReplacementGraph
  else if index.hasCrossKindConflict then
    .conflictingTerminalEvidence
  else
    .open <|
      scheduledMemory.occurrences.filter (isCurrentOpenIndexed index)

end Loam.Application

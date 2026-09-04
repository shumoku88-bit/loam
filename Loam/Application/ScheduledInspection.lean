import Loam.Core.EventMemory
import Loam.Core.ScheduledCompletion
import Loam.Core.ScheduledMemory
import Loam.Core.ScheduledRetirement

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Current Scheduled inspection

This application boundary centralizes the already-qualified current-open reading
used by practical Scheduled consumers.

A completion closes a Scheduled occurrence only when its referenced Actual Event
is present. This preserves the interrupted-publication rule: a raw completion
relation whose Actual endpoint has not yet appeared is inert to readers.

Retirement closes an occurrence immediately in the current view. The current
Practical Core does not retain when retirement/completion evidence became known,
so this module deliberately does not invent historical as-of lifecycle answers.
-/

inductive CurrentOpenScheduledResult (Time : Type) where
  | open (occurrences : List (ScheduledOccurrence Time))
  | unknownCompletionScheduled
  | unknownRetirementScheduled
  | conflictingTerminalEvidence

private def completionReferencesKnownScheduled {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (completionMemory : ScheduledCompletionMemory) : Bool :=
  completionMemory.completions.all fun completion =>
    (ScheduledMemory.findById? scheduledMemory completion.scheduled).isSome

private def retirementReferencesKnownScheduled {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (retirementMemory : ScheduledRetirementMemory) : Bool :=
  retirementMemory.retirements.all fun retirement =>
    (ScheduledMemory.findById? scheduledMemory retirement.scheduled).isSome

private def terminalEvidenceCompatible
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory) : Bool :=
  retirementMemory.retirements.all fun retirement =>
    (ScheduledCompletionMemory.findByScheduled?
      completionMemory retirement.scheduled).isNone

private def hasEffectiveCompletion
    (completionMemory : ScheduledCompletionMemory)
    (eventMemory : EventMemory)
    (scheduled : ScheduledId) : Bool :=
  match ScheduledCompletionMemory.findByScheduled? completionMemory scheduled with
  | none => false
  | some completion => (EventMemory.findById? eventMemory completion.actual).isSome

private def isCurrentOpen {Time : Type}
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory)
    (eventMemory : EventMemory)
    (occurrence : ScheduledOccurrence Time) : Bool :=
  (ScheduledRetirementMemory.findByScheduled?
      retirementMemory occurrence.id).isNone &&
    !hasEffectiveCompletion completionMemory eventMemory occurrence.id

/--
Project the complete current open Scheduled set, or refuse the whole answer when
retained lifecycle evidence is structurally inconsistent.

Representation order is preserved. Consumers that sort for presentation do not
thereby give storage order chronological meaning.
-/
def currentOpenScheduled {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory)
    (eventMemory : EventMemory) : CurrentOpenScheduledResult Time :=
  if !completionReferencesKnownScheduled scheduledMemory completionMemory then
    .unknownCompletionScheduled
  else if !retirementReferencesKnownScheduled scheduledMemory retirementMemory then
    .unknownRetirementScheduled
  else if !terminalEvidenceCompatible completionMemory retirementMemory then
    .conflictingTerminalEvidence
  else
    .open <|
      scheduledMemory.occurrences.filter
        (isCurrentOpen completionMemory retirementMemory eventMemory)

end Loam.Application

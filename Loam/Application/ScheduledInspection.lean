import Loam.Core.EventMemory
import Loam.Core.ScheduledCompletion
import Loam.Core.ScheduledMemory
import Loam.Core.ScheduledReplacement
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

Retirement closes an occurrence immediately in the current view. Observation 105
also qualified explicit Scheduled replacement as a terminal relation, but existing
practical readers do not yet consume that evidence. The replacement-aware entry
below therefore remains separate until every affected reader can be migrated in
one fail-closed cut.

The current Practical Core does not retain when retirement/completion/replacement
evidence became known, so this module deliberately does not invent historical
as-of lifecycle answers.
-/

inductive CurrentOpenScheduledResult (Time : Type) where
  | open (occurrences : List (ScheduledOccurrence Time))
  | unknownCompletionScheduled
  | unknownRetirementScheduled
  | conflictingTerminalEvidence

/--
Replacement-aware current-open result.

Missing replacement endpoints and cyclic replacement topology stay distinct from
ordinary terminal conflicts so a later practical reader can fail closed without
inventing a winner or silently discarding malformed provenance.
-/
inductive CurrentOpenScheduledWithReplacementResult (Time : Type) where
  | open (occurrences : List (ScheduledOccurrence Time))
  | unknownCompletionScheduled
  | unknownRetirementScheduled
  | unknownReplacementScheduled
  | invalidReplacementGraph
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

private def replacementReferencesKnownScheduled {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (replacementMemory : ScheduledReplacementMemory) : Bool :=
  replacementMemory.replacements.all fun replacement =>
    (ScheduledMemory.findById? scheduledMemory replacement.source).isSome &&
      (ScheduledMemory.findById? scheduledMemory replacement.replacement).isSome

private def terminalEvidenceCompatible
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory) : Bool :=
  retirementMemory.retirements.all fun retirement =>
    (ScheduledCompletionMemory.findByScheduled?
      completionMemory retirement.scheduled).isNone

private def replacementTerminalEvidenceCompatible
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory)
    (replacementMemory : ScheduledReplacementMemory) : Bool :=
  replacementMemory.replacements.all fun replacement =>
    (ScheduledCompletionMemory.findByScheduled?
      completionMemory replacement.source).isNone &&
    (ScheduledRetirementMemory.findByScheduled?
      retirementMemory replacement.source).isNone

private def replacementPathAcyclic
    (replacementMemory : ScheduledReplacementMemory)
    (current : ScheduledId)
    (seen : List ScheduledId) : Nat → Bool
  | 0 => false
  | fuel + 1 =>
      if current ∈ seen then
        false
      else
        match ScheduledReplacementMemory.findBySource? replacementMemory current with
        | none => true
        | some replacement =>
            replacementPathAcyclic
              replacementMemory replacement.replacement (current :: seen) fuel

private def replacementGraphAcyclic
    (replacementMemory : ScheduledReplacementMemory) : Bool :=
  replacementMemory.replacements.all fun replacement =>
    replacementPathAcyclic
      replacementMemory replacement.source [] (replacementMemory.replacements.length + 1)

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

private def isCurrentOpenWithReplacement {Time : Type}
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory)
    (replacementMemory : ScheduledReplacementMemory)
    (eventMemory : EventMemory)
    (occurrence : ScheduledOccurrence Time) : Bool :=
  isCurrentOpen completionMemory retirementMemory eventMemory occurrence &&
    (ScheduledReplacementMemory.findBySource?
      replacementMemory occurrence.id).isNone

/--
Project the complete current open Scheduled set, or refuse the whole answer when
retained completion / retirement evidence is structurally inconsistent.

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

/--
Project the complete current-open Scheduled set when explicit replacement
provenance is part of the retained world.

The admitted replacement shape must satisfy all of the currently qualified
conditions before it can close a source occurrence:

- every source and replacement Scheduled identity is retained;
- raw memory is already one-to-one at both endpoints;
- following replacements cannot cycle;
- a replacement source cannot simultaneously carry completion or retirement
  terminal evidence.

Once those conditions hold, every replacement source is superseded and filtered
from the current-open set. Replacement targets remain ordinary retained Scheduled
occurrences and may themselves later be completed, retired, or replaced.
-/
def currentOpenScheduledWithReplacement {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory)
    (replacementMemory : ScheduledReplacementMemory)
    (eventMemory : EventMemory) : CurrentOpenScheduledWithReplacementResult Time :=
  if !completionReferencesKnownScheduled scheduledMemory completionMemory then
    .unknownCompletionScheduled
  else if !retirementReferencesKnownScheduled scheduledMemory retirementMemory then
    .unknownRetirementScheduled
  else if !replacementReferencesKnownScheduled scheduledMemory replacementMemory then
    .unknownReplacementScheduled
  else if !replacementGraphAcyclic replacementMemory then
    .invalidReplacementGraph
  else if !terminalEvidenceCompatible completionMemory retirementMemory ||
      !replacementTerminalEvidenceCompatible
        completionMemory retirementMemory replacementMemory then
    .conflictingTerminalEvidence
  else
    .open <|
      scheduledMemory.occurrences.filter
        (isCurrentOpenWithReplacement
          completionMemory retirementMemory replacementMemory eventMemory)

end Loam.Application

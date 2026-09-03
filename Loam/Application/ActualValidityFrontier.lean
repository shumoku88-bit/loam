import Loam.Core.ActualValidityHistory

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

variable {Time : Type}

private def targetUsed
    (history : ActualValidityHistory Time)
    (id : ActualValidityFactId) : Bool :=
  history.corrections.any fun correction => decide (correction.target = id)

private def uniqueTargets : List ActualValidityCorrection → Bool
  | [] => true
  | correction :: rest =>
      !(rest.any fun other => decide (other.target = correction.target)) &&
        uniqueTargets rest

private def uniqueReplacements : List ActualValidityCorrection → Bool
  | [] => true
  | correction :: rest =>
      !(rest.any fun other => decide (other.replacement = correction.replacement)) &&
        uniqueReplacements rest

private def closedReferences
    (history : ActualValidityHistory Time) : Bool :=
  history.corrections.all fun correction =>
    (history.findFactById? correction.target).isSome &&
      (history.findFactById? correction.replacement).isSome

private def preservesEvent
    (history : ActualValidityHistory Time) : Bool :=
  history.corrections.all fun correction =>
    match history.findFactById? correction.target,
        history.findFactById? correction.replacement with
    | some target, some replacement => decide (target.event = replacement.event)
    | _, _ => false

private def nextReplacement? :
    List ActualValidityCorrection → ActualValidityFactId → Option ActualValidityFactId
  | [], _ => none
  | correction :: rest, id =>
      if correction.target = id then
        some correction.replacement
      else
        nextReplacement? rest id

private def pathAcyclicFrom
    (corrections : List ActualValidityCorrection)
    (start : ActualValidityFactId) : Nat → ActualValidityFactId → Bool
  | 0, _ => true
  | fuel + 1, current =>
      match nextReplacement? corrections current with
      | none => true
      | some next =>
          if next = start then
            false
          else
            pathAcyclicFrom corrections start fuel next

private def acyclic (history : ActualValidityHistory Time) : Bool :=
  history.corrections.all fun correction =>
    pathAcyclicFrom
      history.corrections correction.target history.corrections.length correction.target

/-- Historical validity facts remain retained; correction targets leave the current frontier. -/
def actualValidityFrontierFacts
    (history : ActualValidityHistory Time) : List (ActualValidityFact Time) :=
  history.facts.filter fun fact => !(targetUsed history fact.id)

private def uniqueFrontierEvents : List (ActualValidityFact Time) → Bool
  | [] => true
  | fact :: rest =>
      !(rest.any fun other => decide (other.event = fact.event)) &&
        uniqueFrontierEvents rest

/--
Admit only disjoint closed same-Event correction paths with one current fact per Event.

Sibling corrections, shared replacements, open references, cross-Event replacement,
and cycles remain unresolved rather than receiving storage-order authority.
-/
def actualValidityFrontierAdmissible
    (history : ActualValidityHistory Time) : Bool :=
  uniqueTargets history.corrections &&
    uniqueReplacements history.corrections &&
    closedReferences history &&
    preservesEvent history &&
    acyclic history &&
    uniqueFrontierEvents (actualValidityFrontierFacts history)

/-- Return the current validity facts only when the raw correction history is unambiguous. -/
def admittedActualValidityFacts?
    (history : ActualValidityHistory Time) : Option (List (ActualValidityFact Time)) :=
  if actualValidityFrontierAdmissible history then
    some (actualValidityFrontierFacts history)
  else
    none

/--
Project append-only validity provenance into the existing one-current-date-per-Event view.

This keeps downstream Consumption and review operations on `ActualValidityMemory`
without making raw history itself pretend to contain only current facts.
-/
def admittedActualValidityMemory?
    (history : ActualValidityHistory Time) : Option (ActualValidityMemory Time) := do
  let facts ← admittedActualValidityFacts? history
  ActualValidityMemory.ofEntries?
    (facts.map fun fact => { event := fact.event, validOn := fact.validOn })

@[simp] theorem admittedActualValidityMemory?_empty :
    admittedActualValidityMemory?
      ({
        facts := []
        factIdNodup := by simp
        corrections := []
        correctionIdNodup := by simp
      } : ActualValidityHistory Time) =
      some { entries := [], eventNodup := by simp } := by
  rfl

end Loam.Application

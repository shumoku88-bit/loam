import Loam.Core.ActualValidityHistory
import Loam.Application.ReplacementFrontier

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

variable {Time : Type}

private def correctionEdges
    (history : ActualValidityHistory Time) :
    List (ReplacementFrontier.Edge ActualValidityRef) :=
  history.corrections.map fun correction =>
    { source := correction.target, successor := .revision correction.replacement }

private def factPresent
    (history : ActualValidityHistory Time)
    (ref : ActualValidityRef) : Bool :=
  (history.findFactByRef? ref).isSome

private def preservesEvent
    (history : ActualValidityHistory Time) : Bool :=
  history.corrections.all fun correction =>
    match history.findFactByRef? correction.target,
        history.findFactByRef? (.revision correction.replacement) with
    | some target, some replacement => decide (target.event = replacement.event)
    | _, _ => false

/-- Historical validity facts remain retained; correction targets leave the current frontier. -/
def actualValidityFrontierFacts
    (history : ActualValidityHistory Time) : List (ActualValidityFact Time) :=
  ReplacementFrontier.frontier
    ActualValidityFact.ref history.facts (correctionEdges history)

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
  ReplacementFrontier.structurallyAdmissible
      (factPresent history) (correctionEdges history) &&
    preservesEvent history &&
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
        factRefNodup := by simp
        corrections := []
        correctionIdNodup := by simp
      } : ActualValidityHistory Time) =
      some { entries := [], eventNodup := by simp } := by
  rfl

end Loam.Application

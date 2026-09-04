import Loam.Core

namespace Loam.Observation150

open Loam.Core

set_option autoImplicit false

/-!
# Observation 150 — unified Actual atomic generation

Observation 149 found that the current sidecar topology remains the qualified
production baseline, while a scratch unified-Actual specimen exposed one concrete
benefit: a complete Actual generation can be staged and atomically committed as
old-or-new instead of publishing supporting evidence across multiple files.

This observation asks the narrower semantic question before any persistence
implementation exists:

> Can Event, ActualValidity, EventDescription, and EventCorrection remain distinct
> typed facets while one complete Actual generation becomes the physical authority
> commit unit?

The model deliberately keeps Scheduled, QuantityBasis, and view configuration
outside the Actual generation.
-/

structure CorrectionEdge where
  target : EventId
  replacement : EventId
  deriving Repr, DecidableEq

/--
One physical Actual generation still retains four semantic facets. Unification is
about the commit unit, not erasing distinctions between facts.
-/
structure ActualGeneration where
  events : List EventId
  validities : List EventId
  descriptions : List EventId
  corrections : List CorrectionEdge
  deriving Repr, DecidableEq

private def memberEvent (events : List EventId) (id : EventId) : Bool :=
  events.any fun candidate => decide (candidate = id)

private def correctionResolved (events : List EventId) (edge : CorrectionEdge) : Bool :=
  memberEvent events edge.target && memberEvent events edge.replacement

/--
A candidate generation must have unique authoritative Event identities, at most
one current validity and description endpoint per Event in this observation, and
all retained references must resolve inside the same generation.
-/
def generationAdmissible (generation : ActualGeneration) : Bool :=
  decide generation.events.Nodup &&
  decide generation.validities.Nodup &&
  decide generation.descriptions.Nodup &&
  generation.validities.all (memberEvent generation.events) &&
  generation.descriptions.all (memberEvent generation.events) &&
  generation.corrections.all (correctionResolved generation.events)

private def eventA : EventId := ⟨"e1"⟩
private def eventB : EventId := ⟨"e2"⟩
private def missingEvent : EventId := ⟨"missing"⟩

private def oldGeneration : ActualGeneration :=
  { events := [eventA]
    validities := [eventA]
    descriptions := [eventA]
    corrections := [] }

private def newGeneration : ActualGeneration :=
  { events := [eventA, eventB]
    validities := [eventA, eventB]
    descriptions := [eventA, eventB]
    corrections := [{ target := eventA, replacement := eventB }] }

private def orphanValidityGeneration : ActualGeneration :=
  { newGeneration with
    validities := [eventA, missingEvent] }

private def orphanDescriptionGeneration : ActualGeneration :=
  { newGeneration with
    descriptions := [eventA, missingEvent] }

private def orphanCorrectionGeneration : ActualGeneration :=
  { newGeneration with
    corrections := [{ target := eventA, replacement := missingEvent }] }

private def duplicateEventGeneration : ActualGeneration :=
  { newGeneration with
    events := [eventA, eventA] }

/-- Both representative complete generations are self-contained. -/
theorem complete_generations_admitted :
    generationAdmissible oldGeneration = true ∧
    generationAdmissible newGeneration = true := by
  decide

/-- Occurrence-date evidence cannot point outside the candidate generation. -/
theorem orphan_validity_refused :
    generationAdmissible orphanValidityGeneration = false := by
  decide

/-- Human-recognition evidence has the same reference-closure requirement. -/
theorem orphan_description_refused :
    generationAdmissible orphanDescriptionGeneration = false := by
  decide

/-- Correction topology must close over Events in the same candidate generation. -/
theorem orphan_correction_endpoint_refused :
    generationAdmissible orphanCorrectionGeneration = false := by
  decide

/-- Event authority identities remain unique inside one generation. -/
theorem duplicate_event_authority_refused :
    generationAdmissible duplicateEventGeneration = false := by
  decide

/-! ## Semantic distinctions remain inside the unified generation -/

private def descriptionOnlyCandidate : ActualGeneration :=
  { newGeneration with descriptions := [eventA] }

/--
Changing only description evidence does not silently rewrite the Event, validity,
or correction facets. Physical unification does not imply semantic coalescing.
-/
theorem facet_distinctions_retained :
    descriptionOnlyCandidate.events = newGeneration.events ∧
    descriptionOnlyCandidate.validities = newGeneration.validities ∧
    descriptionOnlyCandidate.corrections = newGeneration.corrections ∧
    descriptionOnlyCandidate.descriptions ≠ newGeneration.descriptions := by
  decide

/-! ## Staged atomic authority -/

structure UnifiedStore where
  authoritative : ActualGeneration
  staged : Option ActualGeneration
  deriving Repr, DecidableEq

private def initialStore : UnifiedStore :=
  { authoritative := oldGeneration, staged := none }

/--
Only a complete admissible generation may enter the sibling staging slot. The
current authoritative generation is not changed by staging.
-/
def stage? (store : UnifiedStore) (candidate : ActualGeneration) : Option UnifiedStore :=
  if generationAdmissible candidate then
    some { authoritative := store.authoritative, staged := some candidate }
  else
    none

/--
Atomic replacement is modeled as changing the authoritative pointer only after a
complete generation has already been staged.
-/
def commit? (store : UnifiedStore) : Option UnifiedStore :=
  match store.staged with
  | none => none
  | some candidate =>
      some { authoritative := candidate, staged := none }

private def visibleGeneration (store : UnifiedStore) : ActualGeneration :=
  store.authoritative

private def stagedNewStore : UnifiedStore :=
  { authoritative := oldGeneration, staged := some newGeneration }

private def committedNewStore : UnifiedStore :=
  { authoritative := newGeneration, staged := none }

/-- A complete new generation can be staged beside the old authority. -/
theorem complete_generation_can_stage :
    stage? initialStore newGeneration = some stagedNewStore := by
  decide

/-- Staging never changes what readers see before the authority commit. -/
theorem staged_generation_is_not_visible :
    visibleGeneration stagedNewStore = oldGeneration := by
  rfl

/-- The one authority switch exposes the complete new generation. -/
theorem atomic_commit_exposes_complete_new_generation :
    commit? stagedNewStore = some committedNewStore ∧
    visibleGeneration committedNewStore = newGeneration := by
  decide

/-- Without a staged complete generation there is no commit transition. -/
theorem commit_without_stage_refused :
    commit? initialStore = none := by
  rfl

/-- Broken cross-facet reference closure is refused before staging. -/
theorem invalid_candidates_never_reach_stage :
    stage? initialStore orphanValidityGeneration = none ∧
    stage? initialStore orphanDescriptionGeneration = none ∧
    stage? initialStore orphanCorrectionGeneration = none ∧
    stage? initialStore duplicateEventGeneration = none := by
  decide

/-! ## Non-Actual families remain outside the authority switch -/

structure NonActualState where
  scheduledToken : Nat
  basisToken : Nat
  viewToken : Nat
  deriving Repr, DecidableEq

private def stableNonActual : NonActualState :=
  { scheduledToken := 11, basisToken := 22, viewToken := 33 }

structure HouseholdWorld where
  actual : UnifiedStore
  nonActual : NonActualState
  deriving Repr, DecidableEq

private def householdBeforeCommit : HouseholdWorld :=
  { actual := stagedNewStore, nonActual := stableNonActual }

private def householdAfterCommit : HouseholdWorld :=
  { actual := committedNewStore, nonActual := stableNonActual }

/--
Committing a new Actual generation does not make Scheduled, QuantityBasis, or view
configuration part of that physical authority boundary.
-/
theorem actual_commit_keeps_non_actual_families_independent :
    householdBeforeCommit.nonActual = householdAfterCommit.nonActual ∧
    householdBeforeCommit.actual.authoritative = oldGeneration ∧
    householdAfterCommit.actual.authoritative = newGeneration := by
  decide

/-! ## Reader-state classification -/

inductive PublicationPhase
  | oldAuthoritative
  | newStaged
  | newCommitted
  deriving Repr, DecidableEq

private def storeAt : PublicationPhase → UnifiedStore
  | .oldAuthoritative => initialStore
  | .newStaged => stagedNewStore
  | .newCommitted => committedNewStore

inductive ReaderImage
  | oldComplete
  | newComplete
  | mixedOrPartial
  deriving Repr, DecidableEq

private def readerImage : UnifiedStore → ReaderImage
  | { authoritative := authoritative, staged := _ } =>
      if authoritative = oldGeneration then .oldComplete
      else if authoritative = newGeneration then .newComplete
      else .mixedOrPartial

/--
Every qualified publication phase exposes either the old complete generation or
the new complete generation. The staged generation is never itself reader-visible.
-/
theorem qualified_atomic_path_never_exposes_mixed_generation
    (phase : PublicationPhase) :
    readerImage (storeAt phase) ≠ .mixedOrPartial := by
  cases phase <;> decide

/-- The exact visible transition is old, old while staged, then new. -/
theorem qualified_atomic_path_is_old_old_new :
    readerImage (storeAt .oldAuthoritative) = .oldComplete ∧
    readerImage (storeAt .newStaged) = .oldComplete ∧
    readerImage (storeAt .newCommitted) = .newComplete := by
  decide

end Loam.Observation150

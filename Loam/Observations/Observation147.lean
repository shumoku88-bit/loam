import Loam.Application.ActualValidityFrontier

namespace Loam.Observation147

open Loam.Core
open Loam.Application

set_option autoImplicit false

variable {Time : Type}

/-!
# Observation 147 — ActualValidity root compression

Observation 146 found that an Event may serve as the initial temporal root while
later date corrections still require distinct revision identity. This
production-shaped observation asks whether the current identified-fact history
can be compressed into that representation without using list order and without
changing the admitted current date.

The candidate is observation-local. No production type or persistence format is
changed here.
-/

inductive RootedNodeRef where
  | root (event : EventId)
  | revision (id : ActualValidityFactId)
deriving Repr, DecidableEq

structure RootedBase (Time : Type) where
  event : EventId
  validOn : Time
deriving Repr, DecidableEq

structure RootedRevision (Time : Type) where
  id : ActualValidityFactId
  event : EventId
  validOn : Time
deriving Repr, DecidableEq

structure RootedCorrection where
  id : ActualValidityCorrectionId
  target : RootedNodeRef
  replacement : ActualValidityFactId
deriving Repr, DecidableEq

structure RootedHistory (Time : Type) where
  bases : List (RootedBase Time)
  revisions : List (RootedRevision Time)
  corrections : List RootedCorrection
deriving Repr, DecidableEq

private def isReplacementId
    (history : ActualValidityHistory Time)
    (id : ActualValidityFactId) : Bool :=
  history.corrections.any fun correction => decide (correction.replacement = id)

private def legacyRootFactIds
    (history : ActualValidityHistory Time) : List ActualValidityFactId :=
  (history.facts.filter fun fact => !(isReplacementId history fact.id)).map
    ActualValidityFact.id

private def rootedTargetRef?
    (history : ActualValidityHistory Time)
    (id : ActualValidityFactId) : Option RootedNodeRef := do
  let fact ← history.findFactById? id
  if isReplacementId history id then
    pure (.revision id)
  else
    pure (.root fact.event)

private def migrateCorrection?
    (history : ActualValidityHistory Time)
    (correction : ActualValidityCorrection) : Option RootedCorrection := do
  let target ← rootedTargetRef? history correction.target
  let _ ← history.findFactById? correction.replacement
  pure {
    id := correction.id
    target := target
    replacement := correction.replacement
  }

/--
Compress only an already-admitted V1 history.

The unique source fact of each correction path becomes the Event-rooted base and
loses its standalone fact identity. Every fact that is the replacement endpoint
of a correction remains an identified revision. Existing correction identity is
retained in this candidate; Observation 147 does not ask whether correction
identity can also be removed.
-/
def migrateAdmitted?
    (history : ActualValidityHistory Time) : Option (RootedHistory Time) := do
  if !actualValidityFrontierAdmissible history then
    none
  else
    let corrections ← history.corrections.mapM (migrateCorrection? history)
    let rootFacts := history.facts.filter fun fact => !(isReplacementId history fact.id)
    let revisionFacts := history.facts.filter fun fact => isReplacementId history fact.id
    pure {
      bases := rootFacts.map fun fact => { event := fact.event, validOn := fact.validOn }
      revisions := revisionFacts.map fun fact =>
        { id := fact.id, event := fact.event, validOn := fact.validOn }
      corrections := corrections
    }

private def rootedTargetUsed
    (history : RootedHistory Time)
    (target : RootedNodeRef) : Bool :=
  history.corrections.any fun correction => decide (correction.target = target)

private def rootedCurrentEntries
    (history : RootedHistory Time) : List (ActualValidity Time) :=
  let bases :=
    (history.bases.filter fun base =>
      !(rootedTargetUsed history (.root base.event))).map fun base =>
        { event := base.event, validOn := base.validOn }
  let revisions :=
    (history.revisions.filter fun revision =>
      !(rootedTargetUsed history (.revision revision.id))).map fun revision =>
        { event := revision.event, validOn := revision.validOn }
  bases ++ revisions

private def rootedCurrentMemory?
    (history : RootedHistory Time) : Option (ActualValidityMemory Time) :=
  ActualValidityMemory.ofEntries? (rootedCurrentEntries history)

private def legacyCurrentTime?
    (history : ActualValidityHistory Time)
    (event : EventId) : Option Time := do
  let memory ← admittedActualValidityMemory? history
  memory.findByEventId? event

private def migratedCurrentTime?
    (history : ActualValidityHistory Time)
    (event : EventId) : Option Time := do
  let rooted ← migrateAdmitted? history
  let memory ← rootedCurrentMemory? rooted
  memory.findByEventId? event

private def rootedMentionsFactId
    (history : RootedHistory Time)
    (id : ActualValidityFactId) : Bool :=
  (history.revisions.any fun revision => decide (revision.id = id)) ||
  (history.corrections.any fun correction =>
    decide (correction.target = .revision id) || decide (correction.replacement = id))

private def eventA : EventId := ⟨"event-a"⟩
private def eventB : EventId := ⟨"event-b"⟩

private def factA : ActualValidityFact Nat :=
  { id := ⟨"fact-a"⟩, event := eventA, validOn := 1 }

private def factB : ActualValidityFact Nat :=
  { id := ⟨"fact-b"⟩, event := eventA, validOn := 2 }

private def factA2 : ActualValidityFact Nat :=
  { id := ⟨"fact-a2"⟩, event := eventA, validOn := 1 }

private def factC : ActualValidityFact Nat :=
  { id := ⟨"fact-c"⟩, event := eventA, validOn := 3 }

private def factOther : ActualValidityFact Nat :=
  { id := ⟨"fact-other"⟩, event := eventB, validOn := 4 }

private def correctionAB : ActualValidityCorrection :=
  { id := ⟨"correction-ab"⟩, target := factA.id, replacement := factB.id }

private def correctionBA2 : ActualValidityCorrection :=
  { id := ⟨"correction-ba2"⟩, target := factB.id, replacement := factA2.id }

private def correctionAC : ActualValidityCorrection :=
  { id := ⟨"correction-ac"⟩, target := factA.id, replacement := factC.id }

private def uncorrected : ActualValidityHistory Nat :=
  { facts := [factA]
    factIdNodup := by simp [factA]
    corrections := []
    correctionIdNodup := by simp }

private def correctedOnce : ActualValidityHistory Nat :=
  { facts := [factA, factB]
    factIdNodup := by simp [factA, factB]
    corrections := [correctionAB]
    correctionIdNodup := by simp [correctionAB] }

private def returnedToOriginalDate : ActualValidityHistory Nat :=
  { facts := [factA, factB, factA2]
    factIdNodup := by simp [factA, factB, factA2]
    corrections := [correctionAB, correctionBA2]
    correctionIdNodup := by simp [correctionAB, correctionBA2] }

private def returnedToOriginalDateReordered : ActualValidityHistory Nat :=
  { facts := [factA2, factA, factB]
    factIdNodup := by simp [factA, factB, factA2]
    corrections := [correctionBA2, correctionAB]
    correctionIdNodup := by simp [correctionAB, correctionBA2] }

private def twoEvents : ActualValidityHistory Nat :=
  { facts := [factOther, factB, factA]
    factIdNodup := by simp [factA, factB, factOther]
    corrections := [correctionAB]
    correctionIdNodup := by simp [correctionAB] }

private def siblingConflict : ActualValidityHistory Nat :=
  { facts := [factA, factB, factC]
    factIdNodup := by simp [factA, factB, factC]
    corrections := [correctionAB, correctionAC]
    correctionIdNodup := by simp [correctionAB, correctionAC] }

private def danglingReplacement : ActualValidityHistory Nat :=
  { facts := [factA]
    factIdNodup := by simp [factA]
    corrections :=
      [{ id := ⟨"dangling"⟩, target := factA.id, replacement := ⟨"missing"⟩ }]
    correctionIdNodup := by simp }

private def crossEventReplacement : ActualValidityHistory Nat :=
  { facts := [factA, factOther]
    factIdNodup := by simp [factA, factOther]
    corrections :=
      [{ id := ⟨"cross"⟩, target := factA.id, replacement := factOther.id }]
    correctionIdNodup := by simp }

private def cyclic : ActualValidityHistory Nat :=
  { facts := [factA, factB]
    factIdNodup := by simp [factA, factB]
    corrections :=
      [ correctionAB,
        { id := ⟨"correction-ba"⟩, target := factB.id, replacement := factA.id } ]
    correctionIdNodup := by simp [correctionAB] }

/-- An uncorrected Event needs no retained temporal revision identity. -/
theorem uncorrected_drops_initial_fact_identity :
    legacyCurrentTime? uncorrected eventA = some 1 ∧
    migratedCurrentTime? uncorrected eventA = some 1 ∧
    match migrateAdmitted? uncorrected with
    | some rooted =>
        rooted.revisions = [] ∧
        rooted.corrections = [] ∧
        rootedMentionsFactId rooted factA.id = false
    | none => False := by
  decide

/-- One correction keeps only the replacement fact as a revision identity. -/
theorem one_correction_keeps_identity_on_demand :
    legacyCurrentTime? correctedOnce eventA = some 2 ∧
    migratedCurrentTime? correctedOnce eventA = some 2 ∧
    match migrateAdmitted? correctedOnce with
    | some rooted =>
        rootedMentionsFactId rooted factA.id = false ∧
        rootedMentionsFactId rooted factB.id = true ∧
        rooted.revisions.length = 1
    | none => False := by
  decide

/-- A -> B -> A remains representable because later A has distinct revision identity. -/
theorem return_to_original_date_preserved :
    legacyCurrentTime? returnedToOriginalDate eventA = some 1 ∧
    migratedCurrentTime? returnedToOriginalDate eventA = some 1 ∧
    match migrateAdmitted? returnedToOriginalDate with
    | some rooted =>
        rootedMentionsFactId rooted factA.id = false ∧
        rootedMentionsFactId rooted factB.id = true ∧
        rootedMentionsFactId rooted factA2.id = true ∧
        rooted.revisions.length = 2
    | none => False := by
  decide

/-- Root selection and the current answer do not depend on the specimen's storage order. -/
theorem root_selection_not_storage_order :
    legacyRootFactIds returnedToOriginalDate = [factA.id] ∧
    legacyRootFactIds returnedToOriginalDateReordered = [factA.id] ∧
    migratedCurrentTime? returnedToOriginalDate eventA =
      migratedCurrentTime? returnedToOriginalDateReordered eventA := by
  decide

/-- Independent Events remain independent across the compression. -/
theorem multiple_events_preserve_current_answers :
    legacyCurrentTime? twoEvents eventA = some 2 ∧
    migratedCurrentTime? twoEvents eventA = some 2 ∧
    legacyCurrentTime? twoEvents eventB = some 4 ∧
    migratedCurrentTime? twoEvents eventB = some 4 := by
  decide

/-- Existing fail-closed ambiguity is not laundered by the compressor. -/
theorem invalid_histories_refuse_before_compression :
    migrateAdmitted? siblingConflict = none ∧
    migrateAdmitted? danglingReplacement = none ∧
    migrateAdmitted? crossEventReplacement = none ∧
    migrateAdmitted? cyclic = none := by
  decide

/-! ## Physical rewrite boundary -/

inductive CanonicalValidityImage
  | v1
  | v2
  deriving Repr, DecidableEq

inductive AtomicReplacePhase
  | beforeRename
  | afterRename
  deriving Repr, DecidableEq

/--
The existing persistence primitive stages beside the canonical path and then
renames once. At the canonical path itself, a crash therefore exposes the old
complete image or the new complete image, never a mixed row generation.
-/
def canonicalImageAt : AtomicReplacePhase → CanonicalValidityImage
  | .beforeRename => .v1
  | .afterRename => .v2

theorem single_file_atomic_rewrite_has_no_mixed_generation
    (phase : AtomicReplacePhase) :
    canonicalImageAt phase = .v1 ∨ canonicalImageAt phase = .v2 := by
  cases phase <;> simp [canonicalImageAt]

end Loam.Observation147

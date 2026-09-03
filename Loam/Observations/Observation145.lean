import Loam.Application.BasisCut
import Loam.Application.ConsumptionInspection
import Loam.Core.EventDescription

namespace Loam.Observation145

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 145 — Destructive historical authority cutover

Observation 129's auxiliary-first argument covered only fresh relations whose
EventIds did not yet exist.  This model adds replacement of existing authority
streams and physical retirement of two old relation files.  It deliberately
models `ABSENT` separately from an empty file: the final correction and basis-cut
images are absent.

The qualified order is:

* replace ActualValidity, EventDescription, QuantityBasis, and source snapshot;
* replace EventMemory (the authority commit point);
* retire EventCorrection, then BasisCut;
* verify the complete new generation;
* publish the receipt last, then remove PREPARED.

ScheduledMemory and the balance-view are outside the mutation model.  A future
publisher should verify their fingerprint equality rather than rewrite them.
-/

inductive GenerationImage
  | oldGeneration
  | newGeneration
  | other
  deriving DecidableEq, Repr

inductive AddedImage
  | absent
  | candidate
  | other
  deriving DecidableEq, Repr

/-- Physical state of a stream whose final canonical state is absence. -/
inductive RetiredImage
  | oldRelation
  | absent
  | other
  deriving DecidableEq, Repr

inductive ReaderOutcome
  | oldCorrect
  | failClosed
  | newCorrect
  | falseReadable
  deriving DecidableEq, Repr

structure PersistentWorld where
  events : GenerationImage
  validities : GenerationImage
  descriptions : AddedImage
  basis : GenerationImage
  corrections : RetiredImage
  basisCut : RetiredImage
  snapshot : AddedImage
  preparedPresent : Bool
  receiptPresent : Bool
  approvalVerified : Bool
  finalVerified : Bool
  deriving DecidableEq, Repr

inductive PublicationPhase
  | initial
  | validityPublished
  | descriptionPublished
  | basisPublished
  | snapshotPublished
  | eventMemoryCommitted
  | correctionsRetired
  | basisCutRetired
  | finalVerified
  | receiptPublished
  | preparedRetired
  deriving DecidableEq, Repr

/-- The already-sealed PREPARED bundle is input; this observation does not create it. -/
def worldAt : PublicationPhase → PersistentWorld
  | .initial =>
      ⟨.oldGeneration, .oldGeneration, .absent, .oldGeneration,
       .oldRelation, .oldRelation, .absent, true, false, true, false⟩
  | .validityPublished =>
      ⟨.oldGeneration, .newGeneration, .absent, .oldGeneration,
       .oldRelation, .oldRelation, .absent, true, false, true, false⟩
  | .descriptionPublished =>
      ⟨.oldGeneration, .newGeneration, .candidate, .oldGeneration,
       .oldRelation, .oldRelation, .absent, true, false, true, false⟩
  | .basisPublished =>
      ⟨.oldGeneration, .newGeneration, .candidate, .newGeneration,
       .oldRelation, .oldRelation, .absent, true, false, true, false⟩
  | .snapshotPublished =>
      ⟨.oldGeneration, .newGeneration, .candidate, .newGeneration,
       .oldRelation, .oldRelation, .candidate, true, false, true, false⟩
  | .eventMemoryCommitted =>
      ⟨.newGeneration, .newGeneration, .candidate, .newGeneration,
       .oldRelation, .oldRelation, .candidate, true, false, true, false⟩
  | .correctionsRetired =>
      ⟨.newGeneration, .newGeneration, .candidate, .newGeneration,
       .absent, .oldRelation, .candidate, true, false, true, false⟩
  | .basisCutRetired =>
      ⟨.newGeneration, .newGeneration, .candidate, .newGeneration,
       .absent, .absent, .candidate, true, false, true, false⟩
  | .finalVerified =>
      ⟨.newGeneration, .newGeneration, .candidate, .newGeneration,
       .absent, .absent, .candidate, true, false, true, true⟩
  | .receiptPublished =>
      ⟨.newGeneration, .newGeneration, .candidate, .newGeneration,
       .absent, .absent, .candidate, true, true, true, true⟩
  | .preparedRetired =>
      ⟨.newGeneration, .newGeneration, .candidate, .newGeneration,
       .absent, .absent, .candidate, false, true, true, true⟩

/--
The combined safety outcome of readers relevant to this cut.  Only an exact old
or exact new stream generation is readable.  Every permitted cross-generation
shape has a production-backed refusal: missing validity before commit, or old
relation endpoints/roots after commit.  Any unrecognised tuple is classified as
a potentially false readable state rather than waved through.
-/
def readerOutcome (world : PersistentWorld) : ReaderOutcome :=
  match (world.events, world.validities, world.descriptions, world.basis,
      world.corrections, world.basisCut, world.snapshot) with
  | (.oldGeneration, .oldGeneration, .absent, .oldGeneration,
      .oldRelation, .oldRelation, .absent) => .oldCorrect
  | (.oldGeneration, .newGeneration, .absent, .oldGeneration,
      .oldRelation, .oldRelation, .absent) => .failClosed
  | (.oldGeneration, .newGeneration, .candidate, .oldGeneration,
      .oldRelation, .oldRelation, .absent) => .failClosed
  | (.oldGeneration, .newGeneration, .candidate, .newGeneration,
      .oldRelation, .oldRelation, .absent) => .failClosed
  | (.oldGeneration, .newGeneration, .candidate, .newGeneration,
      .oldRelation, .oldRelation, .candidate) => .failClosed
  | (.newGeneration, .newGeneration, .candidate, .newGeneration,
      .oldRelation, .oldRelation, .candidate) => .failClosed
  | (.newGeneration, .newGeneration, .candidate, .newGeneration,
      .absent, .oldRelation, .candidate) => .failClosed
  | (.newGeneration, .newGeneration, .candidate, .newGeneration,
      .absent, .absent, .candidate) => .newCorrect
  | _ => .falseReadable

/-! ## Production-semantics specimens -/

private def locus : LocusId := ⟨"synthetic-locus"⟩
private def measure : MeasureId := ⟨"synthetic-measure"⟩

private def event (id key : String) (quanta : Int) : Event :=
  { id := ⟨id⟩
    effects := [Effect.ofQuantity ⟨key⟩ locus measure (Quantity.ofQuanta quanta)]
    keyNodup := by simp }

private def oldEvent : Event := event "old-root" "old-effect" 5
private def newEvent : Event := event "new-root" "new-effect" 7
private def oldReplacement : Event := event "old-replacement" "old-replacement-effect" 9

private def oldEvents : EventMemory :=
  { events := [oldEvent], idNodup := by simp }

private def newEvents : EventMemory :=
  { events := [newEvent], idNodup := by simp }

private def oldCorrection : EventCorrection :=
  { id := ⟨"old-correction"⟩
    target := oldEvent.id
    replacement := oldReplacement.id }

private def oldCorrections : EventCorrectionMemory :=
  { corrections := [oldCorrection], idNodup := by simp }

private def noEventCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def oldBasis : QuantityBasis :=
  QuantityBasis.ofQuantity ⟨"old-basis"⟩ locus measure (Quantity.ofQuanta 10)

private def newBasis : QuantityBasis :=
  QuantityBasis.ofQuantity ⟨"new-basis"⟩ locus measure (Quantity.ofQuanta 20)

private def oldBases : QuantityBasisMemory :=
  { bases := [oldBasis], idNodup := by simp }

private def newBases : QuantityBasisMemory :=
  { bases := [newBasis], idNodup := by simp }

private def noBasisCorrections : QuantityBasisCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def oldCut : BasisCut :=
  [{ basisRoot := oldBasis.id, eventRoot := oldEvent.id }]

/--
Law 1: retiring the old BasisCut before EventMemory authority commit is not
inert.  Under the production BasisCut application, the retained cut gives 10
(the old Event is already reflected by the basis), while physical absence loads
as an empty cut and gives 15.  The tokens and values are public synthetic data.
-/
theorem early_retirement_not_inert :
    BasisCut.inspectCurrentQuantityWithBasisCut?
        oldEvents noEventCorrections oldBases noBasisCorrections oldCut locus measure =
      some (.current (Quantity.ofQuanta 10)) ∧
    BasisCut.inspectCurrentQuantityWithBasisCut?
        oldEvents noEventCorrections oldBases noBasisCorrections [] locus measure =
      some (.current (Quantity.ofQuanta 15)) := by
  decide

private def newValidities : ActualValidityMemory Nat :=
  { entries := [{ event := newEvent.id, validOn := 1 }], eventNodup := by simp }

/-- Replacing V0 by V1 first makes an E0 Consumption projection unavailable. -/
theorem precommit_new_validity_fails_closed
    (routing : RoutingHistory LocusId Nat)
    (purpose : PurposeId) :
    consumptionAtRecorded? oldEvents newValidities routing purpose measure = none := by
  have hMissing : newValidities.findByEventId? oldEvent.id = none := by decide
  simp [consumptionAtRecorded?, oldEvents, hMissing]

/-- Law 3: C0 cannot silently apply to E1 because both old endpoints are absent. -/
theorem postcommit_old_correction_fails_closed :
    inspectQuantity newEvents oldCorrections locus measure =
      .missingCorrectionEndpoint := by
  decide

/-- Law 4: K0 cannot silently apply to E1/B1 because both old roots are absent. -/
theorem postcommit_old_cut_fails_closed :
    BasisCut.inspectCurrentQuantityWithBasisCut?
        newEvents noEventCorrections newBases noBasisCorrections oldCut locus measure = none := by
  decide

/-! ## Reachability and restart qualification -/

/-- Law 2: every permitted auxiliary-first state is old-correct or unavailable. -/
theorem precommit_candidate_state_never_false_readable :
    readerOutcome (worldAt .initial) = .oldCorrect ∧
    readerOutcome (worldAt .validityPublished) = .failClosed ∧
    readerOutcome (worldAt .descriptionPublished) = .failClosed ∧
    readerOutcome (worldAt .basisPublished) = .failClosed ∧
    readerOutcome (worldAt .snapshotPublished) = .failClosed := by
  decide

/-- Law 5: full E1/V1/D1/B1/ABSENT-C/ABSENT-K/S1 is the new answer. -/
theorem final_generation_correct :
    readerOutcome (worldAt .basisCutRetired) = .newCorrect := by
  rfl

/-- No phase reachable in the qualified order exposes a mixed readable answer. -/
theorem reachable_state_never_false_readable (phase : PublicationPhase) :
    readerOutcome (worldAt phase) ≠ .falseReadable := by
  cases phase <;> decide

private def precommitShape (world : PersistentWorld) : Bool :=
  world = worldAt .initial ||
  world = worldAt .validityPublished ||
  world = worldAt .descriptionPublished ||
  world = worldAt .basisPublished ||
  world = worldAt .snapshotPublished

private def postcommitUnverifiedShape (world : PersistentWorld) : Bool :=
  world = worldAt .eventMemoryCommitted ||
  world = worldAt .correctionsRetired ||
  world = worldAt .basisCutRetired

private def fullNewGeneration (world : PersistentWorld) : Bool :=
  world.events = .newGeneration &&
  world.validities = .newGeneration &&
  world.descriptions = .candidate &&
  world.basis = .newGeneration &&
  world.corrections = .absent &&
  world.basisCut = .absent &&
  world.snapshot = .candidate

inductive RestartAction
  | ResumePreCommitPublication
  | ResumePostCommitRetirement
  | RecoverReceiptOnly
  | CleanupLeftoverPrepared
  | Complete
  | FailClosedInconsistent
  deriving DecidableEq, Repr

/--
Receipt-only recovery requires the verified full generation.  EventMemory = E1
alone merely enters post-commit retirement recovery.
-/
def planRestart (world : PersistentWorld) : RestartAction :=
  if !world.approvalVerified then
    .FailClosedInconsistent
  else if world.receiptPresent then
    if fullNewGeneration world && world.finalVerified then
      if world.preparedPresent then .CleanupLeftoverPrepared else .Complete
    else
      .FailClosedInconsistent
  else if !world.preparedPresent then
    .FailClosedInconsistent
  else if precommitShape world && !world.finalVerified then
    .ResumePreCommitPublication
  else if postcommitUnverifiedShape world && !world.finalVerified then
    .ResumePostCommitRetirement
  else if fullNewGeneration world && world.finalVerified then
    .RecoverReceiptOnly
  else
    .FailClosedInconsistent

/-- Law 6: E1 commit is not receipt-only evidence; retirement must resume. -/
theorem postcommit_restart_resumes_retirement :
    planRestart (worldAt .eventMemoryCommitted) = .ResumePostCommitRetirement := by
  decide

/-- The ten requested crash classes have distinct conservative restart plans. -/
theorem crash_case_plans :
    planRestart (worldAt .initial) = .ResumePreCommitPublication ∧
    planRestart (worldAt .validityPublished) = .ResumePreCommitPublication ∧
    planRestart (worldAt .descriptionPublished) = .ResumePreCommitPublication ∧
    planRestart (worldAt .basisPublished) = .ResumePreCommitPublication ∧
    planRestart (worldAt .snapshotPublished) = .ResumePreCommitPublication ∧
    planRestart (worldAt .eventMemoryCommitted) = .ResumePostCommitRetirement ∧
    planRestart (worldAt .correctionsRetired) = .ResumePostCommitRetirement ∧
    planRestart (worldAt .basisCutRetired) = .ResumePostCommitRetirement ∧
    planRestart (worldAt .finalVerified) = .RecoverReceiptOnly ∧
    planRestart (worldAt .receiptPublished) = .CleanupLeftoverPrepared := by
  decide

/-- Law 7: protocol publication of a receipt implies verified exact final state. -/
theorem receipt_requires_full_new_generation (phase : PublicationPhase)
    (hReceipt : (worldAt phase).receiptPresent = true) :
    fullNewGeneration (worldAt phase) = true ∧
    (worldAt phase).corrections = .absent ∧
    (worldAt phase).basisCut = .absent ∧
    (worldAt phase).finalVerified = true := by
  cases phase <;> simp_all [worldAt, fullNewGeneration]

/-- Law 8: an unrecognised mixed physical image is never automatically repaired. -/
theorem unknown_mixed_state_fails_closed :
    let unknown : PersistentWorld :=
      { worldAt .snapshotPublished with basisCut := .absent }
    readerOutcome unknown = .falseReadable ∧
      planRestart unknown = .FailClosedInconsistent := by
  decide

end Loam.Observation145

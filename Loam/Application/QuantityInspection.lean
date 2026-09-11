import Loam.Application.CorrectionFrontier
import Loam.Core.EventCorrectionMemory

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Quantity inspection

The first production application operation stays inside the existing Lean type
world. It consumes retained Practical Core memories directly and returns a
small household-facing answer vocabulary without promoting that vocabulary
into the Core.

The operation is deliberately read-only. It does not load files, publish data,
or claim that a recorded/effective quantity is a balance or universally current
state. Correction shapes that do not justify one current frontier remain
explicit refusals rather than acquiring representation-order authority.
-/

inductive QuantityInspectionAnswer where
  | recorded (quantity : Quantity)
  | singleCorrectionEffective (quantity : Quantity)
  | frontierEffective (quantity : Quantity)
  | missingCorrectionEndpoint
  | frontierRequired
deriving Repr, DecidableEq

/--
Historical arithmetic for one distinct correction, retained locally until its
full equivalence with the generic frontier projection is separately qualified.

Both endpoint Events remain recorded. The projection therefore removes the
superseded target contribution without adding the already-recorded replacement
again.
-/
private def singleCorrectionQuantity?
    (memory : EventMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let projected ← EventCorrection.project? memory correction
  let recorded := EventMemory.quantityAtRecorded memory locus measure
  return recorded - Event.quantityAt projected.original locus measure

/--
Inspect one explicit locus/measure coordinate using retained Core facts and the
qualified correction projections owned by this Application boundary.

Zero corrections exposes the recorded projection. Exactly one distinct,
closed correction keeps the previously qualified arithmetic. A singleton
self-correction is one cycle and therefore requires a valid frontier rather
than being treated as a quantity-preserving exception. Two or more corrections
expose a frontier quantity only when they form closed, non-branching,
non-merging, acyclic correction paths.
-/
def inspectQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId) : QuantityInspectionAnswer :=
  match corrections.corrections with
  | [] =>
      .recorded (EventMemory.quantityAtRecorded events locus measure)
  | [correction] =>
      if correction.target = correction.replacement then
        .frontierRequired
      else
        match singleCorrectionQuantity? events correction locus measure with
        | some quantity => .singleCorrectionEffective quantity
        | none => .missingCorrectionEndpoint
  | _ =>
      match quantityAtCorrectionFrontier? events corrections locus measure with
      | some quantity => .frontierEffective quantity
      | none => .frontierRequired

/-- With no correction facts, expose exactly the Core recorded projection. -/
theorem inspectQuantity_noCorrections
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = []) :
    inspectQuantity events corrections locus measure =
      .recorded (EventMemory.quantityAtRecorded events locus measure) := by
  simp [inspectQuantity, hCorrections]

/-- A singleton self-correction is refused as one correction cycle. -/
@[simp] theorem inspectQuantity_singleSelf
    (events : EventMemory)
    (id : EventId)
    (locus : LocusId)
    (measure : MeasureId) :
    inspectQuantity
      events
      { corrections := [{ target := id, replacement := id }]
        idNodup := by simp }
      locus measure = .frontierRequired := by
  simp [inspectQuantity]

/-- One distinct closed correction exposes exactly the local singleton projection. -/
private theorem inspectQuantity_singleEffective
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (quantity : Quantity)
    (hCorrections : corrections.corrections = [correction])
    (hDistinct : correction.target ≠ correction.replacement)
    (hEffective :
      singleCorrectionQuantity? events correction locus measure = some quantity) :
    inspectQuantity events corrections locus measure =
      .singleCorrectionEffective quantity := by
  simp [inspectQuantity, hCorrections, hDistinct, hEffective]

/-- One distinct correction with an unavailable endpoint remains an explicit refusal. -/
private theorem inspectQuantity_singleMissing
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = [correction])
    (hDistinct : correction.target ≠ correction.replacement)
    (hMissing :
      singleCorrectionQuantity? events correction locus measure = none) :
    inspectQuantity events corrections locus measure = .missingCorrectionEndpoint := by
  simp [inspectQuantity, hCorrections, hDistinct, hMissing]

/-- A qualified multi-correction frontier exposes exactly its derived quantity. -/
theorem inspectQuantity_multipleEffective
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (first second : EventCorrection)
    (rest : List EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (quantity : Quantity)
    (hCorrections : corrections.corrections = first :: second :: rest)
    (hEffective :
      quantityAtCorrectionFrontier? events corrections locus measure = some quantity) :
    inspectQuantity events corrections locus measure = .frontierEffective quantity := by
  simp [inspectQuantity, hCorrections, hEffective]

/-- An unsupported multi-correction shape remains an explicit frontier refusal. -/
theorem inspectQuantity_multipleRequired
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (first second : EventCorrection)
    (rest : List EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = first :: second :: rest)
    (hMissing :
      quantityAtCorrectionFrontier? events corrections locus measure = none) :
    inspectQuantity events corrections locus measure = .frontierRequired := by
  simp [inspectQuantity, hCorrections, hMissing]

end Loam.Application

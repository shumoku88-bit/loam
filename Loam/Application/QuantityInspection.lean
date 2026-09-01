import Loam.Core.CorrectionQuantity
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
choose a correction frontier, or claim that a recorded/effective quantity is a
balance or universally current state.
-/

inductive QuantityInspectionAnswer where
  | recorded (quantity : Quantity)
  | singleCorrectionEffective (quantity : Quantity)
  | missingCorrectionEndpoint
  | frontierRequired
deriving Repr, DecidableEq

/--
Inspect one explicit locus/measure coordinate using only the correction
semantics already retained by the Practical Core.

Zero corrections exposes the recorded projection. Exactly one correction may
expose the existing single-correction effective projection. A missing endpoint
is an explicit refusal. Two or more correction facts require a frontier rather
than an arbitrary winner.
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
      match EventCorrection.quantityAtEffective? events correction locus measure with
      | some quantity => .singleCorrectionEffective quantity
      | none => .missingCorrectionEndpoint
  | _ =>
      .frontierRequired

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

/-- One closed correction exposes exactly the existing Core effective projection. -/
theorem inspectQuantity_singleEffective
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (quantity : Quantity)
    (hCorrections : corrections.corrections = [correction])
    (hEffective :
      EventCorrection.quantityAtEffective? events correction locus measure = some quantity) :
    inspectQuantity events corrections locus measure =
      .singleCorrectionEffective quantity := by
  simp [inspectQuantity, hCorrections, hEffective]

/-- One correction with an unavailable endpoint remains an explicit refusal. -/
theorem inspectQuantity_singleMissing
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = [correction])
    (hMissing :
      EventCorrection.quantityAtEffective? events correction locus measure = none) :
    inspectQuantity events corrections locus measure = .missingCorrectionEndpoint := by
  simp [inspectQuantity, hCorrections, hMissing]

/-- Two or more correction facts refuse to invent a current frontier. -/
theorem inspectQuantity_multiple
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (first second : EventCorrection)
    (rest : List EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = first :: second :: rest) :
    inspectQuantity events corrections locus measure = .frontierRequired := by
  simp [inspectQuantity, hCorrections]

end Loam.Application

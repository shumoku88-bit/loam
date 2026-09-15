import Loam.Application.CorrectionFrontier
import Loam.Application.QuantityInspection

namespace Experiments.Observation245

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
Observation 245 probes the smallest production reuse seam suggested by
Observation 244.

The candidate support fact does not retain a second quantity. It names one
already-retained Event as the admitted opening witness for one coordinate.
Current quantity arithmetic remains owned by `inspectQuantity`.
-/

structure OpeningSupport where
  coordinate : EffectCoordinate
  openingEvent : EventId
  deriving Repr, DecidableEq

private def eventContainsCoordinate
    (event : Event) (coordinate : EffectCoordinate) : Bool :=
  event.effects.any fun effect => decide (effect.coordinate = coordinate)

/--
A support witness is usable only when the named opening Event survives on the
ordinary correction frontier and actually contains the named coordinate.
The witness supplies the opening meaning; this function does not infer that
meaning from sign, description, date, role, or Event list position.
-/
def supportValid
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (support : OpeningSupport) : Bool :=
  match correctionFrontierMemory? events corrections with
  | none => false
  | some frontier =>
      match frontier.findById? support.openingEvent with
      | none => false
      | some event => eventContainsCoordinate event support.coordinate

/--
Gate the existing correction-aware quantity inspection with one optional opening
support witness. No quantity arithmetic is implemented here.
-/
def inspectOpeningSupportedQuantity?
    (support : Option OpeningSupport)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) : Option QuantityInspectionAnswer :=
  match support with
  | none => none
  | some witness =>
      if witness.coordinate = coordinate && supportValid events corrections witness then
        some (inspectQuantity events corrections coordinate.locus coordinate.measure)
      else
        none

/-- A valid support witness delegates exactly to the existing quantity engine. -/
theorem inspectOpeningSupportedQuantity?_delegates
    (support : OpeningSupport)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate)
    (hCoordinate : support.coordinate = coordinate)
    (hValid : supportValid events corrections support = true) :
    inspectOpeningSupportedQuantity? (some support) events corrections coordinate =
      some (inspectQuantity events corrections coordinate.locus coordinate.measure) := by
  simp [inspectOpeningSupportedQuantity?, hCoordinate, hValid]

private def debt : LocusId := ⟨"debt"⟩
private def jpy : MeasureId := ⟨"jpy"⟩
private def coordinate : EffectCoordinate := ⟨debt, jpy⟩

private def eventAt (token : String) (quantity : Int) : Event :=
  { id := ⟨token⟩
    effects := [Effect.ofAnonymousQuantity debt jpy (Quantity.ofQuanta quantity)]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def opening : Event := eventAt "opening" (-100)
private def repayment : Event := eventAt "repayment" 20
private def correctedRepayment : Event := eventAt "repayment-v2" 30
private def replacementOpening : Event := eventAt "opening-v2" (-90)

private def support : OpeningSupport :=
  { coordinate := coordinate, openingEvent := opening.id }

private def noCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def recordedEvents : EventMemory :=
  { events := [opening, repayment]
    idNodup := by simp [opening, repayment, eventAt] }

private def correctedEvents : EventMemory :=
  { events := [opening, repayment, correctedRepayment]
    idNodup := by simp [opening, repayment, correctedRepayment, eventAt] }

private def repaymentCorrection : EventCorrectionMemory :=
  { corrections := [{ target := repayment.id, replacement := correctedRepayment.id }]
    idNodup := by simp }

private def zeroNetEvents : EventMemory :=
  { events := [eventAt "borrow" (-5), eventAt "repay" 5]
    idNodup := by simp [eventAt] }

private def correctedOpeningEvents : EventMemory :=
  { events := [opening, replacementOpening, repayment]
    idNodup := by simp [opening, replacementOpening, repayment, eventAt] }

private def openingCorrection : EventCorrectionMemory :=
  { corrections := [{ target := opening.id, replacement := replacementOpening.id }]
    idNodup := by simp }

private def answerQuanta? : QuantityInspectionAnswer → Option Int
  | .quantity quantity => some quantity.quanta
  | .missingCorrectionEndpoint => none
  | .frontierRequired => none

private def require (label : String) (ok : Bool) : IO Unit := do
  if ok then
    IO.println (label ++ ": PASS")
  else
    throw <| IO.userError (label ++ ": FAIL")

def run : IO Unit := do
  let recorded :=
    inspectOpeningSupportedQuantity? (some support) recordedEvents noCorrections coordinate
  require "opening Event reuses recorded quantity"
    (recorded.bind answerQuanta? == some (-80))

  let corrected :=
    inspectOpeningSupportedQuantity? (some support) correctedEvents repaymentCorrection coordinate
  require "ordinary Event correction remains authoritative"
    (corrected.bind answerQuanta? == some (-70))

  let unsupported :=
    inspectOpeningSupportedQuantity? none zeroNetEvents noCorrections coordinate
  require "zero net activity does not invent support" unsupported.isNone

  let wrongCoordinate : OpeningSupport :=
    { coordinate := ⟨⟨"other"⟩, jpy⟩, openingEvent := opening.id }
  require "support must name the inspected coordinate"
    (inspectOpeningSupportedQuantity?
      (some wrongCoordinate) recordedEvents noCorrections coordinate).isNone

  require "superseded opening witness fails closed"
    (inspectOpeningSupportedQuantity?
      (some support) correctedOpeningEvents openingCorrection coordinate).isNone

  let replacementSupport : OpeningSupport :=
    { coordinate := coordinate, openingEvent := replacementOpening.id }
  let replacementAnswer :=
    inspectOpeningSupportedQuantity?
      (some replacementSupport) correctedOpeningEvents openingCorrection coordinate
  require "republished witness can follow ordinary correction frontier"
    (replacementAnswer.bind answerQuanta? == some (-70))

end Experiments.Observation245

def main : IO Unit := Experiments.Observation245.run

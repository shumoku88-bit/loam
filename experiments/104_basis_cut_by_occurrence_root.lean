import Loam.Application.CorrectionFrontier

namespace Loam.Experiments.Observation104

open Loam.Core
open Loam.Application

set_option autoImplicit false

/--
Experiment-local evidence that one quantity basis already reflects the occurrence
identified by each listed correction-root Event.

The list is intentionally not chronology. It names only the finite occurrences
already folded into one basis observation.
-/
abbrev BasisCut := List EventId

private def findByTarget? : List EventCorrection → EventId → Option EventCorrection
  | [], _ => none
  | correction :: rest, id =>
      if correction.target = id then
        some correction
      else
        findByTarget? rest id

private def isReplacement : List EventCorrection → EventId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.replacement = id then
        true
      else
        isReplacement rest id

private def terminalFrom?
    (corrections : List EventCorrection)
    (current : EventId) : Nat → Option EventId
  | 0 => none
  | fuel + 1 =>
      match findByTarget? corrections current with
      | none => some current
      | some correction => terminalFrom? corrections correction.replacement fuel

/--
Resolve one cut root to the terminal Event currently representing that same
correction path. A cut entry must name a remembered root, not an interior or
terminal replacement.
-/
private def terminalForRoot?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (root : EventId) : Option EventId := do
  let _ ← EventMemory.findById? events root
  if isReplacement corrections.corrections root then
    none
  else
    terminalFrom? corrections.corrections root (corrections.corrections.length + 1)

private def cutTerminals?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : BasisCut → Option (List EventId)
  | [] => some []
  | root :: rest => do
      let terminal ← terminalForRoot? events corrections root
      let later ← cutTerminals? events corrections rest
      return terminal :: later

private def quantityAfterExcludedTerminals?
    (frontier : EventMemory)
    (excluded : List EventId)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let retained ← EventMemory.ofEvents? <|
    frontier.events.filter fun event => !(decide (event.id ∈ excluded))
  return EventMemory.quantityAtRecorded retained locus measure

/--
Naive candidate: remember the terminal Event identity that happened to be
current when the basis was taken.
-/
def currentAfterTerminalCut?
    (basis : Quantity)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (includedTerminals : List EventId)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let frontier ← correctionFrontierMemory? events corrections
  let later ← quantityAfterExcludedTerminals? frontier includedTerminals locus measure
  return Quantity.ofQuanta (basis.quanta + later.quanta)

/--
Root candidate: remember the occurrence root already reflected by the basis,
then resolve that root through the current correction path before excluding the
terminal interpretation from the post-basis quantity.
-/
def currentAfterRootCut?
    (basis : Quantity)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (cut : BasisCut)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let frontier ← correctionFrontierMemory? events corrections
  let excluded ← cutTerminals? events corrections cut
  let later ← quantityAfterExcludedTerminals? frontier excluded locus measure
  return Quantity.ofQuanta (basis.quanta + later.quanta)

private def wallet : LocusId := ⟨"wallet"⟩
private def unit : MeasureId := ⟨"unit"⟩

private def effect (key : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ wallet unit (Quantity.ofQuanta quanta)

private def event (id key : String) (quanta : Int) : Event :=
  { id := ⟨id⟩
    effects := [effect key quanta]
    keyNodup := by simp }

private def preV1 : Event := event "pre-v1" "pre-v1-effect" (-10)
private def preV2 : Event := event "pre-v2" "pre-v2-effect" (-12)
private def preV3 : Event := event "pre-v3" "pre-v3-effect" (-9)
private def later : Event := event "later" "later-effect" (-7)

private def correction (id target replacement : String) : EventCorrection :=
  { id := ⟨id⟩
    target := ⟨target⟩
    replacement := ⟨replacement⟩ }

private def c1 : EventCorrection := correction "c1" "pre-v1" "pre-v2"
private def c2 : EventCorrection := correction "c2" "pre-v2" "pre-v3"

private def eventsV1 : EventMemory :=
  { events := [preV1, preV2, later]
    idNodup := by decide }

private def eventsV2 : EventMemory :=
  { events := [preV1, preV2, preV3, later]
    idNodup := by decide }

private def correctionsV1 : EventCorrectionMemory :=
  { corrections := [c1]
    idNodup := by decide }

private def correctionsV2 : EventCorrectionMemory :=
  { corrections := [c1, c2]
    idNodup := by decide }

private def correctionsV2Reversed : EventCorrectionMemory :=
  { corrections := [c2, c1]
    idNodup := by decide }

private def basis : Quantity := Quantity.ofQuanta 100
private def rootCut : BasisCut := [preV1.id]
private def terminalCutV1 : List EventId := [preV2.id]

/-- Before another correction, a terminal-id cut happens to produce the desired answer. -/
example :
    currentAfterTerminalCut?
        basis eventsV1 correctionsV1 terminalCutV1 wallet unit =
      some (Quantity.ofQuanta 93) := by
  decide

/-- Extending the same correction path makes that remembered terminal stale. -/
example :
    currentAfterTerminalCut?
        basis eventsV2 correctionsV2 terminalCutV1 wallet unit =
      some (Quantity.ofQuanta 84) := by
  decide

/-- The root cut excludes the same pre-basis occurrence under the first correction. -/
example :
    currentAfterRootCut?
        basis eventsV1 correctionsV1 rootCut wallet unit =
      some (Quantity.ofQuanta 93) := by
  decide

/-- Extending the correction path does not require changing the cut root. -/
example :
    currentAfterRootCut?
        basis eventsV2 correctionsV2 rootCut wallet unit =
      some (Quantity.ofQuanta 93) := by
  decide

/-- Correction-memory representation order does not change the root-cut answer. -/
example :
    currentAfterRootCut?
        basis eventsV2 correctionsV2Reversed rootCut wallet unit =
      currentAfterRootCut?
        basis eventsV2 correctionsV2 rootCut wallet unit := by
  decide

/-- A replacement identity is not silently accepted as an occurrence root. -/
example :
    currentAfterRootCut?
        basis eventsV2 correctionsV2 [preV2.id] wallet unit = none := by
  decide

end Loam.Experiments.Observation104

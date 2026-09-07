import Loam.Application.BasisCut

namespace Loam.Experiments.Observation222

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
Observation 222 asks whether `BasisCut` is an independent quantity primitive or a
repair for one specific overlap shape:

* a starting-state observation already contains one occurrence; and
* the same occurrence is also retained in the selected Event world.

The probe deliberately distinguishes a one-time arithmetic rewrite from a stable
semantic normalization.
-/

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

private def laterOnly : EventMemory :=
  { events := [later]
    idNodup := by decide }

private def correctionsV1 : EventCorrectionMemory :=
  { corrections := [c1]
    idNodup := by decide }

private def correctionsV2 : EventCorrectionMemory :=
  { corrections := [c1, c2]
    idNodup := by decide }

private def noEventCorrections : EventCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def basis : QuantityBasis :=
  QuantityBasis.ofQuantity ⟨"basis-root"⟩ wallet unit (Quantity.ofQuanta 100)

private def bases : QuantityBasisMemory :=
  { bases := [basis]
    idNodup := by decide }

private def noBasisCorrections : QuantityBasisCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def cut : BasisCut :=
  [{ basisRoot := basis.id, eventRoot := preV1.id }]

private def noCut : BasisCut := []

private def addQuantities (left right : Quantity) : Quantity :=
  Quantity.ofQuanta (left.quanta + right.quanta)

/--
Cut-free origin read used only by this experiment.  It retains the same
correction-aware Event quantity semantics while assuming the origin and selected
Event world do not overlap.
-/
private def currentFromOrigin?
    (origin : Quantity)
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option Quantity :=
  match inspectQuantity events corrections wallet unit with
  | .recorded quantity => some (addQuantities origin quantity)
  | .singleCorrectionEffective quantity => some (addQuantities origin quantity)
  | .frontierEffective quantity => some (addQuantities origin quantity)
  | .missingCorrectionEndpoint => none
  | .frontierRequired => none

/--
The overlapping representation double-counts the pre-snapshot occurrence when the
cut is absent.
-/
example :
    BasisCut.inspectCurrentQuantityWithBasisCut?
        eventsV1 correctionsV1 bases noBasisCorrections noCut wallet unit =
      some (.current (Quantity.ofQuanta 81)) := by
  decide

/-- The production cut repairs exactly that overlap. -/
example :
    BasisCut.inspectCurrentQuantityWithBasisCut?
        eventsV1 correctionsV1 bases noBasisCorrections cut wallet unit =
      some (.current (Quantity.ofQuanta 93)) := by
  decide

/--
One cut-free normal form keeps the observed snapshot after the pre occurrence and
retains only genuinely post-snapshot selected Events.
-/
example :
    currentFromOrigin? (Quantity.ofQuanta 100) laterOnly noEventCorrections =
      some (Quantity.ofQuanta 93) := by
  decide

/--
Another cut-free normal form moves the origin before the retained historical
occurrence and includes that occurrence in the selected Event world.
-/
example :
    currentFromOrigin? (Quantity.ofQuanta 112) eventsV1 correctionsV1 =
      some (Quantity.ofQuanta 93) := by
  decide

/--
The root cut is stable when the already-reflected occurrence receives another
Event correction: the observed post-occurrence snapshot remains the anchor.
-/
example :
    BasisCut.inspectCurrentQuantityWithBasisCut?
        eventsV2 correctionsV2 bases noBasisCorrections cut wallet unit =
      some (.current (Quantity.ofQuanta 93)) := by
  decide

/--
A one-time algebraic absorption of the old cut into a pre-occurrence origin is NOT
stable under that later correction.  Keeping the old origin 112 now yields 96.
-/
example :
    currentFromOrigin? (Quantity.ofQuanta 112) eventsV2 correctionsV2 =
      some (Quantity.ofQuanta 96) := by
  decide

/--
To preserve the old post-occurrence snapshot semantics after the correction, the
pre-occurrence origin would have to be reconstructed/rebased from 112 to 109.
-/
example :
    currentFromOrigin? (Quantity.ofQuanta 109) eventsV2 correctionsV2 =
      some (Quantity.ofQuanta 93) := by
  decide

/-- Static cut absorption and durable non-overlap reconstruction are observably different. -/
example :
    currentFromOrigin? (Quantity.ofQuanta 112) eventsV2 correctionsV2 ≠
      currentFromOrigin? (Quantity.ofQuanta 109) eventsV2 correctionsV2 := by
  decide

end Loam.Experiments.Observation222

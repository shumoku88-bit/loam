import Init.Data.List.Perm
import Loam.Core.Event

namespace Observation233

open Loam.Core

set_option autoImplicit false

/-!
Observation 233 asks for the smallest safe Transactions-Flow Matrix over neutral
Core Event evidence.

The candidate is an incidence matrix rather than a Locus-to-Locus flow graph:

  row    = EffectCoordinate = (LocusId, MeasureId)
  column = Event
  cell   = exact signed Quantity projected from that Event at that coordinate

No source/destination edge is represented. Per-measure column residuals are
observations, not a global balance requirement: practical Movement admission may
require balance while neutral Core Events do not.
-/

/-- Exact matrix cell at one explicit coordinate and Event. -/
def cell (coordinate : EffectCoordinate) (event : Event) : Quantity :=
  Event.quantityAt event coordinate.locus coordinate.measure

/-- Net change at one coordinate across the selected Event columns. -/
def rowTotal (coordinate : EffectCoordinate) (events : List Event) : Quantity :=
  Quantity.ofQuanta <|
    events.foldl (fun total event => total + (cell coordinate event).quanta) 0

/--
Observed residual of one Event inside one Measure only.

A zero residual witnesses conservation for that Event/Measure column. A nonzero
residual remains visible rather than making the matrix reject the Event.
-/
def measureResidual (measure : MeasureId) (event : Event) : Quantity :=
  Quantity.ofQuanta <|
    event.effects.foldl
      (fun total effect =>
        if effect.measure = measure then total + effect.quantity.quanta else total)
      0

/-- Matrix cells inherit Core's representation-order independence. -/
theorem cell_perm
    (coordinate : EffectCoordinate)
    (left right : Event)
    (hPerm : left.effects.Perm right.effects) :
    cell coordinate left = cell coordinate right := by
  exact Event.quantityAt_perm left right hPerm coordinate.locus coordinate.measure

private def jpy : MeasureId := ⟨"jpy"⟩
private def point : MeasureId := ⟨"point"⟩

private def cashJpy : EffectCoordinate := ⟨⟨"cash"⟩, jpy⟩
private def foodJpy : EffectCoordinate := ⟨⟨"food"⟩, jpy⟩
private def bookJpy : EffectCoordinate := ⟨⟨"book"⟩, jpy⟩
private def incomeJpy : EffectCoordinate := ⟨⟨"income"⟩, jpy⟩
private def pointCoordinate : EffectCoordinate := ⟨⟨"point"⟩, point⟩

/-- A three-posting balanced Event. No pairing among the three Effects is stored. -/
private def splitEvent : Event := {
  id := ⟨"split"⟩
  effects := [
    Effect.ofQuantity ⟨"split-cash"⟩ ⟨"cash"⟩ jpy (Quantity.ofQuanta (-1000)),
    Effect.ofQuantity ⟨"split-food"⟩ ⟨"food"⟩ jpy (Quantity.ofQuanta 600),
    Effect.ofQuantity ⟨"split-book"⟩ ⟨"book"⟩ jpy (Quantity.ofQuanta 400)]
  keyNodup := by decide
}

/-- A neutral Core Event that is intentionally not balanced. -/
private def unbalancedEvent : Event := {
  id := ⟨"unbalanced"⟩
  effects := [
    Effect.ofQuantity ⟨"unbalanced-income"⟩ ⟨"income"⟩ jpy
      (Quantity.ofQuanta 500)]
  keyNodup := by decide
}

/-- One Event carrying independent JPY and point Measures. -/
private def mixedMeasureEvent : Event := {
  id := ⟨"mixed"⟩
  effects := [
    Effect.ofQuantity ⟨"mixed-cash"⟩ ⟨"cash"⟩ jpy (Quantity.ofQuanta (-100)),
    Effect.ofQuantity ⟨"mixed-food"⟩ ⟨"food"⟩ jpy (Quantity.ofQuanta 100),
    Effect.ofQuantity ⟨"mixed-point"⟩ ⟨"point"⟩ point (Quantity.ofQuanta 3)]
  keyNodup := by decide
}

/-- Distinct Effect identity may aggregate at one matrix coordinate. -/
private def repeatedCoordinateEvent : Event := {
  id := ⟨"repeated-coordinate"⟩
  effects := [
    Effect.ofQuantity ⟨"repeat-cash"⟩ ⟨"cash"⟩ jpy (Quantity.ofQuanta (-500)),
    Effect.ofQuantity ⟨"repeat-food-a"⟩ ⟨"food"⟩ jpy (Quantity.ofQuanta 200),
    Effect.ofQuantity ⟨"repeat-food-b"⟩ ⟨"food"⟩ jpy (Quantity.ofQuanta 300)]
  keyNodup := by decide
}

/-!
## Selected witness matrix

The following checks mechanically pin the intended semantics:

                 split   unbalanced   mixed   repeated
cash/jpy         -1000       0        -100      -500
food/jpy           600       0         100       500
book/jpy           400       0           0         0
income/jpy           0     500           0         0
point/point           0       0           3         0

No cell says which negative Effect funded which positive Effect.
-/

example : (cell cashJpy splitEvent).quanta = -1000 := by decide
example : (cell foodJpy splitEvent).quanta = 600 := by decide
example : (cell bookJpy splitEvent).quanta = 400 := by decide
example : (cell incomeJpy unbalancedEvent).quanta = 500 := by decide
example : (cell pointCoordinate mixedMeasureEvent).quanta = 3 := by decide

/-- Same-coordinate Effects add without collapsing their independent Effect keys. -/
example : (cell foodJpy repeatedCoordinateEvent).quanta = 500 := by decide

/-- Coordinate row totals expose exact selected-period net change. -/
example :
    (rowTotal foodJpy
      [splitEvent, unbalancedEvent, mixedMeasureEvent, repeatedCoordinateEvent]).quanta =
      1200 := by decide

/-- Conservation is observed where it actually holds. -/
example : (measureResidual jpy splitEvent).quanta = 0 := by decide
example : (measureResidual jpy mixedMeasureEvent).quanta = 0 := by decide
example : (measureResidual jpy repeatedCoordinateEvent).quanta = 0 := by decide

/-- Neutral Core evidence is retained even when one Event/Measure residual is nonzero. -/
example : (measureResidual jpy unbalancedEvent).quanta = 500 := by decide

/-- Measures are not silently added together. -/
example : (measureResidual point mixedMeasureEvent).quanta = 3 := by decide
example : (measureResidual jpy mixedMeasureEvent).quanta = 0 := by decide

end Observation233

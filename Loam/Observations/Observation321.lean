import Loam.TransactionsFlowReview
import Lean.Elab.Tactic.Omega

namespace Loam.Observation321

open Loam.Core

set_option autoImplicit false

/-!
# Observation 321 — General Transactions-Flow additive correspondence laws

Observation 320 established a finite executable witness for the candidate
Transactions-Flow sparse-summary factorization.

This observation asks two smaller universal questions before any production
index is considered:

1. Is current `rowTotal` always exactly `rowActivity.net`?
2. Is an Event-local left fold over one EffectCoordinate always exactly the
   current `Event.quantityAt` answer?

Both theorems quantify over arbitrary current in-memory values. They are not
fixture checks.
-/

/-! ## 1. Row total is exactly row activity net -/

private def selectedQuanta
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) : Int :=
  (Event.quantityAt
    column.event coordinate.locus coordinate.measure).quanta

private def totalStep
    (coordinate : EffectCoordinate)
    (total : Int)
    (column : Loam.TransactionsFlowReview.Column) : Int :=
  total + selectedQuanta coordinate column

private def activityStep
    (coordinate : EffectCoordinate)
    (state : Int × Int × Nat)
    (column : Loam.TransactionsFlowReview.Column) : Int × Int × Nat :=
  let quantity := selectedQuanta coordinate column
  if quantity > 0 then
    (state.1 + quantity, state.2.1, state.2.2 + 1)
  else if quantity < 0 then
    (state.1, state.2.1 + quantity, state.2.2 + 1)
  else
    state

/--
The invariant needed by the row proof: if the scalar accumulator is equal to
positive + negative before scanning a suffix of columns, it remains equal to
the sum of the two activity accumulators after scanning that suffix.

The contributor count is deliberately arbitrary because it does not affect the
net quantity invariant.
-/
private theorem fold_total_eq_activity_sum
    (columns : List Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate)
    (total positive negative : Int)
    (active : Nat)
    (hInvariant : total = positive + negative) :
    columns.foldl (totalStep coordinate) total =
      let accumulated :=
        columns.foldl (activityStep coordinate) (positive, negative, active)
      accumulated.1 + accumulated.2.1 := by
  induction columns generalizing total positive negative active with
  | nil =>
      simpa using hInvariant
  | cons column rest ih =>
      simp only [List.foldl_cons]
      let quantity := selectedQuanta coordinate column
      by_cases hPositive : quantity > 0
      · apply ih
        simp [totalStep, activityStep, quantity, hPositive, hInvariant,
          Int.add_assoc, Int.add_comm, Int.add_left_comm]
      · by_cases hNegative : quantity < 0
        · apply ih
          simp [totalStep, activityStep, quantity, hPositive, hNegative,
            hInvariant, Int.add_assoc, Int.add_comm, Int.add_left_comm]
        · have hZero : quantity = 0 := by
            omega
          apply ih
          simp [totalStep, activityStep, quantity, hPositive, hNegative, hZero,
            hInvariant]

/--
The scalar row total quanta equal the sum of the two retained activity
partitions for every Snapshot and coordinate.
-/
theorem rowTotal_quanta_eq_activity_parts
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    (Loam.TransactionsFlowReview.rowTotal snapshot coordinate).quanta =
      (Loam.TransactionsFlowReview.rowActivity snapshot coordinate).positive.quanta +
      (Loam.TransactionsFlowReview.rowActivity snapshot coordinate).negative.quanta := by
  change
    snapshot.columns.foldl (totalStep coordinate) 0 =
      let accumulated :=
        snapshot.columns.foldl (activityStep coordinate) (0, 0, 0)
      accumulated.1 + accumulated.2.1
  exact fold_total_eq_activity_sum
    snapshot.columns coordinate 0 0 0 0 (by rfl)

/--
For every Transactions-Flow Snapshot and every coordinate, the separately
implemented current reads are the same quantity observation:

    rowTotal = rowActivity.net

This is stronger than the finite Observation 320 witness and removes one
possible independent numeric meaning from the design map.
-/
theorem rowTotal_eq_rowActivity_net
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    Loam.TransactionsFlowReview.rowTotal snapshot coordinate =
      (Loam.TransactionsFlowReview.rowActivity snapshot coordinate).net := by
  rw [← Quantity.ofQuanta_quanta
      (Loam.TransactionsFlowReview.rowTotal snapshot coordinate)]
  rw [← Quantity.ofQuanta_quanta
      ((Loam.TransactionsFlowReview.rowActivity snapshot coordinate).net)]
  apply congrArg Quantity.ofQuanta
  simpa [Loam.TransactionsFlowReview.RowActivity.net] using
    rowTotal_quanta_eq_activity_parts snapshot coordinate

/-! ## 2. Event-local coordinate fold is exactly Event.quantityAt -/

private def cellFoldlStep
    (coordinate : EffectCoordinate)
    (total : Int)
    (effect : Effect) : Int :=
  if effect.coordinate = coordinate then
    total + effect.quantity.quanta
  else
    total

private def cellFoldrStep
    (coordinate : EffectCoordinate)
    (effect : Effect)
    (total : Int) : Int :=
  if effect.coordinate = coordinate then
    effect.quantity.quanta + total
  else
    total

/--
A left-fold coordinate accumulator equals the same coordinate's right-fold sum,
up to the caller-supplied initial accumulator.

This is the list-algebra bridge between a practical transient cell builder and
the existing Event projection.
-/
private theorem foldl_cell_eq_acc_plus_foldr
    (effects : List Effect)
    (coordinate : EffectCoordinate)
    (acc : Int) :
    effects.foldl (cellFoldlStep coordinate) acc =
      acc + effects.foldr (cellFoldrStep coordinate) 0 := by
  induction effects generalizing acc with
  | nil =>
      simp
  | cons effect rest ih =>
      by_cases hCoordinate : effect.coordinate = coordinate
      · simp [cellFoldlStep, cellFoldrStep, hCoordinate, ih, Int.add_assoc]
      · simp [cellFoldlStep, cellFoldrStep, hCoordinate, ih]

/--
Experiment-only query form of one sparse Event/coordinate cell.

This deliberately specifies the mathematical cell quantity only. It does not
choose List, HashMap, tree, array, or persistence representation.
-/
def eventCellQuanta
    (event : Event)
    (coordinate : EffectCoordinate) : Int :=
  event.effects.foldl (cellFoldlStep coordinate) 0

/--
For every Event and every EffectCoordinate, Event-local coordinate aggregation
has exactly the current `Event.quantityAt` meaning.
-/
theorem eventCellQuanta_eq_quantityAt
    (event : Event)
    (coordinate : EffectCoordinate) :
    eventCellQuanta event coordinate =
      (Event.quantityAt
        event coordinate.locus coordinate.measure).quanta := by
  cases coordinate with
  | mk locus measure =>
      change
        event.effects.foldl (cellFoldlStep ⟨locus, measure⟩) 0 =
          event.effects.foldr (cellFoldrStep ⟨locus, measure⟩) 0
      simpa using
        foldl_cell_eq_acc_plus_foldr event.effects ⟨locus, measure⟩ 0

/--
Quantity-wrapped form of the same correspondence, matching the public cell
vocabulary used by TransactionsFlowReview.
-/
theorem eventCellQuantity_eq_quantityAt
    (event : Event)
    (coordinate : EffectCoordinate) :
    Quantity.ofQuanta (eventCellQuanta event coordinate) =
      Event.quantityAt event coordinate.locus coordinate.measure := by
  apply congrArg Quantity.ofQuanta
  exact eventCellQuanta_eq_quantityAt event coordinate

/-!
## Finding

Two candidate factorization edges are now universal rather than finite:

    rowActivity
        -> net
        = rowTotal

and:

    Event.effects
        -> Event-local coordinate fold
        = Event.quantityAt

The result does not yet prove that Observation 320's entire finite sparse image
implementation is equivalent for arbitrary Snapshots. In particular, a concrete
finite-map builder still needs its own key uniqueness / lookup correspondence
if that representation is ever promoted.

But the arithmetic core no longer depends on the Observation 320 fixtures.
-/

end Loam.Observation321

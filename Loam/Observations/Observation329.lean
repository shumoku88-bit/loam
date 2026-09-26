import Loam.Observations.Observation325
import Std.Data.HashMap.Lemmas

namespace Loam.Observation329

open Loam.Core

set_option autoImplicit false

/-!
# Observation 329 — Event coordinate support is already carried by CellIndex

Observation 328's one-pass Transactions-Flow refinement used two Event-local
derived structures:

1. Observation 325's `CellIndex`, which aggregates exact quantity by
   `CoordinateKey`;
2. a separate deduplicated `eventCoordinates` list, used only to visit each
   represented Event coordinate once.

This observation asks whether the second structure carries any information that
is not already present in the first.

If the answer is no, the local research algorithm can be compressed from:

    raw Effects
      -> CellIndex
      + separate coordinate dedup
      -> one update per represented Event coordinate

to:

    raw Effects
      -> CellIndex
      -> iterate CellIndex keys once

without changing the Event-local semantic boundary.

This is research-only. It does not modify production.
-/

private abbrev CoordinateKey := Loam.Observation325.CoordinateKey

/--
The exact represented coordinate keys already retained by the Event-local sparse
cell index.

Order is intentionally not semantic.
-/
def eventCellKeys (event : Event) : List CoordinateKey :=
  (Loam.Observation325.buildCellIndex event.effects).keys

/--
HashMap key iteration is already duplicate-free.

A second Event-local list-membership dedup structure is therefore not needed
merely to obtain one visit per sparse cell key.
-/
theorem eventCellKeys_nodup (event : Event) :
    (eventCellKeys event).Nodup := by
  unfold eventCellKeys
  exact Std.HashMap.nodup_keys

/--
A coordinate key is present in the Event-local key list exactly when raw Event
evidence contains that coordinate.

This preserves represented zero cells: key presence is about occurrence, not the
final summed quantity.
-/
theorem coordinate_mem_eventCellKeys_iff_raw_occurs
    (event : Event)
    (coordinate : EffectCoordinate) :
    Loam.Observation325.coordinateKey coordinate ∈ eventCellKeys event ↔
      event.effects.any
        (fun effect => decide (effect.coordinate = coordinate)) = true := by
  simp [eventCellKeys, Std.HashMap.mem_iff_contains,
    Loam.Observation325.buildCellIndex_contains_eq_any]

/--
The CellIndex therefore carries both pieces of Event-local information needed by
the one-pass row refinement:

- support: whether the coordinate was represented at all;
- value: the exact post-aggregation cell quantity.

No separate coordinate-support representation is needed to recover either fact.
-/
theorem eventCellIndex_carries_support_and_value
    (event : Event)
    (coordinate : EffectCoordinate) :
    (Loam.Observation325.coordinateKey coordinate ∈ eventCellKeys event ↔
      event.effects.any
        (fun effect => decide (effect.coordinate = coordinate)) = true) ∧
    ((Loam.Observation325.buildCellIndex event.effects).get?
        (Loam.Observation325.coordinateKey coordinate)).getD 0 =
      (Event.quantityAt
        event coordinate.locus coordinate.measure).quanta := by
  constructor
  · exact coordinate_mem_eventCellKeys_iff_raw_occurs event coordinate
  · exact
      Loam.Observation325.buildCellIndex_getD_eq_quantityAt
        event coordinate

/--
Even if the exact Event/coordinate quantity cancels to zero, raw occurrence
still keeps the key in the CellIndex key set.

This is the critical reason a future key-driven builder may remove the separate
dedup list without erasing represented zero rows.
-/
theorem zero_sum_coordinate_remains_in_eventCellKeys
    (event : Event)
    (coordinate : EffectCoordinate)
    (hOccurs :
      event.effects.any
        (fun effect => decide (effect.coordinate = coordinate)) = true)
    (hZero :
      (Event.quantityAt
        event coordinate.locus coordinate.measure).quanta = 0) :
    Loam.Observation325.coordinateKey coordinate ∈ eventCellKeys event ∧
    ((Loam.Observation325.buildCellIndex event.effects).get?
        (Loam.Observation325.coordinateKey coordinate)).getD 0 = 0 := by
  constructor
  · exact
      (coordinate_mem_eventCellKeys_iff_raw_occurs
        event coordinate).2 hOccurs
  · rw [Loam.Observation325.buildCellIndex_getD_eq_quantityAt]
    exact hZero

/-!
## Finding

The separate Event-coordinate dedup list used by Observation 328 is
informationally redundant.

Observation 325's CellIndex already supplies:

    exact coordinate support
      +
    exact aggregated cell value

and the standard HashMap key view supplies that support without duplicates.

So the next Transactions-Flow research candidate can remove the explicit
list-membership dedup stage and drive one update per Event coordinate directly
from CellIndex keys.

This does **not** by itself prove a runtime complexity bound. It does remove the
specific list-membership dedup mechanism that can become quadratic in the number
of distinct coordinates inside one Event.

A stronger next question is now visible:

    can the global RowIndex start empty
      and insert a row when a CellIndex key is first observed,

instead of first computing and seeding Snapshot.rows?

That would remove another derived pre-pass, but it requires a general theorem
that the final RowIndex key set is exactly the represented Snapshot row set while
preserving represented zero rows and current RowActivity values.

No production optimization is authorized by this observation.
-/

end Loam.Observation329

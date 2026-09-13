import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/-!
# Opening quantity support

This is the narrow current-balance evidence earned by Observation 245.
One coordinate may explicitly name one retained Event whose Effect supplies the
opening quantity already present in Actual evidence.

The relation stores no second quantity, date, accounting role, ordering, or
correction history. Absence means unsupported at this boundary, never implicit
zero. Event activity alone does not create opening support.
-/

/-- One explicit claim that a retained Event is the opening witness for a coordinate. -/
structure OpeningSupport where
  coordinate : EffectCoordinate
  openingEvent : EventId
deriving Repr, DecidableEq

/-- A finite partial `EffectCoordinate -> EventId` opening-support relation. -/
structure OpeningSupportMap where
  supports : List OpeningSupport
  coordinateNodup : (supports.map (fun support => support.coordinate)).Nodup

deriving Repr, DecidableEq

namespace OpeningSupportMap

/-- Admit opening support only when each coordinate names at most one opening Event. -/
def ofSupports? (supports : List OpeningSupport) : Option OpeningSupportMap :=
  if h : (supports.map (fun support => support.coordinate)).Nodup then
    some { supports := supports, coordinateNodup := h }
  else
    none

/-- Empty evidence supports no coordinate through an opening Event. -/
def empty : OpeningSupportMap :=
  { supports := [], coordinateNodup := by simp }

/-- Look up only an explicitly retained opening witness. -/
def supportFor? (supportMap : OpeningSupportMap) (coordinate : EffectCoordinate) :
    Option OpeningSupport :=
  supportMap.supports.find? fun support => decide (support.coordinate = coordinate)

/-- Coordinates carrying explicit opening support. -/
def coordinates (supportMap : OpeningSupportMap) : List EffectCoordinate :=
  supportMap.supports.map (fun support => support.coordinate)

@[simp] theorem supportFor?_empty (coordinate : EffectCoordinate) :
    empty.supportFor? coordinate = none := by
  rfl

end OpeningSupportMap

end Loam.Core

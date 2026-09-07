import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/-!
# Zero-origin quantity coverage

This is the narrow evidence earned by the reconstructed household path: one
explicit finite set of neutral quantity coordinates whose retained selected
Event history is known to begin at exact zero.

It is not an Account registry, balance-view policy, accounting role, visibility
window, writer permission, or generic coverage framework. Row order carries no
priority, presentation, temporal, or accounting meaning.
-/

/-- Explicit finite evidence that selected retained history is complete from zero. -/
structure ZeroOriginCoverage where
  coordinates : List EffectCoordinate
  nodup : coordinates.Nodup

namespace ZeroOriginCoverage

/-- Admit one finite zero-origin set only when coordinates are unique. -/
def ofCoordinates? (coordinates : List EffectCoordinate) : Option ZeroOriginCoverage :=
  if h : coordinates.Nodup then
    some { coordinates := coordinates, nodup := h }
  else
    none

/-- The empty evidence set proves no coordinate complete from zero. -/
def empty : ZeroOriginCoverage :=
  { coordinates := [], nodup := by simp }

/-- Whether one neutral quantity coordinate has explicit zero-origin evidence. -/
def covers (coverage : ZeroOriginCoverage) (coordinate : EffectCoordinate) : Bool :=
  decide (coordinate ∈ coverage.coordinates)

end ZeroOriginCoverage

end Loam.Core

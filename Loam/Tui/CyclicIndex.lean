import Std

namespace Loam.Tui.CyclicIndex

set_option autoImplicit false

/-!
# Cyclic index movement

This module owns only the arithmetic for moving within a finite cyclic index
space. Callers retain ownership of cursor/focus state, item availability,
selection meaning, and any `Fin` proof carried by their own state.
-/

/-- Move one position toward the beginning, wrapping at zero. Empty spaces do not move. -/
def backward (count index : Nat) : Nat :=
  if count = 0 then index else (index + count - 1) % count

/-- Move one position toward the end, wrapping after the last position. Empty spaces do not move. -/
def forward (count index : Nat) : Nat :=
  if count = 0 then index else (index + 1) % count

/-- Empty cyclic spaces preserve the caller-owned index. -/
theorem backward_eq_self_of_count_zero (index : Nat) :
    backward 0 index = index := by
  simp [backward]

/-- Empty cyclic spaces preserve the caller-owned index. -/
theorem forward_eq_self_of_count_zero (index : Nat) :
    forward 0 index = index := by
  simp [forward]

/-- Backward movement always returns a valid index when the space is nonempty. -/
theorem backward_lt (count index : Nat) (h : 0 < count) :
    backward count index < count := by
  simp [backward, Nat.ne_of_gt h, Nat.mod_lt _ h]

/-- Forward movement always returns a valid index when the space is nonempty. -/
theorem forward_lt (count index : Nat) (h : 0 < count) :
    forward count index < count := by
  simp [forward, Nat.ne_of_gt h, Nat.mod_lt _ h]

end Loam.Tui.CyclicIndex

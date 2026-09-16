import Std

namespace Loam.Tui.Scroll

set_option autoImplicit false

/-!
# Bounded vertical scrolling

This module owns only the arithmetic shared by independent viewport offsets.
It deliberately does not own workspace state, selection, terminal input, or
rendering policy. Content extent and visible extent remain derived by callers.
-/

/-- Largest meaningful vertical offset for a content/viewport extent pair. -/
def maxOffset (content visible : Nat) : Nat :=
  content - visible

/-- Normalize an offset to the meaningful range for the current extents. -/
def clamp (content visible offset : Nat) : Nat :=
  min offset (maxOffset content visible)

/-- Move toward the beginning while preserving the current viewport bound. -/
def backward (content visible offset amount : Nat) : Nat :=
  clamp content visible (offset - amount)

/-- Move toward the end while preserving the current viewport bound. -/
def forward (content visible offset amount : Nat) : Nat :=
  clamp content visible (offset + amount)

/-- If all content fits, there is no meaningful nonzero offset. -/
theorem maxOffset_eq_zero_of_content_le_visible
    (content visible : Nat) (h : content ≤ visible) :
    maxOffset content visible = 0 := by
  simp [maxOffset, Nat.sub_eq_zero_of_le h]

/-- Normalization never exceeds the largest meaningful offset. -/
theorem clamp_le_maxOffset (content visible offset : Nat) :
    clamp content visible offset ≤ maxOffset content visible := by
  exact Nat.min_le_right _ _

/-- If all content fits, normalization always returns the origin. -/
theorem clamp_eq_zero_of_content_le_visible
    (content visible offset : Nat) (h : content ≤ visible) :
    clamp content visible offset = 0 := by
  simp [clamp, maxOffset, Nat.sub_eq_zero_of_le h]

/-- An already-valid offset is unchanged by normalization. -/
theorem clamp_eq_self_of_le
    (content visible offset : Nat)
    (h : offset ≤ maxOffset content visible) :
    clamp content visible offset = offset := by
  simpa [clamp] using Nat.min_eq_left h

/-- Re-normalizing an offset cannot change it. -/
theorem clamp_idempotent (content visible offset : Nat) :
    clamp content visible (clamp content visible offset) =
      clamp content visible offset := by
  unfold clamp
  apply Nat.min_eq_left
  exact Nat.min_le_right _ _

/-- Forward movement preserves the viewport bound. -/
theorem forward_le_maxOffset
    (content visible offset amount : Nat) :
    forward content visible offset amount ≤ maxOffset content visible := by
  simpa [forward] using clamp_le_maxOffset content visible (offset + amount)

/-- Backward movement preserves the viewport bound. -/
theorem backward_le_maxOffset
    (content visible offset amount : Nat) :
    backward content visible offset amount ≤ maxOffset content visible := by
  simpa [backward] using clamp_le_maxOffset content visible (offset - amount)

end Loam.Tui.Scroll

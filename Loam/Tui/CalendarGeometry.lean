import Lean.Elab.Tactic.Omega

/-!
# Experimental seven-day calendar geometry

Pure, presentation-only arithmetic for both the Week strip and the Month grid.
No household meaning, money projection, selected date, or renderer is changed.

The inputs are *terminal columns*, not pixels. Visual aspect ratios require
measured terminal glyph width/height and empirical review; no universal aesthetic
ratio is assumed or claimed to be proven.
-/

namespace Loam.Tui.CalendarGeometry

set_option autoImplicit false

/-- Seven equally wide days, with six equal inter-day gaps. -/
def gridWidth (cellColumns gapColumns : Nat) : Nat :=
  7 * cellColumns + 6 * gapColumns

/-- Put unoccupied columns at the left, favoring the right for odd remainders. -/
def leftMargin (available occupied : Nat) : Nat :=
  (available - occupied) / 2

def rightMargin (available occupied : Nat) : Nat :=
  available - occupied - leftMargin available occupied

/-- Centering never invents or loses terminal columns when content fits. -/
theorem margins_cover (available occupied : Nat)
    (hfit : occupied ≤ available) :
    leftMargin available occupied + occupied + rightMargin available occupied =
      available := by
  unfold rightMargin leftMargin
  omega

/-- The right/left margin difference is at most one terminal column. -/
theorem margins_balanced (available occupied : Nat) :
    leftMargin available occupied ≤ rightMargin available occupied ∧
    rightMargin available occupied ≤ leftMargin available occupied + 1 := by
  unfold rightMargin leftMargin
  omega

/--
Choose the widest equal day column that fits, subject to a minimum and a cap.
Return none instead of silently violating the minimum. Callers then choose a
separately designed compact/stacked presentation.
-/
def maxFitCell? (available minimum maximum gap : Nat) : Option Nat :=
  if minimum ≤ maximum ∧ gridWidth minimum gap ≤ available then
    let raw := (available - 6 * gap) / 7
    some (if raw ≤ maximum then raw else maximum)
  else
    none

/-- Accepted column sizes honor all three constraints. -/
theorem maxFitCell_sound {available minimum maximum gap chosen : Nat}
    (h : maxFitCell? available minimum maximum gap = some chosen) :
    minimum ≤ chosen ∧ chosen ≤ maximum ∧ gridWidth chosen gap ≤ available := by
  by_cases hg : minimum ≤ maximum ∧ gridWidth minimum gap ≤ available
  · have hAvail : 7 * minimum + 6 * gap ≤ available := by
      simpa only [gridWidth] using hg.2
    have hLower : minimum ≤ (available - 6 * gap) / 7 := by
      omega
    by_cases hc : (available - 6 * gap) / 7 ≤ maximum
    · simp [maxFitCell?, hg, hc] at h
      unfold gridWidth
      omega
    · simp [maxFitCell?, hg, hc] at h
      unfold gridWidth
      omega
  · simp [maxFitCell?, hg] at h

/-- Accepted size is maximal among all feasible sizes under the cap. -/
theorem maxFitCell_maximal {available minimum maximum gap chosen : Nat}
    (h : maxFitCell? available minimum maximum gap = some chosen)
    (candidate : Nat)
    (hCap : candidate ≤ maximum)
    (hFits : gridWidth candidate gap ≤ available) :
    candidate ≤ chosen := by
  by_cases hg : minimum ≤ maximum ∧ gridWidth minimum gap ≤ available
  · have hQuot : candidate ≤ (available - 6 * gap) / 7 := by
      unfold gridWidth at hFits
      omega
    by_cases hc : (available - 6 * gap) / 7 ≤ maximum
    · simp [maxFitCell?, hg, hc] at h
      omega
    · simp [maxFitCell?, hg, hc] at h
      omega
  · simp [maxFitCell?, hg] at h

/-- Concrete integer geometry, kept separate from the renderer. -/
structure CenteredSeven where
  cellColumns : Nat
  gapColumns : Nat
  gridColumns : Nat
  leftColumns : Nat
  rightColumns : Nat
  deriving Repr, DecidableEq

def centeredSeven? (available minimum maximum gap : Nat) :
    Option CenteredSeven := do
  let cell ← maxFitCell? available minimum maximum gap
  let occupied := gridWidth cell gap
  some {
    cellColumns := cell
    gapColumns := gap
    gridColumns := occupied
    leftColumns := leftMargin available occupied
    rightColumns := rightMargin available occupied
  }

/--
Squared pixel geometry is not needed to compare a candidate aspect ratio.
This integer cross-product discrepancy is zero at an exact ratio.
Parameters represent measured glyph dimensions and a chosen target ratio.
-/
def aspectPenalty (cellColumns cellRows glyphWidth glyphHeight
    targetWidth targetHeight : Nat) : Nat :=
  let x := cellColumns * glyphWidth * targetHeight
  let y := cellRows * glyphHeight * targetWidth
  (x - y) + (y - x)

/-- A ratio matched exactly has no aspect discrepancy. -/
theorem aspectPenalty_zero (c r gw gh tw th : Nat)
    (h : c * gw * th = r * gh * tw) :
    aspectPenalty c r gw gh tw th = 0 := by
  simp [aspectPenalty, h]

-- Week and month share seven equal-width columns; their minimum/cap may differ.
example : maxFitCell? 75 10 14 1 = none := by decide
example : maxFitCell? 90 10 14 1 = some 12 := by decide
example : maxFitCell? 110 10 14 1 = some 14 := by decide
example : centeredSeven? 111 10 14 1 =
    some { cellColumns := 14, gapColumns := 1, gridColumns := 104,
           leftColumns := 3, rightColumns := 4 } := by decide
-- Example only: these glyph measurements and preferred ratio are NOT universal.
example : aspectPenalty 12 4 1 2 3 2 = 0 := by decide

end Loam.Tui.CalendarGeometry

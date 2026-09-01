import Std.Tactic.Omega

namespace Loam.Experiments.Observation084

/--
For a 2 × 2 joint table over exact integer counts, one retained joint cell plus
three independent marginal totals determine every cell.

The omitted second-column marginal then follows automatically, so a full set
of row/column marginals is more than enough once one joint coordinate is kept.
-/
theorem twoByTwoMarginalsAndAnchorDetermineJoint
    (a00 a01 a10 a11 b00 b01 b10 b11 : Int)
    (sameAnchor : a00 = b00)
    (sameRow0 : a00 + a01 = b00 + b01)
    (sameRow1 : a10 + a11 = b10 + b11)
    (sameCol0 : a00 + a10 = b00 + b10) :
    a00 = b00 ∧ a01 = b01 ∧ a10 = b10 ∧ a11 = b11 := by
  omega

/-- The remaining column marginal is forced by the same premises. -/
theorem twoByTwoSecondColumnMarginalFollows
    (a00 a01 a10 a11 b00 b01 b10 b11 : Int)
    (sameRow0 : a00 + a01 = b00 + b01)
    (sameRow1 : a10 + a11 = b10 + b11)
    (sameCol0 : a00 + a10 = b00 + b10) :
    a01 + a11 = b01 + b11 := by
  omega

end Loam.Experiments.Observation084

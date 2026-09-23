import Loam.ScheduledCoverageConfig
import Loam.ScheduledReview

namespace Loam.ScheduledCoverageSelector

set_option autoImplicit false

abbrev Record := Loam.ScheduledReview.Record
abbrev Rule := Loam.ScheduledCoverageConfig.Rule

/--
Exact signed-Locus identity used by Scheduled coverage monitoring.

Amounts are deliberately absent. Negative and positive Locus tokens are
deduplicated and sorted so rule creation and later matching observe the same
canonical selector.
-/
structure Shape where
  negativeLoci : List String
  positiveLoci : List String
  deriving Repr, DecidableEq

private def lociWithSign (record : Record) (positive : Bool) : List String :=
  ((record.movement.changes.filterMap fun change =>
      if positive then
        if change.quantity.quanta > 0 then some change.coordinate.token else none
      else
        if change.quantity.quanta < 0 then some change.coordinate.token else none).eraseDups)
    |>.mergeSort (fun left right => left <= right)

/-- Derive the one canonical signed-Locus selector from an explicit Scheduled occurrence. -/
def ofRecord (record : Record) : Shape :=
  {
    negativeLoci := lociWithSign record false
    positiveLoci := lociWithSign record true
  }

/-- A monitoring selector needs evidence on both signed sides. -/
def Shape.usable (shape : Shape) : Bool :=
  !shape.negativeLoci.isEmpty && !shape.positiveLoci.isEmpty

/-- Match one current-open Scheduled occurrence against one retained monitoring rule. -/
def matchesRule (record : Record) (rule : Rule) : Bool :=
  let shape := ofRecord record
  shape.negativeLoci == rule.negativeLoci &&
    shape.positiveLoci == rule.positiveLoci

end Loam.ScheduledCoverageSelector

import Loam.Presentation.HouseholdSnapshot

namespace Loam.Presentation.Reports

open Loam.Core

set_option autoImplicit false

/-!
# Surface-neutral reports presentation

This module translates shared Review answers into renderer-neutral report values.
It owns no file loading, report semantics, accounting classification, or write
authority. Renderers may present the same model as terminal rows, HTML tables,
native widgets, or charts.
-/

structure StockFlow where
  start : String
  endExclusive : String
  opening : Quantity
  increases : Quantity
  decreases : Quantity
  closing : Quantity
  currentTracked : Quantity
  deriving Repr, DecidableEq

structure Model where
  stockFlow : Except String StockFlow

/-- Preserve the qualified Stock–Flow arithmetic while naming presentation roles. -/
def fromSnapshot (snapshot : Loam.Presentation.HouseholdSnapshot) : Model :=
  let stockFlow :=
    match snapshot.stockFlow with
    | .error message => .error message
    | .ok report =>
        .ok {
          start := report.start
          endExclusive := report.endExclusive
          opening := report.reconstructedStart
          increases := report.increasesAcrossEvents
          decreases := report.decreasesAcrossEvents
          closing := report.reconstructedEnd
          currentTracked := report.currentTracked
        }
  { stockFlow := stockFlow }

end Loam.Presentation.Reports

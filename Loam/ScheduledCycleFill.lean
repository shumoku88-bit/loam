import Loam.ActualDate
import Loam.BoundaryPresetConfig

namespace Loam.ScheduledCycleFill

set_option autoImplicit false

/-!
# Current-cycle Scheduled generation

A generation cadence is explicit input intent used only while constructing
ordinary Scheduled occurrences. It is not retained recurrence evidence and does
not introduce a second Scheduled authority.

Generation is clipped to the explicit current boundary window and the current
observation date. The end boundary remains exclusive, matching Current Coverage
and Cycle Budget Scheduled pressure semantics.
-/

/-- User-selected construction cadence. No value of this type is persisted. -/
inductive GenerationCadence where
  | monthly
  | everyTwoMonths
  | yearly
  deriving Repr, DecidableEq

namespace GenerationCadence

/-- Whole Gregorian months between generated occurrences. -/
def months : GenerationCadence → Nat
  | .monthly => 1
  | .everyTwoMonths => 2
  | .yearly => 12

def label : GenerationCadence → String
  | .monthly => "Monthly"
  | .everyTwoMonths => "Every 2 months"
  | .yearly => "Yearly"

end GenerationCadence

/--
Construction request anchored by one explicit Scheduled due date.

The anchor is evidence supplied by the caller. The cadence expresses only how
this one creation action should propose later explicit dates.
-/
structure Request where
  anchor : String
  cadence : GenerationCadence
  deriving Repr, DecidableEq

private def monthIndex? (text : String) : Option Nat := do
  if !Loam.ActualDate.validIsoDate text then none else do
    let [yearText, monthText, _] := text.splitOn "-" | none
    let year ← yearText.toNat?
    let month ← monthText.toNat?
    pure (year * 12 + (month - 1))

/--
Generate later explicit due dates inside one already-resolved current window.

Only dates satisfying

```text
window.start <= date
observedAt   <= date
date         <  window.endExclusive
```

are returned. The anchor itself is never returned.

A missing nominal day fails the whole construction request. For example,
Monthly from January 31 does not silently invent February 28/29. The inputter
must choose a different explicit policy or date instead.
-/
def planAfter
    (window : Loam.BoundaryPresetConfig.CurrentWindow)
    (observedAt : String)
    (request : Request) : Except String (List String) := do
  if !Loam.ActualDate.validIsoDate window.start ||
      !Loam.ActualDate.validIsoDate window.endExclusive ||
      !Loam.ActualDate.validIsoDate observedAt ||
      !Loam.ActualDate.validIsoDate request.anchor then
    throw "loam: Scheduled cycle fill requires valid ISO calendar dates"
  if !(decide (window.start <= observedAt ∧ observedAt < window.endExclusive)) then
    throw "loam: Scheduled cycle fill observation must lie inside the current window"

  let some anchorMonth := monthIndex? request.anchor
    | throw "loam: Scheduled cycle fill anchor is invalid"
  let some endMonth := monthIndex? window.endExclusive
    | throw "loam: Scheduled cycle fill end boundary is invalid"

  let stepMonths := request.cadence.months
  let steps :=
    if endMonth < anchorMonth then 0
    else (endMonth - anchorMonth) / stepMonths

  let mut dates : List String := []
  for index in List.range steps do
    let offset := (index + 1) * stepMonths
    let some date := Loam.ActualDate.shiftMonthsSameDay? request.anchor offset
      | throw
          ("loam: " ++ request.cadence.label ++
           " cycle fill reaches a month without the anchor day; choose an explicit date policy")
    if decide (window.start <= date ∧ observedAt <= date ∧ date < window.endExclusive) then
      dates := dates ++ [date]
  return dates

end Loam.ScheduledCycleFill

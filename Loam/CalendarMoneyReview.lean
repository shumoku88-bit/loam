import Loam.ActualReview
import Loam.Core.AccountingRole

namespace Loam.CalendarMoneyReview

open Loam.Core

set_option autoImplicit false

/-!
# Calendar money review

A small read-only projection for Home's optional money calendar.

The projection reuses correction-aware `ActualReview.Record` evidence and the
explicit `AccountingRoleMap`. It introduces no second date authority, retained
calendar state, transfer heuristic, currency valuation, or cross-Measure
arithmetic.

Only current dated Effects whose Locus is explicitly classified as Income or
Expense contribute monetary direction:

* Income uses the established presentation sign convention, negating raw Income
  role quantity.
* Expense uses the established presentation sign convention and is then negated
  for the calendar's directional `+ / -` display.

That means an ordinary Income effect appears under `+`, an ordinary Expense
effect appears under `-`, and Asset/Liability/Equity movements do not become
fake income or expense. Reversal-shaped role quantities naturally reverse
direction. Distinct Measures remain separate.
-/

structure Row where
  date : String
  measure : MeasureId
  income : Quantity
  expense : Quantity
  unresolvedEffectCount : Nat
  deriving Repr, DecidableEq

structure Snapshot where
  rows : List Row
  deriving Repr, DecidableEq

structure Directional where
  plus : Quantity
  minus : Quantity
  deriving Repr, DecidableEq

private def sameKey (row : Row) (date : String) (measure : MeasureId) : Bool :=
  row.date == date && decide (row.measure = measure)

private def addRow
    (rows : List Row)
    (date : String)
    (measure : MeasureId)
    (incomeDelta expenseDelta : Int)
    (unresolvedDelta : Nat) : List Row :=
  match rows with
  | [] =>
      [{
        date := date
        measure := measure
        income := Quantity.ofQuanta incomeDelta
        expense := Quantity.ofQuanta expenseDelta
        unresolvedEffectCount := unresolvedDelta
      }]
  | row :: rest =>
      if sameKey row date measure then
        {
          row with
          income := Quantity.ofQuanta (row.income.quanta + incomeDelta)
          expense := Quantity.ofQuanta (row.expense.quanta + expenseDelta)
          unresolvedEffectCount := row.unresolvedEffectCount + unresolvedDelta
        } :: rest
      else
        row :: addRow rest date measure incomeDelta expenseDelta unresolvedDelta

private def addEffect
    (roles : AccountingRoleMap)
    (date : String)
    (rows : List Row)
    (effect : Effect) : List Row :=
  match roles.roleOf? effect.locus with
  | some .income =>
      addRow rows date effect.measure (-effect.quantity.quanta) 0 0
  | some .expense =>
      addRow rows date effect.measure 0 effect.quantity.quanta 0
  | some .asset | some .liability | some .equity =>
      rows
  | none =>
      addRow rows date effect.measure 0 0 1

private def addRecord
    (roles : AccountingRoleMap)
    (rows : List Row)
    (record : Loam.ActualReview.Record) : List Row :=
  if !record.isCurrent then rows
  else
    match record.date with
    | none => rows
    | some date =>
        record.event.effects.foldl (addEffect roles date) rows

private def rowLe (left right : Row) : Bool :=
  if left.date == right.date then
    left.measure.token <= right.measure.token
  else
    left.date <= right.date

/--
Project all current dated Actual evidence once.

Home may cheaply slice this process-local answer by visible calendar month without
re-reading canonical Actual or recomputing the correction frontier on each key
press.
-/
def project
    (records : List Loam.ActualReview.Record)
    (roles : AccountingRoleMap) : Snapshot :=
  {
    rows := (records.foldl (addRecord roles) []).mergeSort rowLe
  }

private def positivePart (value : Int) : Int :=
  if value > 0 then value else 0

private def negativeMagnitude (value : Int) : Int :=
  if value < 0 then -value else 0

/--
Collapse Income/Expense role meaning into the two visual directions used by the
calendar while preserving gross opposite-direction activity instead of netting it
away.

`plus` and `minus` are nonnegative magnitudes. An Expense reversal can
contribute to `plus`; an Income reversal can contribute to `minus`.
-/
def Row.directional (row : Row) : Directional :=
  let incomeDirection := row.income.quanta
  let expenseDirection := -row.expense.quanta
  {
    plus := Quantity.ofQuanta
      (positivePart incomeDirection + positivePart expenseDirection)
    minus := Quantity.ofQuanta
      (negativeMagnitude incomeDirection + negativeMagnitude expenseDirection)
  }

/-- Exact row lookup for one calendar day and Measure. -/
def Snapshot.rowFor?
    (snapshot : Snapshot)
    (date : String)
    (measure : MeasureId) : Option Row :=
  snapshot.rows.find? fun row => sameKey row date measure

private def addMeasureIfAbsent
    (measures : List MeasureId)
    (measure : MeasureId) : List MeasureId :=
  if measures.any fun candidate => decide (candidate = measure) then
    measures
  else
    measures ++ [measure]

/-- Measures represented by Income/Expense or unresolved role evidence in one window. -/
def Snapshot.measuresInWindow
    (snapshot : Snapshot)
    (start endExclusive : String) : List MeasureId :=
  snapshot.rows.foldl
    (fun measures row =>
      if decide (start <= row.date && row.date < endExclusive) then
        addMeasureIfAbsent measures row.measure
      else
        measures)
    []
    |>.mergeSort fun left right => left.token <= right.token

end Loam.CalendarMoneyReview

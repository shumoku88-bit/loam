import Loam.Review.CalendarMoneyReview

open Loam.Core
open Loam.CalendarMoneyReview

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

/-- Small list oracle reproducing the pre-index aggregation, test-only. -/
private def referenceAdd
    (rows : List Row) (date : String) (measure : MeasureId)
    (income expense : Int) (unknown : Nat) : List Row :=
  match rows with
  | [] => [{
      date := date
      measure := measure
      income := Quantity.ofQuanta income
      expense := Quantity.ofQuanta expense
      unresolvedEffectCount := unknown }]
  | row :: rest =>
      if row.date == date && decide (row.measure = measure) then
        { row with
          income := Quantity.ofQuanta (row.income.quanta + income)
          expense := Quantity.ofQuanta (row.expense.quanta + expense)
          unresolvedEffectCount := row.unresolvedEffectCount + unknown } :: rest
      else row :: referenceAdd rest date measure income expense unknown

private def reference (records : List Loam.ActualReview.Record) (roles : AccountingRoleMap) : Snapshot :=
  let rows := records.foldl (fun rows record =>
    if !record.isCurrent then rows
    else match record.date with
      | none => rows
      | some date => record.event.effects.foldl (fun rows effect =>
          match roles.roleOf? effect.locus with
          | some .income => referenceAdd rows date effect.measure (-effect.quantity.quanta) 0 0
          | some .expense => referenceAdd rows date effect.measure 0 effect.quantity.quanta 0
          | some .asset | some .liability | some .equity => rows
          | none => referenceAdd rows date effect.measure 0 0 1) rows) []
  { rows := rows.mergeSort fun a b =>
      if a.date == b.date then a.measure.token <= b.measure.token else a.date <= b.date }

private def record
    (id : String) (date : Option String) (sign : Int)
    (replacement : Option EventId := none) : IO Loam.ActualReview.Record := do
  let effects := [
    Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-5 * sign)),
    Effect.ofAnonymousQuantity ⟨"salary"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-10 * sign)),
    Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (15 * sign)),
    Effect.ofAnonymousQuantity ⟨"usd-bank"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-7 * sign)),
    Effect.ofAnonymousQuantity ⟨"unclassified"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (7 * sign)) ]
  let event ← requireSome (Event.ofEffects? ⟨id⟩ effects) "balanced fixture Event"
  return { event, date, description := id, replacement }

def main : IO Unit := do
  let roles ← requireSome (AccountingRoleMap.ofAssignments? [
    { locus := ⟨"bank"⟩, role := .asset },
    { locus := ⟨"salary"⟩, role := .income },
    { locus := ⟨"food"⟩, role := .expense },
    { locus := ⟨"usd-bank"⟩, role := .asset },
    { locus := ⟨"loan"⟩, role := .liability },
    { locus := ⟨"equity"⟩, role := .equity } ]) "fixture roles"
  let normal ← record "normal" (some "2026-06-01") 1
  let reversal ← record "reversal" (some "2026-06-02") (-1)
  let obsolete ← record "obsolete" (some "2026-06-01") 100 (some ⟨"normal"⟩)
  let undated ← record "undated" none 100
  let neutralEvent ← requireSome (Event.ofEffects? ⟨"neutral"⟩ [
    Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 2),
    Effect.ofAnonymousQuantity ⟨"loan"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-1)),
    Effect.ofAnonymousQuantity ⟨"equity"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-1)) ]) "neutral Event"
  let neutral : Loam.ActualReview.Record := {
    event := neutralEvent
    date := some "2026-06-03"
    description := "neutral"
    replacement := none }
  let records := [normal, reversal, obsolete, undated, neutral]
  let actual := project records roles
  expect (decide (actual = reference records roles)) "indexed calendar changed list projection"
  expect (actual.rowFor? "2026-06-03" ⟨"jpy"⟩).isNone
    "Asset/Liability/Equity activity became income, expense or an invented date row"
  let first ← requireSome (actual.rowFor? "2026-06-01" ⟨"jpy"⟩) "JPY first day"
  expect (first.income.quanta == 10 && first.expense.quanta == 15 &&
          first.unresolvedEffectCount == 0) "income/expense signs or superseded/undated filtering changed"
  let reversed ← requireSome (actual.rowFor? "2026-06-02" ⟨"jpy"⟩) "JPY reversal day"
  expect (reversed.directional.plus.quanta == 15 && reversed.directional.minus.quanta == 10)
    "reversal lost gross opposite-direction role meaning"
  let usd ← requireSome (actual.rowFor? "2026-06-01" ⟨"usd"⟩) "unresolved USD day"
  expect (usd.income.quanta == 0 && usd.expense.quanta == 0 && usd.unresolvedEffectCount == 1)
    "unknown role became known zero or mixed Measures"
  let totals := actual.summaryForWindow "2026-06-01" "2026-06-03" ⟨"jpy"⟩
  expect (totals.plus.quanta == 25 && totals.minus.quanta == 25)
    "indexed period summary netted away opposite directions"
  expect ((actual.summaryForWindow "2026-06-01" "2026-06-03" ⟨"usd"⟩).unresolvedEffectCount == 2)
    "indexed window lost unresolved effects"
  expect (decide (project [] roles = { rows := [] })) "empty evidence created calendar rows"

  let generated ← (List.range 600).mapM fun i =>
    record ("sample-" ++ toString i)
      (if i % 13 == 0 then none else Loam.ActualDate.shiftDays? "2026-01-01" (Int.ofNat (i % 97)))
      (if i % 5 == 0 then -1 else 1)
      (if i % 11 == 0 then some ⟨"replacement"⟩ else none)
  let projected := project generated roles
  expect (decide (projected = reference generated roles))
    "indexed date/Measure buckets drifted across many keys"
  expect (decide (projected = project generated.reverse roles))
    "indexed rows depend on input order or hash iteration order"
  let unknownRoles := AccountingRoleMap.empty
  expect (decide (project generated unknownRoles = reference generated unknownRoles))
    "all-unclassified evidence drifted under indexed aggregation"
  IO.println "CalendarMoney: list parity, deterministic order, correction/undated filtering, reversal signs and independent Measures passed."

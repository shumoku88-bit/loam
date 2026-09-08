import Loam.CycleFundingInspection

open Loam.Core
open Loam.CycleFundingInspection

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) : IO α :=
  match value with
  | .ok result => pure result
  | .error message => throw (IO.userError message)

private def yen : MeasureId := ⟨"jpy"⟩
private def wallet : EffectCoordinate := ⟨⟨"selected-wallet"⟩, yen⟩
private def overdraft : EffectCoordinate := ⟨⟨"selected-overdraft"⟩, yen⟩
private def excluded : EffectCoordinate := ⟨⟨"not-selected"⟩, yen⟩
private def knownZero : EffectCoordinate := ⟨⟨"known-zero"⟩, yen⟩

private def event? (id : String) (coordinate : EffectCoordinate) (amount : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩
    [Effect.ofQuantity ⟨id ++ "-in"⟩ coordinate.locus coordinate.measure (Quantity.ofQuanta amount),
     Effect.ofQuantity ⟨id ++ "-out"⟩ ⟨"source"⟩ coordinate.measure (Quantity.ofQuanta (-amount))]

private def row (purpose : String) (remaining : Int) (commitment : Int := 0) :
    Loam.CurrentCoverageReview.Row :=
  { purpose := ⟨purpose⟩
    entitlement := Quantity.ofQuanta (remaining + 6000)
    consumption := Quantity.ofQuanta 6000
    remaining := Quantity.ofQuanta remaining
    commitment := Quantity.ofQuanta commitment
    headroom := Quantity.ofQuanta (remaining - commitment) }

private def current (rows : List Loam.CurrentCoverageReview.Row) :
    Loam.CurrentCoverageReview.Snapshot :=
  { currentWindowStart := "2026-08-14"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows := rows
    scheduledFrontier := some {
      unmanaged := Quantity.ofQuanta 3
      unrouted := Quantity.ofQuanta 5
      unresolvedEligibility := Quantity.ofQuanta 4810 } }

private def assertAmounts (label : String) (summary : Summary)
    (backing assigned residual : Int) : IO Unit := do
  expect (summary.measure == yen) s!"{label}: measure"
  expect (summary.budgetableBacking.quanta == backing) s!"{label}: signed backing"
  expect (summary.remainingAssigned.quanta == assigned) s!"{label}: remaining assigned"
  expect (summary.residualBeforeUnresolved.quanta == residual) s!"{label}: residual"
  expect (summary.unmanagedFuturePressure.quanta == 3) s!"{label}: unmanaged frontier"
  expect (summary.unroutedFuturePressure.quanta == 5) s!"{label}: unrouted frontier"
  expect (summary.unresolvedFuturePressure.quanta == 4810) s!"{label}: unresolved frontier"

def main : IO Unit := do
  let opening ← requireSome (event? "opening" wallet 100) "opening"
  let debt ← requireSome (event? "overdraft" overdraft (-40)) "overdraft"
  let other ← requireSome (event? "other-assets" excluded 10000) "other assets"
  let events ← requireSome (EventMemory.ofEvents? [opening, debt, other]) "events"
  let corrections ← requireSome (EventCorrectionMemory.ofCorrections? []) "corrections"
  let coverage ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [wallet, overdraft, excluded, knownZero]) "zero-origin"
  let inspect := fun selection snapshot =>
    project events corrections coverage selection yen snapshot
  let inspectRows := fun rows => requireOk (inspect [wallet] (current rows))

  -- A, I: unrelated assets and all three global pressures do not inflate or
  -- silently reduce the explicitly selected backing/residual.
  let basic ← inspectRows [row "food" 70]
  assertAmounts "A/I basic and separate frontier" basic 100 70 30

  -- B: negative remaining is clamped per row, not after netting the rows.
  assertAmounts "B negative remaining" (← inspectRows [row "food" 70, row "general" (-20)])
    100 70 30

  -- C/D: retroactive fill does not reserve money already spent; crossing zero does.
  let before ← inspectRows [row "general" (-20)]
  let filled ← inspectRows [row "general" 0]
  let future ← inspectRows [row "general" 20]
  assertAmounts "C before fill" before 100 0 100
  assertAmounts "C retroactive fill" filled 100 0 100
  assertAmounts "D future allocation" future 100 20 80
  expect (before.remainingAssigned == filled.remainingAssigned) "retroactive fill increased assignment"
  expect (filled.residualBeforeUnresolved.quanta - future.residualBeforeUnresolved.quanta == 20)
    "future allocation did not reduce residual by 20"
  assertAmounts "household negative -5546" (← inspectRows [row "general" (-5546)]) 100 0 100
  assertAmounts "household crossing zero" (← inspectRows [row "general" 1000]) 100 1000 (-900)

  -- E: commitment is inside the 100 assigned, not subtracted a second time.
  assertAmounts "E remaining not headroom" (← inspectRows [row "fixed" 100 30]) 100 100 0

  -- F: BalanceReview normalizes presentation duplicates, but funding rejects them.
  expect (!(inspect [wallet, wallet] (current [])).isOk) "F duplicate selection accepted"
  let display ← requireOk (Loam.BalanceReview.project events corrections coverage [wallet, wallet])
  expect (display.rows.length == 1) "BalanceReview presentation normalization changed"

  -- G: both unknown coordinates and activity without origin coverage remain unknown.
  expect (!(inspect [⟨⟨"unknown"⟩, yen⟩] (current [])).isOk) "G missing selected balance accepted"
  expect (!(project events corrections ZeroOriginCoverage.empty [wallet] yen (current [])).isOk)
    "G activity was mistaken for complete balance evidence"
  assertAmounts "evidenced zero" (← requireOk (inspect [knownZero] (current []))) 0 0 0

  -- H: neither mixed selection nor changing the summary's measure can coerce JPY coverage.
  let usd : MeasureId := ⟨"usd"⟩
  let dollars : EffectCoordinate := ⟨wallet.locus, usd⟩
  let mixedCoverage ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [wallet, dollars]) "mixed coverage"
  expect (!(project events corrections mixedCoverage [wallet, dollars] yen (current [])).isOk)
    "H mixed-measure selection accepted"
  expect (!(project events corrections mixedCoverage [dollars] usd (current [])).isOk)
    "H JPY current coverage was coerced to another measure"

  -- J: global frontier copied once, regardless of Purpose count or row order.
  let rows := [row "food" 70, row "general" 0, row "fixed" 0]
  let multi ← inspectRows rows
  assertAmounts "J multiple Purposes" multi 100 70 30
  expect (multi == basic) "J global frontier multiplied by Purpose count"
  expect ((← inspectRows rows.reverse) == multi) "row order changed funding"
  expect (!(inspect [wallet] { current [] with scheduledFrontier := none }).isOk)
    "missing Scheduled frontier became zero"
  expect (!(inspect [wallet] (current [row "food" 70, row "food" 70])).isOk)
    "duplicate Purpose rows double counted assignment"

  assertAmounts "signed selected balances" (← requireOk (inspect [wallet, overdraft] (current [])))
    60 0 60
  assertAmounts "negative backing" (← requireOk (inspect [overdraft] (current []))) (-40) 0 (-40)
  assertAmounts "explicit empty selection" (← requireOk (inspect [] (current [row "food" 70])))
    0 70 (-70)

  -- Neighbor: funding must reuse the physical correction frontier, not sum retained Events.
  let replacement ← requireSome (event? "corrected-opening" wallet 80) "replacement"
  let correctedEvents ← requireSome
    (EventMemory.ofEvents? [opening, debt, other, replacement]) "corrected events"
  let corrected ← requireSome (EventCorrectionMemory.ofCorrections?
    [{ id := ⟨"correction-1"⟩, target := opening.id, replacement := replacement.id }]) "correction"
  assertAmounts "corrected physical balance"
    (← requireOk (project correctedEvents corrected coverage [wallet] yen (current [row "food" 70])))
    80 70 10
  expect (!(project events corrected coverage [wallet] yen (current [])).isOk)
    "missing correction endpoint bypassed BalanceReview refusal"

  IO.println "Cycle Funding: A-J arithmetic, explicit selection, global frontier and correction-aware physical evidence passed."

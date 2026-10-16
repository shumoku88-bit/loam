import Loam.Review.AnnualSourceReadView
import Loam.Review.CurrentBalanceReview
import Loam.Review.CycleSpendingPaceReview

namespace Loam.Tools.NativeAnnualPaceReadViewProbe

open Loam.Core

set_option autoImplicit false

/-!
One-current-generation Daily Pace / current-quantity preflight.
This never infers a pension cycle from 1 January, never reloads the selected
Actual/Scheduled independently for the answer under test, and never publishes.
The explicit observedAt and endExclusive are caller-supplied QUERY POLICY;
there is no as-known-at-day claim.
-/

private def requireOk {α : Type} (value : Except String α) (message : String) :
    IO α := do
  match value with
  | .ok result => return result
  | .error e => throw (IO.userError s!"{message}: {e}")

private def expect (yes : Bool) (message : String) : IO Unit := do
  unless yes do throw (IO.userError message)

def run (args : List String) : IO Unit := do
  let [mode, rootText, sourceText] := args
    | throw (IO.userError
      "usage: NativeAnnualPaceReadViewProbe [match|refuse] ROOT CANDIDATE")
  expect (mode == "match" || mode == "refuse") "bad test mode"
  let root := System.FilePath.mk rootText
  let currentPath := Loam.HouseholdAuthority.path root
  let candidatePath := System.FilePath.mk sourceText
  let before ← IO.FS.readFile currentPath
  let candidate ← IO.FS.readFile candidatePath
  let compared ← Loam.AnnualSourceReadView.compareInstalled? root candidate

  if mode == "refuse" then
    expect (!compared.isOk) "stale current-balance source was accepted"
  else
    let view ← requireOk compared "same-generation annual source view"
    expect (view.generation.wire == before && before == candidate)
      "current source differs from pinned annual reconstruction"
    let bank : EffectCoordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩
    let wifi : EffectCoordinate := ⟨⟨"wifi"⟩, ⟨"jpy"⟩⟩

    -- Only the BANK origin was affirmed by the synthetic assertion. Even
    -- though Wi-Fi has posted events, unknown origin is NOT exact zero.
    expect (view.currentBalances.unsupported.contains wifi)
      "unsupported Wi-Fi origin silently became a known exact balance"
    expect (view.currentBalances.exactRowFor? bank |>.isSome)
      "affirmed bank zero-origin was lost on annual replay"
    expect ((Loam.CurrentBalanceReview.selectExact
        view.currentBalances [wifi]).isError)
      "unasserted Wi-Fi balance was manufactured"

    let selected ← requireOk
      (Loam.CurrentBalanceReview.selectExact view.currentBalances [bank])
      "qualified bank exact balance"
    let measure : MeasureId := ⟨"jpy"⟩
    let day := "2027-01-03"
    let endExclusive := "2027-02-15"

    let derived ← requireOk
      (view.paceForMeasure? measure day endExclusive [bank])
      "Daily Pace from single captured generation"
    let native ← requireOk
      (Loam.CycleSpendingPaceReview.projectForMeasure
        measure day endExclusive [bank] selected view.scheduled)
      "existing native Daily Pace"
    expect (derived == native && derived.remainingDays > 0 &&
            derived.endExclusive == endExclusive)
      "Annual source altered native Daily Pace or cycle horizon"
    expect (derived.dailyPaceQuanta?.isSome)
      "annual source Daily Pace unexpectedly unavailable"

    -- A missing exact support, empty policy, reversed cycle or mixed Measures
    -- must never produce a plausible zero Daily Pace.
    expect ((view.paceForMeasure?
      measure day endExclusive [wifi]).isError)
      "missing Wi-Fi balance support became zero spending power"
    expect ((view.paceForMeasure?
      measure day endExclusive []).isError)
      "empty pool policy became a zero-valued answer"
    expect ((view.paceForMeasure?
      measure day "2027-01-03" [bank]).isError)
      "invalid nonpositive cycle horizon was accepted"
    expect ((view.paceForMeasure?
      ⟨"usd"⟩ day endExclusive [bank]).isError)
      "JPY balance was silently converted to USD"

  expect ((← IO.FS.readFile currentPath) == before)
    "parity probe changed canonical household"
  expect ((← IO.FS.readFile candidatePath) == candidate)
    "parity probe changed annual materialization"
  IO.println s!"NATIVE_ANNUAL_PACE_READ_VIEW_PASS mode={mode}"

end Loam.Tools.NativeAnnualPaceReadViewProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualPaceReadViewProbe.run args

import Loam.Review.AnnualSourceQueryPolicy

namespace Loam.Tools.NativeAnnualQueryPolicyProbe

open Loam.Core

set_option autoImplicit false

/-!
Test-only pinned QUERY policy for a native year-source current-truth answer.
No reliance on Git commit time, publication year as a pension boundary,
live config edits, or fictional retrospective policy versions.
-/

private def expect (yes : Bool) (label : String) : IO Unit := do
  unless yes do throw (IO.userError label)

private def requireOk {α : Type} (e : Except String α) (label : String) :
    IO α := do
  match e with
  | .ok value => return value
  | .error message => throw (IO.userError s!"{label}: {message}")

def run (args : List String) : IO Unit := do
  let [mode, rootText, candidateText] := args
    | throw (IO.userError
      "usage: NativeAnnualQueryPolicyProbe [match|refuse] ROOT CANDIDATE")
  expect (mode == "match" || mode == "refuse") "unknown policy probe mode"
  let root := System.FilePath.mk rootText
  let source := Loam.HouseholdAuthority.path root
  let candidatePath := System.FilePath.mk candidateText
  let before ← IO.FS.readFile source
  let candidate ← IO.FS.readFile candidatePath
  let compared ← Loam.AnnualSourceReadView.compareInstalled? root candidate
  if mode == "refuse" then
    expect (!compared.isOk)
      "stale source accepted with a valid query policy"
  else
    let view ← requireOk compared "same-generation annual read view"
    expect (view.generation.wire == candidate && before == candidate)
      "annual source candidate differs from installed native generation"
    let measure : MeasureId := ⟨"jpy"⟩
    let bank : EffectCoordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩
    let observedAt := "2027-01-03"
    let pool := "bank\tjpy\n"
    let calendar := "pension\t2026-12-15\t2027-02-15\t2027-04-15\n"

    let policy ← requireOk
      (Loam.AnnualSourceQueryPolicy.admit?
        measure observedAt pool calendar)
      "explicit pension policy"
    expect (policy.selection == [bank] &&
            policy.window.source == "pension" &&
            policy.window.start == "2026-12-15" &&
            policy.window.endExclusive == "2027-02-15")
      "year source boundary reset the pension cycle"

    let got ← requireOk (policy.project? view)
      "pinned annual current-truth pace"
    let native ← requireOk
      (view.paceForMeasure? measure observedAt "2027-02-15" [bank])
      "same-generation explicit native projection"
    expect (got == native && got.remainingDays > 0 &&
            got.dailyPaceQuanta?.isSome)
      "pinned query answer differs from existing native Daily Pace"

    let _ ← requireOk
      (policy.requireSameBytes? pool calendar)
      "unchanged exact policy contents"
    -- Even semantically equivalent, re-serialized bytes are a DIFFERENT
    -- external version; do not attribute the old answer to new bytes.
    expect (!(policy.requireSameBytes? "bank\tjpy" calendar).isOk)
      "reformatted pool policy counted as same retained contents"
    expect (!(policy.requireSameBytes? pool
      "pension\t2026-12-15\t2027-02-15\t2027-04-15").isOk)
      "reformatted boundary policy counted as same retained contents"

    -- A deliberate policy revision MAY produce a different present query;
    -- it must never silently mutate an already-captured query receipt.
    let shorter := "pension\t2026-12-15\t2027-02-10\t2027-04-15\n"
    let revision ← requireOk
      (Loam.AnnualSourceQueryPolicy.admit?
        measure observedAt pool shorter)
      "revised external query policy"
    let changed ← requireOk (revision.project? view)
      "revised query projection"
    expect (changed.endExclusive == "2027-02-10" &&
            changed.remainingDays != got.remainingDays &&
            !(policy.requireSameBytes? pool shorter).isOk)
      "query policy revision was silently treated as prior query"

    -- Refuse unknown/ambiguous policy evidence rather than manufacture
    -- spending capacity, a Jan 1 pension restart, or a default answer.
    for wrongPool in [
        "", "wifi\tjpy\n", "bank\tusd\n",
        "bank\tjpy\nbank\tjpy\n", "bank\tUSD\n"] do
      let attempt := Loam.AnnualSourceQueryPolicy.admit?
        measure observedAt wrongPool calendar
      if wrongPool == "wifi\tjpy\n" then
        let wifiPolicy ← requireOk attempt "syntactically valid unsupported pool"
        expect (!(wifiPolicy.project? view).isOk)
          "unknown Wi-Fi balance became available spending money"
      else
        expect (!attempt.isOk)
          "invalid/empty/mixed-Measure query pool was accepted"
    expect (!(Loam.AnnualSourceQueryPolicy.admit?
      measure observedAt pool "").isOk)
      "missing cycle policy silently inferred year boundary"
    expect (!(Loam.AnnualSourceQueryPolicy.admit?
      measure observedAt pool
      "pension\t2026-12-15\t2027-02-15\nother\t2026-12-20\t2027-02-01\n").isOk)
      "ambiguous overlapping pension cycle preset selected a winner"
    expect (!(Loam.AnnualSourceQueryPolicy.admit?
      measure "2028-01-03" pool calendar).isOk)
      "unconfigured future date invented a cycle"
    expect (!(Loam.AnnualSourceQueryPolicy.admit?
      measure observedAt pool
      "pension\t2026-12-15\t2027-02-30\n").isOk)
      "malformed real-calendar boundary accepted"

  expect ((← IO.FS.readFile source) == before)
    "policy probe wrote the installed household"
  expect ((← IO.FS.readFile candidatePath) == candidate)
    "policy probe wrote the replayed journal materialization"
  IO.println s!"NATIVE_ANNUAL_QUERY_POLICY_PASS mode={mode}"

end Loam.Tools.NativeAnnualQueryPolicyProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualQueryPolicyProbe.run args

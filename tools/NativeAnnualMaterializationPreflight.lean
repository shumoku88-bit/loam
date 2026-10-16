import Loam.Authority.AnnualSourceMaterialization
import Loam.Authority.ActualAuthority
import Loam.Review.ScheduledReview

namespace Loam.Tools.NativeAnnualMaterializationPreflight

set_option autoImplicit false

/-!
Purely read-only native bridge acceptance for the proposed annual materialized
full image. Both the installed root and candidate file are disposable synthetic
fixtures supplied by the Python study. No operation writes either file.
-/

private def expect (ok : Bool) (message : String) : IO Unit := do
  unless ok do throw (IO.userError message)

private def required {α : Type} (result : Except String α) (message : String) :
    IO α := do
  match result with
  | .ok value => return value
  | .error error => throw (IO.userError s!"{message}: {error}")

def run (args : List String) : IO Unit := do
  let [mode, rootText, candidateText] := args
    | throw (IO.userError
      "usage: NativeAnnualMaterializationPreflight [match|refuse] ROOT CANDIDATE")
  expect (mode == "match" || mode == "refuse") "unsupported parity mode"
  let root := System.FilePath.mk rootText
  let current := Loam.HouseholdAuthority.path root
  let proposed := System.FilePath.mk candidateText
  let before ← IO.FS.readFile current
  let candidate ← IO.FS.readFile proposed

  let compared ← Loam.AnnualSourceMaterialization.compareInstalled? root candidate
  if mode == "refuse" then
    expect (!compared.isOk) "unsafe annual materialization accepted"
  else
    let generation ← required compared "exact annual source parity"
    expect (generation.wire == before && generation.wire == candidate)
      "qualified materialization differs from current"
    let actual ← required
      (← Loam.ActualAuthority.loadHouseholdObserved? root)
      "same-generation Actual source"
    expect (actual.generation.wire == generation.wire)
      "Actual reader selected another household generation"
    let scheduled ← required
      (Loam.ScheduledReview.fromGenerationForEvents
        actual.generation actual.image.evidence.events)
      "same-generation Scheduled source"
    let openEntries ← required
      (Loam.ScheduledReview.currentOpenRecords scheduled)
      "Scheduled current frontier"
    let openIds := openEntries.map (fun row => row.id.token)
    expect (openIds.contains "first" && !openIds.contains "paid")
      "native Scheduled completion reopened or disappeared"

  expect ((← IO.FS.readFile current) == before)
    "read-only parity changed installed source"
  expect ((← IO.FS.readFile proposed) == candidate)
    "read-only parity changed candidate"
  IO.println s!"NATIVE_ANNUAL_MATERIALIZATION_PREFLIGHT_PASS mode={mode}"

end Loam.Tools.NativeAnnualMaterializationPreflight

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualMaterializationPreflight.run args

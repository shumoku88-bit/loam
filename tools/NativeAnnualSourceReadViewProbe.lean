import Loam.Review.AnnualSourceReadView

namespace Loam.Tools.NativeAnnualSourceReadViewProbe

set_option autoImplicit false

/-!
Read-only qualification of an annual-source materialization against the real
native Actual+Scheduled review path. The caller supplies disposable test data.
No writes, no journal-source selection, and no production cutover.
-/

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) :
    IO α := do
  match value with
  | .ok result => return result
  | .error error => throw (IO.userError s!"{message}: {error}")

def run (args : List String) : IO Unit := do
  let [mode, rootText, candidateText] := args
    | throw (IO.userError
      "usage: NativeAnnualSourceReadViewProbe [match|refuse] ROOT CANDIDATE")
  expect (mode == "match" || mode == "refuse") "unknown probe mode"

  let root := System.FilePath.mk rootText
  let source := Loam.HouseholdAuthority.path root
  let candidatePath := System.FilePath.mk candidateText
  let before ← IO.FS.readFile source
  let candidate ← IO.FS.readFile candidatePath

  let result ← Loam.AnnualSourceReadView.compareInstalled? root candidate
  if mode == "refuse" then
    expect (!result.isOk) "annual read view accepted stale or incomplete candidate"
  else
    let snapshot ← requireOk result "qualified annual-source read view"
    expect (snapshot.generation.wire == before && candidate == before)
      "mixed read view generation or non-exact materialization"

    let native ← requireOk
      (← Loam.ActualAuthority.loadHouseholdObserved? root)
      "installed native Actual read"
    expect (native.generation.wire == snapshot.generation.wire)
      "Actual read sourced another generation"

    let expectedRecords := Loam.ActualReview.recordsFromActualImage native.image
    let ids := snapshot.actualRecords.map (fun row => row.event.id.token)
    expect (ids == expectedRecords.map (fun row => row.event.id.token))
      "lost or duplicated Actual identity"

    let current2027 :=
      Loam.ActualReview.select snapshot.actualRecords (.day "2027-01-03")
    expect (!current2027.isEmpty && current2027.all (fun row => row.isCurrent))
      "native cross-year correction winner lost its revised valid date"

    let nativeScheduled ← requireOk
      (Loam.ScheduledReview.fromGenerationForEvents
        native.generation native.image.evidence.events)
      "installed native cross-family Scheduled"
    let nativeOpen ← requireOk
      (Loam.ScheduledReview.orderedCurrentOpenRecords nativeScheduled)
      "installed Scheduled open frontier"
    let openIds := snapshot.openScheduled.map (fun row => row.id.token)
    expect (openIds == nativeOpen.map (fun row => row.id.token))
      "Scheduled view changed the native current-open frontier"
    expect (openIds.contains "first" && openIds.contains "exception" &&
            !openIds.contains "paid" && !openIds.contains "cancelled")
      "annual source read reopened completed Scheduled or hid open obligations"

  expect ((← IO.FS.readFile source) == before)
    "read-only annual adapter mutated source"
  expect ((← IO.FS.readFile candidatePath) == candidate)
    "read-only annual adapter mutated candidate"
  IO.println s!"NATIVE_ANNUAL_SOURCE_READ_VIEW_PASS mode={mode}"

end Loam.Tools.NativeAnnualSourceReadViewProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualSourceReadViewProbe.run args

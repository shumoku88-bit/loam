import Loam.Publisher.ScheduledTerminalPublisher
import Loam.Authority.HouseholdAuthority
import Loam.Authority.ActualAuthority
import Loam.Review.ScheduledReview
import Loam.Review.ActualReview
import Loam.Tests.Support

namespace Loam.Tools.NativeCrossFamilyYearSource

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

/-!
Real production Scheduled completion publisher across two simultaneously
changed source families. Fixture comes from ScheduledBatchReplacement setup
in a disposable test root; never run against loam-data.
-/

private def current (root : System.FilePath) : IO Loam.HouseholdAuthority.Generation :=
  requireOk (← Loam.HouseholdAuthority.loadCurrent? root)
    "qualified HouseholdImage generation"

private def openIds (root : System.FilePath) : IO (List String) := do
  let observed ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? root)
    "native Actual authority"
  let scheduled ← requireOk
    (Loam.ScheduledReview.fromGenerationForEvents observed.generation
      observed.image.evidence.events)
    "native Scheduled and full Actual closure"
  let records ← requireOk
    (Loam.ScheduledReview.currentOpenRecords scheduled)
    "native Scheduled current frontier"
  return records.map (fun entry => entry.id.token)

private def changedSections
    (before after : Loam.Persistence.HouseholdImage.Image) : List String :=
  before.sections.filterMap fun part =>
    if (Loam.Persistence.HouseholdImage.body? after part.name) != some part.body then
      some part.name
    else none

def run (args : List String) : IO Unit := do
  let [rootText, outText] := args
    | throw (IO.userError "usage: NativeCrossFamilyYearSource ROOT OUTPUT")
  let root := System.FilePath.mk rootText
  let out := System.FilePath.mk outText
  IO.FS.createDirAll out

  let before ← current root
  let openBefore ← openIds root
  expect (openBefore.contains "first") "fixture has no open Scheduled first"
  IO.FS.writeFile (out / "before.household.loam") before.wire

  let effects : List Effect :=
    [ Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-4800))
    , Effect.ofAnonymousQuantity ⟨"wifi"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 4800) ]
  let _ ← requireOk
    (← Loam.ScheduledTerminalPublisher.publishHouseholdCompletion root {
      scheduled := ⟨"first"⟩
      movement := {
        validOn := "2026-11-08"
        description := some "paid first Wi-Fi after year boundary"
        effects := effects
        relations := []
        discharges := []
        total := 4800
      }
    }) "native cross-family Scheduled completion"
  let after ← current root
  expect (before.wire != after.wire) "Scheduled completion was not published"
  let changed := changedSections before.image after.image
  expect (changed == ["Actual", "Scheduled"] || changed == ["Scheduled", "Actual"])
    "Scheduled completion changed something other than exactly Actual+Scheduled"
  for part in before.image.sections do
    if part.name != "Actual" && part.name != "Scheduled" then
      expect (Loam.Persistence.HouseholdImage.body? after.image part.name == some part.body)
        ("unrelated or unknown source family changed: " ++ part.name)
  let openAfter ← openIds root
  expect (!openAfter.contains "first" && !openAfter.contains "paid" &&
          openAfter.contains "second")
    "completed Scheduled returned to open frontier"
  let actual ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? root)
    "native Actual completion evidence"
  let rows := Loam.ActualReview.recordsFromActualImage actual.image
  let completion ← requireSome
    (rows.find? (fun row => row.event.id.token == "scheduled-completion:first"))
    "native completion Actual Event is missing"
  expect completion.isCurrent "native completion Actual is not current"
  IO.FS.writeFile (out / "after.household.loam") after.wire
  IO.println s!"NATIVE_CROSS_FAMILY_YEAR_PASS before={before.wire.utf8ByteSize} after={after.wire.utf8ByteSize} families=Actual,Scheduled"

end Loam.Tools.NativeCrossFamilyYearSource

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeCrossFamilyYearSource.run args

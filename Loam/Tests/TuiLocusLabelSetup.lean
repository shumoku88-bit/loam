import Loam.Cli.NewHouseholdCli
import Loam.HouseholdCommand
import Loam.HouseholdPaths
import Loam.Authority.HouseholdAuthority
import Loam.Presentation.LocusCatalog
import Loam.Tui.LocusLabelSetup
import Loam.Tui.LocusLabelSetupSession
import Loam.Tui.Runtime
import Loam.Tests.Support

namespace Loam.Tests.TuiLocusLabelSetup

open Loam.Tests.Support

set_option autoImplicit false

def main : IO Unit := do
  let base ← IO.FS.createTempDir
  let root := base / "fresh"
  let _ ← requireOk (← Loam.NewHouseholdCli.create root)
    "create independent synthetic household"
  let config := Loam.HouseholdPaths.locusCatalog root
  let empty ← requireOk
    (← Loam.Tui.LocusLabelSetupSession.prepare root)
    "read display catalog in a fresh household"
  expect empty.catalog.isEmpty
    "fresh household unexpectedly admitted any Locus"
  let fresh := Loam.Tui.LocusLabelSetup.initial empty.catalog
  let noChoice := Loam.Tui.LocusLabelSetup.update fresh .enter
  expect (noChoice.publish.isNone && noChoice.state.phase == .choose)
    "empty household could assign label to an unadmitted identity"
  expect (!(← config.pathExists))
    "opening display editor published empty metadata"

  for token in ["bank", "food"] do
    let _ ← requireOk
      (← Loam.HouseholdCommand.admitLocus root { token })
      "admit synthetic account or expense identity"
    pure ()
  let ready ← requireOk
    (← Loam.Tui.LocusLabelSetupSession.prepare root)
    "load the admitted Locus display choices"
  expect (ready.catalog.length == 2 &&
          ready.catalog.head?.map (·.locus.token) == some "bank")
    "admitted identities did not appear in friendly label picker"

  let state := Loam.Tui.LocusLabelSetup.initial ready.catalog
  let picked := Loam.Tui.LocusLabelSetup.update state .enter
  expect (picked.state.phase == .editing && picked.publish.isNone)
    "first Enter did not begin editing the selected admitted Locus"
  let typed := (["ゆ", "う", "ち", "ょ"].foldl
    (fun editor piece =>
      (Loam.Tui.LocusLabelSetup.update editor (.paste piece)).state) picked.state)
  let review := Loam.Tui.LocusLabelSetup.update typed .enter
  expect (review.state.phase == .review && review.publish.isNone)
    "display name preview published without confirmation"
  let back := Loam.Tui.LocusLabelSetup.update review.state .escape
  expect (back.state.phase == .editing && back.publish.isNone)
    "Esc from display-name preview did not edit"
  let confirm := Loam.Tui.LocusLabelSetup.update review.state .enter
  let some draft := confirm.publish
    | throw (IO.userError "second Enter did not expose reviewed display label")
  expect (draft.token == "bank" && draft.label == "ゆうちょ")
    "friendly name changed the stable account identity"
  let oldBytes ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let _ ← requireOk
    (← Loam.Tui.LocusLabelSetupSession.save root ready draft)
    "save admitted bank display label"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == oldBytes)
    "display label rewrote canonical household or transactions"
  let metadata ← requireOk (← Loam.LocusCatalog.loadMetadata root)
    "read typed presentation catalog after save"
  expect (Loam.LocusCatalog.labelForToken metadata "bank" == "ゆうちょ" &&
          Loam.LocusCatalog.labelForToken metadata "food" == "food")
    "display label did not round-trip with unaffected fallback token"
  expect ((Loam.LocusCatalog.metadataForToken? metadata "bank").map (·.help) ==
          some "ゆうちょ")
    "new display label did not get a nonempty codec-compatible help fallback"

  -- Existing user help and historical-only presentation metadata survive.
  IO.FS.writeFile config
    "archived\t古い口座\t以前の記録\nbank\tゆうちょ\t既存の口座説明\n"
  let previous ← requireOk
    (← Loam.Tui.LocusLabelSetupSession.prepare root)
    "load historical-only display row alongside active bank"
  let nextDraft : Loam.Tui.LocusLabelSetup.Draft :=
    { token := "bank", label := "銀行口座" }
  let _ ← requireOk
    (← Loam.Tui.LocusLabelSetupSession.save root previous nextDraft)
    "change friendly label without changing help or archive"
  let retained ← requireOk
    (← Loam.LocusCatalog.loadMetadata root)
    "read labels after editing existing metadata"
  expect ((Loam.LocusCatalog.metadataForToken? retained "bank").map (·.help) ==
          some "既存の口座説明" &&
          (Loam.LocusCatalog.metadataForToken? retained "archived").map (·.label) ==
          some "古い口座")
    "editing bank label lost previous help or historical-only metadata"

  -- Old editor state cannot clobber a later metadata publication.
  let stale ← requireOk
    (← Loam.Tui.LocusLabelSetupSession.prepare root)
    "capture candidate before concurrent change"
  IO.FS.writeFile config "bank\t別の名前\t説明\n"
  let changed ← IO.FS.readFile config
  expect (!(← Loam.Tui.LocusLabelSetupSession.save root stale nextDraft).isOk)
    "stale editor clobbered a newer display catalog"
  expect ((← IO.FS.readFile config) == changed)
    "stale display-name refusal changed metadata"

  -- Corrupt metadata is not an empty state and must never be auto-repaired.
  IO.FS.writeFile config "bank\tbroken\n"
  expect (!(← Loam.Tui.LocusLabelSetupSession.prepare root).isOk)
    "malformed existing display labels silently reset"
  expect ((← IO.FS.readFile config) == "bank\tbroken\n")
    "opening malformed label config wrote new bytes"

  -- A new canonical Locus admission invalidates a previously opened editor.
  IO.FS.writeFile config "bank\t銀行\t銀行の説明\n"
  let oldAdmission ← requireOk
    (← Loam.Tui.LocusLabelSetupSession.prepare root)
    "capture admission-before-change"
  let _ ← requireOk
    (← Loam.HouseholdCommand.admitLocus root { token := "cash" })
    "admit another account after editor opened"
  expect (!(← Loam.Tui.LocusLabelSetupSession.save root oldAdmission nextDraft).isOk)
    "old editor changed metadata after canonical admission changed"

  let invalid := { typed with entered := "bad\tname" }
  expect (!(Loam.Tui.LocusLabelSetup.parse invalid).isOk)
    "tab injection was admitted as a display name"
  let stripped := Loam.Tui.LocusLabelSetup.update picked.state
    (.paste "名前\n\t\x1b[31m")
  expect (!(stripped.state.entered.toList.any fun c => c.toNat < 32))
    "paste introduced a control sequence into display name"

  for bounds in
    ([{ width := 32, height := 9 }, { width := 80, height := 24 }] :
      List Loam.Tui.Kernel.Bounds) do
    for editor in [state, picked.state, typed, review.state] do
      let widget := Loam.Tui.LocusLabelSetup.view bounds editor
      expect (decide (widget.lines.length ≤ bounds.height))
        "friendly-name screen exceeds terminal height"
      for cells in widget.lines do
        expect (decide (Loam.Tui.Layout.displayWidth
            (String.ofList (cells.map (·.glyph))) ≤
            Loam.Tui.Layout.contentWidth bounds))
          "friendly-name screen exceeds terminal width"
  IO.println "Friendly Locus labels: admitted-only, Japanese display, preview/cancel, historic help preservation, stale/malformed/admission-change refusal, canonical separation and bounded terminal layout passed."

end Loam.Tests.TuiLocusLabelSetup

def main : IO Unit := Loam.Tests.TuiLocusLabelSetup.main

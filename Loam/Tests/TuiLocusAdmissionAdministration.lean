import Loam.Tui.LocusAdmissionAdministration

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def catalog : Loam.LocusCatalog.Catalog :=
  [ { locus := ⟨"book"⟩, label := "書籍", help := "本・学習用の書籍" }
  , { locus := ⟨"misc"⟩, label := "予備・雑費", help := "頻度の低い一回物" }
  ]

private def typeText
    (state : Loam.Tui.LocusAdmissionAdministration.State) (text : String) :
    Loam.Tui.LocusAdmissionAdministration.State :=
  text.toList.foldl
    (fun current char => (Loam.Tui.LocusAdmissionAdministration.update current (.input char)).state)
    state

def main : IO Unit := do
  let initial := Loam.Tui.LocusAdmissionAdministration.initial catalog
  expect (initial.catalog.length == 2) "current admitted catalog was not retained"

  let withBook := typeText initial "book"
  expect (withBook.entered == "book") "printable token characters were intercepted by navigation"
  let duplicate := Loam.Tui.LocusAdmissionAdministration.update withBook .enter
  expect (duplicate.publish.isNone) "duplicate token emitted publication"
  expect (duplicate.state.phase == .editing) "duplicate token left editing mode"
  expect (!duplicate.state.notice.isEmpty) "duplicate token did not explain refusal"

  let cleared := { initial with entered := "" }
  let withNew := typeText cleared "stationery"
  let preview := Loam.Tui.LocusAdmissionAdministration.update withNew .enter
  expect (preview.state.phase == .preview) "valid token did not enter preview"
  expect (preview.publish.isNone) "preview published without explicit confirmation"
  let publish := Loam.Tui.LocusAdmissionAdministration.update preview.state .enter
  let some draft := publish.publish | throw (IO.userError "preview confirmation emitted no draft")
  expect (draft.token == "stationery") "published draft lost stable token"

  let invalid := typeText initial "bad token"
  let invalidStep := Loam.Tui.LocusAdmissionAdministration.update invalid .enter
  expect (invalidStep.state.phase == .editing) "invalid token entered preview"
  expect (invalidStep.publish.isNone) "invalid token emitted publication"

  let scrolled := Loam.Tui.LocusAdmissionAdministration.update initial .down
  expect (scrolled.state.scroll == 1) "down arrow did not inspect the next existing Locus"
  let cancelled := Loam.Tui.LocusAdmissionAdministration.update initial .escape
  expect cancelled.cancel "escape did not cancel administration"

  IO.println "TUI Locus admission administration: visibility, typing, preview and refusal passed."

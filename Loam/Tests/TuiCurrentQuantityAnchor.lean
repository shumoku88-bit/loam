import Loam.Tui.CurrentQuantityAnchor
import Loam.Tui.Kernel
import Loam.Tui.Terminal

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def typeText
    (state : Loam.Tui.CurrentQuantityAnchor.State) (text : String) :
    Loam.Tui.CurrentQuantityAnchor.State :=
  text.toList.foldl
    (fun current char =>
      (Loam.Tui.CurrentQuantityAnchor.update current (.input char)).state)
    state

private def press
    (state : Loam.Tui.CurrentQuantityAnchor.State) (key : Loam.Tui.Terminal.Key) :
    Loam.Tui.CurrentQuantityAnchor.State :=
  (Loam.Tui.CurrentQuantityAnchor.update state key).state

private def assertion (locus : String) (quanta : Int) : Loam.CurrentQuantityAnchor.Assertion := {
  coordinate := ⟨⟨locus⟩, ⟨"jpy"⟩⟩
  quantity := Quantity.ofQuanta quanta
}

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

def main : IO Unit := do
  let enteredLocus := typeText Loam.Tui.CurrentQuantityAnchor.initial "mother-wifi-debt"
  let quantityFocus := press (press enteredLocus .tab) .tab
  let enteredQuantity := typeText quantityFocus "-12345"
  let addStep := Loam.Tui.CurrentQuantityAnchor.update enteredQuantity .enter
  expect (addStep.state.assertions == [assertion "mother-wifi-debt" (-12345)])
    "quantity Enter did not append the exact observed row"
  expect (addStep.state.form.measure == "jpy")
    "adding an observation did not retain the practical measure default"
  expect (addStep.state.form.locus.isEmpty && addStep.state.form.quantity.isEmpty)
    "adding an observation did not clear the next-row locus and quantity"

  let previewFocus :=
    press (press (press (press addStep.state .tab) .tab) .tab) .tab
  let previewState := (Loam.Tui.CurrentQuantityAnchor.update previewFocus .enter).state
  let publishStep := Loam.Tui.CurrentQuantityAnchor.update previewState .enter
  let published ← requireSome publishStep.publish
    "preview Publish did not emit the complete observation image"
  expect (published == [assertion "mother-wifi-debt" (-12345)])
    "published TUI intent changed the observed coordinate or quantity"

  let duplicate := assertion "same-coordinate" 5
  let duplicateState : Loam.Tui.CurrentQuantityAnchor.State := {
    assertions := [duplicate, duplicate]
    form := { focus := 4 }
  }
  let duplicatePreview :=
    (Loam.Tui.CurrentQuantityAnchor.update duplicateState .enter).state
  let duplicatePublish := Loam.Tui.CurrentQuantityAnchor.update duplicatePreview .enter
  let duplicateImage ← requireSome duplicatePublish.publish
    "duplicate-coordinate preview did not reach the publisher boundary"
  expect (duplicateImage.length == 2)
    "TUI silently introduced coordinate uniqueness semantics"

  let badQuantityState : Loam.Tui.CurrentQuantityAnchor.State := {
    form := { locus := "wifi", measure := "jpy", quantity := "12x", focus := 2 }
  }
  let badStep := Loam.Tui.CurrentQuantityAnchor.update badQuantityState .enter
  expect badStep.state.assertions.isEmpty
    "noninteger quantity became an observation"
  expect (!badStep.state.notice.isEmpty)
    "noninteger quantity did not produce local representation feedback"

  let previewText := widgetText (Loam.Tui.CurrentQuantityAnchor.view previewState)
  expect (contains "replaces the current anchor image" previewText)
    "preview no longer explains complete-image replacement semantics"
  expect (contains "shared publisher derives the Event root cut" previewText)
    "preview no longer exposes the publisher-owned cut boundary"

  IO.println "Current quantity TUI: complete-image observation intent qualified without reconciliation semantics."

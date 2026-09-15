import Loam.Tui.AttentionCli

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def due : Attention String :=
  { id := ⟨"attention-due"⟩
    context := "cancel subscription"
    due := .dueOn "2026-10-01" }

private def noDue : Attention String :=
  { id := ⟨"attention-no-due"⟩
    context := "watch refund"
    due := .noDueDate }

private def unknownDue : Attention String :=
  { id := ⟨"attention-unknown"⟩
    context := "watch unexpected income timing"
    due := .dueUndetermined }

private def typeText
    (state : Loam.Tui.AttentionAdministration.State)
    (text : String) : Loam.Tui.AttentionAdministration.State :=
  text.toList.foldl
    (fun current char =>
      (Loam.Tui.AttentionAdministration.update current (.input char)).state)
    state

def main : IO Unit := do
  let admin0 := Loam.Tui.AttentionAdministration.initial .unavailable "2026-09-16"
  let adminText := widgetText (Loam.Tui.AttentionAdministration.view admin0)
  expect (contains "No canonical Attention stream yet" adminText)
    "administration hid the unavailable bootstrap state"
  expect (contains "Press n to create the first household matter" adminText)
    "administration did not expose the first-write entrance"

  let new0 := (Loam.Tui.AttentionAdministration.update admin0 (.input 'n')).state
  let new1 := typeText new0 "watch refund"
  let new2 := (Loam.Tui.AttentionAdministration.update new1 .enter).state
  let addUnknown := Loam.Tui.AttentionAdministration.update new2 (.input 'u')
  match addUnknown.add with
  | some draft =>
      expect (draft.context == "watch refund") "new Attention context changed before publication"
      expect (draft.due == AttentionDue.dueUndetermined)
        "unknown due meaning collapsed during TUI creation"
  | none => throw (IO.userError "Attention new-item wizard did not emit publication intent")

  let dated0 := (Loam.Tui.AttentionAdministration.update admin0 (.input 'n')).state
  let dated1 := typeText dated0 "cancel subscription"
  let dated2 := (Loam.Tui.AttentionAdministration.update dated1 .enter).state
  let dated3 := (Loam.Tui.AttentionAdministration.update dated2 (.input 'd')).state
  let dated4 := typeText dated3 "2026-10-01"
  let datedStep := Loam.Tui.AttentionAdministration.update dated4 .enter
  match datedStep.add with
  | some draft =>
      expect (draft.context == "cancel subscription") "dated Attention context changed"
      expect (draft.due == AttentionDue.dueOn "2026-10-01")
        "known due date changed before publication"
  | none => throw (IO.userError "dated Attention wizard did not emit publication intent")

  let noDue0 := (Loam.Tui.AttentionAdministration.update admin0 (.input 'n')).state
  let noDue1 := typeText noDue0 "watch refund without promised date"
  let noDue2 := (Loam.Tui.AttentionAdministration.update noDue1 .enter).state
  let addNoDue := Loam.Tui.AttentionAdministration.update noDue2 (.input 'n')
  match addNoDue.add with
  | some draft =>
      expect (draft.due == AttentionDue.noDueDate)
        "no-due meaning collapsed during TUI creation"
  | none => throw (IO.userError "no-due Attention wizard did not emit publication intent")

  let openEvidence : Loam.AttentionReview.Availability :=
    .available { openItems := [due, noDue, unknownDue] }
  let adminOpen := Loam.Tui.AttentionAdministration.initial openEvidence "2026-09-16"
  let resolveConfirm :=
    (Loam.Tui.AttentionAdministration.update adminOpen (.input 'r')).state
  let resolveStep := Loam.Tui.AttentionAdministration.update resolveConfirm .enter
  match resolveStep.close with
  | some draft =>
      expect (draft.attention == due.id) "resolve intent changed selected Attention identity"
      expect (draft.knownOn == "2026-09-16") "resolve intent lost explicit current date"
      expect (draft.kind == AttentionClosureKind.resolved) "resolve intent changed closure kind"
  | none => throw (IO.userError "resolve confirmation did not emit closure intent")

  let secondSelected := (Loam.Tui.AttentionAdministration.update adminOpen .down).state
  let dropConfirm :=
    (Loam.Tui.AttentionAdministration.update secondSelected (.input 'x')).state
  let dropStep := Loam.Tui.AttentionAdministration.update dropConfirm .enter
  match dropStep.close with
  | some draft =>
      expect (draft.attention == noDue.id) "drop intent changed selected Attention identity"
      expect (draft.kind == AttentionClosureKind.dropped) "drop intent changed closure kind"
  | none => throw (IO.userError "drop confirmation did not emit closure intent")

  IO.println "Attention administration TUI: bootstrap, due choices, selection, resolve and drop intents passed."

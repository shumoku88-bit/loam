import Loam.AttentionReview
import Loam.HouseholdCommand
import Loam.Tui.AttentionAdministration

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

  -- Empty context is refused before choosing due meaning.
  let emptyContext := (Loam.Tui.AttentionAdministration.update new0 .enter).state
  expect (emptyContext.mode == .newContext "") "empty context advanced to due meaning"
  expect (contains "Enter a short household matter" emptyContext.notice)
    "empty context did not show descriptive feedback"

  -- Invalid calendar date is refused in dated due mode.
  let invalidDate0 := typeText dated3 "2026-02-31"
  let invalidStep := Loam.Tui.AttentionAdministration.update invalidDate0 .enter
  expect (invalidStep.add.isNone) "invalid date emitted publication intent"
  expect (invalidStep.state.mode == .newDate "cancel subscription" "2026-02-31")
    "invalid date left date editor"
  expect (contains "Enter a real calendar date in YYYY-MM-DD form" invalidStep.state.notice)
    "invalid date did not produce calendar feedback"

  -- Back navigation from browse mode.
  expect (Loam.Tui.AttentionAdministration.update admin0 .escape).back
    "Esc did not return back intent"
  expect (Loam.Tui.AttentionAdministration.update admin0 (.input 'q')).back
    "q did not return back intent"
  expect (Loam.Tui.AttentionAdministration.update admin0 (.input 'b')).back
    "b did not return back intent"

  -- Selection bounds: moveCursor cycles.
  let openEvidence : Loam.AttentionReview.Availability :=
    .available { openItems := [due, noDue, unknownDue] }
  let adminOpen := Loam.Tui.AttentionAdministration.initial openEvidence "2026-09-16"
  let upSelected := (Loam.Tui.AttentionAdministration.update adminOpen .up).state
  expect (upSelected.cursor == 2) "Up from top did not cycle to bottom"
  let downSelected := (Loam.Tui.AttentionAdministration.update upSelected .down).state
  expect (downSelected.cursor == 0) "Down from bottom did not cycle to top"

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

  -- Publisher refusal leaves evidence untouched and displays the error notice.
  let errorState := Loam.Tui.AttentionAdministration.withPublishError adminOpen "publication refused"
  expect (errorState.mode == .browse) "error did not return to browse mode"
  expect (errorState.notice == "publication refused") "error notice was not preserved"
  match errorState.evidence with
  | .available snap =>
      expect (snap.openItems.map Attention.id == [due.id, noDue.id, unknownDue.id])
        "publisher refusal corrupted evidence"
  | .unavailable => throw (IO.userError "publisher refusal made evidence unavailable")

  -- Attention / Manage entrance view verification.
  let manageText := widgetText (Loam.Tui.AttentionAdministration.view adminOpen)
  expect (contains "Attention / Manage" manageText) "view missing Attention / Manage heading"
  expect (contains "Household matters that should not disappear from view" manageText)
    "view missing descriptive subtitle"
  expect (contains "n new   r resolve today   x drop today   Up/Down select" manageText)
    "view missing action help footer"

  -- End-to-end lifecycle in an isolated temporary directory:
  -- 1. Missing file produces unavailable bootstrap view.
  -- 2. addAttention bootstraps file and publishes item.
  -- 3. Reloading evidence reflects the new item in Attention / Manage.
  -- 4. closeAttention resolves the item.
  -- 5. Reloading evidence reflects 0 open items.
  let tmpRoot := (System.FilePath.mk "/tmp") / "loam-attention-tui-test"
  try
    if ← tmpRoot.pathExists then
      IO.FS.removeDirAll tmpRoot
    IO.FS.createDirAll tmpRoot

    let initialLoad ← Loam.AttentionReview.loadEvidence (tmpRoot / "attention.loam")
    match initialLoad with
    | .ok .unavailable => pure ()
    | _ => throw (IO.userError "bootstrap did not report unavailable")
    let bootstrapAdmin := Loam.Tui.AttentionAdministration.initial .unavailable "2026-09-16"
    let bootstrapText := widgetText (Loam.Tui.AttentionAdministration.view bootstrapAdmin)
    expect (contains "Attention / Manage" bootstrapText) "view missing Attention / Manage heading"
    expect (contains "No canonical Attention stream yet" bootstrapText) "bootstrap missing stream text"

    -- Publish a new attention item
    let addDraft : Loam.AttentionPublisher.AddDraft := {
      context := "renew passport"
      due := .dueOn "2026-11-20"
    }
    let addedId ←
      match ← Loam.HouseholdCommand.addAttention tmpRoot addDraft with
      | .ok id => pure id
      | .error message => throw (IO.userError message)
    expect (addedId.token == "attention-1") "first attention id unexpected"

    -- Reload evidence and refresh administration view
    let reloadedLoad ← Loam.AttentionReview.loadEvidence (tmpRoot / "attention.loam")
    let .ok reloadedEvidence := reloadedLoad | throw (IO.userError "reloading evidence failed")
    let adminRefreshed := Loam.Tui.AttentionAdministration.initial reloadedEvidence "2026-09-16"
    let refreshedText := widgetText (Loam.Tui.AttentionAdministration.view adminRefreshed)
    expect (contains "renew passport" refreshedText) "refreshed view missing newly added item"
    expect (contains "due 2026-11-20" refreshedText) "refreshed view missing due date"

    -- Close (resolve) the item
    let closeDraft : Loam.AttentionPublisher.CloseDraft := {
      attention := addedId
      knownOn := "2026-09-16"
      kind := .resolved
    }
    match ← Loam.HouseholdCommand.closeAttention tmpRoot closeDraft with
    | .ok () => pure ()
    | .error message => throw (IO.userError message)

    -- Reload evidence and refresh administration view
    let closedLoad ← Loam.AttentionReview.loadEvidence (tmpRoot / "attention.loam")
    let .ok closedEvidence := closedLoad | throw (IO.userError "reloading closed evidence failed")
    let adminClosed := Loam.Tui.AttentionAdministration.initial closedEvidence "2026-09-16"
    let closedText := widgetText (Loam.Tui.AttentionAdministration.view adminClosed)
    expect (contains "0 open" closedText) "closed item remained open in view"
    expect (!contains "renew passport" closedText) "resolved item context remained visible in open view"
  finally
    if ← tmpRoot.pathExists then
      IO.FS.removeDirAll tmpRoot

  IO.println "Attention administration TUI: bootstrap, due choices, invalid date refusal, selection, resolve and drop intents, error handling, Home integration, and end-to-end publication passed."

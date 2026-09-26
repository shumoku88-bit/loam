import Loam.Tui.BoundedHistorySupportAdministration

open Loam.Core
open Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def row
    (locus : String)
    (start : Option String)
    (hasAnchor : Bool) : Loam.BoundedHistorySupportReview.Row := {
  coordinate := ⟨⟨locus⟩, ⟨"jpy"⟩⟩
  startDay := start
  hasExactCurrentAnchor := hasAnchor
}

private def typeText
    (state : Loam.Tui.BoundedHistorySupportAdministration.State)
    (text : String) : Loam.Tui.BoundedHistorySupportAdministration.State :=
  text.toList.foldl
    (fun current char =>
      (Loam.Tui.BoundedHistorySupportAdministration.update current (.input char)).state)
    state

def main : IO Unit := do
  let snapshot : Loam.BoundedHistorySupportReview.Snapshot := {
    rows := [
      row "cash" none true,
      row "bank" (some "2026-04-04") true,
      row "stale" (some "2026-05-01") false
    ]
  }
  let initial := Loam.Tui.BoundedHistorySupportAdministration.initial snapshot
  expect initial.startDay.isEmpty
    "history support TUI invented a default start day"

  let dated := typeText initial "2026-09-01"
  let some draft := Loam.Tui.BoundedHistorySupportAdministration.draft? dated
    | throw (IO.userError "valid explicit start did not form a draft")
  expect (draft.coordinate.locus.token == "cash" && draft.startDay == some "2026-09-01")
    "history support TUI changed explicit coordinate/start"

  let preview := Loam.Tui.BoundedHistorySupportAdministration.update dated .enter
  expect (preview.state.phase == .preview && preview.publish.isNone)
    "history support first Enter did not enter preview"
  let publish := Loam.Tui.BoundedHistorySupportAdministration.update preview.state .enter
  expect (publish.publish == some draft)
    "history support preview confirmation changed the draft"

  let bank :=
    (Loam.Tui.BoundedHistorySupportAdministration.update initial .down).state
  expect (bank.startDay == "2026-04-04")
    "history support candidate navigation did not load retained start"
  let cleared :=
    String.toList bank.startDay |>.foldl
      (fun state _ =>
        (Loam.Tui.BoundedHistorySupportAdministration.update state .backspace).state)
      bank
  let some clearDraft := Loam.Tui.BoundedHistorySupportAdministration.draft? cleared
    | throw (IO.userError "empty retained start did not form removal draft")
  expect (clearDraft.coordinate.locus.token == "bank" && clearDraft.startDay.isNone)
    "history support removal draft changed coordinate or retained a date"

  let stale :=
    (Loam.Tui.BoundedHistorySupportAdministration.update bank .down).state
  let staleCleared :=
    String.toList stale.startDay |>.foldl
      (fun state _ =>
        (Loam.Tui.BoundedHistorySupportAdministration.update state .backspace).state)
      stale
  expect (Loam.Tui.BoundedHistorySupportAdministration.draft? staleCleared).isSome
    "stale support without current anchor could not be removed"

  let staleChanged := typeText staleCleared "2026-06-01"
  expect (Loam.Tui.BoundedHistorySupportAdministration.draft? staleChanged).isNone
    "stale support without current anchor was changeable"

  let invalid := typeText initial "2026-02-29"
  expect (Loam.Tui.BoundedHistorySupportAdministration.draft? invalid).isNone
    "history support TUI accepted invalid calendar date"

  let empty :=
    Loam.Tui.BoundedHistorySupportAdministration.initial { rows := [] }
  let refused := Loam.Tui.BoundedHistorySupportAdministration.update empty .enter
  expect (refused.publish.isNone && !refused.state.notice.isEmpty)
    "empty history support candidate set failed without explanation"

  let cancel := Loam.Tui.BoundedHistorySupportAdministration.update initial .escape
  expect cancel.cancel "Esc did not cancel history support administration"

  IO.println
    "Bounded history support TUI: explicit certification, preview, move/remove, stale cleanup and refusal paths passed."

import Loam.Application.ScheduledBulkEdit
import Loam.Presentation.MeasurePresentation
import Loam.Tui.EditorSession
import Loam.Tui.Layout

namespace Loam.Tui.ScheduledBulkEdit

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
Presentation-only amount/range input, explicit checkbox selection, and reviewed
replacement drafts. Back is the initial preview action. Publication is emitted
only by Publish all, and stale refusal belongs to the session's reload boundary.
-/

inductive Mode where
  | parameters
  | selection
  | preview (draft : Loam.ScheduledReplacementPublisher.BatchDraft)

structure State where
  observedWire : String
  source : Loam.ScheduledBulkEdit.Record
  candidates : List Loam.ScheduledBulkEdit.Record
  presentation : List Loam.MeasurePresentation.Metadata := []
  fromDate : String
  throughDate : String := ""
  amount : String := ""
  focus : Nat := 0
  row : Nat := 0
  selected : List ScheduledId := []
  mode : Mode := .parameters
  choice : Nat := 0
  notice : String := ""

abbrev Step := Loam.Tui.EditorSession.Step State Loam.ScheduledReplacementPublisher.BatchDraft

def initial
    (wire : String) (source : Loam.ScheduledBulkEdit.Record)
    (candidates : List Loam.ScheduledBulkEdit.Record) (fromDate : String)
    (presentation : List Loam.MeasurePresentation.Metadata := []) : State :=
  { observedWire := wire, source, candidates, fromDate, presentation }

def visibleCandidates (state : State) : List Loam.ScheduledBulkEdit.Record :=
  state.candidates.filter fun record =>
    Loam.ScheduledBulkEdit.inPeriod record state.fromDate state.throughDate

private def amount? (state : State) : Except String Int := do
  let some amount := Loam.MeasurePresentation.parseQuanta?
      state.presentation state.source.measure state.amount
    | throw ("Enter an exact " ++ state.source.measure.token ++ " amount (no rounding).")
  if amount <= 0 then throw "Enter a positive amount."
  return amount

private def chooseCandidates (state : State) : State :=
  match (do
      Loam.ScheduledBulkEdit.validatePeriod state.fromDate state.throughDate
      let _ ← amount? state
      pure () : Except String Unit) with
  | .error message => { state with notice := message }
  | .ok () => { state with mode := .selection, selected := [], row := 0, notice := "" }

private def preview (state : State) : State :=
  let proposal : Except String Loam.ScheduledReplacementPublisher.BatchDraft := do
    Loam.ScheduledBulkEdit.validatePeriod state.fromDate state.throughDate
    let amount ← amount? state
    let drafts ← Loam.ScheduledBulkEdit.amountDrafts (visibleCandidates state) state.selected amount
    return { observedWire := state.observedWire, drafts := drafts }
  match proposal with
  | .error message => { state with notice := message }
  | .ok draft => { state with mode := .preview draft, row := 0, choice := 0, notice := "" }

private def editField (state : State) (edit : String → String) : State :=
  match state.focus % 3 with
  | 0 => { state with amount := edit state.amount, notice := "" }
  | 1 => { state with fromDate := edit state.fromDate, notice := "" }
  | _ => { state with throughDate := edit state.throughDate, notice := "" }

private def moveRow (state : State) (count : Nat) (back : Bool) : State :=
  { state with row := if back then state.row - 1 else min (count - 1) (state.row + 1) }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .parameters =>
      match key with
      | .escape => { state, cancel := true }
      | .tab | .down => { state := { state with focus := (state.focus + 1) % 3 } }
      | .shiftTab | .up => { state := { state with focus := (state.focus + 2) % 3 } }
      | .backspace => { state := editField state Loam.Tui.Terminal.backspaceText }
      | .input char => { state := editField state (fun text => text.push char) }
      | .paste text => { state := editField state (· ++ Loam.Tui.Terminal.singleLinePaste text) }
      | .enter => { state := chooseCandidates state }
      | _ => { state }
  | .selection =>
      let records := visibleCandidates state
      match key with
      | .escape => { state, cancel := true }
      | .up | .input 'k' => { state := moveRow state records.length true }
      | .down | .input 'j' => { state := moveRow state records.length false }
      | .home => { state := { state with row := 0 } }
      | .«end» => { state := { state with row := records.length - 1 } }
      | .input ' ' =>
          match records[state.row]? with
          | none => { state }
          | some record =>
              let selected :=
                if state.selected.contains record.id then state.selected.filter (· != record.id)
                else state.selected ++ [record.id]
              { state := { state with selected, notice := "" } }
      | .input 'a' => { state := { state with selected := records.map (·.id), notice := "" } }
      | .input 'd' => { state := { state with selected := [], notice := "" } }
      | .input 'e' => { state := { state with mode := .parameters, notice := "" } }
      | .enter => { state := preview state }
      | _ => { state }
  | .preview draft =>
      match key with
      | .escape => { state := { state with mode := .selection, row := 0, notice := "" } }
      | .up | .input 'k' => { state := moveRow state draft.drafts.length true }
      | .down | .input 'j' => { state := moveRow state draft.drafts.length false }
      | .home => { state := { state with row := 0 } }
      | .«end» => { state := { state with row := draft.drafts.length - 1 } }
      | .tab | .right => { state := { state with choice := (state.choice + 1) % 3 } }
      | .shiftTab | .left => { state := { state with choice := (state.choice + 2) % 3 } }
      | .enter =>
          match state.choice % 3 with
          | 0 => { state := { state with mode := .selection, row := 0 } }
          | 1 => { state, publish := some draft }
          | _ => { state, cancel := true }
      | _ => { state }

private def amountText (state : State) (amount : Int) : String :=
  Loam.MeasurePresentation.formatGroupedQuanta state.presentation state.source.measure amount

private def recordText (state : State) (record : Loam.ScheduledBulkEdit.Record) : String :=
  let amount :=
    match Loam.ScheduledBulkEdit.simpleAmount? record with
    | some value => amountText state value
    | none => "split: edit individually"
  let shape := Loam.ScheduledCoverageSelector.ofRecord record
  record.scheduledOn ++ "  " ++ amount ++ " " ++ record.measure.token ++ "  " ++
    String.intercalate "," shape.negativeLoci ++ " -> " ++
    String.intercalate "," shape.positiveLoci ++ "  " ++ record.id.token

/-- A finite viewport keeps the selected candidate/preview visible; footer never scrolls. -/
def view (bounds : Bounds) (state : State) : Widget := Id.run do
  let width := Loam.Tui.Layout.contentWidth bounds
  let line := fun (text : String) => Widget.row [span (Loam.Tui.Layout.clip width text)]
  let muted := fun (text : String) => Widget.row [span (Loam.Tui.Layout.clip width text) .muted]
  let helpLines := fun (tokens : List String) =>
    (Loam.Tui.Layout.flowTokens width "  " tokens).map muted
  let header := [line "Scheduled / Batch amount edit",
    muted "Similarity is a suggestion, not proof of the same contract. You choose the targets."]
  let notice := if state.notice.isEmpty then [] else [line state.notice]
  let (body, help) := match state.mode with
    | .parameters =>
        let fields := ["New amount (" ++ state.source.measure.token ++ "): " ++ state.amount,
          "From (inclusive): " ++ state.fromDate,
          "Through (inclusive): " ++ state.throughDate]
        let rows := fields.zipIdx.map fun (text, index) =>
          Widget.row [span (Loam.Tui.Layout.clip width
            ((if index == state.focus then "> " else "  ") ++ text))
            (if index == state.focus then .selected else .normal)]
        (header ++ [muted ("Reference: " ++ recordText state state.source)] ++ rows ++
          [muted "Empty Through = all retained later dates.",
           muted "Dates/Loci/Measure unchanged; no guessed split allocations."] ++ notice,
          helpLines ["[Tab/Shift-Tab] field", "[Enter] candidates", "[Esc] cancel"])
    | .selection =>
        let records := visibleCandidates state
        let fixed := header ++
          [line ("New amount: " ++ state.amount ++ " " ++ state.source.measure.token),
           line ("Period: " ++ state.fromDate ++ " .. " ++
            (if state.throughDate.isEmpty then "all later dates" else state.throughDate)),
           line (toString state.selected.length ++ " checked / " ++ toString records.length ++ " candidates")]
        let help := helpLines ["[j/k] row", "[Space] check", "[a] all", "[d] clear",
          "[e] amount/period", "[Enter] preview", "[Esc] cancel"]
        let capacity := max 1 (Loam.Tui.Layout.footerBodyCapacity bounds help.length - fixed.length - notice.length)
        let rows := (Loam.Tui.Layout.centeredListWindow records state.row capacity).map fun (index, record) =>
          Widget.row [span (Loam.Tui.Layout.clip width
            ((if index == state.row then "> " else "  ") ++
             (if state.selected.contains record.id then "[x] " else "[ ] ") ++ recordText state record))
            (if index == state.row then .selected else .normal)]
        (fixed ++ (if records.isEmpty then [muted "No current-open candidates in this period."] else rows) ++ notice, help)
    | .preview draft =>
        let unchanged := state.selected.length - draft.drafts.length
        let fixed := header ++
          [line ("Preview: " ++ toString draft.drafts.length ++ " replacements"),
           line ("Checked unchanged: " ++ toString unchanged ++ "  Unchecked: " ++
            toString ((visibleCandidates state).length - state.selected.length)),
           muted "Dates/Loci/Measure/routing retained.",
           muted "Paid Actual is untouched."]
        let help := helpLines ["[j/k] review rows", "[Tab/Left/Right] action", "[Enter] choose", "[Esc] back"]
        let actions := Widget.row <| (["Back", "Publish all", "Cancel"].zipIdx.map fun (label, index) =>
          span ("[" ++ label ++ "] ") (if index == state.choice then .selected else .normal))
        let capacity := max 1 (Loam.Tui.Layout.footerBodyCapacity bounds (help.length + 1) - fixed.length - notice.length)
        let rows := (Loam.Tui.Layout.centeredListWindow draft.drafts state.row capacity).map fun (index, replacement) =>
          let original := state.candidates.find? (fun record => record.id == replacement.source)
          let before := (original.bind Loam.ScheduledBulkEdit.simpleAmount?).map (amountText state) |>.getD "?"
          let after := replacement.movement.changes.foldl
            (fun total change => if change.quantity.quanta > 0 then total + change.quantity.quanta else total) 0
          Widget.row [span (Loam.Tui.Layout.clip width
            ((if index == state.row then "> " else "  ") ++ replacement.scheduledOn ++ "  " ++
              before ++ " -> " ++ amountText state after ++ " " ++ state.source.measure.token ++
              "  " ++ replacement.source.token)) (if index == state.row then .selected else .normal)]
        (fixed ++ rows ++ notice, actions :: help)
  return .column (Loam.Tui.Layout.fitWithFooter bounds body help)

end Loam.Tui.ScheduledBulkEdit

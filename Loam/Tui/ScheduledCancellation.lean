import Loam.Tui.EditorSession
import Loam.Tui.Layout
import Loam.Tui.Scroll
import Loam.Publisher.ScheduledTerminalPublisher
import Loam.Tui.Main
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.ScheduledCancellation

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Selected Scheduled cancellation confirmation

Cancellation has no editable household payload. This module therefore keeps only
presentation evidence needed to confirm the visible target. The durable intent is
just the Scheduled identity; `ScheduledTerminalPublisher` re-reads lifecycle and
Movement evidence before publication.
-/
structure State where
  target : Loam.Core.ScheduledId
  scheduledOn : String
  expected : List String
  scroll : Nat := 0
  notice : String := ""
  -- 0 = Cancel Scheduled, 1 = Keep. Protective default is Keep.
  choice : Fin 2 := ⟨1, by omega⟩

abbrev Step :=
  Loam.Tui.EditorSession.Step State (Loam.ScheduledTerminalPublisher.CancellationDraft)

private def expectedLines (record : Loam.Tui.Main.ScheduledRecord) : List String :=
  record.movement.changes.map fun change =>
    change.coordinate.token ++ "  " ++ toString change.quantity.quanta ++ " " ++ record.measure.token

/-- Capture display-only context for one selected Scheduled identity. -/
def initial (record : Loam.Tui.Main.ScheduledRecord) : State :=
  { target := record.id
    scheduledOn := record.scheduledOn
    expected := expectedLines record }

/-- Confirmation owns no lifecycle semantics and emits at most one target-only intent. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, cancel := true }
  | .tab | .shiftTab | .left | .right =>
      { state := { state with choice := ⟨(state.choice.val + 1) % 2, Nat.mod_lt _ (by omega)⟩ } }
  | .enter =>
      if state.choice.val = 0 then
        { state, publish := some { scheduled := state.target } }
      else
        { state, cancel := true }
  | _ => { state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def footer (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := (Loam.Tui.Layout.wrapColumns width state.notice).map line
  let help := if width < 46 then
    "Tab choose  Enter  Esc keep"
  else
    "Tab/Left/Right select  Enter confirm  Esc keep"
  Loam.Tui.Layout.boundFeedbackFooter bounds <|
    feedback ++
    [ muted "Retirement keeps history; no deletion."
    , .row ((["Cancel Scheduled", "Keep"].zipIdx).map fun (label, index) =>
        span ("[" ++ label ++ "] ")
          (if state.choice.val = index then .selected else .normal))
    , muted help
    ]

private def header (bounds : Bounds) (state : State) (available : Nat) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  if available >= 7 then
    [ line "Scheduled / Cancel"
    , line (Loam.Tui.Layout.clip width ("Due: " ++ state.scheduledOn))
    , line (Loam.Tui.Layout.clip width ("Target: " ++ state.target.token))
    ]
  else if available >= 4 then
    [ line "Scheduled / Cancel"
    , line (Loam.Tui.Layout.clip width
        ("Due: " ++ state.scheduledOn ++ "  Target: " ++ state.target.token))
    ]
  else
    [ line "Scheduled / Cancel" ]

private def expectedRows (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let columns := width - 4
  -- If a long retained identity cannot fit in the summary, keep every byte
  -- available in the scrollable review rather than silently clipping it.
  let target := "Target: " ++ state.target.token
  let fullTarget :=
    if Loam.Tui.Layout.displayWidth target > width then
      (Loam.Tui.Layout.wrapColumns columns target).map line
    else []
  fullTarget ++ (state.expected.flatMap fun effect =>
    (Loam.Tui.Layout.wrapColumns columns (" " ++ effect)).map line)

/-- All size-dependent rows come from live terminal bounds. -/
def expectedCapacity (bounds : Bounds) (state : State) : Nat :=
  let available := Loam.Tui.Layout.footerBodyCapacity bounds (footer bounds state).length
  available - (header bounds state available).length - 2

def updateForBounds (bounds : Bounds) (state : State)
    (key : Loam.Tui.Terminal.Key) : Step :=
  let content := (expectedRows bounds state).length
  let capacity := expectedCapacity bounds state
  let current := Loam.Tui.Scroll.clamp content capacity state.scroll
  let page := max 1 capacity
  match key with
  | .up =>
      let offset := Loam.Tui.Scroll.backward content capacity current 1
      { state := { state with scroll := offset } }
  | .down =>
      let offset := Loam.Tui.Scroll.forward content capacity current 1
      { state := { state with scroll := offset } }
  | .pageUp =>
      let offset := Loam.Tui.Scroll.backward content capacity current page
      { state := { state with scroll := offset } }
  | .pageDown =>
      let offset := Loam.Tui.Scroll.forward content capacity current page
      { state := { state with scroll := offset } }
  | .home => { state := { state with scroll := 0 } }
  | .«end» =>
      let offset := Loam.Tui.Scroll.maxOffset content capacity
      { state := { state with scroll := offset } }
  | .enter =>
      if state.choice.val == 0 && capacity == 0 then
        { state := { state with notice := "Enlarge terminal to review the Scheduled effects." } }
      else
        update state key
  | _ => update state key

/-- Bounded confirmation: target and actions stay in view, all expected effects
    remain reachable by review scrolling; Keep is the protective default. -/
def view (bounds : Bounds) (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let actions := footer bounds state
  let available := Loam.Tui.Layout.footerBodyCapacity bounds actions.length
  let context := header bounds state available
  let height := available - context.length
  let rows := expectedRows bounds state
  let visible := expectedCapacity bounds state
  let offset := Loam.Tui.Scroll.clamp rows.length visible state.scroll
  let count := min rows.length (offset + visible)
  let progress := s!"{count}/{rows.length} lines" ++
    (if offset > 0 then " ▲" else "") ++
    (if count < rows.length then " ▼" else "")
  let effects := Loam.Tui.Layout.framedPanel width height "Expected effects"
    (.column ((rows.drop offset).take visible)) true (some progress)
  let body : Widget := .column (context ++ [effects])
  .column ((Loam.Tui.Layout.fitWithFooter bounds
    (Loam.Tui.Layout.widgetRows body) actions).map fun row =>
      Loam.Tui.Layout.clipWidgetRow width row)

end Loam.Tui.ScheduledCancellation

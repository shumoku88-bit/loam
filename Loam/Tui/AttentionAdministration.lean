import Loam.ActualDate
import Loam.ActualReview
import Loam.AttentionPublisher
import Loam.AttentionReview
import Loam.Tui.CyclicIndex
import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.AttentionAdministration

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Attention administration

This is a small presentation-only writer surface over the existing Attention
model. It deliberately exposes only the first practical verbs earned by G2-009:
add, resolve, and drop. It does not introduce priority, taxonomy, amount fields,
selected-day membership, editing, reopening, or relation provenance.
-/

inductive Mode where
  | browse
  | newContext (text : String)
  | newDue (context : String)
  | newDate (context date : String)
  | confirmClose (attention : AttentionId) (kind : AttentionClosureKind)
deriving Repr, DecidableEq

structure State where
  evidence : Loam.AttentionReview.Availability
  today : String
  cursor : Nat := 0
  mode : Mode := .browse
  notice : String := ""

structure Step where
  state : State
  back : Bool := false
  add : Option Loam.AttentionPublisher.AddDraft := none
  close : Option Loam.AttentionPublisher.CloseDraft := none

/-- Start one administration session from the same typed answer as the read workspace. -/
def initial (evidence : Loam.AttentionReview.Availability) (today : String) : State :=
  { evidence := evidence, today := today }

private def openItems (state : State) : List (Attention String) :=
  match state.evidence with
  | .unavailable => []
  | .available snapshot => snapshot.openItems

/-- Currently selected open item, if any. -/
def selected? (state : State) : Option (Attention String) :=
  (openItems state)[state.cursor]?

private def moveCursor (state : State) (back : Bool) : State :=
  let items := openItems state
  if items.isEmpty then
    { state with cursor := 0 }
  else
    let count := items.length
    let next :=
      if back then Loam.Tui.CyclicIndex.backward count state.cursor
      else Loam.Tui.CyclicIndex.forward count state.cursor
    { state with cursor := next, notice := "" }

private def dropLast (text : String) : String :=
  String.ofList text.toList.dropLast

private def emitAdd
    (state : State) (context : String) (due : AttentionDue String) : Step :=
  { state := { state with mode := .browse, notice := "" }
    add := some { context := context, due := due } }

private def beginClose
    (state : State) (kind : AttentionClosureKind) : Step :=
  match selected? state with
  | none => { state := { state with notice := "No open Attention item is selected." } }
  | some item =>
      { state := { state with mode := .confirmClose item.id kind, notice := "" } }

/-- Local key transition. Durable intent is emitted only by explicit confirmation. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .browse =>
      match key with
      | .escape | .input 'q' | .input 'Q' | .input 'b' | .input 'B' =>
          { state, back := true }
      | .up | .input 'k' | .input 'K' => { state := moveCursor state true }
      | .down | .input 'j' | .input 'J' => { state := moveCursor state false }
      | .input 'n' | .input 'N' =>
          { state := { state with mode := .newContext "", notice := "" } }
      | .input 'r' | .input 'R' => beginClose state .resolved
      | .input 'x' | .input 'X' => beginClose state .dropped
      | _ => { state }
  | .newContext text =>
      match key with
      | .escape => { state := { state with mode := .browse, notice := "" } }
      | .backspace =>
          { state := { state with mode := .newContext (dropLast text), notice := "" } }
      | .enter =>
          if text.isEmpty then
            { state := { state with notice := "Enter a short household matter before choosing due meaning." } }
          else
            { state := { state with mode := .newDue text, notice := "" } }
      | .input char =>
          { state := { state with mode := .newContext (text.push char), notice := "" } }
      | _ => { state }
  | .newDue context =>
      match key with
      | .escape => { state := { state with mode := .browse, notice := "" } }
      | .input 'd' | .input 'D' =>
          { state := { state with mode := .newDate context "", notice := "" } }
      | .input 'n' | .input 'N' => emitAdd state context .noDueDate
      | .input 'u' | .input 'U' => emitAdd state context .dueUndetermined
      | _ => { state }
  | .newDate context date =>
      match key with
      | .escape => { state := { state with mode := .browse, notice := "" } }
      | .backspace =>
          { state := { state with mode := .newDate context (dropLast date), notice := "" } }
      | .enter =>
          if Loam.ActualDate.validIsoDate date then
            emitAdd state context (.dueOn date)
          else
            { state := { state with notice := "Enter a real calendar date in YYYY-MM-DD form." } }
      | .input char =>
          { state := { state with mode := .newDate context (date.push char), notice := "" } }
      | _ => { state }
  | .confirmClose attention kind =>
      match key with
      | .escape => { state := { state with mode := .browse, notice := "" } }
      | .enter =>
          { state := { state with mode := .browse, notice := "" }
            close := some { attention := attention, knownOn := state.today, kind := kind } }
      | _ => { state }

/-- Refresh after shared publication without retaining stale open-item evidence. -/
def refreshed
    (evidence : Loam.AttentionReview.Availability)
    (notice : String)
    (state : State) : State :=
  { state with evidence := evidence, cursor := 0, mode := .browse, notice := notice }

/-- Failed publication returns to the current browse surface with the refusal visible. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .browse, notice := message }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def kindLabel : AttentionClosureKind → String
  | .resolved => "resolve"
  | .dropped => "drop"

private def selectedContext (state : State) (id : AttentionId) : String :=
  match (openItems state).find? (fun item => item.id == id) with
  | some item => item.context
  | none => id.token

private def browseView (state : State) : Widget :=
  let items := openItems state
  let rows := (items.take 12).zipIdx.map fun (item, index) =>
    let marker := if index = state.cursor then "> " else "  "
    line (marker ++ Loam.ActualReview.shortText 72 (Loam.AttentionReview.summary item))
  let body :=
    match state.evidence with
    | .unavailable =>
        [ line "No canonical Attention stream yet."
        , muted "Press n to create the first household matter."
        ]
    | .available _ =>
        if items.isEmpty then
          [ line "0 open"
          , muted "Press n to add a household matter."
          ]
        else rows
  .column <|
    [ line "Attention / Manage"
    , muted "Household matters that should not disappear from view"
    , blank
    ] ++ body ++
    [ blank
    , muted "n new   r resolve today   x drop today   Up/Down select"
    , muted "Due date is optional; unknown timing remains distinct from no due date."
    , muted "Esc/b/q back"
    , line state.notice
    ]

/-- Render one small administration state. -/
def view (state : State) : Widget :=
  match state.mode with
  | .browse => browseView state
  | .newContext text =>
      .column
        [ line "Attention / New"
        , muted "What household matter should stay visible?"
        , blank
        , line (if text.isEmpty then "> _" else "> " ++ text)
        , blank
        , muted "Enter next   Esc cancel   Backspace delete"
        , line state.notice
        ]
  | .newDue context =>
      .column
        [ line "Attention / New / Due meaning"
        , line (Loam.ActualReview.shortText 72 context)
        , blank
        , line "d  due on a known date"
        , line "n  no due date"
        , line "u  due timing unknown"
        , blank
        , muted "Choose d / n / u   Esc cancel"
        , line state.notice
        ]
  | .newDate context date =>
      .column
        [ line "Attention / New / Due date"
        , line (Loam.ActualReview.shortText 72 context)
        , blank
        , line ("Due: " ++ if date.isEmpty then "_" else date)
        , blank
        , muted "YYYY-MM-DD   Enter publish   Esc cancel   Backspace delete"
        , line state.notice
        ]
  | .confirmClose attention kind =>
      .column
        [ line ("Attention / " ++ kindLabel kind)
        , line (Loam.ActualReview.shortText 72 (selectedContext state attention))
        , blank
        , line ("Record " ++ kindLabel kind ++ " on " ++ state.today ++ "?")
        , muted "Enter confirm   Esc cancel"
        , line state.notice
        ]

end Loam.Tui.AttentionAdministration

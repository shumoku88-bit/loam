import Loam.SettlementReview
import Loam.Tui.Layout
import Loam.Tui.Main

namespace Loam.Tui.SettlementWorkspace

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

/-!
# Read-only settlement workspace

Presentation-only workspace over `SettlementReview.Snapshot`.

The workspace owns no settlement interpretation or write authority. It can only:

- switch between open-only and all current commitments;
- move one list cursor;
- render the already-admitted direct/netting provenance.

A later input workflow may reuse this screen, but this first surface is
deliberately observational.
-/

inductive Scope where
  | openOnly
  | all
deriving Repr, DecidableEq, BEq

structure State where
  snapshot : Loam.SettlementReview.Snapshot
  scope : Scope := .openOnly
  row : Nat := 0
  notice : String := ""
deriving Repr, DecidableEq

inductive Event where
  | previous
  | next
  | cycleScope
  | back
  | other
deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
  | back
deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  command : Command := .stay

def initial (snapshot : Loam.SettlementReview.Snapshot) : State :=
  { snapshot := snapshot }

def visibleRows (state : State) : List Loam.SettlementReview.Row :=
  match state.scope with
  | .openOnly => state.snapshot.openRows
  | .all => state.snapshot.rows

def selectedRow? (state : State) : Option Loam.SettlementReview.Row :=
  (visibleRows state)[state.row]?

private def clamp (state : State) : State :=
  let count := (visibleRows state).length
  if count = 0 then { state with row := 0 }
  else { state with row := min state.row (count - 1) }

private def previous (state : State) : State :=
  if state.row = 0 then
    { state with notice := "No previous settlement commitment." }
  else
    { state with row := state.row - 1, notice := "" }

private def next (state : State) : State :=
  if state.row + 1 < (visibleRows state).length then
    { state with row := state.row + 1, notice := "" }
  else
    { state with notice := "No next settlement commitment." }

private def cycleScope (state : State) : State :=
  let scope := match state.scope with
    | .openOnly => Scope.all
    | .all => Scope.openOnly
  clamp { state with scope := scope, row := 0, notice := "" }

def update (state : State) (event : Event) : Step :=
  match event with
  | .previous => { state := previous state }
  | .next => { state := next state }
  | .cycleScope => { state := cycleScope state }
  | .back => { state, command := .back }
  | .other => { state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def endpointText : RelationEndpoint → String
  | .household => "household"
  | .external id => id.token

private def directionText (row : Loam.SettlementReview.Row) : String :=
  endpointText row.debtor ++ " -> " ++ endpointText row.creditor

private def statusText (row : Loam.SettlementReview.Row) : String :=
  if row.outstanding.quanta = 0 then "settled" else "open"

private def scopeText : Scope → String
  | .openOnly => "Open"
  | .all => "All current"

private def windowStart (state : State) : Nat :=
  if state.row > 7 then state.row - 6 else 0

private def rowText
    (selected : Bool) (row : Loam.SettlementReview.Row) : String :=
  let marker := if selected then " > " else "   "
  marker ++
    Loam.Tui.Layout.padRight 22 row.id.token ++
    Loam.Tui.Layout.padLeft 11 (toString row.committed.quanta) ++
    Loam.Tui.Layout.padLeft 11 (toString row.settled.quanta) ++
    Loam.Tui.Layout.padLeft 11 (toString row.outstanding.quanta) ++
    " " ++ Loam.Tui.Layout.padRight 8 row.measure.token ++
    " " ++ statusText row

private def listLines (state : State) : List Widget :=
  let rows := visibleRows state
  let start := windowStart state
  if rows.isEmpty then
    [muted "  (no settlement commitments in this scope)"]
  else
    (List.range 9).filterMap fun offset => do
      let index := start + offset
      let row ← rows[index]?
      some (line (rowText (index = state.row) row))

private def directLines (row : Loam.SettlementReview.Row) : List Widget :=
  if row.direct.isEmpty then
    [muted "     (none)"]
  else
    row.direct.map fun allocation =>
      line
        ("     " ++ allocation.correspondence.token ++ "  " ++
          toString allocation.quantity.quanta ++ " " ++ row.measure.token ++
          "  @ " ++ allocation.event.token ++ "/" ++ allocation.effect.token)

private def nettingOutcomeText : NetSettlementOutcome → String
  | .zero => "zero"
  | .physical event effect => "physical " ++ event.token ++ "/" ++ effect.token

private def nettingLines (row : Loam.SettlementReview.Row) : List Widget :=
  if row.netting.isEmpty then
    [muted "     (none)"]
  else
    row.netting.map fun allocation =>
      line
        ("     " ++ allocation.member.token ++ "  " ++
          toString allocation.quantity.quanta ++ " " ++ row.measure.token ++
          "  context " ++ allocation.context.token ++
          "  [" ++ nettingOutcomeText allocation.outcome ++ "]")

private def detailLines (state : State) : List Widget :=
  match selectedRow? state with
  | none =>
      [ line " Selected settlement details"
      , muted "   (no commitment selected)"
      ]
  | some row =>
      [ line " Selected settlement details"
      , line ("   Identity    : " ++ row.id.token)
      , line ("   Direction   : " ++ directionText row)
      , line ("   Source      : " ++ row.sourceEvent.token ++ "/" ++ row.sourceEffect.token)
      , line ("   Measure     : " ++ row.measure.token)
      , line ("   Committed   : " ++ toString row.committed.quanta)
      , line ("   Settled     : " ++ toString row.settled.quanta)
      , line ("   Outstanding : " ++ toString row.outstanding.quanta)
      , line "   Direct:"
      ] ++ directLines row ++
      [line "   Netting:"] ++ nettingLines row

def view (bounds : Bounds) (state : State) : Widget :=
  let count := (visibleRows state).length
  let body :=
    [ line " Settlement"
    , muted "Home > Settlement"
    , muted
        ("Current admitted commitments; scope: " ++ scopeText state.scope ++
          " (" ++ toString count ++ ")")
    , blank
    , muted "   Commitment              committed    settled outstanding measure  status"
    ] ++
    listLines state ++
    [blank] ++
    detailLines state ++
    (if state.notice.isEmpty then [] else [line state.notice])
  let footer :=
    [ muted "[j/k] select   [f] open/all   [q/Esc] home"
    , muted "Read-only: quantities and provenance come from SettlementReview."
    ]
  .column (Loam.Tui.Layout.fitWithFooter bounds body footer)

end Loam.Tui.SettlementWorkspace

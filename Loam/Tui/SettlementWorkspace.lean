import Loam.SettlementReview
import Loam.Tui.Layout
import Loam.Tui.Main

namespace Loam.Tui.SettlementWorkspace

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

/-!
# Settlement workspace

The default surface is intentionally compact. It answers the ordinary question:

```text
what is this?
how much remains?
```

Internal identity, source provenance, allocation modes, revision-aware
extinguishment evidence, and exact composition stay behind an explicit detail
toggle. This keeps the admitted semantic model rich without making the routine
screen read like an audit log.
-/

inductive Scope where
  | openOnly
  | all
deriving Repr, DecidableEq, BEq

structure State where
  snapshot : Loam.SettlementReview.Snapshot
  scope : Scope := .openOnly
  row : Nat := 0
  detailOpen : Bool := false
  notice : String := ""
deriving Repr, DecidableEq

inductive Event where
  | previous
  | next
  | cycleScope
  | toggleDetail
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
    { state with notice := "No previous item." }
  else
    { state with row := state.row - 1, notice := "" }

private def next (state : State) : State :=
  if state.row + 1 < (visibleRows state).length then
    { state with row := state.row + 1, notice := "" }
  else
    { state with notice := "No next item." }

private def cycleScope (state : State) : State :=
  let scope := match state.scope with
    | .openOnly => Scope.all
    | .all => Scope.openOnly
  clamp { state with scope := scope, row := 0, detailOpen := false, notice := "" }

private def toggleDetail (state : State) : State :=
  match selectedRow? state with
  | none => { state with notice := "No item is selected." }
  | some _ => { state with detailOpen := !state.detailOpen, notice := "" }

def update (state : State) (event : Event) : Step :=
  match event with
  | .previous => { state := previous { state with detailOpen := false } }
  | .next => { state := next { state with detailOpen := false } }
  | .cycleScope => { state := cycleScope state }
  | .toggleDetail => { state := toggleDetail state }
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

private def displayName (row : Loam.SettlementReview.Row) : String :=
  match row.label with
  | some label => if label.isEmpty then row.id.token else label
  | none => row.id.token

private def scopeText : Scope → String
  | .openOnly => "Open"
  | .all => "All current"

private def windowStart (state : State) : Nat :=
  if state.row > 9 then state.row - 8 else 0

private def rowText
    (selected : Bool) (row : Loam.SettlementReview.Row) : String :=
  let marker := if selected then " > " else "   "
  let status := if row.outstanding.quanta = 0 then "done" else ""
  marker ++
    Loam.Tui.Layout.padRight 38 (displayName row) ++
    Loam.Tui.Layout.padLeft 13 (toString row.outstanding.quanta) ++
    " " ++ Loam.Tui.Layout.padRight 9 row.measure.token ++
    status

private def listLines (state : State) : List Widget :=
  let rows := visibleRows state
  let start := windowStart state
  if rows.isEmpty then
    [muted "  (nothing to show in this view)"]
  else
    (List.range 11).filterMap fun offset => do
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

private def extinguishmentLines (row : Loam.SettlementReview.Row) : List Widget :=
  if row.extinguishments.isEmpty then
    [muted "     (none)"]
  else
    row.extinguishments.map fun allocation =>
      let whenText := allocation.effectiveOn.getD "date unknown"
      line
        ("     " ++ allocation.id.token ++ "  " ++
          toString allocation.quantity.quanta ++ " " ++ row.measure.token ++
          "  @ " ++ whenText)

private def summaryLines (state : State) : List Widget :=
  match selectedRow? state with
  | none => []
  | some row =>
      [ line (" Selected: " ++ displayName row)
      , line
          ("   Remaining " ++ toString row.outstanding.quanta ++
            " " ++ row.measure.token)
      , muted "   [d] details"
      ]

private def detailLines (state : State) : List Widget :=
  match selectedRow? state with
  | none => []
  | some row =>
      [ line (" Details: " ++ displayName row)
      , line ("   Identity    : " ++ row.id.token)
      , line ("   Direction   : " ++ directionText row)
      , line ("   Source      : " ++ row.sourceEvent.token ++ "/" ++ row.sourceEffect.token)
      , line ("   Measure     : " ++ row.measure.token)
      , line ("   Committed   : " ++ toString row.committed.quanta)
      , line ("   Settled     : " ++ toString row.settled.quanta)
      , line ("   Adjusted    : " ++ toString row.extinguished.quanta)
      , line ("   Remaining   : " ++ toString row.outstanding.quanta)
      , line "   Direct:"
      ] ++ directLines row ++
      [line "   Netting:"] ++ nettingLines row ++
      [line "   Non-settlement reduction:"] ++ extinguishmentLines row

def view (bounds : Bounds) (state : State) : Widget :=
  let count := (visibleRows state).length
  let body :=
    [ line " Settlement"
    , muted "Home > Settlement"
    , muted (scopeText state.scope ++ " (" ++ toString count ++ ")")
    , blank
    , muted "   Item                                      remaining measure"
    ] ++
    listLines state ++
    [blank] ++
    (if state.detailOpen then detailLines state else summaryLines state) ++
    (if state.notice.isEmpty then [] else [line state.notice])
  let footer :=
    [ muted "[j/k] select   [f] open/all   [d] details   [q/Esc] home"
    , muted "Routine view hides internal IDs and provenance."
    ]
  .column (Loam.Tui.Layout.fitWithFooter bounds body footer)

end Loam.Tui.SettlementWorkspace

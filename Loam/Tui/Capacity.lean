import Loam.CapacityReview
import Loam.CurrentCoverageReview
import Loam.ActualReview
import Loam.Tui.Kernel
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.Capacity

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Capacity workspace

This surface consumes the shared all-retained `CapacityReview` answer. When the
caller can also justify one explicit future horizon, it may attach the shared
`CurrentCoverageReview` answer for current decision support.

Selection, scrolling, labels, and transfer intent are presentation state. The TUI
does not recompute Consumption, Scheduled Commitment, or Headroom, and it does
not publish Capacity movements; publication remains in the shared
`CapacityPublisher` reached by the caller.
-/

structure State where
  snapshot : Loam.CapacityReview.Snapshot
  selected : Option (Fin snapshot.rows.length)
  coverage : Option Loam.CurrentCoverageReview.Snapshot := none
  coverageSource : String := ""
  coverageNotice : String := ""
  notice : String := ""

inductive Event where
  | up
  | down
  | transfer
  | back
  | other
  deriving Repr, DecidableEq, BEq

inductive Step where
  | stay (state : State)
  | transfer (state : State)
  | back


def initial (snapshot : Loam.CapacityReview.Snapshot) : State :=
  let selected : Option (Fin snapshot.rows.length) :=
    if h : 0 < snapshot.rows.length then some ⟨0, h⟩ else none
  { snapshot := snapshot, selected := selected }

/-- Attach one already-derived shared current coverage answer. -/
def withCoverage
    (coverage : Loam.CurrentCoverageReview.Snapshot)
    (source : String)
    (state : State) : State :=
  { state with
      coverage := some coverage
      coverageSource := source
      coverageNotice := "" }

/-- Preserve the Capacity workspace while explicitly recording why coverage is absent. -/
def withoutCoverage (message : String) (state : State) : State :=
  { state with coverage := none, coverageSource := "", coverageNotice := message }

/-- Current selected Purpose, when the all-retained review has one. -/
def selectedPurpose? (state : State) : Option PurposeId := do
  let index ← state.selected
  let row ← state.snapshot.rows[index.val]?
  pure row.purpose

/-- Preserve the local row coordinate when a fresh shared Capacity snapshot arrives. -/
def refreshed (snapshot : Loam.CapacityReview.Snapshot) (state : State) : State :=
  let selected : Option (Fin snapshot.rows.length) :=
    match state.selected with
    | some index =>
        if h : index.val < snapshot.rows.length then
          some ⟨index.val, h⟩
        else if h : 0 < snapshot.rows.length then
          some ⟨0, h⟩
        else
          none
    | none =>
        if h : 0 < snapshot.rows.length then some ⟨0, h⟩ else none
  { snapshot := snapshot
    selected := selected
    coverage := state.coverage
    coverageSource := state.coverageSource
    coverageNotice := state.coverageNotice
    notice := state.notice }


def movePrevious (state : State) : State :=
  match state.selected with
  | none => { state with notice := "No remembered Capacity purpose is available." }
  | some index =>
      if h : index.val = 0 then
        { state with notice := "No previous Capacity row." }
      else
        { state with
            selected := some ⟨index.val - 1, by omega⟩
            notice := "" }


def moveNext (state : State) : State :=
  match state.selected with
  | none => { state with notice := "No remembered Capacity purpose is available." }
  | some index =>
      if h : index.val + 1 < state.snapshot.rows.length then
        { state with selected := some ⟨index.val + 1, h⟩, notice := "" }
      else
        { state with notice := "No next Capacity row." }


def update (state : State) (event : Event) : Step :=
  match event with
  | .back => .back
  | .transfer => .transfer state
  | .up => .stay (movePrevious state)
  | .down => .stay (moveNext state)
  | .other => .stay state

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []


def windowSize : Nat := 12


def windowStart (state : State) : Nat :=
  match state.selected with
  | none => 0
  | some index =>
      if index.val < windowSize then 0
      else index.val + 1 - windowSize


def visibleRows (state : State) : List (Nat × Loam.CapacityReview.Row) :=
  let start := windowStart state
  (List.range windowSize).filterMap fun offset =>
    let index := start + offset
    match state.snapshot.rows[index]? with
    | none => none
    | some row => some (index, row)

private def coverageRow?
    (state : State) (purpose : PurposeId) : Option Loam.CurrentCoverageReview.Row := do
  let coverage ← state.coverage
  coverage.rows.find? fun row => row.purpose == purpose

private def hasUnresolvedFrontier (state : State) : Bool :=
  match state.coverage.bind (fun snapshot => snapshot.scheduledFrontier) with
  | none => false
  | some frontier =>
      frontier.unrouted.quanta > 0 || frontier.unresolvedEligibility.quanta > 0

/-- Human diagnosis only. Quantities remain authoritative in CurrentCoverageReview. -/
def coverageLabel (state : State) (row : Loam.CurrentCoverageReview.Row) : String :=
  if row.remaining.quanta < 0 then
    "OVER NOW"
  else if row.headroom.quanta < 0 then
    "FUTURE SHORT"
  else if hasUnresolvedFrontier state then
    "CHECK"
  else
    "OK"

private def rowLine
    (state : State) (index : Nat) (row : Loam.CapacityReview.Row) : Widget :=
  let selected :=
    match state.selected with
    | none => false
    | some current => current.val == index
  let marker := if selected then "▶ " else "  "
  let purpose := Loam.ActualReview.shortText 28 row.purpose.token
  let text :=
    match coverageRow? state row.purpose with
    | none => marker ++ purpose ++ ": " ++ toString row.entitlement.quanta ++ " jpy"
    | some current =>
        marker ++ purpose ++
          ": cap " ++ toString current.entitlement.quanta ++
          " | now " ++ toString current.remaining.quanta ++
          " | after-known " ++ toString current.headroom.quanta ++
          " | " ++ coverageLabel state current
  .row [span text (if selected then .selected else .normal)]

private def coverageFooter (state : State) : List Widget :=
  match state.coverage with
  | none =>
      if state.coverageNotice.isEmpty then
        [ muted "No cycle, period, or selected-day meaning is inferred here." ]
      else
        [ muted "No cycle, period, or selected-day meaning is inferred here."
        , muted ("Current coverage unavailable: " ++ state.coverageNotice)
        ]
  | some coverage =>
      let source :=
        if state.coverageSource.isEmpty then "explicit configured horizon"
        else state.coverageSource
      let frontierLine :=
        match coverage.scheduledFrontier with
        | none => "Scheduled frontier: no remembered Capacity Purpose to project."
        | some frontier =>
            "Scheduled frontier: unmanaged " ++ toString frontier.unmanaged.quanta ++
            " | unrouted " ++ toString frontier.unrouted.quanta ++
            " | unresolved " ++ toString frontier.unresolvedEligibility.quanta ++ " jpy"
      [ muted
          ("Coverage: observed " ++ coverage.observedAt ++
           " | " ++ source ++ " -> " ++ coverage.endExclusive)
      , muted "now = Entitlement - correction-frontier Actual; after-known also subtracts managed current-open Scheduled."
      , muted frontierLine
      , muted "Coverage labels are presentation only; this is not SafeToSpend authority."
      ]

/-- Render all-retained JPY Capacity plus optional shared current coverage evidence. -/
def view (state : State) : Widget :=
  if state.snapshot.rows.isEmpty then
    .column <|
      [ line "Capacity / Current"
      , muted "Home > Capacity"
      , muted "0 remembered purposes"
      , blank
      , line "No spending-purpose capacity is retained."
      , blank
      , muted "All-retained view; no cycle or time window is inferred."
      ] ++ coverageFooter state ++
      [ muted "t transfer can grant Capacity from unallocated to a new Purpose token."
      , muted "unallocated is an allocation boundary, not money available to allocate."
      , muted "t transfer   b home   q quit"
      , muted state.notice
      ]
  else
    .column <|
      [ line "Capacity / Current"
      , muted "Home > Capacity"
      , muted (toString state.snapshot.rows.length ++ " remembered purpose(s)")
      , blank
      ] ++
      ((visibleRows state).map fun row => rowLine state row.1 row.2) ++
      [ blank
      , muted "Entitlement is derived from all retained JPY Capacity movements."
      , muted "Order shown is first retained appearance, not priority."
      ] ++ coverageFooter state ++
      [ muted "t opens a local transfer editor; shared CapacityPublisher owns publication."
      , muted "unallocated is an allocation boundary, not money available to allocate."
      , muted "↑/↓ select/scroll   t transfer   b home   q quit"
      , muted state.notice
      ]

end Loam.Tui.Capacity

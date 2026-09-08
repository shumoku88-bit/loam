import Loam.CurrentCoverageReview
import Loam.CycleBudgetReview
import Loam.Tui.Terminal

namespace Loam.Tui.CycleBudget

open Loam.Tui.Kernel
open Loam.Tui.Terminal
set_option autoImplicit false

inductive Submode where
  | normal
  | grantPicker (shortages : List Loam.CurrentCoverageReview.Row) (selected : Nat)
  deriving Repr, DecidableEq

structure State where
  snapshot : Loam.CycleBudgetReview.Snapshot
  scroll : Nat := 0
  notice : String := ""
  submode : Submode := .normal
  deriving Repr

inductive Intent where
  | stay | home | capacity | quit | unresolved
  | grant (row : Loam.CurrentCoverageReview.Row)
  deriving Repr, DecidableEq

/-- Home's c is the read-only current-cycle entrance; e retains raw Capacity. -/
def isHomeEntrance (key : Key) : Bool := key == .input 'c' || key == .input 'C'

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def padded (width : Nat) (text : String) : String :=
  String.ofList (List.replicate (width - text.length) ' ') ++ text

private def amount (label : String) (quantity : Loam.Core.Quantity) : Widget :=
  line (label ++ String.ofList (List.replicate (34 - label.length) ' ') ++
    padded 10 (toString quantity.quanta) ++ " jpy")

/-- Values are mapped directly; no budget arithmetic or status inference. -/
def coverageRow (row : Loam.CurrentCoverageReview.Row) : Widget :=
  line (padded 9 (toString row.entitlement.quanta) ++
    padded 9 (toString row.consumption.quanta) ++
    padded 9 (toString row.remaining.quanta) ++
    padded 14 (toString row.commitment.quanta) ++
    padded 14 (toString row.headroom.quanta) ++ "  " ++ row.purpose.token)

private def fundingLines (snapshot : Loam.CycleBudgetReview.Snapshot) : List Widget :=
  [line "Funding"] ++
  (match snapshot.selection with
   | .error _ => []
   | .ok selection => [muted ("Budget backing: " ++
       (if selection.isEmpty then "(explicitly none)" else String.intercalate " / "
         (selection.map fun c => c.locus.token ++ " " ++ c.measure.token)))]) ++
  (match snapshot.funding with
   | .error message => [line ("Funding unavailable: " ++ message)]
   | .ok summary =>
     [ amount "Budgetable backing" summary.budgetableBacking
     , amount "Remaining assigned" summary.remainingAssigned
     , amount "Residual before unresolved" summary.residualBeforeUnresolved ]) ++
  -- Frontier stays visible even when the optional funding configuration fails.
  (match snapshot.funding with
   | .ok summary =>
     [ amount "Unresolved future pressure" summary.unresolvedFuturePressure
     , amount "Unrouted future pressure" summary.unroutedFuturePressure
     , amount "Unmanaged future pressure" summary.unmanagedFuturePressure ]
   | .error _ =>
     match snapshot.coverage with
     | .error _ => [muted "Future pressure unavailable: CurrentCoverage unavailable"]
     | .ok coverage =>
       match coverage.scheduledFrontier with
       | none => [muted "Future pressure unavailable: Scheduled frontier missing"]
       | some frontier =>
         [ amount "Unresolved future pressure" frontier.unresolvedEligibility
         , amount "Unrouted future pressure" frontier.unrouted
         , amount "Unmanaged future pressure" frontier.unmanaged ])

def body (state : State) : List Widget :=
  let snapshot := state.snapshot
  (match snapshot.window with
   | .error message => [line "Budget / Current Cycle", line ("Boundary unavailable: " ++ message)]
   | .ok window =>
     [ line ("Budget / " ++ window.source ++ " Cycle")
     , line (window.start ++ " -> " ++ window.endExclusive ++ " (end exclusive)")
     , line ("Observed " ++ snapshot.observedAt ++ "   " ++
         match Loam.ActualDate.daysBetween? snapshot.observedAt window.endExclusive with
         | some days => toString days ++ " days to next boundary"
         | none => "Boundary distance unavailable") ]) ++
  fundingLines snapshot ++
  [line "Physical balances (display selection; not total budget backing)"] ++
  (match snapshot.physical with
   | .error message => [line ("Physical balances unavailable: " ++ message)]
   | .ok balances =>
     if balances.rows.isEmpty then [muted "No physical display coordinates selected."]
     else balances.rows.map fun row =>
       line (row.coordinate.locus.token ++ ": " ++ toString row.quantity.quanta ++ " " ++
         row.coordinate.measure.token ++
         match snapshot.selection with
         | .error _ => "  [backing selection unavailable]"
         | .ok selection =>
           if row.coordinate ∈ selection then "  [budget backing]" else "  [outside budget backing]")) ++
  [line "Purpose coverage / jpy"] ++
  (match snapshot.coverage with
   | .error message => [line ("CurrentCoverage unavailable: " ++ message)]
   | .ok coverage =>
     [muted "      Cap    Spent      Now  Known future   After-known  Purpose"] ++
     coverage.rows.map coverageRow) ++
  (if state.notice.isEmpty then [] else [line state.notice])

private def pageSize (bounds : Bounds) : Nat := bounds.height - 2

private def paddedRight (width : Nat) (text : String) : String :=
  if text.length >= width then text
  else text ++ String.ofList (List.replicate (width - text.length) ' ')

def update (bounds : Bounds) (state : State) (key : Key) : State × Intent :=
  match state.submode with
  | .grantPicker shortages selected =>
      match key with
      | .input 'q' | .input 'Q' =>
          ({ state with submode := .normal }, .quit)
      | .escape | .input 'b' | .input 'B' =>
          ({ state with submode := .normal, notice := "" }, .stay)
      | .up | .input 'k' | .input 'K' =>
          let next := if selected == 0 then 0 else selected - 1
          ({ state with submode := .grantPicker shortages next }, .stay)
      | .down | .input 'j' | .input 'J' =>
          let next := if selected + 1 < shortages.length then selected + 1 else selected
          ({ state with submode := .grantPicker shortages next }, .stay)
      | .enter =>
          match shortages[selected]? with
          | some chosen =>
              ({ state with submode := .normal, notice := "" }, .grant chosen)
          | none =>
              ({ state with submode := .normal }, .stay)
      | _ => (state, .stay)
  | .normal =>
      let limit := (body state).length - pageSize bounds
      match key with
      | .input 'q' | .input 'Q' => (state, .quit)
      | .escape | .input 'b' | .input 'B' => (state, .home)
      | .input 'e' | .input 'E' => (state, .capacity)
      | .input 'u' | .input 'U' =>
        match state.snapshot.coverage with
        | .ok coverage =>
          if coverage.unresolvedScheduled.isEmpty then
            ({ state with notice := "No unresolved Scheduled routing subjects." }, .stay)
          else
            ({ state with notice := "" }, .unresolved)
        | .error _ =>
          ({ state with notice := "CurrentCoverage unavailable." }, .stay)
      | .input 'g' | .input 'G' =>
        match state.snapshot.coverage with
        | .ok coverage =>
          let shortages := coverage.rows.filter (fun row => row.headroom.quanta < 0)
          if shortages.isEmpty then
            ({ state with notice := "No Purpose has negative After-known headroom." }, .stay)
          else if shortages.length == 1 then
            match shortages.head? with
            | some chosen => ({ state with notice := "" }, .grant chosen)
            | none => (state, .stay)
          else
            ({ state with submode := .grantPicker shortages 0, notice := "" }, .stay)
        | .error _ =>
          ({ state with notice := "CurrentCoverage unavailable." }, .stay)
      | .up | .input 'k' => ({ state with scroll := state.scroll - 1 }, .stay)
      | .down | .input 'j' => ({ state with scroll := min limit (state.scroll + 1) }, .stay)
      | _ => (state, .stay)

def grantPickerView (_bounds : Bounds) (state : State)
    (shortages : List Loam.CurrentCoverageReview.Row) (selected : Nat) : Widget :=
  let listLines : List Widget :=
    shortages.zipIdx.map fun (row, idx) =>
      let isSel := idx == selected
      let marker := if isSel then "▶  " else "   "
      let content := marker ++ paddedRight 20 row.purpose.token ++ padded 14 (toString row.headroom.quanta) ++ " jpy"
      .row [span content (if isSel then .selected else .normal)]
  .column <|
    [ line "Capacity / Cycle Grant / Select Purpose"
    , muted "Select Purpose with negative After-known headroom:"
    , line ""
    , muted ("   " ++ paddedRight 20 "Purpose" ++ padded 14 "After-known")
    ] ++ listLines ++
    [ line ""
    , if state.notice.isEmpty then line "" else line state.notice
    , muted "j/k select   Enter confirm   b/Esc cancel"
    ]

def view (bounds : Bounds) (state : State) : Widget :=
  match state.submode with
  | .grantPicker shortages selected =>
      grantPickerView bounds state shortages selected
  | .normal =>
      let lines := body state
      let page := pageSize bounds
      let offset := min state.scroll (lines.length - page)
      let visible := (lines.drop offset).take page
      .column (visible ++ List.replicate (page - visible.length) (line "") ++
        [muted ("j/k scroll " ++ toString (offset + 1) ++ "/" ++ toString lines.length ++
          " | g grant | u route | e Capacity/actions | b Home | q quit | read only")])

end Loam.Tui.CycleBudget

import Loam.CycleBudgetReview
import Loam.Tui.Terminal

namespace Loam.Tui.CycleBudget

open Loam.Tui.Kernel
open Loam.Tui.Terminal
set_option autoImplicit false

structure State where
  snapshot : Loam.CycleBudgetReview.Snapshot
  scroll : Nat := 0
  notice : String := ""
  deriving Repr

inductive Intent where
  | stay | home | capacity | quit
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

def update (bounds : Bounds) (state : State) (key : Key) : State × Intent :=
  let limit := (body state).length - pageSize bounds
  match key with
  | .input 'q' | .input 'Q' => (state, .quit)
  | .escape | .input 'b' | .input 'B' => (state, .home)
  | .input 'e' | .input 'E' => (state, .capacity)
  | .up | .input 'k' => ({ state with scroll := state.scroll - 1 }, .stay)
  | .down | .input 'j' => ({ state with scroll := min limit (state.scroll + 1) }, .stay)
  | _ => (state, .stay)

def view (bounds : Bounds) (state : State) : Widget :=
  let lines := body state
  let page := pageSize bounds
  let offset := min state.scroll (lines.length - page)
  let visible := (lines.drop offset).take page
  .column (visible ++ List.replicate (page - visible.length) (line "") ++
    [muted ("j/k scroll " ++ toString (offset + 1) ++ "/" ++ toString lines.length ++
      " | e Capacity/actions | b Home | q quit | read only")])

end Loam.Tui.CycleBudget

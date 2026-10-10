import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Runtime
import Loam.Tui.Terminal
import Loam.Tui.ReportDestination

namespace Loam.Tui.HomeCommandPalette

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
A short-lived, hierarchical command chooser. Pages and selection are presentation
state only: leaf choices delegate to the existing Home session entries and their
validated publishers. The palette never reads or publishes household data.
-/

inductive Choice where
  | record
  | actual
  | exchange
  | scheduled
  | attention
  | settlements
  | dailyPace
  | balances
  | report (destination : Loam.Tui.Reports.Destination)
  | budget
  | capacity
  | purposeRouting
  | manageLoci
  | observeQuantities
  deriving Repr, DecidableEq

inductive Page where
  | commands
  | transactions
  | planning
  | analysis
  | envelopeBudget
  | maintenance
  deriving Repr, DecidableEq

structure State where
  page : Page := .commands
  selected : Nat := 0
  deriving Repr, DecidableEq

private inductive Entry where
  | page (target : Page)
  | action (choice : Choice)

private def entries : Page → List (Entry × String)
  | .commands =>
      [ (.page .transactions, "Transactions →")
      , (.page .planning, "Plans and attention →")
      , (.page .analysis, "Reports and analysis →")
      , (.page .envelopeBudget, "Envelope budget →")
      , (.page .maintenance, "Household setup →")
      ]
  | .transactions =>
      [ (.action .record, "Record / new entry")
      , (.action .actual, "Actual / transactions")
      , (.action .exchange, "Exchange / currencies")
      ]
  | .planning =>
      [ (.action .scheduled, "Scheduled / plans")
      , (.action .attention, "Attention / follow-up")
      , (.action .settlements, "Settlements")
      ]
  | .analysis =>
      [ (.action .dailyPace, "Daily Pace")
      , (.action .balances, "Balances / Current")
      ] ++ Loam.Tui.Reports.Destination.all.map fun destination =>
        (.action (.report destination), destination.label)
  | .envelopeBudget =>
      [ (.action .budget, "Budget / current cycle")
      , (.action .capacity, "Capacity / allocations")
      , (.action .purposeRouting, "Purpose routing")
      ]
  | .maintenance =>
      [ (.action .manageLoci, "Manage Loci")
      , (.action .observeQuantities, "Observe quantities")
      ]

inductive Transition where
  | stay (state : State)
  | open (choice : Choice)
  | close
  deriving Repr, DecidableEq

/-- Pure navigation; only a leaf can request an existing workspace. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Transition :=
  match key with
  | .left | .escape | .input 'q' | .input 'Q' | .input ' ' =>
      match state.page with
      | .commands => .close
      | _ => .stay {}
  | .right =>
      match (entries state.page)[state.selected]? with
      | some (.page target, _) => .stay { page := target }
      | _ => .stay state
  | .enter =>
      match (entries state.page)[state.selected]? with
      | some (.page target, _) => .stay { page := target }
      | some (.action choice, _) => .open choice
      | none => .stay state
  | .up | .input 'k' | .input 'K' =>
      .stay { state with selected := state.selected - 1 }
  | .down | .input 'j' | .input 'J' =>
      .stay { state with selected := min (entries state.page).length.pred (state.selected + 1) }
  | _ => .stay state

private def canFloat (bounds : Bounds) : Bool :=
  Loam.Tui.Layout.contentWidth bounds >= 64 && bounds.height >= 18

/-- Keep one rectangle across pages, sized for the largest current command group.
Eight rows cover borders, context and help. Leave two rows above/below a floating
panel; compact terminals use their available height and retain scrolling. -/
private def panelHeight (bounds : Bounds) : Nat :=
  let largest := (entries .commands).foldl (fun count (entry, _) =>
    match entry with
    | .page target => max count (entries target).length
    | .action _ => count) (entries .commands).length
  let available := if canFloat bounds then bounds.height - 4 else bounds.height
  min (largest + 8) available

/-- A bounded selection-relative viewport, recomputed on resize. No second
selection or retained scroll authority is needed for this short chooser. -/
def view (bounds : Bounds) (state : State) : Widget :=
  let panelWidth := min 54 (Loam.Tui.Layout.contentWidth bounds)
  let height := panelHeight bounds
  let framed := height >= 5 && panelWidth >= 2
  let bodyHeight := if framed then height - 2 else height
  let (path, description, backLabel) :=
    match state.page with
    | .commands => (" Home / Commands", " Choose a command group.", "Esc close")
    | .transactions => (" Commands / Transactions", " Recording and exchange.", "Esc back")
    | .planning => (" Commands / Plans and attention", " Scheduled household work.", "Esc back")
    | .analysis => (" Commands / Reports and analysis", " Read household answers.", "Esc back")
    | .envelopeBudget =>
        (" Commands / Envelope budget", " Budget features are optional.", "Esc back")
    | .maintenance => (" Commands / Household setup", " Explicit household evidence.", "Esc back")
  let header : List Widget :=
    if bodyHeight >= 9 then [.row [span path], .row [span description], .row []]
    else if bodyHeight >= 3 then [.row [span path]] else []
  let footer : List Widget :=
    if bodyHeight >= 9 then
      [.row [], .row [span " ↑/↓ select  → group  ← back" .muted],
       .row [span (" Enter open  " ++ backLabel) .muted]]
    else if bodyHeight >= 2 then
      [.row [span (" ↑↓/jk Enter  " ++ backLabel) .muted]]
    else []
  let page := bodyHeight - (header.length + footer.length)
  let items := entries state.page
  let offset := min (items.length - page) ((state.selected + 1) - page)
  let lines := (items.zipIdx.drop offset |>.take page).map fun ((_, title), index) =>
    let markerText := if state.selected == index then "  > " else "    "
    let width := if framed then panelWidth - 2 else panelWidth
    let text := Loam.Tui.Layout.padRight width (markerText ++ title)
    .row [span text (if state.selected == index then .selected else .normal)]
  let body : Widget := .column <|
    header ++ lines ++ List.replicate (page - lines.length) (.row []) ++ footer
  if framed then
    Loam.Tui.Layout.framedPanel panelWidth height "Commands" body
  else
    .column <| body.lines.map fun cells =>
      .row ((Loam.Tui.Layout.clipCells panelWidth cells).map fun cell =>
        span (String.singleton cell.glyph) cell.style)

private def floating? (bounds : Bounds) : Option (Nat × Nat × Nat × Nat) :=
  let available := Loam.Tui.Layout.contentWidth bounds
  if !canFloat bounds then
    none
  else
    let width := min 54 (available - 4)
    let height := panelHeight bounds
    some ((bounds.height - height) / 2,
      (available - width) / 2, width, height)

private def renderPanel
    (bounds : Bounds) (geometry : Option (Nat × Nat × Nat × Nat))
    (old next : CompiledWidget) : IO Unit := do
  match geometry with
  | some (top, left, width, _) =>
      Loam.Tui.Terminal.emitDirtyRegion bounds top left width old next
  | none =>
      Loam.Tui.Terminal.redrawFromBlank bounds next

/-- Run a short-lived modal chooser, including idle resize polling. -/
private partial def session
    (bounds : Bounds) (geometry : Option (Nat × Nat × Nat × Nat))
    (state : State) (frame : CompiledWidget) : IO (Option Choice) := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let geometry := if active == bounds then geometry else floating? active
  let frame ←
    if active == bounds then pure frame
    else do
      let next := compileWidget (view active state)
      -- Clear the old rectangle when switching between floating and compact.
      Loam.Tui.Terminal.redrawFromBlank active (compileWidget (.row []))
      renderPanel active geometry (compileWidget (.row [])) next
      pure next
  match update state key with
  | .close => return none
  | .open choice => return some choice
  | .stay next =>
      if next == state then
        session active geometry state frame
      else
        let nextFrame := compileWidget (view active next)
        renderPanel active geometry frame nextFrame
        session active geometry next nextFrame

/-- Prefer a floating panel above Home; use full-width on small terminals. -/
def run (bounds : Bounds) : IO (Option Choice) := do
  let geometry := floating? bounds
  let state : State := {}
  let frame := compileWidget (view bounds state)
  renderPanel bounds geometry (compileWidget (.row [])) frame
  session bounds geometry state frame

end Loam.Tui.HomeCommandPalette

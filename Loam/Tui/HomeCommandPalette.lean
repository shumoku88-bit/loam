import Loam.Tui.InputEdit
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
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
  /-- Search is a temporary lens, never a replacement for the category tree. -/
  search : Option String := none
  searchSelected : Nat := 0
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

/-- Search destinations are derived from the existing category leaves.
    This is NOT a second dispatcher: choice identity and category labels remain
    owned by `entries`. -/
structure SearchResult where
  choice : Choice
  label : String
  group : String
  deriving Repr, DecidableEq

private def catalog : List SearchResult :=
  (entries .commands).flatMap fun (root, groupName) =>
    match root with
    | .page page =>
        (entries page).filterMap fun (leaf, label) =>
          match leaf with
          | .action choice =>
              some { choice, label, group := groupName.replace " →" "" }
          | .page _ => none
    | .action _ => []

private def subsequence : List Char → List Char → Bool
  | [], _ => true
  | _ :: _, [] => false
  | needle@(head :: tail), current :: rest =>
      if head == current then subsequence tail rest
      else subsequence needle rest

/-- Prefix, then substring, then ordered fuzzy subsequence. Search is
    case-insensitive and can match a command or its discoverable category. -/
private def matchRank? (query label : String) : Option Nat :=
  let needle := query.toLower
  let haystack := label.toLower
  if needle.isEmpty || haystack.startsWith needle then some 0
  else if (haystack.splitOn needle).length > 1 then some 1
  else if subsequence needle.toList haystack.toList then some 2
  else none

/-- Public pure projection for testing; stable order for equal-scoring rows. -/
def searchResults (query : String) : List SearchResult :=
  let ranked := catalog.zipIdx.filterMap fun (entry, index) =>
    match matchRank? query (entry.label ++ " " ++ entry.group) with
    | some rank => some (rank, index, entry)
    | none => none
  (ranked.mergeSort fun a b =>
    if a.1 == b.1 then a.2.1 <= b.2.1 else a.1 <= b.1).map (·.2.2)

inductive Transition where
  | stay (state : State)
  | open (choice : Choice)
  | close
  deriving Repr, DecidableEq

/-- Restore the selected parent group from the actual Commands entries.
    This avoids a second copy of the group order or retained navigation state. -/
private def rootGroupSelection (page : Page) : Nat :=
  ((entries .commands).findIdx? (fun (entry, _) =>
    match entry with
    | .page target => decide (target = page)
    | .action _ => false)).getD 0

/-- Search owns ordinary letters (including j/k/q and spaces); arrows navigate
    matches, Esc returns to the exactly preserved hierarchical page. -/
private def updateSearch (state : State) (query : String)
    (key : Loam.Tui.Terminal.Key) : Transition :=
  let rows := searchResults query
  match key with
  | .escape | .left =>
      .stay { state with search := none }
  | .up =>
      .stay { state with searchSelected := state.searchSelected - 1 }
  | .down =>
      .stay { state with searchSelected :=
        (min (rows.length - 1) (state.searchSelected + 1)) }
  | .enter =>
      match rows[state.searchSelected]? with
      | some item => .open (item.choice)
      | none => .stay state
  | .input _ | .backspace | .paste _ =>
      match Loam.Tui.InputEdit.apply? key query with
      | some edited =>
          let clipped := String.ofList <| (edited.toList.filter
            (fun c => c.toNat >= 32 && c.toNat != 127)).take 64
          .stay { state with search := some clipped, searchSelected := 0 }
      | none => .stay state
  | _ => .stay state

/-- One pure command interpreter; the search lens and hierarchy share leaves. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Transition :=
  match state.search with
  | some query => updateSearch state query key
  | none =>
      match key with
      | .input '/' => .stay { state with search := some "", searchSelected := 0 }
      | .left | .escape | .input 'q' | .input 'Q' | .input ' ' =>
          match state.page with
          | .commands => .close
          | _ => .stay { selected := rootGroupSelection state.page }
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
          .stay { state with selected :=
            (min ((entries state.page).length - 1) (state.selected + 1)) }
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
  let searching := state.search.isSome
  let query := state.search.getD ""
  let (path, description, backLabel) :=
    if searching then
      (" Commands / Search",
       " / " ++ query ++ "▏  (" ++ toString (searchResults query).length ++ " matches)",
       "Esc browse")
    else
      match state.page with
      | .commands => (" Home / Commands", " Choose a command group.  / search", "Esc close")
      | .transactions => (" Commands / Transactions", " Recording and exchange.  / search", "Esc back")
      | .planning => (" Commands / Plans and attention", " Scheduled household work.  / search", "Esc back")
      | .analysis => (" Commands / Reports and analysis", " Read household answers.  / search", "Esc back")
      | .envelopeBudget =>
          (" Commands / Envelope budget", " Budget features are optional.  / search", "Esc back")
      | .maintenance =>
          (" Commands / Household setup", " Explicit household evidence.  / search", "Esc back")
  let header : List Widget :=
    if bodyHeight >= 9 then
      [.row [span path], .row [span (Loam.Tui.Layout.clip (panelWidth - 3) description)], .row []]
    else if bodyHeight >= 3 then [.row [span path]] else []
  let footer : List Widget :=
    if bodyHeight >= 9 then
      if searching then
        [.row [], .row [span " ↑/↓ select  Backspace edit" .muted],
         .row [span " Enter open  Esc browse" .muted]]
      else
        [.row [], .row [span " ↑/↓ select  → group  / search" .muted],
         .row [span (" Enter open  " ++ backLabel) .muted]]
    else if bodyHeight >= 2 then
      [.row [span
        (if searching then " ↑↓ Enter  Esc browse" else " ↑↓ Enter  / search  " ++ backLabel) .muted]]
    else []
  let page := bodyHeight - (header.length + footer.length)
  let items : List String :=
    if searching then
      (searchResults query).map fun item => item.label ++ " · " ++ item.group
    else
      (entries state.page).map Prod.snd
  let selected := if searching then state.searchSelected else state.selected
  let offset := min (items.length - page)
    (Loam.Tui.Layout.trailingWindowStart selected page)
  let shown := (items.zipIdx.drop offset |>.take page)
  let lines :=
    if searching && items.isEmpty && page > 0 then
      [.row [span "  No matches. Esc to browse." .muted]]
    else shown.map fun (title, index) =>
      let markerText := if selected == index then "  > " else "    "
      let width := if framed then panelWidth - 2 else panelWidth
      let shownText := Loam.Tui.Layout.clip width (markerText ++ title)
      let padded := Loam.Tui.Layout.padRight width shownText
      .row [span padded (if selected == index then .selected else .normal)]
  let body : Widget := .column <|
    header ++ lines ++ List.replicate (page - lines.length) (.row []) ++ footer
  if framed then
    -- Use the existing active-frame accent only for a truly floating overlay.
    -- Compact full-width presentations keep their quiet border.
    Loam.Tui.Layout.framedPanel panelWidth height "Commands" body (canFloat bounds)
  else
    .column <| body.lines.map fun cells =>
      .row ((Loam.Tui.Layout.clipCells panelWidth cells).map fun cell =>
        span (String.singleton cell.glyph) cell.style)

private def floating? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 64 18 54 (panelHeight bounds)

private def renderPanel
    (bounds : Bounds) (geometry : Option Loam.Tui.ModalSurface.Rectangle)
    (old next : CompiledWidget) : IO Unit :=
  Loam.Tui.ModalSurface.paint bounds geometry .fromBlank old next

/-- Run a short-lived modal chooser, including idle resize polling. -/
private partial def session
    (bounds : Bounds) (geometry : Option Loam.Tui.ModalSurface.Rectangle)
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

import Loam.Tui.ReportsModel
import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.RoleFlowReview
import Loam.Presentation.Reports
import Loam.Tui.RoleBalances
import Loam.Tui.ScheduledCoveragePane
import Loam.Tui.TransactionsFlowPane
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Scroll
import Loam.Tui.Terminal

namespace Loam.Tui.Reports

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Production Reports rendering

Terminal rendering for the Reports workspace.

State transitions and query production remain in `Loam.Tui.ReportsModel`.
This module consumes that presentation state and shared Review answers only; it
does not load household data, publish facts, or define report semantics.
-/

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def signedQuanta (quantity : Loam.Core.Quantity) : String :=
  if quantity.quanta > 0 then "+" ++ toString quantity.quanta else toString quantity.quanta

private def padNum (columns : Nat) (text : String) : String :=
  let width := Loam.Tui.Layout.displayWidth text
  if width ≥ columns then Loam.Tui.Layout.clip columns text
  else Loam.Tui.Layout.padLeft columns text


private def field (state : State) (index : Nat) (label text : String) : Widget :=
  .row
    [ span (label ++ ": ")
    , span (if text.isEmpty then "_" else text)
        (if state.window.form.focus.val = index then .selected else .normal)
    ]

private def comparisonField
    (state : State) (index : Nat) (label text : String) : Widget :=
  .row
    [ span (label ++ ": ")
    , span (if text.isEmpty then "_" else text)
        (if state.comparison.focus.val = index then .selected else .normal)
    ]

private def comparisonFormLines (state : State) : List Widget :=
  [ comparisonField state 0 "Left start" state.comparison.leftStart
  , comparisonField state 1 "Left end (exclusive)" state.comparison.leftEndExclusive
  , comparisonField state 2 "Right start" state.comparison.rightStart
  , comparisonField state 3 "Right end (exclusive)" state.comparison.rightEndExclusive
  , .row [span "[Run comparison]"
      (if state.comparison.focus.val = 4 then .selected else .normal)]
  ]

private def comparisonPanels
    (bounds : Option Bounds) (left right : List Widget) : List Widget :=
  match bounds with
  | some terminal =>
      if terminal.width ≥ 120 then
        let width := Loam.Tui.Layout.contentWidth terminal
        let dividerWidth := 3
        let leftWidth := (width - dividerWidth) / 2
        let rightWidth := width - dividerWidth - leftWidth
        let leftWidget : Widget := .column left
        let rightWidget : Widget := .column right
        let height := max leftWidget.lines.length rightWidget.lines.length
        Loam.Tui.Layout.sideBySide
          height leftWidth rightWidth leftWidget rightWidget
      else
        left ++ [blank] ++ right
  | none => left ++ [blank] ++ right

private def liquidityField (state : State) : Widget :=
  .row
    [ span "Assume Scheduled complete through: "
    , span
        (if state.liquidityForm.assumedCompleteThrough.isEmpty then
          "_"
        else
          state.liquidityForm.assumedCompleteThrough)
        (if state.liquidityForm.focus.val = 0 then .selected else .normal)
    ]

private def menuRow (state : State) (index : Nat) (label note : String) : Widget :=
  .row
    [ span (if state.menuIndex.val = index then "> " else "  ")
    , span label (if state.menuIndex.val = index then .selected else .normal)
    , span ("  " ++ note) .muted
    ]

private def menuView (state : State) : Widget :=
  .column
    [ line "Reports"
    , muted "Home > Reports"
    , muted "Small derived views over shared production evidence."
    , blank
    , menuRow state 0 "Stock–Flow" "state change across an explicit window"
    , menuRow state 1 "Transactions Flow" "where quantity moved, including zero-net circulation"
    , menuRow state 2 "Income & Expense" "occurrence-time role flow"
    , menuRow state 3 "Balances" "evidence-aware current accounting projections"
    , menuRow state 4 "Liquidity" "UNKNOWN baseline + explicit conditional overlay"
    , menuRow state 5 "Budget Window" "explicit entitlement / consumption query"
    , menuRow state 6 "Scheduled Coverage" "future monthly / multi-month plan holes"
    , menuRow state 7 "Fava Projection" "launch disposable Beancount/Fava observation in browser"
    , blank
    , muted "↑/↓ or j/k select   Enter open   s/t/i/r/l/w/c/f direct"
    , muted "q / Esc home"
    , line state.notice
    ]

private def stockFlowMeasureSuffix (measure : Option Loam.Core.MeasureId) : String :=
  match measure with
  | none => ""
  | some selected => " " ++ selected.token

private def stockFlowResultLines (state : State) : List Widget :=
  match state.stockFlowSnapshot with
  | none => [muted "No explicit Stock–Flow window has been run yet."]
  | some snapshot =>
      let label := Loam.Tui.Layout.padRight 36
      let measure := stockFlowMeasureSuffix snapshot.measure
      [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , line (label "Reconstructed at start:" ++ padNum 12 (toString snapshot.reconstructedStart.quanta) ++ measure)
      , line (label "Reconstructed at end:" ++ padNum 12 (toString snapshot.reconstructedEnd.quanta) ++ measure)
      , blank
      , line (label "Tracked increases across Events:" ++ padNum 12 (signedQuanta snapshot.increasesAcrossEvents) ++ measure)
      , line (label "Tracked decreases across Events:" ++ padNum 12 (signedQuanta snapshot.decreasesAcrossEvents) ++ measure)
      , line (label "Net change:" ++ padNum 12 (signedQuanta snapshot.netChange) ++ measure)
      , blank
      , muted (label "Current tracked balance now:" ++ padNum 12 (toString snapshot.currentTracked.quanta) ++ measure)
      , muted "Boundary values are reconstructed from current accepted evidence."
      , muted "They are not archived historical balance snapshots."
      , muted "Increase/decrease is tracked-balance motion, not income/spending."
      ]

private def stockFlowView (state : State) : Widget :=
  .column <|
    [ line "Reports / Stock–Flow"
    , muted "Why did the tracked balance change between two boundaries?"
    , muted "Calendar month is only a coordinate convenience, not a household cycle."
    , line ("Window: " ++ windowSourceLabel state)
    , muted "Named presets are replaceable query config; reports still receive explicit coordinates only."
    , blank
    , field state 0 "Start" state.window.form.start
    , field state 1 "End (exclusive)" state.window.form.endExclusive
    , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
    , blank
    ] ++
    stockFlowResultLines state ++
    [ blank
    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "c compare periods   q / Esc Reports menu"
    , line state.notice
    ]

private def stockFlowComparisonLines
    (state : State) (bounds : Option Bounds) : List Widget :=
  match state.stockFlowComparison with
  | none => [muted "No two-period Stock–Flow comparison has been run yet."]
  | some comparison =>
      let left :=
        [line "Left period"] ++
        stockFlowResultLines { state with stockFlowSnapshot := some comparison.left }
      let right :=
        [line "Right period"] ++
        stockFlowResultLines { state with stockFlowSnapshot := some comparison.right }
      comparisonPanels bounds left right

private def stockFlowCompareView (state : State) (bounds : Option Bounds) : Widget :=
  .column <|
    [ line "Reports / Stock–Flow / Compare"
    , muted "Same qualified Stock–Flow question, two independent explicit windows."
    , muted "Wide terminals show Left and Right side by side; narrow terminals stack them."
    , blank
    ] ++
    comparisonFormLines state ++
    [ blank ] ++
    stockFlowComparisonLines state bounds ++
    [ blank
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "q / Esc single-period Stock–Flow"
    , line state.notice
    ]


private def transactionWindowLines (state : State) : List Widget :=
  [ line "Reports / Transactions Flow"
  , muted "Which exact coordinates moved in this window?"
  , muted "Zero-net circulation visible via gross activity."
  , line ("Window: " ++ windowSourceLabel state)
  , muted "Presets only resolve explicit [start, end) dates."
  , blank
  , field state 0 "Start" state.window.form.start
  , field state 1 "End (exclusive)" state.window.form.endExclusive
  , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
  , blank
  ]

private def transactionsFlowView (state : State) (bounds : Option Bounds) : Widget :=
  if state.transactions.detail then
    .column <|
      [ line "Reports / Transactions Flow"
      , muted "Focused nonzero Event witnesses for coordinate."
      , blank
      ] ++
      Loam.Tui.TransactionsFlowPane.detailLines state.transactions ++
      [ blank
      , muted "↑/↓ or j/k scroll contributors"
      , muted "b / Esc summary   q quit"
      , muted "No pairwise flow edge inferred from signed Effects."
      , line state.notice
      ]
  else
    .column <|
      transactionWindowLines state ++
      Loam.Tui.TransactionsFlowPane.summaryLines state.transactions bounds ++
      [ blank
      , muted "[ / ] source   ← / → Month   m sel-day month"
      , muted "↑/↓ select coord   Enter detail   Tab window focus"
      , muted "q / Esc Reports menu"
      , line state.notice
      ]

private def incomeExpenseBreakdownRows
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId) (role : Loam.Core.AccountingRole) :
    List Loam.RoleFlowReview.Row :=
  (snapshot.rows.filter fun row =>
    decide (row.coordinate.measure = measure ∧ row.role = role)).mergeSort fun a b =>
      a.coordinate.locus.token <= b.coordinate.locus.token

private def incomeExpenseDisplayQuanta
    (role : Loam.Core.AccountingRole) (quantity : Loam.Core.Quantity) : Int :=
  if role = .income then -quantity.quanta else quantity.quanta

private def incomeExpenseBreakdownLines
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId) (role : Loam.Core.AccountingRole)
    (heading : String) : List Widget :=
  let rows := incomeExpenseBreakdownRows snapshot measure role
  if rows.isEmpty then
    [muted (heading ++ ": (none)")]
  else
    [muted heading] ++ rows.map fun row =>
      line
        ("  " ++ Loam.Tui.Layout.padRight 24 row.coordinate.locus.token ++
          padNum 12 (toString (incomeExpenseDisplayQuanta role row.quantity)) ++
          " " ++ measure.token)

private def incomeExpenseMeasureLines
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (summary : Loam.Presentation.Reports.IncomeExpenseMeasure) : List Widget :=
  let measure := summary.measure
  let label := Loam.Tui.Layout.padRight 16
  [ line (measure.token ++ "  occurrence-time P/L-shaped flow")
  , line (label "Income:" ++ padNum 12 (toString summary.income.quanta) ++ " " ++ measure.token)
  , line (label "Expense:" ++ padNum 12 (toString summary.expense.quanta) ++ " " ++ measure.token)
  , line (label "Result:" ++ padNum 12 (toString summary.result.quanta) ++ " " ++ measure.token)
  , blank
  ] ++
  incomeExpenseBreakdownLines snapshot measure .income "Income breakdown" ++
  [blank] ++
  incomeExpenseBreakdownLines snapshot measure .expense "Expense breakdown"

private def unresolvedIncomeExpenseLine
    (entry : Loam.RoleFlowReview.UnresolvedEffect) : Widget :=
  line
    ("? " ++ entry.date ++ "  " ++ entry.effect.locus.token ++ "  " ++
      signedQuanta entry.effect.quantity ++ " " ++ entry.effect.measure.token ++
      "  [" ++ entry.event.token ++ "]")

private def incomeExpenseResultLines (state : State) : List Widget :=
  match state.incomeExpenseSnapshot with
  | none => [muted "No explicit Income & Expense window has been run yet."]
  | some snapshot =>
      let summary := Loam.Presentation.Reports.incomeExpenseFromRoleFlow snapshot
      let unresolved := snapshot.unresolvedEffects
      [ line ("Window [" ++ summary.start ++ ", " ++ summary.endExclusive ++ ")")
      , muted "Income display = -raw signed Income; Expense display = raw signed Expense."
      , muted "Distinct Measures remain separate and are never valued or summed together."
      , blank
      ] ++
      (if summary.measures.isEmpty then
        [muted "No classified Income or Expense quantity appears in this window."]
       else
        summary.measures.flatMap fun measure =>
          incomeExpenseMeasureLines snapshot measure ++ [blank]) ++
      [ line ("Unresolved role Effects: " ++ toString summary.unresolvedEffectCount) ] ++
      (unresolved.take 8).map unresolvedIncomeExpenseLine ++
      (if unresolved.length > 8 then
        [muted ("... " ++ toString (unresolved.length - 8) ++ " later unresolved Effect(s) omitted")]
       else
        []) ++
      [ muted
          (if unresolved.isEmpty then
            "Role classification is complete for selected quantity Effects."
           else
            "Totals are partial while unresolved role Effects remain above.")
      , muted "This is occurrence-time role flow, not accrual recognition or period closing."
      ]

private def incomeExpenseView (state : State) : Widget :=
  .column <|
    [ line "Reports / Income & Expense"
    , muted "What Income / Expense role flow occurred inside this explicit window?"
    , line ("Window: " ++ windowSourceLabel state)
    , muted "AccountingRole is explicit authority; no role is inferred from spelling or sign."
    , blank
    , field state 0 "Start" state.window.form.start
    , field state 1 "End (exclusive)" state.window.form.endExclusive
    , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
    , blank
    ] ++
    incomeExpenseResultLines state ++
    [ blank
    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "c compare periods   q / Esc Reports menu"
    , line state.notice
    ]

private def incomeExpenseComparisonLines
    (state : State) (bounds : Option Bounds) : List Widget :=
  match state.incomeExpenseComparison with
  | none => [muted "No two-period Income & Expense comparison has been run yet."]
  | some comparison =>
      let left :=
        [line "Left period"] ++
        incomeExpenseResultLines
          { state with incomeExpenseSnapshot := some comparison.left }
      let right :=
        [line "Right period"] ++
        incomeExpenseResultLines
          { state with incomeExpenseSnapshot := some comparison.right }
      comparisonPanels bounds left right

private def incomeExpenseCompareView (state : State) (bounds : Option Bounds) : Widget :=
  .column <|
    [ line "Reports / Income & Expense / Compare"
    , muted "Same occurrence-time role-flow question, two independent explicit windows."
    , muted "No delta, percentage, equal-duration, or baseline meaning is inferred."
    , blank
    ] ++
    comparisonFormLines state ++
    [ blank ] ++
    incomeExpenseComparisonLines state bounds ++
    [ blank
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "q / Esc single-period Income & Expense"
    , line state.notice
    ]

private def balancesResultLines (state : State) : List Widget :=
  match state.roleBalanceSnapshot with
  | none => [muted "Current RoleBalance answer unavailable; press Enter to retry."]
  | some snapshot => Loam.Tui.RoleBalances.lines snapshot

private def balancesView (state : State) : Widget :=
  .column <|
    [ line "Reports / Balances"
    , muted "Current evidence-aware accounting projections from shared RoleBalance."
    , muted "Balance Sheet / Net Worth / Trial Balance are presentations, not separate engines."
    , blank
    ] ++
    balancesResultLines state ++
    [ blank
    , muted "Enter refresh   ↑/↓ or j/k scroll"
    , muted "q / Esc Reports menu"
    , line state.notice
    ]

private def liquidityPointLine
    (measure : Loam.Core.MeasureId)
    (point : Loam.ConditionalBalancePathReview.Point) : Widget :=
  line
    ("- " ++ point.date ++
      "  Scheduled " ++ padNum 10 (signedQuanta point.scheduledChange) ++
      "  -> " ++ padNum 10 (toString point.balance.quanta) ++ " " ++ measure.token)

private def liquidityResultLines (state : State) : List Widget :=
  match state.liquiditySnapshot with
  | none => [muted "No conditional selected-balance outlook has been run yet."]
  | some snapshot =>
      let points := snapshot.points.take 12
      [ line "CONDITIONAL selected-balance outlook"
      , line ("As of: " ++ snapshot.asOf)
      , line
          ("Assumption: no additional Scheduled items through " ++
            snapshot.assumedCompleteThrough)
      , line
          ("Current selected balance: " ++
            toString snapshot.currentSelected.quanta ++ " " ++ snapshot.measure.token)
      , blank
      ] ++
      (if points.isEmpty then
        [muted "No selected current-open Scheduled changes occur inside this horizon."]
       else
        points.map (liquidityPointLine snapshot.measure)) ++
      (if snapshot.points.length > 12 then
        [muted ("... " ++ toString (snapshot.points.length - 12) ++ " later change point(s) omitted")]
       else
        []) ++
      [ blank
      , line
          ("Conditional balance at horizon: " ++
            toString snapshot.finalAtHorizon.quanta ++ " " ++ snapshot.measure.token)
      , line
          ("Conditional day-boundary low-water: " ++
            toString snapshot.lowWater.quanta ++ " " ++ snapshot.measure.token)
      , muted "This is the replaceable balance-view selection, not canonical liquidity."
      , muted "The numbers are conditional on the explicit completeness assumption above."
      , muted "Same-day effects are netted; no intraday low-water is claimed."
      ]

private def liquidityView (state : State) : Widget :=
  .column <|
    [ line "Reports / Liquidity"
    , muted "What can LOAM safely say about the future selected-balance path?"
    , blank
    , line "Forecast path: UNKNOWN"
    , line "Known low-water mark: UNKNOWN"
    , muted "Production still has no retained complete-future evidence for this report."
    , muted "Known Scheduled items are not silently treated as all future flows."
    , blank
    , line "Read-only conditional query"
    , liquidityField state
    , .row
        [ span "[Run conditional]"
            (if state.liquidityForm.focus.val = 1 then .selected else .normal) ]
    , muted "Running this does not write or upgrade the assumption into evidence."
    , blank
    ] ++
    liquidityResultLines state ++
    [ blank
    , muted "m selected-day month end   Tab / Shift-Tab focus"
    , muted "Enter next/run   Backspace delete   q / Esc Reports menu"
    , line state.notice
    ]

private def budgetRowLine (row : Loam.BudgetWindowReview.Row) : Widget :=
  line
    (Loam.Tui.Layout.padRight 16 row.purpose.token ++
      padNum 10 (toString row.entitlement.quanta) ++
      padNum 10 (toString row.consumption.quanta) ++
      padNum 10 (toString row.remaining.quanta) ++ " jpy")

private def budgetTableHeader : Widget :=
  muted
    (Loam.Tui.Layout.padRight 16 "Purpose" ++
      padNum 10 "Entitled" ++
      padNum 10 "Consumed" ++
      padNum 10 "Remaining")

private def budgetResultLines (state : State) : List Widget :=
  match state.budgetSnapshot with
  | none => [muted "No explicit Budget Window has been run yet."]
  | some snapshot =>
      [ line ("Budget window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , muted (toString snapshot.rows.length ++ " remembered purpose(s)")
      , budgetTableHeader
      ] ++
      (snapshot.rows.take 10).map budgetRowLine ++
      [ muted "Remaining is derived exactly as Entitlement - Consumption." ]

private def budgetView (state : State) : Widget :=
  .column <|
    [ line "Reports / Budget Window"
    , muted "Calendar month is only a coordinate convenience, not a household cycle."
    , line ("Window: " ++ windowSourceLabel state)
    , muted "Named presets are replaceable query config; reports still receive explicit coordinates only."
    , blank
    , field state 0 "Start" state.window.form.start
    , field state 1 "End (exclusive)" state.window.form.endExclusive
    , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
    , muted "Coordinates stay explicit [start, end); no cycle or budget period is inferred."
    , blank
    ] ++
    budgetResultLines state ++
    [ blank
    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "q / Esc Reports menu"
    , line state.notice
    ]

private def scheduledCoverageView (state : State) : Widget :=
  .column <|
    [ line "Reports / Scheduled Coverage"
    , muted "Which monitored future months already have explicit current-open Scheduled evidence?"
    , muted "The grid starts after the selected Home date; monitoring rules are replaceable read-side config."
    , blank
    ] ++
    (match state.scheduledCoverageSnapshot with
     | none => [muted "Coverage has not been loaded yet; press Enter to refresh."]
     | some snapshot => Loam.Tui.ScheduledCoveragePane.lines snapshot) ++
    [ blank
    , muted "Enter refresh   ↑/↓ scroll"
    , muted "q / Esc Reports menu"
    , line state.notice
    ]


private def fullView (state : State) (bounds : Option Bounds := none) : Widget :=
  match state.mode with
  | .menu => menuView state
  | .stockFlow => stockFlowView state
  | .stockFlowCompare => stockFlowCompareView state bounds
  | .transactionsFlow => transactionsFlowView state bounds
  | .incomeExpense => incomeExpenseView state
  | .incomeExpenseCompare => incomeExpenseCompareView state bounds
  | .balances => balancesView state
  | .liquidity => liquidityView state
  | .budgetWindow => budgetView state
  | .scheduledCoverage => scheduledCoverageView state

/-- Number of existing trailing notice/help rows kept outside the scrolling body. -/
private def fixedFooterSize : Mode → Nat
  | .menu => 3
  | .stockFlow => 4
  | .stockFlowCompare => 3
  | .transactionsFlow => 4
  | .incomeExpense => 4
  | .incomeExpenseCompare => 3
  | .balances => 4
  | .liquidity => 3
  | .budgetWindow => 4
  | .scheduledCoverage => 4

private def viewParts (state : State) (bounds : Option Bounds := none) : List Widget × List Widget :=
  match fullView state bounds with
  | .column children =>
      let footerSize := min (fixedFooterSize state.mode) children.length
      let bodySize := children.length - footerSize
      (children.take bodySize, children.drop bodySize)
  | other => ([other], [])

private def bodyPageSize (bounds : Bounds) (footer : List Widget) : Nat :=
  bounds.height - (footer.length + 1)

/-- Largest meaningful vertical offset for the current report and terminal height. -/
def scrollLimit (bounds : Bounds) (state : State) : Nat :=
  let parts := viewParts state (some bounds)
  Loam.Tui.Scroll.maxOffset parts.1.length (bodyPageSize bounds parts.2)

private def scrollPositionLine
    (mode : Mode) (offset page total : Nat) : Widget :=
  let first := if total = 0 then 0 else offset + 1
  let last := min total (offset + page)
  let action := match mode with | .menu => "select" | .transactionsFlow => "navigate" | _ => "scroll"
  muted ("Lines " ++ toString first ++ "–" ++ toString last ++ "/" ++ toString total ++
    "   ↑/↓ or j/k " ++ action)

private def requestedOffset (state : State) (page : Nat) : Nat :=
  match state.mode with
  | .menu =>
      -- The seven menu rows follow four heading/context rows in `menuView`.
      (4 + state.menuIndex.val + 1) - page
  | .transactionsFlow =>
    if state.transactions.detail then
      state.scroll
    else
      match Loam.Tui.TransactionsFlowPane.selectedSummaryLine? state.transactions with
      | none => state.scroll
      | some selectedBodyLine =>
          let selectedLine := (transactionWindowLines state).length + selectedBodyLine
          (selectedLine + 1) - page
  | _ => state.scroll

/-- Bound only presentation rows; report answers and query coordinates are unchanged. -/
def viewForBounds (bounds : Bounds) (state : State) : Widget :=
  let parts := viewParts state (some bounds)
  let page := bodyPageSize bounds parts.2
  let offset := Loam.Tui.Scroll.clamp parts.1.length page (requestedOffset state page)
  let position := scrollPositionLine state.mode offset page parts.1.length
  if bounds.height < parts.2.length + 1 then
    -- In a tiny terminal, retain as much navigation as possible. Existing views
    -- put their notice last and their most essential back/quit row immediately
    -- before it, so reverse the navigation rows and omit body before overflowing.
    let navigation := parts.2.dropLast.reverse
    let notice := parts.2.getLast?.toList
    .column <| (navigation ++ [position] ++ notice).take bounds.height
  else
    .column <|
      (parts.1.drop offset).take page ++
      [position] ++
      parts.2

/-- Apply the existing interaction grammar, then clamp presentation-only scrolling. -/
def updateForBounds
    (bounds : Bounds) (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  let step := update state key
  let parts := viewParts step.state (some bounds)
  let page := bodyPageSize bounds parts.2
  { step with state := { step.state with
      scroll := Loam.Tui.Scroll.clamp parts.1.length page step.state.scroll } }

/-- Unbounded compatibility view used by existing pure presentation tests. -/
def view (state : State) : Widget := fullView state none

end Loam.Tui.Reports

import Loam.Tui.ReportsModel
import Loam.Review.BudgetWindowReview
import Loam.Review.ConditionalBalancePathReview
import Loam.Review.MultimeasureSpendReview
import Loam.Presentation.MeasurePresentation
import Loam.Review.DailyRoleFlowReview
import Loam.Review.MonthlyRoleFlowReview
import Loam.Review.RoleFlowReview
import Loam.Presentation.Reports
import Loam.Tui.RoleBalances
import Loam.Tui.TransactionsFlowPane
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.LocusTrendComparePane
import Loam.Tui.Scroll
import Loam.Tui.Terminal
import Loam.Tui.Viewport

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
  [ line ("Compare by: " ++ comparisonSourceLabel state)
  , muted "Automatic sources keep two adjacent explicit windows; editing switches to Custom."
  , blank
  , comparisonField state 0 "Left start" state.comparison.leftStart
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
    , menuRow state 6 "Multicurrency Spend" "expense, original amount, and exchange evidence kept separate"
    , menuRow state 7 "Trend" "one to three exact Loci on one shared time axis"
    , menuRow state 8 "Fava Projection" "launch disposable Beancount/Fava observation in browser"
    , blank
    , muted "↑/↓ or j/k select   Enter open   s/t/i/r/l/w/x/v/f direct"
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
    , muted "[ / ] source   ← / → comparison pair   e edit dates   Enter next/run"
    , muted "Tab / Shift-Tab focus   Backspace delete   q / Esc single-period"
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

private def incomeExpenseRowLines
    (rows : List Loam.RoleFlowReview.Row)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole)
    (heading : String) : List Widget :=
  let selected :=
    (rows.filter fun row =>
      decide (row.coordinate.measure = measure) && row.quantity.quanta != 0)
      |>.mergeSort fun a b => a.coordinate.locus.token <= b.coordinate.locus.token
  if selected.isEmpty then
    [muted (heading ++ ": (none)")]
  else
    [muted heading] ++ selected.map fun row =>
      line
        ("  " ++ Loam.Tui.Layout.padRight 24 row.coordinate.locus.token ++
          padNum 12 (toString (incomeExpenseDisplayQuanta role row.quantity)) ++
          " " ++ measure.token)

private def incomeExpenseBreakdownLines
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId) (role : Loam.Core.AccountingRole)
    (heading : String) : List Widget :=
  incomeExpenseRowLines
    (incomeExpenseBreakdownRows snapshot measure role) measure role heading

private def expensePartitionTotal
    (rows : List Loam.RoleFlowReview.Row)
    (measure : Loam.Core.MeasureId) : Int :=
  rows.foldl
    (fun total row =>
      if row.coordinate.measure = measure then total + row.quantity.quanta else total)
    0

private def expenseProvenanceLines
    (snapshot : Loam.IncomeExpenseProvenanceReview.Snapshot)
    (measure : Loam.Core.MeasureId) : List Widget :=
  match snapshot.expenseProvenance with
  | .unknown reason =>
      [ muted "Expense provenance: UNKNOWN"
      , muted ("  " ++ reason)
      ] ++
      incomeExpenseBreakdownLines
        snapshot.roleFlow measure .expense "Expense breakdown"
  | .available partition =>
      let linkedTotal := expensePartitionTotal partition.scheduledLinked measure
      let unlinkedTotal := expensePartitionTotal partition.noScheduledLink measure
      [ line
          ("Scheduled-linked expense:" ++
            padNum 12 (toString linkedTotal) ++ " " ++ measure.token)
      ] ++
      incomeExpenseRowLines
        partition.scheduledLinked measure .expense "  Breakdown" ++
      [blank,
       line
          ("No Scheduled link:" ++
            padNum 12 (toString unlinkedTotal) ++ " " ++ measure.token)
      ] ++
      incomeExpenseRowLines
        partition.noScheduledLink measure .expense "  Breakdown" ++
      [ muted
          "Scheduled-linked means retained completion provenance, not a fixed/recurring-cost classification." ]

private def incomeExpenseMeasureLines
    (snapshot : Loam.IncomeExpenseProvenanceReview.Snapshot)
    (summary : Loam.Presentation.Reports.IncomeExpenseMeasure) : List Widget :=
  let measure := summary.measure
  let label := Loam.Tui.Layout.padRight 16
  [ line (measure.token ++ "  occurrence-time P/L-shaped flow")
  , line (label "Income:" ++ padNum 12 (toString summary.income.quanta) ++ " " ++ measure.token)
  , line (label "Expense:" ++ padNum 12 (toString summary.expense.quanta) ++ " " ++ measure.token)
  , line (label "Result:" ++ padNum 12 (toString summary.result.quanta) ++ " " ++ measure.token)
  , blank
  ] ++
  incomeExpenseBreakdownLines snapshot.roleFlow measure .income "Income breakdown" ++
  [blank] ++
  expenseProvenanceLines snapshot measure

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
      let roleFlow := snapshot.roleFlow
      let summary := Loam.Presentation.Reports.incomeExpenseFromRoleFlow roleFlow
      let unresolved := roleFlow.unresolvedEffects
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

private def monthlyMeasures
    (snapshot : Loam.MonthlyRoleFlowReview.Snapshot) : List Loam.Core.MeasureId :=
  snapshot.rows.foldl
    (fun measures row =>
      if row.coordinate.measure ∈ measures then measures
      else measures ++ [row.coordinate.measure])
    []

private def monthlyRows
    (snapshot : Loam.MonthlyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole) : List Loam.MonthlyRoleFlowReview.Row :=
  (snapshot.rows.filter fun row =>
    decide (row.coordinate.measure = measure ∧ row.role = role)).mergeSort fun a b =>
      a.coordinate.locus.token <= b.coordinate.locus.token

private def monthlyDisplayQuanta
    (role : Loam.Core.AccountingRole) (quantity : Loam.Core.Quantity) : Int :=
  if role = .income then -quantity.quanta else quantity.quanta

private def monthlyRoleQuanta
    (snapshot : Loam.MonthlyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole)
    (month : String) : Int :=
  snapshot.rows.foldl
    (fun total row =>
      if decide (row.coordinate.measure = measure ∧ row.role = role) then
        total + (Loam.MonthlyRoleFlowReview.Row.quantityAt row month).quanta
      else
        total)
    0

private def monthlyRolePeriodQuanta
    (snapshot : Loam.MonthlyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole) : Int :=
  snapshot.rows.foldl
    (fun total row =>
      if decide (row.coordinate.measure = measure ∧ row.role = role) then
        total + (Loam.MonthlyRoleFlowReview.Row.total row).quanta
      else
        total)
    0

private def monthlyBlockSize
    (bounds : Option Bounds) (showWindowTotal : Bool) : Nat :=
  match bounds with
  | none => 2
  | some terminal =>
      let fixedWidth := 24 + (if showWindowTotal then 14 else 0)
      max 1 ((Loam.Tui.Layout.contentWidth terminal - fixedWidth) / 14)

private def monthlyBlocks
    (blockSize : Nat) (months : List String) : List (List String) :=
  let size := max 1 blockSize
  let blockCount := (months.length + size - 1) / size
  (List.range blockCount).map fun index =>
    (months.drop (index * size)).take size

private def incomeExpenseAmountText
    (state : State)
    (measure : Loam.Core.MeasureId)
    (quanta : Int) : String :=
  Loam.MeasurePresentation.formatGroupedQuanta
    state.multimeasurePresentation measure quanta

private def monthlyRowLine
    (state : State)
    (row : Loam.MonthlyRoleFlowReview.Row)
    (months : List String)
    (showPeriodTotal : Bool) : Widget :=
  let cells :=
    months.foldl
      (fun text month =>
        text ++
          padNum 14
            (incomeExpenseAmountText state row.coordinate.measure
              (monthlyDisplayQuanta row.role
                (Loam.MonthlyRoleFlowReview.Row.quantityAt row month))))
      ""
  let period :=
    if showPeriodTotal then
      padNum 14
        (incomeExpenseAmountText state row.coordinate.measure
          (monthlyDisplayQuanta row.role
            (Loam.MonthlyRoleFlowReview.Row.total row)))
    else
      ""
  line
    ("  " ++ Loam.Tui.Layout.padRight 22 row.coordinate.locus.token ++
      cells ++ period)

private def monthlyTotalLine
    (state : State)
    (snapshot : Loam.MonthlyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole)
    (label : String)
    (months : List String)
    (showPeriodTotal : Bool) : Widget :=
  let cells :=
    months.foldl
      (fun text month =>
        let raw := monthlyRoleQuanta snapshot measure role month
        let display := if role = .income then -raw else raw
        text ++ padNum 14 (incomeExpenseAmountText state measure display))
      ""
  let period :=
    if showPeriodTotal then
      let rawPeriod := monthlyRolePeriodQuanta snapshot measure role
      let displayPeriod := if role = .income then -rawPeriod else rawPeriod
      padNum 14 (incomeExpenseAmountText state measure displayPeriod)
    else
      ""
  line
    ("  " ++ Loam.Tui.Layout.padRight 22 label ++ cells ++ period)

private def monthlyNetLine
    (state : State)
    (snapshot : Loam.MonthlyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (months : List String)
    (showPeriodTotal : Bool) : Widget :=
  let cells :=
    months.foldl
      (fun text month =>
        let income := -(monthlyRoleQuanta snapshot measure .income month)
        let expense := monthlyRoleQuanta snapshot measure .expense month
        text ++ padNum 14 (incomeExpenseAmountText state measure (income - expense)))
      ""
  let period :=
    if showPeriodTotal then
      let income := -(monthlyRolePeriodQuanta snapshot measure .income)
      let expense := monthlyRolePeriodQuanta snapshot measure .expense
      padNum 14 (incomeExpenseAmountText state measure (income - expense))
    else
      ""
  line
    ("  " ++ Loam.Tui.Layout.padRight 22 "Net" ++ cells ++ period)

private def monthlyDivider
    (months : List String) (showPeriodTotal : Bool) : Widget :=
  let width := 24 + months.length * 14 + (if showPeriodTotal then 14 else 0)
  muted (String.ofList (List.replicate width '-'))

private def monthlyMeasureBlockLines
    (state : State)
    (snapshot : Loam.MonthlyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (block : List String)
    (blockIndex blockCount : Nat)
    (showPeriodTotal : Bool) : List Widget :=
  let header :=
    block.foldl (fun text month => text ++ padNum 14 month)
      (Loam.Tui.Layout.padRight 24 "Account")
  let heading :=
    measure.token ++ "  Monthly Accounts" ++
      (if blockCount > 1 then
        "  block " ++ toString (blockIndex + 1) ++ "/" ++ toString blockCount
       else
        "")
  let headerWithPeriod :=
    if showPeriodTotal then header ++ Loam.Tui.Layout.padLeft 14 "Window total"
    else header
  let incomeRows := monthlyRows snapshot measure .income
  let expenseRows := monthlyRows snapshot measure .expense
  [ line heading
  , muted headerWithPeriod
  , monthlyDivider block showPeriodTotal
  , muted "  Income"
  ] ++
  (incomeRows.map fun row => monthlyRowLine state row block showPeriodTotal) ++
  [ monthlyTotalLine state snapshot measure .income "Total Income" block showPeriodTotal
  , monthlyDivider block showPeriodTotal
  , muted "  Expense"
  ] ++
  (expenseRows.map fun row => monthlyRowLine state row block showPeriodTotal) ++
  [ monthlyTotalLine state snapshot measure .expense "Total Expense" block showPeriodTotal
  , monthlyDivider block showPeriodTotal
  , monthlyNetLine state snapshot measure block showPeriodTotal
  ]

private def monthlyAccountsResultLines
    (state : State) (bounds : Option Bounds) : List Widget :=
  match state.incomeExpenseSnapshot with
  | none => [muted "No explicit Income & Expense window has been run yet."]
  | some incomeExpense =>
      let snapshot := incomeExpense.monthly
      let measures := monthlyMeasures snapshot
      let showPeriodTotal := snapshot.months.length > 1
      let blocks :=
        monthlyBlocks (monthlyBlockSize bounds showPeriodTotal) snapshot.months
      [ muted
          "Every touched calendar month is shown; zero means no admitted current flow, not a forecast."
      , blank
      ] ++
      (if measures.isEmpty then
        [muted "No classified Income or Expense quantity appears in this window."]
       else
        measures.flatMap fun measure =>
          (blocks.zipIdx.flatMap fun entry =>
            monthlyMeasureBlockLines
              state snapshot measure entry.1 entry.2 blocks.length showPeriodTotal ++ [blank])) ++
      [ line ("Unresolved role Effects: " ++ toString snapshot.unresolvedEffects.length)
      , muted
          (if snapshot.unresolvedEffects.isEmpty then
            "Role classification is complete for selected quantity Effects."
           else
            "Monthly totals are partial while unresolved role Effects remain.")
      , muted "Monthly Accounts groups the selected recorded flow by calendar month; it does not create a separate monthly ledger."
      ]

private def dailyMeasures
    (snapshot : Loam.DailyRoleFlowReview.Snapshot) : List Loam.Core.MeasureId :=
  snapshot.rows.foldl
    (fun measures row =>
      if row.coordinate.measure ∈ measures then measures
      else measures ++ [row.coordinate.measure])
    []

private def dailyRows
    (snapshot : Loam.DailyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole) : List Loam.DailyRoleFlowReview.Row :=
  (snapshot.rows.filter fun row =>
    decide (row.coordinate.measure = measure ∧ row.role = role)).mergeSort fun a b =>
      a.coordinate.locus.token <= b.coordinate.locus.token

private def dailyRoleQuanta
    (snapshot : Loam.DailyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole)
    (date : String) : Int :=
  snapshot.rows.foldl
    (fun total row =>
      if decide (row.coordinate.measure = measure ∧ row.role = role) then
        total + (Loam.DailyRoleFlowReview.Row.quantityAt row date).quanta
      else
        total)
    0

private def dailyRoleWindowQuanta
    (snapshot : Loam.DailyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole) : Int :=
  snapshot.rows.foldl
    (fun total row =>
      if decide (row.coordinate.measure = measure ∧ row.role = role) then
        total + (Loam.DailyRoleFlowReview.Row.total row).quanta
      else
        total)
    0

private def dailyShortDate (date : String) : String :=
  match date.splitOn "-" with
  | [_, month, day] => month ++ "-" ++ day
  | _ => date

private def dailyBlockSize
    (bounds : Option Bounds) (dateCount : Nat) : Nat :=
  let showWindowTotal := dateCount > 1
  match bounds with
  | none => min 7 (max 1 dateCount)
  | some terminal =>
      let content := Loam.Tui.Layout.contentWidth terminal
      let withoutBlockTotal := 24 + (if showWindowTotal then 14 else 0)
      let initial := min 7 (max 1 ((content - withoutBlockTotal) / 12))
      if dateCount > initial then
        min 7 (max 1 ((content - (withoutBlockTotal + 14)) / 12))
      else
        initial

private def dailyBlocks
    (blockSize : Nat) (dates : List String) : List (List String) :=
  let size := max 1 blockSize
  let blockCount := (dates.length + size - 1) / size
  (List.range blockCount).map fun index =>
    (dates.drop (index * size)).take size

private def dailyRowQuanta
    (row : Loam.DailyRoleFlowReview.Row) (date : String) : Int :=
  let raw := (Loam.DailyRoleFlowReview.Row.quantityAt row date).quanta
  if row.role = .income then -raw else raw

private def dailyRowBlockTotal
    (row : Loam.DailyRoleFlowReview.Row) (dates : List String) : Int :=
  dates.foldl (fun total date => total + dailyRowQuanta row date) 0

private def dailyRowWindowTotal
    (row : Loam.DailyRoleFlowReview.Row) : Int :=
  let raw := (Loam.DailyRoleFlowReview.Row.total row).quanta
  if row.role = .income then -raw else raw

private def dailyExpenseRowLine
    (state : State)
    (row : Loam.DailyRoleFlowReview.Row)
    (dates : List String)
    (showBlockTotal showWindowTotal : Bool) : Widget :=
  let cells :=
    dates.foldl
      (fun text date =>
        text ++
          padNum 12
            (incomeExpenseAmountText state row.coordinate.measure
              (dailyRowQuanta row date)))
      ""
  let blockTotal :=
    if showBlockTotal then
      padNum 14
        (incomeExpenseAmountText state row.coordinate.measure
          (dailyRowBlockTotal row dates))
    else
      ""
  let windowTotal :=
    if showWindowTotal then
      padNum 14
        (incomeExpenseAmountText state row.coordinate.measure
          (dailyRowWindowTotal row))
    else
      ""
  line
    ("  " ++ Loam.Tui.Layout.padRight 22 row.coordinate.locus.token ++
      cells ++ blockTotal ++ windowTotal)

private def dailyAggregateLine
    (state : State)
    (snapshot : Loam.DailyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (role : Loam.Core.AccountingRole)
    (label : String)
    (dates : List String)
    (showBlockTotal showWindowTotal : Bool) : Widget :=
  let displayForDate := fun date =>
    let raw := dailyRoleQuanta snapshot measure role date
    if role = .income then -raw else raw
  let cells :=
    dates.foldl
      (fun text date =>
        text ++ padNum 12 (incomeExpenseAmountText state measure (displayForDate date)))
      ""
  let blockTotal :=
    if showBlockTotal then
      let value := dates.foldl (fun total date => total + displayForDate date) 0
      padNum 14 (incomeExpenseAmountText state measure value)
    else
      ""
  let windowTotal :=
    if showWindowTotal then
      let raw := dailyRoleWindowQuanta snapshot measure role
      let display := if role = .income then -raw else raw
      padNum 14 (incomeExpenseAmountText state measure display)
    else
      ""
  line
    ("  " ++ Loam.Tui.Layout.padRight 22 label ++
      cells ++ blockTotal ++ windowTotal)

private def dailyNetLine
    (state : State)
    (snapshot : Loam.DailyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (dates : List String)
    (showBlockTotal showWindowTotal : Bool) : Widget :=
  let netForDate := fun date =>
    let income := -(dailyRoleQuanta snapshot measure .income date)
    let expense := dailyRoleQuanta snapshot measure .expense date
    income - expense
  let cells :=
    dates.foldl
      (fun text date =>
        text ++ padNum 12 (incomeExpenseAmountText state measure (netForDate date)))
      ""
  let blockTotal :=
    if showBlockTotal then
      let value := dates.foldl (fun total date => total + netForDate date) 0
      padNum 14 (incomeExpenseAmountText state measure value)
    else
      ""
  let windowTotal :=
    if showWindowTotal then
      let income := -(dailyRoleWindowQuanta snapshot measure .income)
      let expense := dailyRoleWindowQuanta snapshot measure .expense
      padNum 14 (incomeExpenseAmountText state measure (income - expense))
    else
      ""
  line
    ("  " ++ Loam.Tui.Layout.padRight 22 "Net" ++
      cells ++ blockTotal ++ windowTotal)

private def dailyDivider
    (dates : List String)
    (showBlockTotal showWindowTotal : Bool) : Widget :=
  let width :=
    24 + dates.length * 12 +
      (if showBlockTotal then 14 else 0) +
      (if showWindowTotal then 14 else 0)
  muted (String.ofList (List.replicate width '-'))

private def dailyMeasureBlockLines
    (state : State)
    (snapshot : Loam.DailyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (block : List String)
    (blockIndex blockCount : Nat)
    (expenseRows : List Loam.DailyRoleFlowReview.Row) : List Widget :=
  let showBlockTotal := blockCount > 1
  let showWindowTotal := snapshot.dates.length > 1
  let heading :=
    measure.token ++ "  Daily Flow" ++
      (if blockCount > 1 then
        "  block " ++ toString (blockIndex + 1) ++ "/" ++ toString blockCount
       else
        "")
  let dateRange :=
    match block.head?, block.getLast? with
    | some first, some last =>
        if first == last then "Date: " ++ first
        else "Dates: " ++ first ++ " .. " ++ last
    | _, _ => ""
  let header :=
    block.foldl
      (fun text date => text ++ padNum 12 (dailyShortDate date))
      (Loam.Tui.Layout.padRight 24 "Flow / Expense account")
  let headerWithBlock :=
    if showBlockTotal then header ++ Loam.Tui.Layout.padLeft 14 "Block total"
    else header
  let headerWithWindow :=
    if showWindowTotal then headerWithBlock ++ Loam.Tui.Layout.padLeft 14 "Window total"
    else headerWithBlock
  [ line heading
  , muted dateRange
  , muted headerWithWindow
  , dailyDivider block showBlockTotal showWindowTotal
  , dailyAggregateLine state snapshot measure .income "Income"
      block showBlockTotal showWindowTotal
  ] ++
  (expenseRows.map fun row =>
    dailyExpenseRowLine state row block showBlockTotal showWindowTotal) ++
  [ dailyDivider block showBlockTotal showWindowTotal
  , dailyNetLine state snapshot measure block showBlockTotal showWindowTotal
  ]

private def dailyFlowResultLines
    (state : State) (bounds : Option Bounds) : List Widget :=
  match state.incomeExpenseSnapshot with
  | none => [muted "No explicit Income & Expense window has been run yet."]
  | some incomeExpense =>
      let snapshot := incomeExpense.daily
      let measures := dailyMeasures snapshot
      let blocks := dailyBlocks (dailyBlockSize bounds snapshot.dates.length) snapshot.dates
      [ muted
          "Daily axis shows classified activity dates only; omitted dates are not asserted zero or forecast."
      , blank
      ] ++
      (if measures.isEmpty then
        [muted "No classified Income or Expense activity appears in this window."]
       else
        measures.flatMap fun measure =>
          let expenseRows := dailyRows snapshot measure .expense
          blocks.zipIdx.flatMap fun entry =>
            dailyMeasureBlockLines
              state snapshot measure entry.1 entry.2 blocks.length expenseRows ++ [blank]) ++
      [ line ("Unresolved role Effects: " ++ toString snapshot.unresolvedEffects.length)
      , muted
          (if snapshot.unresolvedEffects.isEmpty then
            "Role classification is complete for selected quantity Effects."
           else
            "Daily totals are partial while unresolved role Effects remain.")
      , muted "Daily Flow is a projection of the same occurrence-time flow, not stored daily state."
      ]

private def dailyMeasureBlockSource
    (state : State)
    (snapshot : Loam.DailyRoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId)
    (block : List String)
    (blockIndex blockCount : Nat)
    (expenseRows : List Loam.DailyRoleFlowReview.Row) :
    Loam.Tui.Viewport.Source Widget :=
  {
    extent := expenseRows.length + 8
    slice := fun offset count =>
      List.take count <|
        List.drop offset <|
          (dailyMeasureBlockLines
            state snapshot measure block blockIndex blockCount expenseRows) ++ [blank]
  }

private def dailyFlowSource
    (state : State) (bounds : Option Bounds) :
    Loam.Tui.Viewport.Source Widget :=
  match state.incomeExpenseSnapshot with
  | none =>
      Loam.Tui.Viewport.ofList
        [muted "No explicit Income & Expense window has been run yet."]
  | some incomeExpense =>
      let snapshot := incomeExpense.daily
      let measures := dailyMeasures snapshot
      let blocks := dailyBlocks (dailyBlockSize bounds snapshot.dates.length) snapshot.dates
      let intro :=
        Loam.Tui.Viewport.ofList
          [ muted
              "Daily axis shows classified activity dates only; omitted dates are not asserted zero or forecast."
          , blank
          ]
      let body :=
        if measures.isEmpty then
          Loam.Tui.Viewport.ofList
            [muted "No classified Income or Expense activity appears in this window."]
        else
          Loam.Tui.Viewport.concat <|
            measures.flatMap fun measure =>
              let expenseRows := dailyRows snapshot measure .expense
              blocks.zipIdx.map fun entry =>
                dailyMeasureBlockSource
                  state snapshot measure entry.1 entry.2 blocks.length expenseRows
      let tail :=
        Loam.Tui.Viewport.ofList
          [ line ("Unresolved role Effects: " ++ toString snapshot.unresolvedEffects.length)
          , muted
              (if snapshot.unresolvedEffects.isEmpty then
                "Role classification is complete for selected quantity Effects."
               else
                "Daily totals are partial while unresolved role Effects remain.")
          , muted
              "Daily Flow is a projection of the same occurrence-time flow, not stored daily state."
          ]
      Loam.Tui.Viewport.concat [intro, body, tail]

private def incomeExpenseHeaderLines (state : State) : List Widget :=
  [ line "Reports / Income & Expense"
  , muted "What Income / Expense role flow occurred inside this explicit window?"
  , line ("View: " ++ state.incomeExpenseDisplay.label ++ "   g toggle")
  , line ("Window: " ++ windowSourceLabel state)
  , muted "AccountingRole is explicit authority; no role is inferred from spelling or sign."
  , blank
  , field state 0 "Start" state.window.form.start
  , field state 1 "End (exclusive)" state.window.form.endExclusive
  , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
  , blank
  ]

private def incomeExpenseFooterLines (state : State) : List Widget :=
  [ muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
  , muted "g Summary/Monthly/Daily   Tab / Shift-Tab focus   Enter next/run"
  , muted "c compare periods   q / Esc Reports menu"
  , line state.notice
  ]

private def incomeExpenseView
    (state : State) (bounds : Option Bounds) : Widget :=
  .column <|
    incomeExpenseHeaderLines state ++
    (match state.incomeExpenseDisplay with
     | .summary => incomeExpenseResultLines state
     | .monthly => monthlyAccountsResultLines state bounds
     | .daily => dailyFlowResultLines state bounds) ++
    [blank] ++ incomeExpenseFooterLines state

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
    , muted "[ / ] source   ← / → comparison pair   e edit dates   Enter next/run"
    , muted "Tab / Shift-Tab focus   Backspace delete   q / Esc single-period"
    , line state.notice
    ]


private def formattedMeasureQuantity
    (state : State)
    (measure : Loam.Core.MeasureId)
    (quantity : Loam.Core.Quantity) : String :=
  Loam.MeasurePresentation.formatQuanta
    state.multimeasurePresentation measure quantity.quanta

private def formattedSignedMeasureQuantity
    (state : State)
    (measure : Loam.Core.MeasureId)
    (quantity : Loam.Core.Quantity) : String :=
  let text := formattedMeasureQuantity state measure quantity
  if quantity.quanta > 0 then "+" ++ text else text

private def measureTotalRows
    (state : State)
    (heading emptyText : String)
    (rows : List Loam.MultimeasureSpendReview.MeasureTotal) : List Widget :=
  [line heading] ++
    (if rows.isEmpty then
      [muted ("  " ++ emptyText)]
     else
      rows.map fun row =>
        line
          ("  " ++ Loam.Tui.Layout.padRight 12 row.measure.token ++
            padNum 14 (formattedMeasureQuantity state row.measure row.quantity) ++
            " " ++ row.measure.token))

private def exchangeEffectText
    (state : State)
    (label : String) (effect : Loam.Core.Effect) : Widget :=
  line
    ("  " ++ Loam.Tui.Layout.padRight 12 label ++
      padNum 14
        (formattedSignedMeasureQuantity state effect.measure effect.quantity) ++
      " " ++ effect.measure.token ++
      "  " ++ effect.locus.token)

private def exchangeOccurrenceLines
    (state : State)
    (exchange : Loam.MultimeasureSpendReview.ExchangeOccurrence) : List Widget :=
  let description :=
    if exchange.description.isEmpty then "" else "  " ++ exchange.description
  [ line (exchange.date ++ description ++ "  [" ++ exchange.event.token ++ "]")
  , exchangeEffectText state "source" exchange.source
  , exchangeEffectText state "destination" exchange.destination
  ] ++
  (if exchange.extraEffects.isEmpty then
    []
   else
    [muted "  extra Effects"] ++
      exchange.extraEffects.map (exchangeEffectText state "extra"))

private def multimeasureUnresolvedEffectLine
    (state : State)
    (entry : Loam.MultimeasureSpendReview.UnresolvedEffect) : Widget :=
  line
    ("? " ++ entry.date ++ "  " ++ entry.effect.locus.token ++ "  " ++
      formattedSignedMeasureQuantity state entry.effect.measure entry.effect.quantity ++
      " " ++ entry.effect.measure.token ++
      "  [" ++ entry.event.token ++ "]")

private def multimeasureUnresolvedOriginalLine
    (state : State)
    (entry : Loam.MultimeasureSpendReview.UnresolvedOriginalAmount) : Widget :=
  line
    ("? " ++ entry.date ++ "  original " ++
      formattedMeasureQuantity state entry.measure entry.quantity ++
      " " ++ entry.measure.token ++
      "  [" ++ entry.event.token ++ "]")

private def multimeasureSpendResultLines (state : State) : List Widget :=
  match state.multimeasureSpendSnapshot with
  | none => [muted "No explicit Multicurrency Spend window has been run yet."]
  | some snapshot =>
      [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , muted "Distinct Measures remain separate. No FX rate, valuation, or home currency is inferred."
      , blank
      ] ++
      measureTotalRows state
        "Ordinary accounting Expense" "No classified ordinary Expense in this window."
        snapshot.accountingExpense ++
      [blank] ++
      measureTotalRows state
        "Original presented Expense" "No OriginalAmount evidence attached to classified Expense."
        snapshot.originalPresentedExpense ++
      [blank] ++
      measureTotalRows state
        "Exchange-associated Expense" "No classified Expense attached to Exchange Events."
        snapshot.exchangeExpense ++
      [blank, line "Exchange occurrences"] ++
      (if snapshot.exchanges.isEmpty then
        [muted "  No qualified Exchange Event in this window."]
       else
        snapshot.exchanges.flatMap fun exchange =>
          exchangeOccurrenceLines state exchange ++ [blank]) ++
      [ line
          ("Unresolved ordinary Effects: " ++
            toString snapshot.unresolvedExpenseEffects.length)
      ] ++
      (snapshot.unresolvedExpenseEffects.take 6).map
        (multimeasureUnresolvedEffectLine state) ++
      [ line
          ("Unresolved exchange Effects: " ++
            toString snapshot.unresolvedExchangeEffects.length)
      ] ++
      (snapshot.unresolvedExchangeEffects.take 6).map
        (multimeasureUnresolvedEffectLine state) ++
      [ line
          ("Unresolved original amounts: " ++
            toString snapshot.unresolvedOriginalAmounts.length)
      ] ++
      (snapshot.unresolvedOriginalAmounts.take 6).map
        (multimeasureUnresolvedOriginalLine state) ++
      [ muted "Exchange quantities are evidence of the exchange occurrence, not spending totals."
      , muted "Original presented amounts remain observations; they are not converted into accounting Measure."
      ]

private def multimeasureSpendView (state : State) : Widget :=
  .column <|
    [ line "Reports / Multicurrency Spend"
    , muted "What was spent, what was originally presented, and what was exchanged in this window?"
    , line ("Window: " ++ windowSourceLabel state)
    , muted "This is a read lens over existing evidence, not a Trip transaction type."
    , blank
    , field state 0 "Start" state.window.form.start
    , field state 1 "End (exclusive)" state.window.form.endExclusive
    , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
    , blank
    ] ++
    multimeasureSpendResultLines state ++
    [ blank
    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "q / Esc Reports menu"
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

private def budgetRowLine
    (measure : Loam.Core.MeasureId)
    (row : Loam.BudgetWindowReview.Row) : Widget :=
  line
    (Loam.Tui.Layout.padRight 16 row.purpose.token ++
      padNum 10 (toString row.entitlement.quanta) ++
      padNum 10 (toString row.consumption.quanta) ++
      padNum 10 (toString row.remaining.quanta) ++ " " ++ measure.token)

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
      (snapshot.rows.take 10).map (budgetRowLine snapshot.measure) ++
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


private def fullView (state : State) (bounds : Option Bounds := none) : Widget :=
  match state.mode with
  | .menu => menuView state
  | .stockFlow => stockFlowView state
  | .stockFlowCompare => stockFlowCompareView state bounds
  | .transactionsFlow => transactionsFlowView state bounds
  | .incomeExpense => incomeExpenseView state bounds
  | .incomeExpenseCompare => incomeExpenseCompareView state bounds
  | .multimeasureSpend => multimeasureSpendView state
  | .balances => balancesView state
  | .liquidity => liquidityView state
  | .budgetWindow => budgetView state
  | .locusTrendCompare =>
      Loam.Tui.LocusTrendComparePane.viewFullScreen
        (bounds.getD { width := 80, height := 24 }) state.trendCompare state.notice

/-- Number of existing trailing notice/help rows kept outside the scrolling body. -/
private def fixedFooterSize : Mode → Nat
  | .menu => 3
  | .stockFlow => 4
  | .stockFlowCompare => 3
  | .transactionsFlow => 4
  | .incomeExpense => 4
  | .incomeExpenseCompare => 3
  | .multimeasureSpend => 4
  | .balances => 4
  | .liquidity => 3
  | .budgetWindow => 4
  | .locusTrendCompare => 4

private structure ViewParts where
  body : Loam.Tui.Viewport.Source Widget
  footer : List Widget

private def withCopyHelp (footer : List Widget) : List Widget :=
  -- Keep the essential back row immediately before notice for tiny terminals.
  footer.take (footer.length - 2) ++
    [muted "[y] copy screen   Shift+drag select"] ++ footer.drop (footer.length - 2)

private def staticViewParts
    (state : State) (bounds : Option Bounds) : ViewParts :=
  match fullView state bounds with
  | .column children =>
      let footerSize := min (fixedFooterSize state.mode) children.length
      let bodySize := children.length - footerSize
      {
        body := Loam.Tui.Viewport.ofList (children.take bodySize)
        footer := withCopyHelp (children.drop bodySize)
      }
  | other =>
      { body := Loam.Tui.Viewport.ofList [other], footer := [] }

private def dailyIncomeExpenseViewParts
    (state : State) (bounds : Option Bounds) : ViewParts :=
  {
    body :=
      Loam.Tui.Viewport.concat
        [ Loam.Tui.Viewport.ofList (incomeExpenseHeaderLines state)
        , dailyFlowSource state bounds
        , Loam.Tui.Viewport.ofList [blank]
        ]
    footer := withCopyHelp (incomeExpenseFooterLines state)
  }

private def viewParts
    (state : State) (bounds : Option Bounds := none) : ViewParts :=
  match state.mode, state.incomeExpenseDisplay with
  | .incomeExpense, .daily => dailyIncomeExpenseViewParts state bounds
  | _, _ => staticViewParts state bounds

private def bodyPageSize (bounds : Bounds) (footer : List Widget) : Nat :=
  bounds.height - (footer.length + 1)

/--
Prepared presentation rows for one long, scroll-only report surface.

This cache contains presentation Widgets only. It carries no household evidence,
query authority, or persistence state. Daily Flow is the first user because real
device wheel input showed that rebuilding its report body for every scroll packet
can let terminal input outrun rendering.
-/
structure PreparedScrollView where
  body : List Widget
  footer : List Widget
  page : Nat
  extent : Nat

/--
Materialize the bounded Daily body once. Other report surfaces keep their
existing direct path until they demonstrate the same need.
-/
def prepareScrollView?
    (bounds : Bounds) (state : State) : Option PreparedScrollView :=
  match state.mode, state.incomeExpenseDisplay with
  | .incomeExpense, .daily =>
      let parts := dailyIncomeExpenseViewParts state (some bounds)
      let page := bodyPageSize bounds parts.footer
      some {
        body := parts.body.slice 0 parts.body.extent
        footer := parts.footer
        page
        extent := parts.body.extent
      }
  | _, _ => none

/-- Largest meaningful vertical offset for the current report and terminal height. -/
def scrollLimit (bounds : Bounds) (state : State) : Nat :=
  let parts := viewParts state (some bounds)
  Loam.Tui.Scroll.maxOffset parts.body.extent (bodyPageSize bounds parts.footer)

private def scrollPositionLine
    (mode : Mode) (offset page total : Nat) : Widget :=
  let first := if total = 0 then 0 else offset + 1
  let last := min total (offset + page)
  let action := match mode with
    | .menu => "select"
    | .transactionsFlow | .locusTrendCompare => "navigate"
    | _ => "scroll"
  muted ("Lines " ++ toString first ++ "–" ++ toString last ++ "/" ++ toString total ++
    "   ↑/↓ or j/k " ++ action)

private def requestedOffset (state : State) (page : Nat) : Nat :=
  match state.mode with
  | .menu =>
      -- The nine menu rows follow four heading/context rows in `menuView`.
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

/--
Render a scroll position from already prepared presentation rows.

The visible result follows the same footer and position-line geometry as
`viewForBounds`, but does not rebuild Daily projection presentation.
-/
def viewPreparedScroll
    (bounds : Bounds) (state : State) (prepared : PreparedScrollView) : Widget :=
  let offset :=
    Loam.Tui.Scroll.clamp prepared.extent prepared.page state.scroll
  let position :=
    scrollPositionLine state.mode offset prepared.page prepared.extent
  if bounds.height < prepared.footer.length + 1 then
    let navigation := prepared.footer.dropLast.reverse
    let notice := prepared.footer.getLast?.toList
    .column <| (navigation ++ [position] ++ notice).take bounds.height
  else
    .column <|
      (prepared.body.drop offset).take prepared.page ++
      [position] ++
      prepared.footer

/--
Clamp a pure vertical scroll move against a prepared body without rebuilding
the report presentation.
-/
def scrollPrepared
    (state : State) (prepared : PreparedScrollView) (forward : Bool)
    (distance : Nat := 1) : State :=
  let requested :=
    if forward then state.scroll + distance else state.scroll - distance
  { state with
      scroll := Loam.Tui.Scroll.clamp prepared.extent prepared.page requested }

/-- Bound only presentation rows; report answers and query coordinates are unchanged. -/
def viewForBounds (bounds : Bounds) (state : State) : Widget :=
  if state.mode = .locusTrendCompare then
    Loam.Tui.LocusTrendComparePane.viewFullScreen
      bounds state.trendCompare state.notice
  else
    let parts := viewParts state (some bounds)
    let page := bodyPageSize bounds parts.footer
    let offset := Loam.Tui.Scroll.clamp parts.body.extent page (requestedOffset state page)
    let position := scrollPositionLine state.mode offset page parts.body.extent
    if bounds.height < parts.footer.length + 1 then
      -- In a tiny terminal, retain as much navigation as possible. Existing views
      -- put their notice last and their most essential back/quit row immediately
      -- before it, so reverse the navigation rows and omit body before overflowing.
      let navigation := parts.footer.dropLast.reverse
      let notice := parts.footer.getLast?.toList
      .column <| (navigation ++ [position] ++ notice).take bounds.height
    else
      .column <|
        parts.body.slice offset page ++
        [position] ++
        parts.footer

/-- Apply the existing interaction grammar, then clamp presentation-only scrolling. -/
def updateForBounds
    (bounds : Bounds) (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  let pointerAdjusted :=
    match state.mode, key with
    | .locusTrendCompare, .pointer col row
    | .locusTrendCompare, .pointerDrag col row =>
        if Loam.Tui.LocusTrendComparePane.pointerInPlot
            bounds state.trendCompare row then
          { state with
              trendCompare :=
                Loam.Tui.LocusTrendComparePane.selectColumn
                  bounds state.trendCompare col
              notice := "" }
        else
          state
    | _, _ => state
  let step : Step :=
    match key with
    | .pointer _ _ | .pointerDrag _ _ | .pointerMotion _ _ =>
        { state := pointerAdjusted }
    | _ => update pointerAdjusted key
  if step.state.mode = .locusTrendCompare then
    { step with state := { step.state with scroll := 0 } }
  else
    let parts := viewParts step.state (some bounds)
    let page := bodyPageSize bounds parts.footer
    { step with state := { step.state with
        scroll := Loam.Tui.Scroll.clamp parts.body.extent page step.state.scroll } }

/-- Coalesced wheel events retain the same pure navigation result with one redraw. -/
def updateForBoundsWithRepeat (bounds : Bounds) (state : State)
    (key : Loam.Tui.Terminal.Key) (count : Nat) : Step :=
  if key == .up || key == .down then
    (List.range (max 1 count)).foldl
      (fun step _ => updateForBounds bounds step.state key) { state := state }
  else updateForBounds bounds state key

/-- Unbounded compatibility view used by existing pure presentation tests. -/
def view (state : State) : Widget := fullView state none

end Loam.Tui.Reports

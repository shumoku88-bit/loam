from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


reports_path = Path("Loam/Tui/Reports.lean")
reports = reports_path.read_text()

reports = replace_once(
    reports,
    "import Loam.StockFlowReview\n",
    "import Loam.StockFlowReview\nimport Loam.TransactionsFlowReview\n",
    "Reports import",
)
reports = replace_once(
    reports,
    "  | stockFlow\n  | accounting\n",
    "  | stockFlow\n  | transactionsFlow\n  | accounting\n",
    "Mode transactionsFlow",
)
reports = replace_once(
    reports,
    "  | stockFlow (start endExclusive : String)\n  | conditionalLiquidity",
    "  | stockFlow (start endExclusive : String)\n  | transactionsFlow (start endExclusive : String)\n  | conditionalLiquidity",
    "Query transactionsFlow",
)
reports = replace_once(
    reports,
    "  menuIndex : Fin 4 := ⟨0, by decide⟩\n",
    "  menuIndex : Fin 5 := ⟨0, by decide⟩\n",
    "menu Fin 5",
)
reports = replace_once(
    reports,
    "  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none\n  liquiditySnapshot",
    "  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none\n"
    "  transactionsSnapshot : Option Loam.TransactionsFlowReview.Snapshot := none\n"
    "  transactionsIndex : Nat := 0\n"
    "  transactionsDetail : Bool := false\n"
    "  liquiditySnapshot",
    "Transactions Flow state",
)
reports = replace_once(
    reports,
    "  scroll : Nat := 0\n  deriving Repr, DecidableEq\n\nstructure Step",
    "  scroll : Nat := 0\n\nstructure Step",
    "presentation State derive removal",
)
reports = replace_once(
    reports,
    "def withStockFlowSnapshot\n"
    "    (state : State) (snapshot : Loam.StockFlowReview.Snapshot) : State :=\n"
    "  { state with stockFlowSnapshot := some snapshot, notice := \"\", scroll := 0 }\n\n\n"
    "def withLiquiditySnapshot",
    "def withStockFlowSnapshot\n"
    "    (state : State) (snapshot : Loam.StockFlowReview.Snapshot) : State :=\n"
    "  { state with stockFlowSnapshot := some snapshot, notice := \"\", scroll := 0 }\n\n\n"
    "def withTransactionsFlowSnapshot\n"
    "    (state : State) (snapshot : Loam.TransactionsFlowReview.Snapshot) : State :=\n"
    "  { state with\n"
    "      transactionsSnapshot := some snapshot\n"
    "      transactionsIndex := 0\n"
    "      transactionsDetail := false\n"
    "      notice := \"\"\n"
    "      scroll := 0 }\n\n\n"
    "def withLiquiditySnapshot",
    "withTransactionsFlowSnapshot",
)
reports = replace_once(
    reports,
    "      stockFlowSnapshot := none\n"
    "      liquiditySnapshot := none\n"
    "      budgetSnapshot := none\n"
    "      notice := message",
    "      stockFlowSnapshot := none\n"
    "      transactionsSnapshot := none\n"
    "      transactionsIndex := 0\n"
    "      transactionsDetail := false\n"
    "      liquiditySnapshot := none\n"
    "      budgetSnapshot := none\n"
    "      notice := message",
    "withError transactions clear",
)
reports = replace_once(
    reports,
    "      stockFlowSnapshot := none\n"
    "      liquiditySnapshot := none\n"
    "      budgetSnapshot := none\n"
    "      scroll := 0 }\n\n\n"
    "def moveFocus",
    "      stockFlowSnapshot := none\n"
    "      transactionsSnapshot := none\n"
    "      transactionsIndex := 0\n"
    "      transactionsDetail := false\n"
    "      liquiditySnapshot := none\n"
    "      budgetSnapshot := none\n"
    "      scroll := 0 }\n\n\n"
    "def moveFocus",
    "clearResults transactions clear",
)
reports = replace_once(
    reports,
    "  let next := if back then (state.menuIndex.val + 3) % 4 else (state.menuIndex.val + 1) % 4\n",
    "  let next := if back then (state.menuIndex.val + 4) % 5 else (state.menuIndex.val + 1) % 5\n",
    "five-row menu movement",
)
reports = replace_once(
    reports,
    """private def selectMenuMode (state : State) : State :=
  let mode :=
    match state.menuIndex.val with
    | 0 => Mode.stockFlow
    | 1 => Mode.accounting
    | 2 => Mode.liquidity
    | _ => Mode.budgetWindow
  { state with mode := mode, notice := "", scroll := 0 }
""",
    """private def selectMenuMode (state : State) : State :=
  let mode :=
    match state.menuIndex.val with
    | 0 => Mode.stockFlow
    | 1 => Mode.transactionsFlow
    | 2 => Mode.accounting
    | 3 => Mode.liquidity
    | _ => Mode.budgetWindow
  { state with mode := mode, notice := "", scroll := 0 }
""",
    "menu mode mapping",
)
reports = replace_once(
    reports,
    """  | .input 's' | .input 'S' =>
      { state := { state with mode := .stockFlow, notice := "", scroll := 0 } }
  | .input 'a' | .input 'A' =>
""",
    """  | .input 's' | .input 'S' =>
      { state := { state with mode := .stockFlow, notice := "", scroll := 0 } }
  | .input 't' | .input 'T' =>
      { state := { state with mode := .transactionsFlow, notice := "", scroll := 0 } }
  | .input 'a' | .input 'A' =>
""",
    "transactions direct key",
)
reports = replace_once(
    reports,
    """private def queryForMode (state : State) : Option Query :=
  match state.mode with
  | .stockFlow => some (.stockFlow state.form.start state.form.endExclusive)
  | .budgetWindow => some (.budgetWindow state.form.start state.form.endExclusive)
  | _ => none
""",
    """private def queryForMode (state : State) : Option Query :=
  match state.mode with
  | .stockFlow => some (.stockFlow state.form.start state.form.endExclusive)
  | .transactionsFlow => some (.transactionsFlow state.form.start state.form.endExclusive)
  | .budgetWindow => some (.budgetWindow state.form.start state.form.endExclusive)
  | _ => none
""",
    "transactions query",
)

transaction_logic = r'''
private def transactionCoordinateLe
    (left right : Loam.Core.EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

private def transactionRowLe
    (left right : Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) : Bool :=
  if left.2.gross.quanta == right.2.gross.quanta then
    transactionCoordinateLe left.1 right.1
  else
    left.2.gross.quanta >= right.2.gross.quanta

private def transactionRows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) :
    List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) :=
  (snapshot.rows.map fun coordinate =>
      (coordinate, Loam.TransactionsFlowReview.rowActivity snapshot coordinate))
    |>.filter (fun row => row.2.activeEvents > 0)
    |>.mergeSort transactionRowLe

private def transactionContributions
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : Loam.Core.EffectCoordinate) :
    List (Loam.TransactionsFlowReview.Column × Loam.Core.Quantity) :=
  snapshot.columns.filterMap fun column =>
    let quantity := Loam.Core.Event.quantityAt
      column.event coordinate.locus coordinate.measure
    if quantity.quanta = 0 then none else some (column, quantity)

private def moveTransactionSelection (state : State) (back : Bool) : State :=
  match state.transactionsSnapshot with
  | none => state
  | some snapshot =>
      let count := (transactionRows snapshot).length
      if count = 0 then
        { state with transactionsIndex := 0, scroll := 0 }
      else
        let maxIndex := count - 1
        let current := min state.transactionsIndex maxIndex
        let next := if back then current - 1 else min maxIndex (current + 1)
        { state with transactionsIndex := next, scroll := 0, notice := "" }

private def updateTransactionsFlow
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  if state.transactionsDetail then
    match key with
    | .escape | .input 'b' | .input 'B' =>
        { state := { state with transactionsDetail := false, scroll := 0, notice := "" } }
    | .up | .input 'k' | .input 'K' =>
        { state := { state with scroll := state.scroll - 1 } }
    | .down | .input 'j' | .input 'J' =>
        { state := { state with scroll := state.scroll + 1 } }
    | _ => { state }
  else
    match state.transactionsSnapshot with
    | none => updateWindowReport state key
    | some snapshot =>
        let rows := transactionRows snapshot
        match key with
        | .escape | .input 'b' | .input 'B' =>
            { state := { state with mode := .menu, notice := "", scroll := 0 } }
        | .up | .input 'k' | .input 'K' =>
            { state := moveTransactionSelection state true }
        | .down | .input 'j' | .input 'J' =>
            { state := moveTransactionSelection state false }
        | .left => { state := shiftCalendarMonth state false }
        | .right => { state := shiftCalendarMonth state true }
        | .input '[' => { state := cycleWindowSource state false }
        | .input ']' => { state := cycleWindowSource state true }
        | .tab =>
            { state := { state with form := moveFocus state.form false, notice := "" } }
        | .shiftTab =>
            { state := { state with form := moveFocus state.form true, notice := "" } }
        | .backspace =>
            if state.form.focus.val < 2 then
              { state := editWindowState state (fun text => String.ofList text.toList.dropLast) }
            else
              { state }
        | .input 'm' | .input 'M' => { state := resetCalendarMonth state }
        | .input char =>
            if state.form.focus.val < 2 then
              { state := editWindowState state (fun text => text.push char) }
            else
              { state }
        | .enter =>
            if state.form.focus.val < 2 then
              { state := { state with form := moveFocus state.form false, notice := "" } }
            else if rows.isEmpty then
              { state := { state with notice := "No quantity activity in this window." } }
            else
              { state := { state with transactionsDetail := true, scroll := 0, notice := "" } }
        | _ => { state }

'''
reports = replace_once(
    reports,
    "\nprivate def updateLiquidity (state : State)",
    "\n" + transaction_logic + "private def updateLiquidity (state : State)",
    "transactions update logic insertion",
)
reports = replace_once(
    reports,
    """  | .menu => updateMenu state key
  | .stockFlow => updateWindowReport state key
  | .budgetWindow => updateWindowReport state key
""",
    """  | .menu => updateMenu state key
  | .stockFlow => updateWindowReport state key
  | .transactionsFlow => updateTransactionsFlow state key
  | .budgetWindow => updateWindowReport state key
""",
    "update dispatch",
)
reports = replace_once(
    reports,
    """    , menuRow state 0 "Stock–Flow" "state change across an explicit window"
    , menuRow state 1 "Accounting" "role projection not justified by current authority"
    , menuRow state 2 "Liquidity" "UNKNOWN baseline + explicit conditional overlay"
    , menuRow state 3 "Budget Window" "explicit entitlement / consumption query"
    , blank
    , muted "↑/↓ or j/k select   Enter open   s/a/l/w direct"
""",
    """    , menuRow state 0 "Stock–Flow" "state change across an explicit window"
    , menuRow state 1 "Transactions Flow" "where quantity moved, including zero-net circulation"
    , menuRow state 2 "Accounting" "role projection not justified by current authority"
    , menuRow state 3 "Liquidity" "UNKNOWN baseline + explicit conditional overlay"
    , menuRow state 4 "Budget Window" "explicit entitlement / consumption query"
    , blank
    , muted "↑/↓ or j/k select   Enter open   s/t/a/l/w direct"
""",
    "menu rows",
)

transaction_view = r'''
private def transactionWindowLines (state : State) : List Widget :=
  [ line "Reports / Transactions Flow"
  , muted "Which exact household coordinates moved inside this explicit window?"
  , muted "Zero-net circulation remains visible through gross activity."
  , line ("Window: " ++ windowSourceLabel state)
  , muted "Calendar month and named presets only resolve explicit [start, end) coordinates."
  , blank
  , field state 0 "Start" state.form.start
  , field state 1 "End (exclusive)" state.form.endExclusive
  , .row [span "[Run]" (if state.form.focus.val = 2 then .selected else .normal)]
  , blank
  ]

private def transactionSummaryPrefix
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (rows : List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity)) :
    List Widget :=
  [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
  , muted (toString rows.length ++ " active coordinate(s); zero cells are omitted.")
  , muted "Rows are ordered by gross quantity for presentation salience only."
  , blank
  ]

private def transactionRowLine
    (state : State) (index : Nat)
    (row : Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) : Widget :=
  let coordinate := row.1
  let activity := row.2
  line
    ((if state.transactionsIndex = index then "> " else "  ") ++
      coordinate.locus.token ++ "/" ++ coordinate.measure.token ++
      "  net " ++ toString activity.net.quanta ++
      "  gross " ++ toString activity.gross.quanta ++
      "  positive " ++ signedQuanta activity.positive ++
      "  negative " ++ signedQuanta activity.negative ++
      "  " ++ toString activity.activeEvents ++ " events")

private def transactionRowLines
    (state : State) : Nat →
    List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) →
    List Widget
  | _, [] => []
  | index, row :: rest =>
      transactionRowLine state index row :: transactionRowLines state (index + 1) rest

private def selectedTransactionRow?
    (state : State) :
    Option (Loam.TransactionsFlowReview.Snapshot ×
      (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity)) := do
  let snapshot ← state.transactionsSnapshot
  let row ← (transactionRows snapshot)[state.transactionsIndex]?
  some (snapshot, row)

private def transactionContributionLine
    (coordinate : Loam.Core.EffectCoordinate)
    (entry : Loam.TransactionsFlowReview.Column × Loam.Core.Quantity) : Widget :=
  let column := entry.1
  let quantity := entry.2
  let description :=
    if column.description.isEmpty then
      "[" ++ column.event.id.token ++ "]"
    else
      column.description ++ "  [" ++ column.event.id.token ++ "]"
  line
    ("- " ++ column.date ++ "  " ++ signedQuanta quantity ++ " " ++
      coordinate.measure.token ++ "  " ++ description)

private def transactionDetailLines (state : State) : List Widget :=
  match selectedTransactionRow? state with
  | none => [muted "No selected Transactions Flow coordinate is available."]
  | some (snapshot, row) =>
      let coordinate := row.1
      let activity := row.2
      let contributions := transactionContributions snapshot coordinate
      [ line ("Focused coordinate: " ++ coordinate.locus.token ++ "/" ++ coordinate.measure.token)
      , line
          ("Net " ++ toString activity.net.quanta ++
            " | gross " ++ toString activity.gross.quanta ++
            " | positive " ++ signedQuanta activity.positive ++
            " | negative " ++ signedQuanta activity.negative)
      , muted (toString contributions.length ++ " contributing Event(s); unrelated zero cells are omitted.")
      , blank
      ] ++
      contributions.map (transactionContributionLine coordinate) ++
      [ blank
      , muted "Signs are exact quantity changes, not income/expense or source/destination labels."
      ]

private def transactionSummaryLines (state : State) : List Widget :=
  match state.transactionsSnapshot with
  | none => [muted "No explicit Transactions Flow window has been run yet."]
  | some snapshot =>
      let rows := transactionRows snapshot
      transactionSummaryPrefix snapshot rows ++
      if rows.isEmpty then
        [muted "No quantity activity appears in this explicit window."]
      else
        transactionRowLines state 0 rows

private def transactionsFlowView (state : State) : Widget :=
  if state.transactionsDetail then
    .column <|
      [ line "Reports / Transactions Flow"
      , muted "Focused nonzero Event witnesses for one exact coordinate."
      , blank
      ] ++
      transactionDetailLines state ++
      [ blank
      , muted "↑/↓ or j/k scroll contributors"
      , muted "b / Esc summary   q quit"
      , muted "No pairwise flow edge is inferred from these signed Effects."
      , line state.notice
      ]
  else
    .column <|
      transactionWindowLines state ++
      transactionSummaryLines state ++
      [ blank
      , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
      , muted "↑/↓ or j/k select coordinate   Enter detail   Tab / Shift-Tab window focus"
      , muted "b / Esc Reports menu   q quit"
      , line state.notice
      ]

'''
reports = replace_once(
    reports,
    "\nprivate def accountingView (state : State)",
    "\n" + transaction_view + "private def accountingView (state : State)",
    "transactions view insertion",
)
reports = replace_once(
    reports,
    """  | .menu => menuView state
  | .stockFlow => stockFlowView state
  | .accounting => accountingView state
""",
    """  | .menu => menuView state
  | .stockFlow => stockFlowView state
  | .transactionsFlow => transactionsFlowView state
  | .accounting => accountingView state
""",
    "view dispatch",
)
reports = replace_once(
    reports,
    """  | .menu => 3
  | .stockFlow => 4
  | .accounting => 2
""",
    """  | .menu => 3
  | .stockFlow => 4
  | .transactionsFlow => 4
  | .accounting => 2
""",
    "footer size",
)
reports = replace_once(
    reports,
    '  let action := match mode with | .menu => "select" | _ => "scroll"\n',
    '  let action := match mode with | .menu => "select" | .transactionsFlow => "navigate" | _ => "scroll"\n',
    "scroll action label",
)
reports = replace_once(
    reports,
    """  | .menu =>
      -- The four menu rows follow four heading/context rows in `menuView`.
      (4 + state.menuIndex.val + 1) - page
  | _ => state.scroll
""",
    """  | .menu =>
      -- The five menu rows follow four heading/context rows in `menuView`.
      (4 + state.menuIndex.val + 1) - page
  | .transactionsFlow =>
      if state.transactionsDetail then
        state.scroll
      else
        match state.transactionsSnapshot with
        | none => state.scroll
        | some snapshot =>
            let rows := transactionRows snapshot
            if rows.isEmpty then state.scroll
            else
              let index := min state.transactionsIndex (rows.length - 1)
              let selectedLine :=
                (transactionWindowLines state).length +
                (transactionSummaryPrefix snapshot rows).length + index
              (selectedLine + 1) - page
  | _ => state.scroll
""",
    "selection-aware bounded view",
)
reports_path.write_text(reports)


cli_path = Path("Loam/Tui/Cli.lean")
cli = cli_path.read_text()
cli = replace_once(
    cli,
    "import Loam.StockFlowReview\n",
    "import Loam.StockFlowReview\nimport Loam.TransactionsFlowReview\n",
    "Cli TransactionsFlowReview import",
)
cli = replace_once(
    cli,
    """    | some (.stockFlow start endExclusive) =>
        match ← Loam.StockFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withStockFlowSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.conditionalLiquidity assumedCompleteThrough) =>
""",
    """    | some (.stockFlow start endExclusive) =>
        match ← Loam.StockFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withStockFlowSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.transactionsFlow start endExclusive) =>
        match ← Loam.TransactionsFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withTransactionsFlowSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.conditionalLiquidity assumedCompleteThrough) =>
""",
    "Cli Transactions Flow query execution",
)
cli_path.write_text(cli)


test_path = Path("Loam/Tests/TuiReports.lean")
test = test_path.read_text()
test = replace_once(
    test,
    "  let lastMenuItem := (List.range 3).foldl\n",
    "  let lastMenuItem := (List.range 4).foldl\n",
    "Reports five-item small-menu test",
)
test_path.write_text(test)


workflow_path = Path(".github/workflows/tui.yml")
workflow = workflow_path.read_text()
path_anchor = "      - 'Loam/Tests/TuiReports.lean'\n"
count = workflow.count(path_anchor)
if count != 2:
    raise SystemExit(f"TUI workflow test path: expected 2 matches, got {count}")
workflow = workflow.replace(
    path_anchor,
    path_anchor + "      - 'Loam/Tests/TuiTransactionsFlow.lean'\n",
)
workflow = replace_once(
    workflow,
    """      - name: Verify Reports menu, Stock-Flow, conditional Liquidity and Budget Window surfaces
        run: lake env lean --run Loam/Tests/TuiReports.lean
""",
    """      - name: Verify sparse Transactions-Flow Reports interaction
        run: lake env lean --run Loam/Tests/TuiTransactionsFlow.lean

      - name: Verify Reports menu, Stock-Flow, Transactions-Flow, conditional Liquidity and Budget Window surfaces
        run: lake env lean --run Loam/Tests/TuiReports.lean
""",
    "TUI workflow Transactions Flow test step",
)
workflow_path.write_text(workflow)

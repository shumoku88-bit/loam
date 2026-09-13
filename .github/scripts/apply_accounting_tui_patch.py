from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}\n--- old ---\n{old}")
    p.write_text(text.replace(old, new, 1))


reports = "Loam/Tui/Reports.lean"
cli = "Loam/Tui/Cli.lean"
tests = "Loam/Tests/TuiReports.lean"

replace_once(
    reports,
    "import Loam.StockFlowReview\nimport Loam.TransactionsFlowReview\nimport Loam.Tui.Calendar\n",
    "import Loam.StockFlowReview\nimport Loam.TransactionsFlowReview\nimport Loam.RoleFlowReview\nimport Loam.Tui.Calendar\n",
)

replace_once(
    reports,
    "  | stockFlow (start endExclusive : String)\n  | transactionsFlow (start endExclusive : String)\n  | conditionalLiquidity (assumedCompleteThrough : String)\n",
    "  | stockFlow (start endExclusive : String)\n  | transactionsFlow (start endExclusive : String)\n  | accountingFlow (start endExclusive : String)\n  | conditionalLiquidity (assumedCompleteThrough : String)\n",
)

replace_once(
    reports,
    "  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none\n  transactionsSnapshot : Option Loam.TransactionsFlowReview.Snapshot := none\n  transactionsIndex : Nat := 0\n",
    "  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none\n  transactionsSnapshot : Option Loam.TransactionsFlowReview.Snapshot := none\n  accountingSnapshot : Option Loam.RoleFlowReview.Snapshot := none\n  transactionsIndex : Nat := 0\n",
)

replace_once(
    reports,
    "def withTransactionsFlowSnapshot\n    (state : State) (snapshot : Loam.TransactionsFlowReview.Snapshot) : State :=\n  { state with\n      transactionsSnapshot := some snapshot\n      transactionsIndex := 0\n      transactionsDetail := false\n      notice := \"\"\n      scroll := 0 }\n\n\ndef withLiquiditySnapshot\n",
    "def withTransactionsFlowSnapshot\n    (state : State) (snapshot : Loam.TransactionsFlowReview.Snapshot) : State :=\n  { state with\n      transactionsSnapshot := some snapshot\n      transactionsIndex := 0\n      transactionsDetail := false\n      notice := \"\"\n      scroll := 0 }\n\n\ndef withAccountingSnapshot\n    (state : State) (snapshot : Loam.RoleFlowReview.Snapshot) : State :=\n  { state with accountingSnapshot := some snapshot, notice := \"\", scroll := 0 }\n\n\ndef withLiquiditySnapshot\n",
)

replace_once(
    reports,
    "      transactionsSnapshot := none\n      transactionsIndex := 0\n",
    "      transactionsSnapshot := none\n      accountingSnapshot := none\n      transactionsIndex := 0\n",
)

# The same pair occurs in clearResults after withError; replace the remaining one.
replace_once(
    reports,
    "      transactionsSnapshot := none\n      transactionsIndex := 0\n",
    "      transactionsSnapshot := none\n      accountingSnapshot := none\n      transactionsIndex := 0\n",
)

replace_once(
    reports,
    "  | .stockFlow => some (.stockFlow state.form.start state.form.endExclusive)\n  | .transactionsFlow => some (.transactionsFlow state.form.start state.form.endExclusive)\n  | .budgetWindow => some (.budgetWindow state.form.start state.form.endExclusive)\n",
    "  | .stockFlow => some (.stockFlow state.form.start state.form.endExclusive)\n  | .transactionsFlow => some (.transactionsFlow state.form.start state.form.endExclusive)\n  | .accounting => some (.accountingFlow state.form.start state.form.endExclusive)\n  | .budgetWindow => some (.budgetWindow state.form.start state.form.endExclusive)\n",
)

replace_once(
    reports,
    "private def updateEvidenceLimit (state : State) (key : Loam.Tui.Terminal.Key) : Step :=\n  match key with\n  | .escape | .input 'b' | .input 'B' =>\n      { state := { state with mode := .menu, notice := \"\", scroll := 0 } }\n  | .up | .input 'k' | .input 'K' =>\n      { state := { state with scroll := state.scroll - 1 } }\n  | .down | .input 'j' | .input 'J' =>\n      { state := { state with scroll := state.scroll + 1 } }\n  | _ => { state }\n\n\n",
    "",
)

replace_once(
    reports,
    "  | .budgetWindow => updateWindowReport state key\n  | .accounting => updateEvidenceLimit state key\n  | .liquidity => updateLiquidity state key\n",
    "  | .budgetWindow => updateWindowReport state key\n  | .accounting => updateWindowReport state key\n  | .liquidity => updateLiquidity state key\n",
)

replace_once(
    reports,
    "    , menuRow state 2 \"Accounting\" \"role projection not justified by current authority\"\n",
    "    , menuRow state 2 \"Accounting\" \"occurrence-time Income / Expense role flow\"\n",
)

old_accounting = '''private def accountingView (state : State) : Widget :=
  .column
    [ line "Reports / Accounting"
    , muted "Where is the accounting-role counterpart structure?"
    , blank
    , line "Accounting projection: UNAVAILABLE"
    , blank
    , muted "Current production authority does not justify the role evidence needed"
    , muted "for this report. The reverted read adapter is not restored here."
    , muted "Reports will not infer roles from Locus names, signs, Purpose,"
    , muted "or presentation state merely to make this screen numeric."
    , blank
    , muted "b / Esc Reports menu   q quit"
    , line state.notice
    ]
'''

new_accounting = '''private def addAccountingMeasureIfAbsent
    (measures : List Loam.Core.MeasureId) (measure : Loam.Core.MeasureId) :
    List Loam.Core.MeasureId :=
  if measure ∈ measures then measures else measures ++ [measure]

private def accountingMeasures
    (snapshot : Loam.RoleFlowReview.Snapshot) : List Loam.Core.MeasureId :=
  snapshot.rows.foldl
    (fun measures row =>
      match row.role with
      | .income => addAccountingMeasureIfAbsent measures row.coordinate.measure
      | .expense => addAccountingMeasureIfAbsent measures row.coordinate.measure
      | _ => measures)
    []

private def accountingRoleQuanta
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId) (role : Loam.Core.AccountingRole) : Int :=
  snapshot.rows.foldl
    (fun total row =>
      if decide (row.coordinate.measure = measure ∧ row.role = role) then
        total + row.quantity.quanta
      else
        total)
    0

private def accountingMeasureLines
    (snapshot : Loam.RoleFlowReview.Snapshot) (measure : Loam.Core.MeasureId) : List Widget :=
  let rawIncome := accountingRoleQuanta snapshot measure .income
  let rawExpense := accountingRoleQuanta snapshot measure .expense
  let income := -rawIncome
  let expense := rawExpense
  let result := income - expense
  let label := Loam.Tui.Layout.padRight 16
  [ line (measure.token ++ "  occurrence-time P/L-shaped flow")
  , line (label "Income:" ++ padNum 12 (toString income) ++ " " ++ measure.token)
  , line (label "Expense:" ++ padNum 12 (toString expense) ++ " " ++ measure.token)
  , line (label "Result:" ++ padNum 12 (toString result) ++ " " ++ measure.token)
  ]

private def unresolvedAccountingLine
    (entry : Loam.RoleFlowReview.UnresolvedEffect) : Widget :=
  line
    ("? " ++ entry.date ++ "  " ++ entry.effect.locus.token ++ "  " ++
      signedQuanta entry.effect.quantity ++ " " ++ entry.effect.measure.token ++
      "  [" ++ entry.event.token ++ "]")

private def accountingResultLines (state : State) : List Widget :=
  match state.accountingSnapshot with
  | none => [muted "No explicit occurrence-time accounting window has been run yet."]
  | some snapshot =>
      let measures := accountingMeasures snapshot
      let unresolved := snapshot.unresolvedEffects
      [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , muted "Income display = -raw signed Income; Expense display = raw signed Expense."
      , muted "Distinct Measures remain separate and are never valued or summed together."
      , blank
      ] ++
      (if measures.isEmpty then
        [muted "No classified Income or Expense quantity appears in this window."]
       else
        measures.flatMap fun measure => accountingMeasureLines snapshot measure ++ [blank]) ++
      [ line ("Unresolved role Effects: " ++ toString unresolved.length) ] ++
      (unresolved.take 8).map unresolvedAccountingLine ++
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

private def accountingView (state : State) : Widget :=
  .column <|
    [ line "Reports / Accounting"
    , muted "What Income / Expense role flow occurred inside this explicit window?"
    , line ("Window: " ++ windowSourceLabel state)
    , muted "AccountingRole is explicit authority; no role is inferred from spelling or sign."
    , blank
    , field state 0 "Start" state.form.start
    , field state 1 "End (exclusive)" state.form.endExclusive
    , .row [span "[Run]" (if state.form.focus.val = 2 then .selected else .normal)]
    , blank
    ] ++
    accountingResultLines state ++
    [ blank
    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "b / Esc Reports menu   q quit"
    , line state.notice
    ]
'''
replace_once(reports, old_accounting, new_accounting)

replace_once(
    reports,
    "  | .transactionsFlow => 4\n  | .accounting => 2\n  | .liquidity => 3\n",
    "  | .transactionsFlow => 4\n  | .accounting => 4\n  | .liquidity => 3\n",
)

replace_once(
    cli,
    "import Loam.StockFlowReview\nimport Loam.TransactionsFlowReview\nimport Loam.Tui.Main\n",
    "import Loam.StockFlowReview\nimport Loam.TransactionsFlowReview\nimport Loam.RoleFlowReview\nimport Loam.Tui.Main\n",
)

replace_once(
    cli,
    "    | some (.transactionsFlow start endExclusive) =>\n        match ← Loam.TransactionsFlowReview.loadSnapshot dataDir root start endExclusive with\n        | .ok snapshot => pure (Loam.Tui.Reports.withTransactionsFlowSnapshot step.state snapshot)\n        | .error message => pure (Loam.Tui.Reports.withError step.state message)\n    | some (.conditionalLiquidity assumedCompleteThrough) =>\n",
    "    | some (.transactionsFlow start endExclusive) =>\n        match ← Loam.TransactionsFlowReview.loadSnapshot dataDir root start endExclusive with\n        | .ok snapshot => pure (Loam.Tui.Reports.withTransactionsFlowSnapshot step.state snapshot)\n        | .error message => pure (Loam.Tui.Reports.withError step.state message)\n    | some (.accountingFlow start endExclusive) =>\n        match ← Loam.RoleFlowReview.loadSnapshot dataDir root start endExclusive with\n        | .ok snapshot => pure (Loam.Tui.Reports.withAccountingSnapshot step.state snapshot)\n        | .error message => pure (Loam.Tui.Reports.withError step.state message)\n    | some (.conditionalLiquidity assumedCompleteThrough) =>\n",
)

old_test = '''  let accounting := { initial with mode := Loam.Tui.Reports.Mode.accounting }
  let accountingText := widgetText (Loam.Tui.Reports.view accounting)
  expect (contains "Accounting projection: UNAVAILABLE" accountingText)
    "Accounting page invented a projection after the read-adapter revert"
  expect (contains "reverted read adapter is not restored" accountingText)
    "Accounting page lost the current authority boundary"
  expect (contains "not infer roles" accountingText)
    "Accounting page lost its no-inference boundary"
'''

new_test = '''  let accounting := { initial with mode := Loam.Tui.Reports.Mode.accounting }
  let accountingText := widgetText (Loam.Tui.Reports.view accounting)
  expect (contains "Reports / Accounting" accountingText)
    "Accounting heading was not rendered"
  expect (contains "No explicit occurrence-time accounting window has been run yet" accountingText)
    "Accounting page did not preserve the explicit-run boundary"
  expect (contains "no role is inferred" accountingText)
    "Accounting page lost its no-inference boundary"
  match (Loam.Tui.Reports.update accounting .enter).query with
  | some (.accountingFlow start endExclusive) =>
      expect (start == "2026-09-01") "Accounting Run changed explicit start"
      expect (endExclusive == "2026-10-01") "Accounting Run changed explicit end"
  | _ => throw (IO.userError "Accounting Run did not emit its explicit role-flow query")

  let pensionCoordinate : EffectCoordinate := ⟨⟨"pension"⟩, ⟨"jpy"⟩⟩
  let foodCoordinate : EffectCoordinate := ⟨⟨"food"⟩, ⟨"jpy"⟩⟩
  let accountingReport := Loam.Tui.Reports.withAccountingSnapshot accounting {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    rows :=
      [ { coordinate := pensionCoordinate
        , role := .income
        , quantity := Quantity.ofQuanta (-225276) }
      , { coordinate := foodCoordinate
        , role := .expense
        , quantity := Quantity.ofQuanta 50000 }
      ]
    unresolvedEffects :=
      [ { event := ⟨"actual-unresolved"⟩
        , date := "2026-09-12"
        , effect := Effect.ofAnonymousQuantity
            ⟨"mystery"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 5) }
      ]
  }
  let accountingReportText := widgetText (Loam.Tui.Reports.view accountingReport)
  expect (contains "Income:" accountingReportText && contains "225276 jpy" accountingReportText)
    "Accounting view did not present credit-normal Income"
  expect (contains "Expense:" accountingReportText && contains "50000 jpy" accountingReportText)
    "Accounting view did not present debit-normal Expense"
  expect (contains "Result:" accountingReportText && contains "175276 jpy" accountingReportText)
    "Accounting view did not derive the occurrence-time result"
  expect (contains "Unresolved role Effects: 1" accountingReportText && contains "mystery" accountingReportText)
    "Accounting view hid unresolved role evidence"
  expect (contains "not accrual recognition or period closing" accountingReportText)
    "Accounting view overstated occurrence-time flow as a closed P/L"

  let accountingEditing : Loam.Tui.Reports.State := {
    accountingReport with form := { accountingReport.form with focus := ⟨0, by decide⟩ }
  }
  let accountingEdited := (Loam.Tui.Reports.update accountingEditing .backspace).state
  expect accountingEdited.accountingSnapshot.isNone
    "editing Accounting coordinates left a stale role-flow snapshot visible"
'''
replace_once(tests, old_test, new_test)

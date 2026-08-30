# Observation 049 — Is Accounting Role Primitive?

## Question

Observation 031 separated a conventional `Account` object from a neutral `Locus` coordinate:

```text
Account as domain object
    ≠
Locus as observable coordinate
```

That observation deliberately left a boundary open. It did not show that familiar accounting distinctions such as Asset, Liability, Equity, Income, and Expense can be recovered from `Locus` itself.

The next question is therefore:

> If the future asks Balance Sheet / Profit & Loss questions, or distinguishes Asset from Liability and Income from Expense, does the neutral physical core determine those answers, or is an additional accounting-role relation required?

This observation does **not** reintroduce a conventional `Account` object.

It adds only one overlay:

```text
role : Locus -> AccountingRole
```

with the selected accounting vocabulary:

```text
AssetRole
LiabilityRole
EquityRole
IncomeRole
ExpenseRole
```

## Why Alloy

The missing question is static relational independence:

1. hold the physical `Event -> Locus -> Measure -> Quantity` history fixed;
2. hold every physical balance fixed;
3. vary only the accounting-role relation;
4. ask whether accounting-report answers can change.

No transition semantics are required. TLA+ would add machinery without answering a different question. J is unnecessary because this is not primarily quotient counting, and Lean is premature unless a reusable general law emerges.

So this observation uses **Alloy only**.

## Neutral physical core

The physical core remains deliberately small:

```text
Event identity
  + effect : Locus × Measure -> signed Quantity
  + parent*
```

Current balances are derived from current tips. The physical vocabulary asks only:

- balance by `Locus × Measure`;
- total quantity by Measure.

The accounting role is outside that core.

## Accounting overlay

Each Locus receives one role in each modeled world:

```text
World.role : Locus -> one AccountingRole
```

From that relation the model derives two levels of accounting answers.

### Statement placement

```text
Balance Sheet = Asset + Liability + Equity loci
Profit & Loss = Income + Expense loci
```

### Finer role vocabulary

The model also preserves role-specific balances for:

- Asset;
- Liability;
- Equity;
- Income;
- Expense.

This distinction matters because proving only that a Locus can move between Balance Sheet and P&L would not yet show that Asset versus Liability, or Income versus Expense, is independent of physical location.

## Pressure

### 1. Same physical core, different statement placement

Keep the physical core and every physical answer identical.

Can one Locus be Asset in one world and Income in another, while another Locus swaps in the opposite direction, changing Balance Sheet and P&L answers without changing any physical quantity?

Expected: **SAT**.

### 2. Same statement family, different finer role

Keep the physical core identical and keep the set of Balance Sheet loci and P&L loci identical.

Can a Balance Sheet Locus change from Asset to Liability while a P&L Locus changes from Income to Expense?

Expected: **SAT**.

This asks whether even the finer accounting distinction is recoverable from `where` plus statement family alone.

### 3. Physical core determines physical answers

If `present`, `effect`, and `parent` are identical, can physical coordinate balances or totals differ?

Expected check result: **UNSAT** counterexample.

### 4. Physical core determines accounting vocabulary

If the physical core is identical but role is not fixed, must all selected accounting answers remain identical?

Expected check result: **SAT** counterexample.

### 5. Physical core plus AccountingRole determines selected vocabulary

If both the physical core and the role relation are identical, can either the physical answers or selected accounting answers differ?

Expected check result: **UNSAT** counterexample.

## Expected Alloy result

Alloy 6.2.0 + Sat4j, exactly 2 Events / 2 Loci / 1 Measure / 2 coordinate Cells / 5 AccountingRoles / 2 Worlds / 5-bit Ints:

```text
accountingRoleOverlayCanChangeStatementPlacement             SAT
accountingRoleOverlayCanChangeWithinStatements               SAT
PhysicalCoreDeterminesPhysicalAnswers                        UNSAT
PhysicalCoreDeterminesAccountingVocabulary                   SAT
PhysicalCorePlusAccountingRoleDeterminesSelectedVocabulary   UNSAT
```

The workflow records the exact solver result set. This section remains an expectation until CI executes the model on the pull-request head.

## Interpretation if the expected result holds

The bounded separation would be:

```text
where quantity is
    ≠
what accounting role that locus plays
```

and more specifically:

```text
Balance Sheet vs Profit & Loss
    is not determined by physical placement

Asset vs Liability
    is not determined by physical placement

Income vs Expense
    is not determined by physical placement
```

That would sharpen Observation 031 without reversing it:

```text
Account object          may still be unnecessary
AccountingRole relation may still be necessary
```

The word **primitive** must remain vocabulary-relative here. This experiment can show that the selected physical core is insufficient and that adding a role relation is sufficient for the selected report vocabulary. It cannot show that AccountingRole is metaphysically primitive, nor that it could never later be derived from some richer semantic facts.

## Important boundaries

This observation does **not** establish:

- that a conventional `Account` object should return;
- that the five selected accounting roles are the only useful roles;
- that every real-world Locus has exactly one accounting role in production;
- that accounting role can never be derived from ownership, obligation, legal claim, institution, access, settlement state, or another richer relation;
- debit / credit presentation rules;
- accounting equations or closing rules;
- period recognition rules;
- valuation policy;
- liquidity or backing eligibility;
- asynchronous settlement;
- reconciliation evidence;
- historical changes to accounting role.

The result is bounded to the selected future vocabulary and finite Alloy scope.

## Next question

If accounting role remains independent of physical placement, the next planned pressure is temporal rather than classificatory:

> Can an initiated movement and its later settlement be represented safely when they do not happen at the same instant?

That is Observation 050, where TLA+ becomes useful because the question is about transition order and intermediate states rather than static relational independence.

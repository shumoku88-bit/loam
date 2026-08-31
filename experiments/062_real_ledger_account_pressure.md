# Observation 062 — Do real ledger shapes force Account back?

## Question

Observations 031 and 049 separated two ideas that conventional bookkeeping often fuses:

```text
Account as domain object
    !=
Locus as observable quantity coordinate

where quantity is
    !=
what accounting role that locus plays
```

Observation 062 applies real-data pressure to that separation.

A private household ledger supplied by the repository owner contains recurring structural shapes including:

- holding-to-holding transfer;
- ordinary expense;
- one payment split across several expense classifications;
- income received into a holding locus;
- expense funded by a liability;
- liability repayment from a holding locus;
- refund / reimbursement that reverses an expense classification;
- opening balance against equity.

The public experiment deliberately copies **none** of the private descriptions, identities, dates, or quantities. Only those anonymized structural shapes enter the model.

The question is:

> Can those representative ledger shapes be expressed and recognized from `Event + Locus + signed Quantity + AccountingRole` without restoring a conventional stored `Account` object or nominal event-kind field?

## Why Alloy

The pressure is structural rather than temporal.

We want to ask whether several concrete shapes can coexist in one small model, whether accounting role remains necessary to recognize them, and whether nominal account/event names add observational power to the selected vocabulary.

Alloy is therefore sufficient. TLA+, SPIN, and Apalache would add transition machinery without answering a different question. Lean should wait unless a reusable practical law emerges.

## Anonymous specimen vocabulary

The model keeps only:

```text
Event
Effect
Locus
signed Quantity
AccountingRole
```

with the already observed accounting-role vocabulary:

```text
Asset
Liability
Equity
Income
Expense
```

Each Effect belongs to one Event, names one Locus, and carries one non-zero signed integer quantity. Within one Event, one Locus can appear at most once, matching the sparse posting shape of the sampled ledger records.

`AccountName` and `EventKind` are included only as deliberately nominal presentation relations. They do not participate in structural recognition.

## Representative shapes

The experiment asks for eight distinct Events at once.

### Holding transfer

```text
Asset     -q
Asset     +q
```

### Expense

```text
Asset     -q
Expense   +q
```

### Split expense

```text
Asset     -(q1 + q2)
Expense   +q1
Expense   +q2
```

### Income

```text
Asset     +q
Income    -q
```

### Liability-funded expense

```text
Expense     +q
Liability   -q
```

### Liability repayment

```text
Asset       -q
Liability   +q
```

### Expense refund / reimbursement

```text
Asset      +q
Expense    -q
```

### Opening balance

```text
Asset    +q
Equity   -q
```

Every representative Event is zero-total in the selected Measure. Observation 062 does not claim that every future LOAM Event must be zero-total; this is only a property of these bookkeeping-shaped specimens.

## Pressures

### 1. Can all representative shapes coexist without Account or EventKind primitives?

Expected: **SAT**.

A witness would show that the selected real-ledger vocabulary does not itself force a conventional `Account` object back into the neutral core.

### 2. Can nominal account names and event-kind labels change while the semantic core stays fixed?

Keep Effect structure and AccountingRole fixed, but change `AccountName` and `EventKind` assignments.

Expected: **SAT**, while every selected structural classification remains unchanged.

### 3. Can AccountingRole change a recognized shape while Effect structure stays fixed?

Keep the same Event / Effect / Locus / Quantity structure and the same nominal presentation, but vary only AccountingRole.

Can one two-effect zero-total Event be expense-like in one world and holding-transfer-like in another?

Expected: **SAT**.

This re-applies Observation 049 under a concrete ledger-shaped vocabulary: signed placement alone should not determine accounting interpretation.

### 4. Does Effect structure alone determine the selected ledger-shape vocabulary?

Expected check result: **SAT counterexample**.

### 5. Does Effect structure plus AccountingRole determine the selected ledger-shape vocabulary?

Expected check result: **UNSAT counterexample**.

### 6. Can purely nominal presentation change the selected ledger-shape vocabulary once AccountingRole is fixed?

Expected check result: **UNSAT counterexample**.

## Important boundaries

This observation does **not** establish:

- that a conventional Account object is useless for every application;
- that `Locus` is the final production name;
- that all real ledger records are covered by the eight specimens;
- debit / credit presentation rules;
- accounting equations as primitive domain law;
- period closing or recognition policy;
- tax, business-use, plan, series, or issue metadata semantics;
- exchange-rate or multi-Measure settlement semantics;
- that every practical Event must balance to zero;
- how imported ledger identity should map to LOAM stable identity;
- whether a ledger posting should map one-to-one to a practical LOAM Effect.

The last boundary is especially important. This experiment asks only whether the **observable structural shapes** fit the existing coordinate vocabulary. It does not yet choose an import representation.

## Next decision

If the expected Alloy results hold, the useful new information is not "Account is gone forever." It is narrower:

> Real household bookkeeping shapes still do not force Account identity or nominal EventKind into the neutral core; `AccountingRole` remains the independent relation that makes accounting-shaped readings possible.

The next pressure should then come from information present in the private ledger but intentionally excluded here, such as plan/series metadata, event identity linkage, or multi-Measure activity, rather than from inventing more account structure prematurely.

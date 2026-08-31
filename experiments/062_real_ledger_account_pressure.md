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

## Observed pressures

### 1. All representative shapes coexist without Account or EventKind primitives

Observed: **SAT**.

The bounded witness contains all eight distinct structural shapes at once using exactly 8 Events, 7 Loci, and 17 Effects.

This shows expressibility for the selected real-ledger vocabulary without restoring a conventional `Account` object or a stored nominal EventKind.

### 2. Nominal account names and event-kind labels can change while the semantic core stays fixed

Keep Effect structure and AccountingRole fixed, but change `AccountName` and `EventKind` assignments.

Observed: **SAT**.

The selected structural classifications remain unchanged because those nominal relations are not part of the recognition vocabulary.

### 3. AccountingRole can change a recognized shape while Effect structure stays fixed

Keep the same Event / Effect / Locus / Quantity structure and the same nominal presentation, but vary only AccountingRole.

Observed: **SAT**.

The model finds a two-effect zero-total Event that is expense-like in one world and holding-transfer-like in another.

This re-applies Observation 049 under a concrete ledger-shaped vocabulary: signed placement alone does not determine accounting interpretation.

### 4. Effect structure alone does not determine the selected ledger-shape vocabulary

Observed check result: **SAT counterexample**.

Because the Event / Effect / Locus / Quantity structure is shared by both worlds, the counterexample isolates the missing distinction in AccountingRole.

### 5. Effect structure plus AccountingRole determines the selected ledger-shape vocabulary

Observed check result: **UNSAT counterexample**.

Within this bounded vocabulary, once the Effect structure and AccountingRole relation are fixed, the selected eight structural classifications cannot differ.

### 6. Purely nominal presentation cannot change the selected ledger-shape vocabulary once AccountingRole is fixed

Observed check result: **UNSAT counterexample**.

Changing `AccountName` and `EventKind` does not alter the selected structural answers when the semantic core is fixed.

## Alloy result

Alloy 6.2.0 + Sat4j, exactly 8 Events / 7 Loci / 17 Effects / 2 Worlds / 2 AccountNames / 2 EventKinds / 5-bit Ints:

```text
representativeLedgerShapes                    SAT
sameSemanticCoreDifferentNominals             SAT
roleOverlayCanChangeRecognizedShape            SAT
EffectCoreAloneDeterminesSelectedShapes        SAT counterexample
EffectCorePlusRoleDeterminesSelectedShapes     UNSAT counterexample
NominalPresentationCannotChangeSelectedShapes  UNSAT counterexample
```

Observation 062 run #2 completed SUCCESS on executable model head `597e40ac523771cba1517740e9f5eb782676af0e`.

Run #1 failed before solving because the commands omitted an explicit scope for the parent `World` signature. Adding `exactly 2 World` fixed only that Alloy scope declaration; the structural hypotheses and expected results were unchanged.

## Interpretation

The private real-ledger specimens do not reverse Observations 031 or 049. They strengthen their practical relevance.

For the selected shapes:

```text
real bookkeeping-shaped Event
    =
Event + signed Effects over Loci
      + independent AccountingRole
```

is sufficient to recognize the chosen transfer, expense, income, liability, refund, and opening-balance structures.

The bounded conclusion is therefore:

> Real household bookkeeping shapes still do not force conventional Account identity or nominal EventKind into the neutral core. AccountingRole remains the independent relation that makes accounting-shaped readings possible.

This does **not** mean the word `Account` is forbidden at an application boundary. It means the selected observable answers do not yet require it as an additional canonical domain identity beyond Locus plus independent role.

A second useful result comes from split expense. Multi-posting activity does not itself force a new transaction-kind hierarchy. Distinct Effects can remain visible inside one Event and role-aware projection can recognize the split shape without assigning an authoritative order to those Effects.

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

## Next pressure

Observation 062 did not earn more account structure.

The more interesting pressure now comes from information deliberately excluded from the anonymous specimens but present in real records, including:

- explicit plan / series linkage;
- explicit event or issue linkage;
- annotations that are not quantity coordinates;
- more than one Measure;
- the relationship between imported posting identity and LOAM Effect identity.

Those should be observed separately rather than bundled into a larger Account abstraction.

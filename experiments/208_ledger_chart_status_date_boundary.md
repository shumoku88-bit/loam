# Observation 208 — Ledger chart / status / posting-date boundary

Status: **Ledger/hledger reconstruction gate; qualified bounded additive composition**

## Question

After Observation 207, the remaining plain-text-accounting pressure is no longer well described as “virtual postings are missing”. A more ordinary Ledger/hledger question remains:

```text
account hierarchy
+ inherited / overridden accounting role
+ transaction and posting status
+ transaction and posting date
+ report selection
+ balance-assertion selection
```

Can these selected meanings be reconstructed as relations and query policy over the existing Event / Effect / Locus identities, or does the neutral physical Event/Effect shape need to grow?

This observation is deliberately about **semantic selection**, not parser or CLI compatibility. Existing LOAM quantity projection already answers the arithmetic question once the selected Effects are known.

## External pressure

hledger 1.52 documents all of the following:

- colon-separated account names form a hierarchy and reports can be depth-limited;
- subaccounts inherit a parent account type unless a nearer declaration overrides it;
- transaction and individual posting status marks are separately expressible;
- individual postings may carry a date different from their parent transaction, including bank-clearing examples;
- balance assertions consider postings of all statuses, even when ordinary reports are status-filtered;
- subaccount-inclusive balance assertions exist separately from subaccount-exclusive assertions.

Ledger 3 likewise exposes hierarchical accounts, state flags, and effective dates. This probe uses the hledger rules above because their cross-feature interaction is stated especially explicitly.

References:

- https://hledger.org/1.52/hledger.html
- https://ledger-cli.org/doc/ledger3.html

## Relation to existing LOAM evidence

Observation 031 already established:

```text
Account object != Locus coordinate
```

Observation 049 established:

```text
physical placement != AccountingRole
```

and showed that an independent role relation is sufficient for the selected bounded Balance-Sheet / P&L vocabulary.

Observation 062 then showed representative real-ledger transaction shapes can be recognized from:

```text
Event + signed Effects + Locus + AccountingRole
```

without restoring a conventional Account object or nominal EventKind.

Observation 140 / F057 already separates recognition-time policy from payment/invoice/service timing. Observation 141 / F083-F084 already permits as-published and current-restated historical views. Observations 142-143 / F089-F090 already separate valuation coordinate from rate-source authority.

Observation 207 further showed that accounting-only and query-generated contribution planes can compose with assertions and correction-aware historical queries without forcing Event/Effect growth in the bounded model.

So Observation 208 does not reopen those questions. It targets the remaining ordinary chart/status/date seam.

## Observation-local model

The physical specimen retains only:

```text
Event
Effect -> Event
Effect -> Locus
```

No quantity is needed because this probe asks which Effects enter a selected view. Existing quantity aggregation can run after that selection.

Each modeled world adds separate relations:

```text
parent             : Locus -> lone Locus
role declaration   : Locus -> lone AccountingRole
transaction status : Event -> Status
posting status     : Effect -> optional Status
transaction date   : Event -> Date
posting date       : Effect -> optional Date
```

and one query policy:

```text
selected subtree root
selected AccountingRole
selected Status
through Date
```

The hierarchy is a finite acyclic parent relation.

### Accounting role

A Locus uses its own declared role when present. Otherwise it inherits the nearest declared ancestor role. A child declaration overrides the parent declaration.

This is an observation-local reconstruction of the selected hledger type-inheritance behavior. It does not propose a production `AccountTree` or permanent five-role enum.

### Status

For this bounded selection candidate, an explicit posting status is used when present; otherwise the posting uses its transaction status.

The retained distinction is the important part of this probe:

```text
transaction status
    !=
posting-specific status evidence
```

The words `Unmarked`, `Pending`, and `Cleared` are observation-local external vocabulary, not proposed neutral Core states.

### Date

Likewise, an explicit posting date is used when present; otherwise the transaction date supplies the selected date.

The probe therefore preserves:

```text
transaction date
    !=
posting-specific date evidence
```

without turning Event into a universal multi-date record.

### Report selection

An Effect is selected by the bounded report when it is:

```text
inside the selected subtree
+ has the selected effective AccountingRole
+ has the selected effective Status
+ has effective Date <= query Date
```

### Assertion selection

The modeled subaccount-inclusive assertion view selects:

```text
inside the selected subtree
+ effective Date <= query Date
```

and deliberately ignores the report status filter, matching the selected hledger assertion/status interaction.

The model does not yet reproduce every assertion form or ordering rule.

## C-seeking attacks

### 1. Flat role declarations determine a tree report

Hold role declarations, status/date evidence, and query policy fixed. Change only hierarchy.

Observed: **counterexample exists**.

A child can move in or out of the selected subtree while every physical Event/Effect and flat role declaration remains unchanged.

So hierarchy is not merely typography for this query.

### 2. Parent role inheritance changes statement selection

Hold physical evidence and hierarchy fixed. Give a parent Asset in one world and Expense in another while the child has no declaration.

Observed: **SAT witness**.

The child’s selected accounting reading changes without changing its physical Locus.

### 3. Child declaration overrides parent

Give the parent Asset and child Expense.

Observed: **SAT witness** where the child is selected as Expense and not Asset.

This checks that an inherited-role candidate does not erase explicit local authority.

### 4. Transaction status alone determines status-filtered report selection

Hold transaction status and all other relations fixed. Change only one posting-specific status.

Observed: **counterexample exists**.

So one Event-level status is too small for a vocabulary that can observe posting-specific status.

### 5. Status-filtered report and assertion use the same selected set

Keep physical evidence fixed while posting status changes report inclusion.

Observed: **SAT witness** where report selection changes but assertion selection does not.

This is the same kind of selection-law separation exposed by Observation 207: one universal “selected balance” knob is too small.

### 6. Transaction date alone determines period selection

Hold transaction date fixed. Change only posting-specific date across the query boundary.

Observed: **counterexample exists**.

So Event occurrence date alone is too small for Ledger/hledger-style posting-date questions.

## Conservative candidate

The positive candidate is:

```text
existing Event / Effect / Locus identity
+ hierarchy relation
+ role declarations with inheritance policy
+ transaction/posting status evidence
+ transaction/posting date evidence
+ explicit query policy
    -> report-selected Effect set
     + assertion-selected Effect set
```

Fixing those relations fixed both selected sets in the bounded model. The pressure therefore remains additive/compositional rather than a demonstrated need to change Event or Effect itself.

## Observed Alloy matrix

Alloy 6.2.0 + Sat4j on the exact executable branch head `cd4276494c1b2e0547800d5ead749e223f8cd3a5` produced the selected matrix:

```text
hierarchyChangesSubtreeReport                       SAT
inheritedRoleChangesStatementSelection              SAT
childRoleOverrideWitness                            SAT
postingStatusChangesReportButNotAssertion           SAT
postingDateChangesPeriodSelection                   SAT

FlatRoleDataDeterminesTreeReport                    SAT counterexample
TransactionStatusDeterminesStatusFilteredReport     SAT counterexample
TransactionDateDeterminesDatedReport                SAT counterexample
AssertionSelectionIndependentOfStatusQuery          UNSAT counterexample
ExplicitOverlaysDetermineSelectedViews              UNSAT counterexample
```

Dedicated workflow run `34014875669`, job `101436815742`, completed SUCCESS.

The preceding run failed before solving because an observation-local variable named `root` shadowed the `World.root` field in Alloy. Renaming only that local variable to `rootLocus` repaired the type error; no relation, predicate, assertion, scope, expected result, or semantic hypothesis changed.

## Interpretation

The bounded result is:

```text
hierarchy
transaction/posting status distinction
transaction/posting date distinction
report-vs-assertion selection law
    = independently observable Ledger information

but

existing Event / Effect / Locus identity
+ explicit additive relations
+ query policy
    -> selected report and assertion Effect sets
```

So Observation 208 classifies this selected Ledger pressure as:

```text
B / CONSERVATIVE ADDITIVE COMPOSITION
C / CORE-SHAPE PRESSURE NOT DEMONSTRATED
```

The result does not say hierarchy, status, or posting date are “just UI”. They are genuine information. It says their selected semantics need not be encoded by enlarging the neutral physical Event/Effect shape.

## Production boundary

This observation does **not** earn:

- a production `Account` object;
- a production account tree;
- colon-separated Locus naming semantics;
- permanent Asset/Liability/Equity/Revenue/Expense enums;
- permanent Unmarked/Pending/Cleared enums;
- mutable reconciliation state;
- status fields on Event or Effect;
- extra date fields on Event or Effect;
- hledger query-language compatibility;
- Ledger file-format compatibility;
- every hledger depth/type/alias rule;
- every balance-assertion form or ordering rule;
- close/open/retain/assign semantics;
- cost, lot, market-value, or realised/unrealised gain semantics.

The narrow qualified result is that the selected ordinary Ledger chart/status/date behavior can be reconstructed without enlarging the neutral physical Event/Effect shape.

## Next Ledger gate

The next unresolved cluster is generation/finality rather than more chart metadata:

```text
balance assignment
+ close/open/retain generation
+ assertion ordering
+ status/real/auto/date interaction
```

Only after that should the reconstruction program move to the valuation/lots/gain cluster.

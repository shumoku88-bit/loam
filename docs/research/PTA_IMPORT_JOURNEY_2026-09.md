# PTA import journey — kind migration design

Status: **INTERACTION DESIGN / NO PRODUCTION IMPORTER YET**

Baseline:

```text
LOAM main 5da8fe934461f258e610da258cda62ddca5f4995
Observation 385 classifier + hledger adapter boundary merged as #1583 / #1586
```

## Goal

A Ledger/hledger user with years of existing history should be able to try LOAM
without first learning LOAM's internal file topology, evidence families, or
formal vocabulary.

The migration surface should be kind in a precise sense:

> automate what the source makes explicit, ask only about meaning LOAM cannot
> know, explain why a decision is needed, and never turn uncertainty into a
> silent accounting claim.

This is not a request to make the semantic boundary permissive. It is a request
to make a fail-closed boundary understandable.

## Human vocabulary

The classifier keeps its internal research vocabulary:

```text
Direct / Normalize / Review / Refuse
```

The ordinary migration UI should not lead with those words.

Prefer:

```text
Ready
Needs your decision
Cannot import yet
```

"Normalize" is normally invisible when it is only source syntax processing.
When normalization exposes a meaningful source distinction, that distinction is
shown in the relevant review step.

## Journey

The first complete journey should contain six small stages.

```text
Choose journal
    |
    v
1. Scan summary
    |
    v
2. Accounts / categories
    |
    v
3. Measures
    |
    v
4. Transactions needing attention
    |
    v
5. History knowledge
    |
    v
6. Final preview
    |
    v
Create fresh household
    |
    v
Canonical reload + report check
```

No Actual/Scheduled/config authority is changed during stages 1–6.

The UI is a review surface until the final create action.

## 1. Scan summary

The first screen answers only "what did LOAM find?"

Example:

```text
Import hledger journal

household.journal

Transactions found        842
Ready                      817
Need your decision          22
Cannot import yet            3

Nothing has been written.

Enter  Continue
Esc    Cancel
```

This screen does not expose 842 rows.

The user should see the shape of the work before being asked to make any
decision.

### Details are available, not mandatory

A details action may expand counts by reason:

```text
Needs your decision
  Account meaning             8
  Measure display scale       2
  Cleared / pending status    9
  Balance assertion           3

Cannot import yet
  Virtual posting             2
  Posting-specific date       1
```

The common case remains one page.

## 2. Accounts and categories

Imported source account names are source vocabulary, not LOAM accounting truth.

Example:

```text
Account 3 of 18

Assets:Checking

LOAM can keep this identity as:
  assets-checking

What does it mean in your household?

> Asset
  Liability
  Expense
  Income
  Equity
  Leave unclassified

Source name suggests: Asset

Enter  Use selection
s      Use source suggestion
Esc    Back
```

### Rules

- Preserve the original source name visibly throughout preview.
- Generate a safe Locus-token proposal, but let the user edit it.
- A source prefix may create a **suggestion**, never an automatic
  AccountingRole fact.
- "Leave unclassified" is a legitimate choice where current LOAM semantics allow
  it.
- Duplicate/colliding Locus proposals are caught before publication.
- Repeated decisions should support a bulk shortcut, for example:
  "apply this accepted prefix suggestion to the remaining 12 Assets:* names".
  The bulk action itself must be previewed.

Friendly display labels may be proposed separately. Locus identity, display
label, and AccountingRole must not collapse into one imported "account" object.

## 3. Measures

A source commodity token is not automatically a currency and does not carry a
LOAM display scale by itself.

Example:

```text
Measure 2 of 3

USD

Proposed LOAM identity: usd
Proposed display scale: 2

Source values seen:
  -12.34 USD
   80.00 USD
  100.00 USD

> Accept
  Change identity
  Change display scale

No rounding is allowed.
```

### Rules

- Exact source quantities must be representable in the selected scale.
- If any source amount would require rounding, Continue is disabled and the
  exact offending examples are shown.
- A familiar symbol such as USD may create a presentation suggestion, not a
  hidden "currency" semantic claim.
- Measure setup is reviewed once per Measure, not once per transaction.

## 4. Transactions needing attention

Do not make the user inspect all history.

Only transactions blocked by a retained source distinction appear here, grouped
by reason first.

Example group:

```text
Cleared / pending status                       9 transactions

LOAM does not currently retain this source status.
The quantities themselves can be represented.

[View examples]
[Decide later]
```

Example individual refusal:

```text
Cannot import transaction 314

2024-08-03  Dinner

Reason:
  This transaction contains a virtual posting.
  LOAM cannot currently preserve that meaning as ordinary Actual quantity.

Source:
  Assets:Cash        -900 JPY
  Expenses:Food       900 JPY
  (Budget:Food)      -900 JPY

Enter  Back to review
Esc    Cancel import
```

### No "import anyway" escape hatch in v1

The classifier boundary must remain meaningful.

For v1:

- Review means an explicit, named migration policy must exist before the
  transaction can become Ready.
- Refuse means the transaction cannot be published by this importer.
- There is no generic "ignore warning" or "force import".

If a later policy deliberately drops a source distinction, the final preview
must name that loss and count the affected transactions.

## 5. History knowledge

Imported transaction history does not prove historical completeness.

Ask this after transaction review, in ordinary language.

```text
How much history do you know for this imported household?

> I have the full history from zero
  This history is complete from a date
  I only know the current balances
  I am not sure yet
```

The choices map to existing independent LOAM support families.

The UI must not infer an answer from:

- the first source transaction;
- an account named Opening;
- a balance assertion;
- matching ending balances;
- the age of the journal.

"I am not sure yet" is a valid migration outcome. Reports that require stronger
history support should remain explicit about the missing evidence.

## 6. Final preview

The final screen is the semantic receipt.

Example:

```text
Ready to create LOAM household

Source
  household.journal

Transactions
  Ready                     839
  Not imported                3

Household identities
  Loci                       24
  Measures                    3
  Accounting roles           22
  Unclassified                2

History knowledge
  Unknown for now

Important
  3 source transactions will not be imported.
  No historical-completeness claim will be created.

Nothing has been written yet.

Enter  Create household
b      Back
Esc    Cancel
```

The final action should not be available while an unresolved Review case remains.

## Publication shape

The first production importer should target a **fresh household**, not append
into an already-active one.

Desired operational shape:

```text
source
  -> normalize
  -> classify
  -> collect review decisions
  -> validate complete migration plan
  -> build staged fresh household
  -> canonical read-back
  -> run selected report/review checks
  -> expose household to user
```

The staging area is not authority.

A failed validation or failed canonical reread must leave the existing household
untouched.

The exact atomic activation mechanism is a later implementation question; this
document does not invent one.

## Recovery and interruption

A kind importer must assume people stop halfway.

Before final publication, the migration session may be discarded safely because
no household authority has changed.

A later implementation may persist a resumable draft, but v1 does not require
it. If draft persistence is added, it is migration-session state, not Actual
evidence and not external occurrence identity.

After final publication, the result is a LOAM household. The external journal is
not a synchronization authority.

## Source provenance without false identity

The final household may retain human-readable migration provenance such as:

```text
Imported from hledger
Source file: household.journal
Imported on: 2026-09-29
Source transactions scanned: 842
Transactions admitted: 839
Transactions not admitted: 3
```

This is a migration receipt.

It must not claim that source line number, source order, or content hash is the
stable identity of a continuing external Event.

Observation 075 remains the identity boundary.

## Progressive disclosure

The ordinary user should not need to see:

- EventId;
- EffectKey;
- OpeningSupport;
- ZeroOriginCoverage;
- CurrentQuantityAnchor;
- LocusAdmission;
- classifier disposition names.

Those remain implementation/diagnostic vocabulary.

The migration UI speaks in:

- accounts/categories;
- currencies/units;
- current balances;
- history from a date;
- transactions that need attention.

An advanced details view may reveal exact LOAM evidence that will be published.

## Error style

Errors should answer three questions:

```text
What did LOAM find?
Why can it not continue?
What can I do next?
```

Prefer:

```text
USD amount 12.345 cannot be represented with scale 2.
LOAM would have to round it, so import is stopped.

Choose a larger display scale or go back.
```

Avoid:

```text
invalid quantity
```

Likewise, unsupported source semantics should be named rather than described as
parse failures.

## Bulk friendliness

Large journals require bulk operations, but bulk must never become semantic
guessing.

Good candidates:

- accept a repeated Locus-token transformation after preview;
- accept repeated source-prefix AccountingRole suggestions after one explicit
  bulk confirmation;
- accept one Measure mapping for all occurrences of that Measure.

Bad candidates:

- silently infer every Assets:* account as Asset;
- silently drop all cleared/pending status;
- silently skip unsupported transactions;
- silently claim full history.

## First-use success criterion

A successful first-time migration is not "all source syntax imported".

It is:

1. the user understands what will and will not move;
2. no unresolved semantic distinction reaches publication;
3. exact quantities remain exact;
4. the new household can be canonically reloaded;
5. the user reaches at least one useful existing LOAM surface, ideally
   Balances/Trend, without editing canonical files by hand.

## Implementation order

Do not build all six screens at once.

A narrow implementation sequence is:

1. typed migration-plan / preview model, read-only;
2. account/Locus and Measure mapping validation;
3. grouped Review/Refuse presentation;
4. explicit history-knowledge selection;
5. final semantic receipt;
6. fresh-household staging/publication;
7. only then polish TUI navigation and optional resume behavior.

The first code slice should stop after rendering the preview model. It should
perform no publication.

## Non-goals

This design does not authorize:

- appending imported history into an existing active household;
- bidirectional sync;
- generic "force import";
- automatic role inference;
- automatic historical-completeness inference;
- virtual-posting semantics;
- market-price/lot semantics;
- one giant imported Account record;
- hiding skipped/refused transaction counts;
- making hledger a permanent runtime dependency for ordinary LOAM use.

## Decision

The importer should be strict underneath and gentle on top.

```text
strict semantic boundary
        +
small questions
        +
grouped review
        +
clear explanations
        +
one final receipt
        =
kind migration
```

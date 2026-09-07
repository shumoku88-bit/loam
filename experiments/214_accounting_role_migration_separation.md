# Observation 214 — AccountingRole-preserving Locus normalization

Status: **PROBE — canonical migration pressure / RESEARCH_ONLY**

## Trigger

Production `loamTui` dogfood exposed a source-shaped Locus spelling at daily Record input. The deeper question is no longer merely how to make that spelling friendlier.

The household wants ordinary questions such as:

```text
What were expenses in this interval?
What was income in this interval?
What assets / liabilities do I currently have?
```

while LOAM's neutral `Locus` identity should not need to encode hledger/HRA account taxonomy in its token spelling.

The canonical household data may be rewritten if a better representation is qualified. Therefore this probe asks whether the information currently suggested by names such as `expenses:*`, `income:*`, `liabilities:*`, and `equity:*` can be split out as an explicit relation before any destructive vocabulary normalization.

## Current household pressure

The current new-write vocabulary is mixed.

It contains flat operational Loci such as holding, investment, food/book/coffee, pension/support, liability, rent, and utilities identities, while a smaller set of approved expense Loci still retain HRA/hledger-shaped source spelling.

Historical admitted Events retain broader source-shaped expense, income, liability, and equity families. `loam-data` already tracks this as DD-002, "HRA-derived Locus vocabulary in admitted history".

Current `ActualRouting` independently routes source expense Loci to household Purposes. Therefore the `expenses:` prefix is not needed merely to recover Purpose.

The data also supplies an important warning against mechanical leaf-name merging: a holding-like point identity and a historical income-shaped point-source identity can be distinct accounting coordinates even when their human leaf vocabulary is similar. Prefix removal is therefore not the same operation as identity merging.

## Prior qualified results

Observation 031:

```text
Account object != Locus coordinate
```

Observation 049:

```text
where quantity is != AccountingRole
```

and, for the selected Balance Sheet / Profit & Loss vocabulary, an independent role relation was sufficient to determine the selected accounting partition.

Observation 062 then applied representative real-ledger pressure and found that transfer, expense, split expense, income, liability-funded expense, liability repayment, refund, and opening-balance shapes can be recognized from:

```text
Event + signed Effects + Locus + AccountingRole
```

without restoring a conventional Account object or nominal EventKind.

Observation 110 showed that debit/credit polarity can remain a derived presentation over signed Effects while accounting explanation remains independent.

Observation 208 showed that hledger-style hierarchy and inherited role can be additive relations/query policy without making colon-separated Locus naming semantic.

Observation 213 most recently separated:

```text
canonical identity != display/input alias != AccountingRole != Purpose
```

Observation 214 therefore does **not** ask again whether AccountingRole is independent. It asks what that independence means for a destructive canonical Locus migration.

## Question

Can a source-shaped canonical vocabulary be normalized by transporting AccountingRole separately from Locus spelling while preserving the selected role-aware report answers?

And what extra condition distinguishes a harmless one-to-one re-key from a many-to-one identity merge?

## Observation-local model

The Alloy model contains:

```text
OldLocus
NewLocus
Effect -> OldLocus
AccountingRole
Migration.rekey   : OldLocus -> one NewLocus
Migration.oldRole : OldLocus -> one AccountingRole
Migration.newRole : NewLocus -> lone AccountingRole
```

The selected role vocabulary remains observation-local:

```text
Asset
Liability
Equity
Income
Expense
```

No production enum or persistence format is proposed.

Effect identity and quantity payload are conceptually unchanged by this probe. The model checks **which Effects are selected by each accounting role** before and after re-key. Since a future qualified migration would preserve each Effect's quantity exactly, equality of the selected Effect sets is sufficient for equality of any deterministic role-selected quantity fold over those Effects.

Current-balance arithmetic itself is already owned by QuantityBasis / Event effects / corrections / basis-cut projections and is not reimplemented here.

## Candidate separation

For one old coordinate `o`:

```text
old token spelling
    -> rekey(o)

old AccountingRole(o)
    -> new AccountingRole(rekey(o))
```

The role is **transported explicitly**. It is not inferred from the new token and the runtime is not asked to parse `assets:` / `expenses:` / `income:` prefixes as semantics.

## C-seeking attacks

### 1. One-to-one re-key plus role transport preserves role-selected reports

Require an injective old-to-new Locus mapping and transport the old role to each new target.

Expected: **SAT witness** with several distinct roles and all selected report Effect sets preserved.

This would show that spelling normalization need not erase accounting classification.

### 2. Flat identity alone determines report classification

Hold the old evidence and old-to-new mapping fixed while allowing only the new AccountingRole relation to differ.

Expected: **SAT witness** with different role-selected answers.

So a flat token such as `pension`, `smbc`, or `tobacco` cannot by itself replace the classification information previously carried by source account declarations/naming conventions.

### 3. Same-role many-to-one merge can preserve accounting report selection

Collapse two distinct old Loci with the same role onto one new Locus and transport that role.

Expected: **SAT witness** where role-selected Effect sets remain equal but the re-key is not injective.

This is deliberately dangerous in a useful way. It shows:

```text
accounting report parity != identity preservation
```

Per-Locus history, balance, routing, provenance, or other household questions can still distinguish the two source coordinates.

### 4. Different-role many-to-one merge pressure exists

Allow two old Loci with different roles to collide on one new Locus.

Expected: **SAT candidate**.

The model then attacks whether one post-migration role can preserve both source classifications.

### 5. Role transport determines the selected report partition

Expected check: **UNSAT counterexample**.

### 6. A different-role merge can preserve all selected role reports

Expected check: **UNSAT counterexample**. With every modeled source Locus observed by at least one Effect, one new Locus with one role cannot preserve two conflicting source classifications.

### 7. Accounting report parity implies identity preservation

Expected check: **SAT counterexample**.

A same-role merge should refute this stronger claim.

## Interpretation if the matrix survives

The candidate migration boundary becomes:

```text
one-to-one Locus re-key
+ explicit transported AccountingRole
+ complete reference translation
    -> role-aware report classification can survive

many-to-one Locus merge
    -> separate semantic decision
    -> accounting parity alone is insufficient evidence
```

This is materially different from both of the tempting shortcuts:

```text
strip `expenses:` and forget the role
```

and:

```text
merge anything with the same human leaf name
```

Neither shortcut is justified by prior LOAM results.

## Production implications if qualified

A later production slice may be justified to introduce the **smallest explicit role evidence needed by actual report questions**, then use it during a quiescent canonical vocabulary cutover.

A candidate cutover would need to translate every retained Locus reference consistently, not only Event effects. Depending on the final selected mapping this can include:

- selected Movement Event evidence;
- LocusAdmission;
- QuantityBasis / corrections / basis cut references;
- balance-view selection;
- ActualRouting source coordinates;
- Scheduled or other retained evidence that names Loci;
- any future role evidence itself.

The exact inventory must be generated from the then-current authority topology immediately before cutover.

## Deliberate boundaries

Even a successful Observation 214 does **not** establish:

- a permanent production five-role taxonomy;
- that every Locus must always have exactly one role through all time;
- role-history or effective-date semantics;
- hledger account hierarchy in production;
- colon-separated naming semantics;
- that every current source-shaped Locus should be renamed;
- which English/Japanese flat spelling should win;
- that two old Loci with the same role may be merged;
- that similar leaf names denote the same household identity;
- period recognition / accrual policy;
- valuation or exchange-rate policy;
- that balance-view selection is identical to Asset selection;
- that Purpose routing is derivable from AccountingRole.

In particular, "account balance" and "all assets" remain different possible queries. `balance-view.tsv` already demonstrates that presentation/holding selection can be narrower than an accounting role partition.

## Next gate if qualified

Before writing canonical data, build a complete **migration candidate table** over the current household vocabulary:

```text
old Locus
candidate new Locus
AccountingRole evidence
Purpose-routing evidence
other retained references
collision class
```

Classify every row as:

```text
injective re-key
historical-only retain
possible merge requiring separate proof
unresolved
```

Only then should a single quiescent data cutover be prepared and parity-tested.

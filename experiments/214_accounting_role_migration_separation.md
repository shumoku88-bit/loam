# Observation 214 — AccountingRole-preserving Locus normalization

Status: **COMPLETE — role-preserving re-key survives / RESEARCH_ONLY**

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

## Executed result

Alloy 6.2.0 + Sat4j ran on exact branch head
`da7a3599ecc376d1733587fdac52f8084fd7d50b`.
Dedicated workflow run `34083640585` completed **SUCCESS**.

Observed matrix:

```text
injectiveRoleTransportPreservesReports              SAT
sameFlatIdentitiesDifferentRoleAnswers               SAT
sameRoleMergePreservesAccountingButLosesIdentity     SAT
differentRoleMergeCandidate                          SAT
RoleTransportDeterminesSelectedReports               UNSAT counterexample
DifferentRoleMergeCannotPreserveSelectedReports      UNSAT counterexample
AccountingParityImpliesIdentityPreservation           SAT counterexample
```

## Findings

### 1. One-to-one re-key plus role transport preserves the selected accounting partition

A witness exists with several distinct AccountingRoles where the Locus mapping is injective, the old role is transported to the new target, and every role-selected Effect set is unchanged.

So source-shaped spelling is not required to retain the selected accounting classification.

### 2. Flat identity alone is insufficient

Holding old evidence and the old-to-new mapping fixed while changing only the post-migration AccountingRole produced different role-selected report answers.

Therefore:

```text
flat Locus token
    !=
AccountingRole evidence
```

A token such as `pension`, `smbc`, or `tobacco` cannot by itself replace the classification information that was previously recoverable from source account declarations or naming conventions.

### 3. Same-role merge can fool an accounting-only parity check

Alloy found a many-to-one mapping where two distinct old Loci share the same AccountingRole and the selected accounting report Effect sets are preserved.

But the mapping is not injective.

Therefore:

```text
accounting report parity
    !=
stable Locus identity preservation
```

Per-Locus history, balance, routing, provenance, or another household query may still distinguish those source coordinates.

### 4. Different-role merge cannot preserve the selected role vocabulary with one post-migration role

The model allows two differently classified source Loci to collide on one new Locus, so the pressure is not ruled out syntactically.

But with every source Locus observed by at least one Effect, Alloy found no counterexample to the claim that such a collision cannot preserve all role-selected report answers when the new Locus has at most one AccountingRole.

This is a concrete stop sign against mechanical leaf-name merging.

### 5. Explicit role transport is sufficient for the selected report classification

Alloy found no counterexample where role transport holds but the selected report partition changes.

For the bounded migration vocabulary:

```text
one-to-one re-key
+ transported AccountingRole
    -> selected accounting report classification preserved
```

The quantity fold itself remains ordinary existing LOAM arithmetic over unchanged Effect quantities.

## Migration boundary

The qualified candidate is:

```text
one-to-one Locus re-key
+ explicit transported AccountingRole
+ complete reference translation
    -> role-aware report classification can survive

many-to-one Locus merge
    -> separate semantic decision
    -> accounting parity alone is insufficient evidence
```

This is materially different from both tempting shortcuts:

```text
strip `expenses:` and forget the role
```

and:

```text
merge anything with the same human leaf name
```

Neither shortcut is justified.

## Production implication

The observation now justifies the **next gate**, not an immediate data rewrite:

> inventory the current household Locus vocabulary, assign explicit candidate AccountingRole evidence where actually needed by household report questions, and prepare a one-to-one normalization candidate separately from any merge candidates.

A future cutover should translate every retained Locus reference consistently, not only Event effects. Depending on the then-current authority topology this can include:

- selected Movement Event evidence;
- LocusAdmission;
- QuantityBasis / corrections / basis cut references;
- balance-view selection;
- ActualRouting source coordinates;
- Scheduled or other retained evidence that names Loci;
- the new role evidence itself.

The exact inventory must be regenerated immediately before cutover.

## Deliberate boundaries

Observation 214 does **not** establish:

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

## Next gate

Build a complete migration candidate table over the current household vocabulary:

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

Only after that inventory should a production AccountingRole representation and a single quiescent canonical data cutover be designed.

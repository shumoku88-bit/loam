# Liquidity / Budget Window obligation DAG — G2-007

Status: **Generation-2 audit evidence, qualification pending CI**

Primary instruments: **DRAKONview + obligation DAG**.

G2-007 places the conditional selected-balance Liquidity path and Budget Window beside each other at the same semantic scale. Both are report/read compositions, but the pressure exposed by the diagrams is different:

- Conditional Liquidity composes **two readers that both observe Actual**;
- Budget Window loads one shared evidence image but repeats one **query-global correction admission** inside Purpose-local projection.

The audit therefore earns two small repairs rather than one generic report abstraction.

## 1. Conditional Liquidity: one Actual generation

Before G2-007 the load path was:

```text
BalanceReview.loadSnapshot
    |
    +-- reads actual.loam generation A

ScheduledReview.loadHouseholdEvidence
    |
    +-- reads actual.loam generation B

project balances + scheduled
```

`BalanceReview` needs the correction-aware Event world to establish current selected quantities. `ScheduledReview` independently needs Actual Event identities while admitting Scheduled completion, retirement, and replacement evidence.

Those are different semantic consumers, but one conditional path answer requires the two observations to belong to one published Actual generation. Otherwise a writer could replace `actual.loam` between the reads and one answer could combine:

```text
current selected balance from generation A
+
Scheduled lifecycle admission against generation B
```

The obligation DAG is therefore:

```text
selected actual.loam
        |
        v
enter Actual ownership
        |
        +--------------------+
        |                    |
        v                    v
BalanceReview           ScheduledReview
Actual read             Actual read
        |                    |
        +---------+----------+
                  |
                  v
      same published generation
                  |
                  v
        conditional path project
```

The production repair uses the existing `ActualAuthority.withActualFileOwnership` primitive around the two existing readers. No second decoder, combined Evidence type, or retained Liquidity authority is introduced.

Verdict: **REPAIR**.

## 2. Budget Window: global frontier, local arithmetic

`BudgetWindowReview.loadEvidence` already loads one immutable composition of:

- Capacity / CapacityEffective;
- Actual Event / EventCorrection / admitted ActualValidity;
- ActualRouting.

The multi-Purpose snapshot then projects every retained Purpose.

Before G2-007 the shape was:

```text
for Purpose p:
    entitlementAtEffectiveWindow?(p)
    correctionFrontierMemory?
    consumptionAtRecordedWindow?(p)
```

The DAG separates the obligations:

```text
loaded Evidence
    |
    v
remembered Purposes
    |
    +-- empty ----------------------> empty Snapshot
    |
    v
first Purpose Entitlement
    |
    v
one correction frontier
    |
    +------------------------------+
    |                              |
    v                              v
first Consumption             later Purposes
                                   |
                                   +-- Entitlement(p)
                                   +-- Consumption(p, SAME frontier)
```

The correction frontier depends only on shared Event/correction evidence. It is query-global.

Entitlement and Consumption quantities are still Purpose-dependent. G2-007 deliberately does **not** replace those folds with a new all-Purpose aggregation engine merely because a single-pass implementation might be possible.

### Refusal-order constraint

The frontier must not be forced eagerly before the Purpose list is known.

An empty Capacity/Purpose image previously produced an empty successful snapshot without asking whether the unused correction world was admissible. G2-007 retains that behavior:

```text
no Purposes
    -> no correction obligation
    -> empty Snapshot
```

For a non-empty Purpose list, the first Purpose also keeps the existing local order:

```text
Entitlement(first)
    before
Correction frontier
    before
Consumption(first)
```

After that first gate, the admitted frontier is shared by later Purpose-local Consumption folds.

Verdict: **SIMPLIFY**, limited to shared correction-world admission.

## 3. Why there is no shared Liquidity/Budget abstraction

The sibling diagrams look superficially similar because both are read-side reports with time coordinates. Their obligations are not the same.

Conditional Liquidity owns a **cross-reader temporal consistency** obligation:

```text
same Actual generation
```

Budget Window owns a **within-query factorization** obligation:

```text
one correction world
+
Purpose-local window arithmetic
```

A generic `ReportEvidence`, `WindowContext`, or prepared-query object would combine unrelated reasons for existence. G2-007 therefore keeps the report boundaries separate.

## 4. What remains intentionally local

G2-007 does not attempt to share or precompute every scan.

### Capacity effective completeness

`entitlementAtEffectiveWindow?` still owns its existing Capacity window/completeness admission. Removing repeated checks would require a new prepared-capacity contract or a lower-level unchecked arithmetic entrance. No independent need for that API has been established here.

### Purpose-local Actual consumption

Each Purpose still needs its own routing-sensitive quantity. Converting the whole Budget Window into one aggregated all-Purpose pass would be a larger semantic change and could create a second consumption engine.

### Cross-authority atomicity

Budget Window still does not claim an atomic transaction spanning Capacity, Actual, and ActualRouting authorities. G2-007 only removes repeated reconstruction from one already-loaded Actual correction relation. No new cross-authority publication semantics are implied.

## 5. Qualification targets

The production change should be considered qualified only if the existing report tests and relevant CI remain green, especially:

- `Loam/Tests/BudgetWindowReview.lean` with multiple Purposes;
- `Loam/Tests/ConditionalBalancePathReview.lean`;
- Production TUI report builds/flows;
- normal compression and selected Lean qualification.

Expected final verdict after CI:

```text
Conditional Liquidity: REPAIR QUALIFIED
Budget Window:         SIMPLIFY QUALIFIED
Sibling abstraction:   KEEP SEPARATE
```

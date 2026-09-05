# Observation 197 — Does equal wallet quantity determine future movement rights?

Status: **F033 active falsification observation**

## Question

F033 comes from a concrete restricted-wallet pressure:

```text
same numeric balance
but
not the same permitted future movements
```

Current PayPay documentation provides one live example of that shape. PayPay Money and PayPay Money Lite can both be used as PayPay balance, while bank-account withdrawal is available to PayPay Money / PayPay Money (salary) and not to PayPay Money Lite. PayPay also distinguishes person-to-person sending from bank withdrawal, so one broad `usable` flag is not enough to describe every future operation.

Current source check, 2026-09-06:

- https://paypay.ne.jp/help/c0042/
- https://paypay.ne.jp/help/c0006/
- https://paypay.ne.jp/help/c0427/

The formal question is deliberately more neutral than PayPay product taxonomy:

> If numeric wallet quantity and Observation-048-style allocation eligibility are held fixed, can two worlds still differ on which future movement operations are permitted?

## Relation to Observation 048

Observation 048 already qualified:

```text
held quantity
    !=
allocation eligibility
```

and explicitly left liquidity, access, ownership, convertibility, and legal restrictions outside its boundary.

Observation 197 therefore holds **both quantity and broad allocation eligibility equal** across the central two-world witness. The only new pressure is future operation permission.

If the model varied only `allocatable`, it would merely repeat Observation 048 and F033 should be marked redundant. It does not.

## Candidate compression under attack

A too-small candidate says:

```text
quantity + broad allocation eligibility
    ->
all relevant future movement permissions
```

A second too-small candidate says:

```text
quantity + spendability
    ->
sendability + withdrawability
```

F033 asks whether those implications survive a bounded two-world test.

## Why Alloy

This is a static information-independence question:

1. hold selected quantitative evidence equal;
2. hold the already-qualified allocation overlay equal;
3. vary only future-operation permission evidence;
4. ask whether legitimate operation queries differ.

No retry, publication order, expiry transition, or arithmetic theorem is needed. Alloy remains the smallest instrument.

## Observation-local vocabulary

```text
Wallet
Amount
RightKind = Spend | Send | Withdraw
World
```

Each World contains:

```text
quantity    : Wallet -> one Amount
allocatable : set Wallet
allowed     : Wallet -> set RightKind
```

`RightKind` and `allowed` are experiment-local evidence. They are not a production proposal for `WalletKind`, `MoneyClass`, capabilities, permissions, legal-right objects, or an extensible operation enum.

## Selected probes

### Representative restricted wallet

Can an allocatable wallet be spendable and sendable but not withdrawable?

Expected: **SAT**.

### Same quantity and allocation, different rights

Can Left and Right have exactly the same quantity relation and exactly the same allocation-eligibility set while one selected wallet is withdrawable in only one world?

Both worlds additionally keep that wallet spendable and sendable.

Expected: **SAT**.

This is the central F033 witness.

### Same quantity and spendability, different transfer right

Can two worlds agree on quantity and spendability while sendability differs?

Expected: **SAT**.

This pressures a single coarse `usable` / `spendable` flag.

## Deliberately too-strong checks

### Quantity and allocation determine rights

```text
same quantity
+ same allocatable set
    ->
same operation rights
```

Expected: **SAT counterexample**.

### Spendability determines all rights

```text
same quantity
+ same spendability
    ->
same sendability and withdrawability
```

Expected: **SAT counterexample**.

## Positive sufficiency check

When quantity, allocation eligibility, and explicit right evidence are all held equal, the selected spend / send / withdraw views must be equal.

Expected counterexample: **UNSAT**.

This checks only internal sufficiency for the selected vocabulary. It does not claim `allowed` is the canonical representation.

## Candidate interpretation if the matrix holds

The bounded result would be:

```text
quantity
    !=
future movement rights
```

and more strongly for the selected pressure:

```text
quantity + broad allocation eligibility
    -/->
withdraw / send permission
```

That would earn independently observable future-operation-right information for queries that need it.

It would **not** earn a PayPay-specific balance-class field. Several information-equivalent representations could remain possible, including policy-derived rights, source/provenance facts, restricted-value evidence, or some smaller relation not yet considered.

## Deliberate boundaries

Observation 197 does **not** establish:

- a production wallet or account type;
- `PayPayMoney` / `PayPayMoneyLite` domain constructors;
- a generic capability framework;
- that rights attach permanently to a Locus;
- how rights change through identity verification or policy revision;
- payment-source priority (F035);
- receiver-side class transformation (F036);
- expiry (F037);
- merchant- or item-specific restrictions (F038/F040);
- legal ownership semantics;
- persistence, CLI, TUI, or household-data changes.

If the result is a counterexample, runtime remains `RESEARCH_ONLY`. Production implementation still waits for real dogfood pressure.

## Falsification status

Until the exact model executes successfully, F033 remains:

```text
Work     = OBSERVING
Finding  = UNTESTED
Runtime  = RESEARCH_ONLY
```

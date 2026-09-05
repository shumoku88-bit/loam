# Observation 197 — Does equal wallet quantity determine future movement rights?

Status: **F033 qualified — COUNTEREXAMPLE**

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

## Executed result

Alloy 6.2.0 + Sat4j produced exactly the expected matrix:

```text
representativeRestrictedWallet                         SAT
sameQuantityAndAllocationDifferentRights               SAT
sameQuantityAndSpendabilityDifferentTransferRight      SAT
QuantityAndAllocationDetermineRights                   SAT counterexample
SpendabilityDeterminesAllRights                        SAT counterexample
ExplicitRightsDetermineSelectedViews                   UNSAT counterexample
```

Dedicated Observation 197 CI completed SUCCESS.

## Central witness

Left and Right can keep:

```text
same quantity
same broad allocation eligibility
same spendability
same sendability
```

while the selected wallet is withdrawable in Left and not withdrawable in Right.

So even after Observation 048's allocation distinction is retained, the selected future-operation answer is not reconstructed.

A second witness keeps quantity and spendability equal while sendability differs. Therefore one coarse `usable` / `spendable` state is also too small for the selected operation vocabulary.

## Qualified bounded separation

```text
quantity
    !=
future movement rights
```

and, for the stronger selected pressure:

```text
quantity + broad allocation eligibility
    -/->
withdraw / send permission
```

The exact future-operation-right evidence used in the model is sufficient for the selected views, but Observation 197 does not claim that this evidence shape is canonical.

## Interpretation

F033 therefore finds a genuine counterexample to the tested compression. Numeric equality does not imply operational equivalence, and broad allocation eligibility does not close that gap.

What has been earned is only this information statement:

> Some future-movement-right information is independently observable when the query needs to distinguish operations such as spend, send, and withdraw.

This does **not** earn a PayPay-specific balance-class field. Several information-equivalent representations could remain possible, including policy-derived rights, source/provenance facts, restricted-value evidence, or some smaller relation not yet considered.

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

Production implementation still waits for real dogfood pressure.

## Falsification result

```text
F033
  Work     = DONE
  Finding  = COUNTEREXAMPLE
  Runtime  = RESEARCH_ONLY
```

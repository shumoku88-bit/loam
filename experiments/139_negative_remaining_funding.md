# Observation 139 — Negative Remaining and funding composition

Status: **experiment under qualification**

## Question

The external accounting pressure survey identified one immediate household-budget gap:

> Does a negative `Remaining` value contain enough information to distinguish cash-funded consumption from liability-funded consumption at a Capacity boundary?

Observation 137 established, in its bounded specimen, that:

```text
previous Remaining
    = previous Capacity projection
    - previous Actual consumption
```

and that positive unused Remaining may cross a boundary only under independently meaningful boundary authority.

It did not test negative Remaining.

This observation attacks the tempting compression:

```text
same Capacity
+ same Consumption
+ same negative Remaining
    -> same funding consequence
```

without introducing `OverspendKind`, `DebtEnvelope`, `CreditCardPaymentCategory`, or a special credit-budget object.

## Minimal specimen

One stable Purpose is used:

```text
Food
```

Two adjacent Capacity authority ranges are fixed:

```text
Previous [0,1)  Food Capacity 10
Next     [1,2)  Food Capacity 10
```

The initial physical state is also fixed:

```text
Asset-role Cash locus      20
Liability-role locus        0
Expense-role Food locus     0
```

Every world records one Food Actual with quantity 12. Therefore every world has:

```text
Consumption = 12
Previous Capacity = 10
Remaining = -2
Next Capacity = 10
```

Only the Actual physical effect differs.

### Cash-funded world

```text
Cash       -12
Liability    0
Expense    +12
```

Selected post-Actual projection:

```text
Asset quantity      8
Liability quantity  0
Net funding position 8
```

### Liability-funded world

```text
Cash         0
Liability  +12
Expense    +12
```

Selected post-Actual projection:

```text
Asset quantity      20
Liability quantity  12
Net funding position 8
```

The worlds therefore deliberately share both:

```text
Remaining = -2
net funding position = 8
```

while differing in asset/liability composition.

A third identity-distinct copy repeats the cash-funded physical definition to test whether world identity itself contributes anything to the selected answers.

## Pressure

### 1. Negative Remaining alone

If two worlds have the same Capacity evidence, the same consumption quantity, and therefore the same negative Remaining, must their asset/liability funding projections agree?

Expected: **no**.

The cash-funded and liability-funded worlds are intended counterexamples.

### 2. Negative Remaining plus aggregate net position

Perhaps the missing distinction is merely aggregate household position.

The specimen therefore also fixes the same simple net position:

```text
asset quantity - liability quantity = 8
```

in both worlds.

If Remaining and this net aggregate are both equal, must the funding composition agree?

Expected: **no**.

This tests whether an aggregate net-worth-like answer is still too compressed for the selected question.

### 3. Does different funding force different next Capacity?

The two worlds deliberately retain the same next Capacity authority:

```text
Next Food Capacity = 10
```

while their physical funding composition differs.

Expected: the claim that different funding composition *must* create a different next Capacity is false.

This preserves the separation:

```text
budget authority
    !=
physical funding / liability composition
```

A later explicit boundary policy may choose to connect them, but that connection is not inferred merely from negative Remaining.

### 4. Full Actual physical evidence

If two worlds share the same Actual purpose, quantity, and complete Locus effect definition, can the selected Remaining / asset / liability / net answers differ?

Expected: **no bounded counterexample**.

If this holds, the smaller candidate is:

```text
Capacity authority
+ Actual quantity / Purpose evidence
+ Actual physical Locus effects
+ accounting-role interpretation
    -> Remaining
    -> selected asset/liability funding projection
```

without a retained overspending-kind fact.

## Expected commands

The workflow requires the following witnesses:

```text
sameNegativeRemainingDifferentFundingComposition       SAT
cashFundedNegativeRemainingIsReachable                 SAT
liabilityFundedNegativeRemainingIsReachable            SAT
sameBoundaryCapacityDifferentFundingPressure           SAT
equalPhysicalDefinitionDifferentIdentitySameAnswer     SAT
```

and the following assertion results:

```text
NegativeRemainingDeterminesFundingComposition               SAT counterexample
NegativeRemainingAndNetPositionDetermineFundingComposition SAT counterexample
DifferentFundingCompositionRequiresDifferentNextCapacity   SAT counterexample
ActualPhysicalDefinitionDeterminesFundingProjection         UNSAT counterexample
```

## Interpretation gate

If qualification matches the expected result, the bounded conclusion will be deliberately narrow:

```text
negative Remaining
    is a budget projection

negative Remaining
    does not encode
whether the consumption reduced an asset
or increased a liability
```

But this does **not** automatically earn a new deficit category.

If the complete Actual physical effects plus accounting-role interpretation determine the selected funding projection, then information equivalent to the distinction already exists upstream. A UI may say `cash overspending` or `credit overspending` without those phrases becoming canonical household facts.

## Not earned by this observation

Even if the expected result qualifies, it does not establish:

- a production `OverspendKind`;
- a `CreditCardPaymentCategory` or `DebtEnvelope`;
- a canonical credit-card object;
- a universal rule for how negative Remaining affects next Capacity;
- mixed cash/liability deficit attribution;
- ordering rules when several Actuals consume one Capacity;
- Backing movement policy;
- automatic debt repayment planning;
- interest, fees, minimum payments, or statement cycles;
- a production AccountingRole change.

Mixed funding is intentionally deferred. The first question is only whether the pure cash-funded versus liability-funded distinction is already recoverable from existing kinds of evidence.

## Tool choice

**Alloy first.**

The first pressure is static independence and sufficiency:

- hold budget evidence fixed;
- hold aggregate net position fixed;
- vary the physical funding shape;
- ask whether selected answers diverge.

No transition/liveness law is needed yet. TLA+ becomes relevant only if later work asks how mixed funding, repayment, or boundary publication evolves through time.

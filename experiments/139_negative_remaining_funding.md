# Observation 139 — Negative Remaining and funding composition

Status: **qualified bounded result**

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
Asset quantity        8
Liability quantity    0
Net funding position  8
```

### Liability-funded world

```text
Cash         0
Liability  +12
Expense    +12
```

Selected post-Actual projection:

```text
Asset quantity        20
Liability quantity    12
Net funding position   8
```

The worlds therefore deliberately share both:

```text
Remaining = -2
net funding position = 8
```

while differing in asset/liability composition.

A third identity-distinct copy repeats the cash-funded physical definition to test whether world identity itself contributes anything to the selected answers.

## Qualified Alloy result

Alloy 6.2.0 + Sat4j produced the complete expected result set:

```text
sameNegativeRemainingDifferentFundingComposition       SAT
cashFundedNegativeRemainingIsReachable                 SAT
liabilityFundedNegativeRemainingIsReachable            SAT
sameBoundaryCapacityDifferentFundingPressure           SAT
equalPhysicalDefinitionDifferentIdentitySameAnswer     SAT

NegativeRemainingDeterminesFundingComposition                SAT counterexample
NegativeRemainingAndNetPositionDetermineFundingComposition  SAT counterexample
ActualPhysicalDefinitionDeterminesFundingProjection          UNSAT counterexample
```

Executable qualification head:

```text
228102c0ce1d1c6083c66fec1a0c8d23e95d032f
```

GitHub Actions:

```text
Observation 139
run 33774365348
job 100712252260
SUCCESS
```

Both the Alloy execution step and the expected-result checker completed successfully.

## Findings

### 1. Negative Remaining does not determine funding composition

The cash-funded and liability-funded worlds share:

```text
Previous Capacity = 10
Consumption       = 12
Remaining         = -2
Next Capacity     = 10
```

but their post-Actual asset/liability projections differ.

Therefore, in this bounded vocabulary:

```text
negative Remaining
    does not determine
asset-funded vs liability-funded composition
```

### 2. Adding one aggregate net position is still too small

Both worlds also share:

```text
asset quantity - liability quantity = 8
```

while retaining different asset/liability composition.

So the stronger compression also fails:

```text
negative Remaining
+ aggregate net funding position
    does not determine
funding composition
```

An aggregate net-worth-like answer can therefore erase information needed by the selected funding question.

### 3. Different funding composition can coexist with one next Capacity

The witness `sameBoundaryCapacityDifferentFundingPressure` is SAT while both worlds retain:

```text
Next Food Capacity = 10
```

Thus this bounded pressure does not force budget authority to mutate merely because physical funding composition differs:

```text
Capacity authority
    !=
physical asset/liability composition
```

A future explicit boundary policy may connect those questions, but negative Remaining alone does not supply such authority.

### 4. Complete Actual physical evidence is sufficient for the selected projection

The assertion:

```text
ActualPhysicalDefinitionDeterminesFundingProjection
```

has no bounded counterexample.

When two worlds share the same:

```text
Actual Purpose
Actual quantity
complete Actual Locus effects
```

and the specimen retains the same accounting-role interpretation, their selected:

```text
Remaining
asset quantity
liability quantity
net funding position
```

cannot differ in the bounded model.

The identity-distinct cash-funded copy also produces the same selected answer.

So the smaller qualified candidate is:

```text
Capacity authority
+ Actual quantity / Purpose evidence
+ Actual physical Locus effects
+ accounting-role interpretation
    -> Remaining
    -> selected asset/liability funding projection
```

without a retained overspending-kind fact.

## Interpretation

The bounded conclusion is deliberately narrow:

```text
negative Remaining
    is a budget projection

negative Remaining
    does not encode
whether the consumption reduced an asset
or increased a liability
```

But the missing distinction need not become another canonical budget noun if it is already observable in upstream physical/accounting evidence.

A household UI may legitimately present phrases such as:

```text
cash overspending
credit / liability-funded overspending
```

without storing those phrases as independent household truth.

This strengthens the existing LOAM separation:

```text
Capacity / Remaining
    budget authority and projection

Actual physical effects
    what quantities actually changed where

AccountingRole
    how selected loci participate in an accounting view
```

The selected budget deficit and the selected funding composition are related questions, but one does not own the other's truth.

## What this closes

The external survey used YNAB's distinct cash and credit overspending behavior as pressure. Observation 139 does not reproduce YNAB's product objects. Instead it shows that the first pure cash-versus-liability distinction can already be represented without a canonical credit-budget object or retained overspending-kind fact.

That reduces the immediate pressure to enlarge the envelope-budget ontology.

The ordinary negative-Remaining question can therefore remain compressed until a future operation asks something not recoverable from the existing upstream evidence.

## Not earned by this observation

This result does not establish:

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

Mixed funding remains a possible later pressure, but it should be observed only if dogfood or an external accounting question requires source-specific attribution within one Actual. It is not automatically the next experiment.

## Tool choice

**Alloy was sufficient.**

The pressure was static independence and sufficiency:

- hold budget evidence fixed;
- hold aggregate net position fixed;
- vary the physical funding shape;
- ask whether selected answers diverge.

No transition/liveness law was needed. TLA+ becomes relevant only if later work asks how mixed funding, repayment, or boundary publication evolves through time.

## Next pressure

Observation 139 removes the strongest immediate negative-Remaining compression concern without adding a budget concept.

The next externally observed gap should therefore preferably move to a genuinely different boundary rather than keep elaborating envelope vocabulary:

> Can accounting recognition time differ from occurrence, invoice, payment, delivery, or service time without rewriting the underlying Actual evidence?

That is the stronger next candidate from the September external accounting pressure survey.

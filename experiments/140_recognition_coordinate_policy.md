# Observation 140 — Recognition as a coordinate projection

Status: **qualified expected result**

## Question

The September external accounting pressure survey identified a second clear gap after negative `Remaining`:

> accounting recognition time may differ from invoice, payment, due, delivery, or service-use time.

LOAM already separates several neighbouring meanings:

```text
Scheduled != Actual
initiated != settled
physical Locus != AccountingRole
```

But those separations do not establish when an accounting expense or revenue belongs to a queried period.

This observation tests a smaller and slightly stranger possibility:

> recognition may not be one canonical timestamp at all.
>
> It may be a projection over time coordinates under an independently meaningful recognition definition.

The experiment therefore deliberately does **not** introduce a `RecognitionTime` field.

## Minimal specimen

Five experiment-local coordinates are used:

```text
C0  invoice evidence
C1  payment + service start
C2  due coordinate
C1..C4  service range
```

The amount is fixed at 12.

Every world has exactly the same timing evidence:

```text
invoice at C0
payment at C1
due at C2
service range C1..C4
quantity 12
```

Only the recognition definition differs.

### Immediate world

Recognise the entire 12 at the first service coordinate:

```text
C1 = 12
C2 = 0
C3 = 0
C4 = 0
```

### Spread world

Recognise evenly across the four service coordinates:

```text
C1 = 3
C2 = 3
C3 = 3
C4 = 3
```

Both worlds therefore preserve the same whole-service amount:

```text
recognised over C1..C4 = 12
```

while giving different answers to narrower query ranges.

A third identity-distinct recognition definition repeats the immediate definition to test whether recognition-definition identity itself contributes to the selected result.

## Pressure

### 1. Timing evidence does not determine period recognition

The strongest shortcut under attack is:

```text
invoice coordinate
+ payment coordinate
+ due coordinate
+ service DateRange
+ quantity
    -> recognised amount by query DateRange
```

Qualified result: **false in the bounded specimen**.

The immediate and spread worlds hold all of that evidence fixed while producing:

```text
first service period:
  Immediate = 12
  Spread    = 3

later service periods:
  Immediate = 0
  Spread    = 9
```

Operational timing evidence is therefore insufficient by itself.

### 2. Payment time is not universally recognition time

A second tempting compression is:

```text
recognition happens where payment happens
```

The spread world keeps recognising 3 at C2, C3, and C4 after payment at C1.

Qualified result: Alloy finds the expected bounded counterexample to the rule that the payment coordinate contains all recognition.

### 3. Recognition need not be represented as one scalar time

The spread world has no single coordinate that contains the whole recognised quantity.

That does not yet prove a production representation, but it is pressure against prematurely adding:

```text
RecognitionTime : Timestamp
```

as though recognition always had one instant.

The smaller candidate is a coordinate-sensitive projection:

```text
timing / obligation evidence
+ service DateRange
+ recognition definition
+ query DateRange
    -> recognised accounting view
```

### 4. Definition identity is not yet earned

`ImmediateDefinition` and `ImmediateDefinitionCopy` are different atoms with the same experiment-local definition.

Qualified result: they produce the same recognised answer for every selected DateRange.

So even if an independent recognition definition is needed, this observation does not establish that a stable recognition-policy identity belongs in the Practical Core.

### 5. Whole-service conservation

Both bounded definitions recognise exactly the original quantity over the full service range.

Qualified result: no bounded counterexample to:

```text
sum recognised over whole service range = quantity
```

This is only a specimen invariant, not yet a universal accounting law. Amendments, refunds, partial service, taxes, foreign exchange, and cancellation are outside this observation.

## Qualified command results

Alloy 6.2.0 + Sat4j matched the expected boundary:

```text
sameTimingEvidenceDifferentRecognitionProjection  SAT
recognitionCanRemainAfterPaymentCoordinate         SAT
equalDefinitionDifferentIdentitySameProjection    SAT

TimingEvidenceDeterminesRecognitionProjection      SAT counterexample
PaymentCoordinateContainsAllRecognition            SAT counterexample
RecognitionDefinitionDeterminesProjection          UNSAT counterexample
WholeServiceRecognitionConservesQuantity           UNSAT counterexample
```

Executable qualification head:

```text
b73a8de5b9d51853f8086abd55568bfe331ba1c6
```

Qualification job:

```text
100715239957  SUCCESS
```

## Interpretation gate

The bounded conclusion is:

```text
invoice / payment / due / service timing
    does not determine
period recognition

payment coordinate
    !=
recognition coordinate in general

recognition
    can be distributed across coordinates
```

The observation therefore supports thinking of recognition as a **time-coordinate accounting projection**, rather than as another lifecycle timestamp attached to an Event.

But the result remains bounded. It does not establish a universal accrual model or require deferred-accounting machinery in household use.

## Not earned by this observation

This observation does not establish:

- canonical `Invoice`;
- canonical `DeferredExpense` or `DeferredRevenue`;
- canonical `Accrual`;
- canonical `RecognitionSchedule`;
- canonical `RecognitionTime`;
- production `RecognitionPolicy` identity;
- receivable / payable workflow;
- tax recognition rules;
- cancellation or amendment ordering;
- period close / publication semantics;
- generated accounting entries;
- persistence, CLI, TUI, or Practical Core changes.

The invoice / due / payment names in this specimen are experiment-local pressure coordinates only.

## Tool choice

**Alloy first** was sufficient for this question.

The qualified pressure is static information independence:

- hold operational timing evidence fixed;
- vary only the recognition definition;
- period accounting answers diverge;
- equal recognition definitions produce equal selected projections.

TLA+ becomes relevant later only if publication, amendment, cancellation, or period-close ordering becomes the hard question.

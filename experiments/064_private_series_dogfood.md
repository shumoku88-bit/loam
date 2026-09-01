# Observation 064 private dogfood — explicit Series membership under real Plan pressure

## Purpose

Observation 064 established a bounded separation:

```text
Plan content
    !=
recurrence classification
    !=
Series membership
```

This checkpoint asks whether the current private canonical Plan source still exerts that pressure without copying private Series identities, Plan identities, dates, quantities, descriptions, account-like coordinates, recurrence labels, or other metadata values into the public repository.

It does not introduce Observation 085.

## Privacy-safe current snapshot summary

A read-only inspection of the current private canonical Plan snapshot produced only these structural counts:

```text
Plan records observed:                                      31
Plan records with explicit Plan identity:                   31
Plan records with explicit Series membership:               30
Plan records without explicit Series membership:             1
unique explicit Series identities observed:                 10
Series with exactly one observed Plan member:                0
Series with multiple observed Plan members:                 10
Plan records with explicit recurrence classification:       19
Series-tagged Plans with explicit recurrence classification:19
Series-tagged Plans without recurrence classification:      11
Series spanning recurrence-present / recurrence-absent Plans:5
Series spanning multiple explicit recurrence classifications:0
recurrence classifications shared by multiple Series:        2
```

No private identifier or metadata value is required to interpret these counts.

## Pressure A — recurrence is not required for observed Series membership

The current source contains Series-tagged Plans that do not carry an explicit recurrence classification.

Therefore the current data does not support treating recurrence classification as the representation from which Series membership is reconstructed:

```text
explicit Series membership
    can remain observable
while
explicit recurrence classification
    is absent
```

This is real-data support for the Observation 064 separation rather than a new abstraction.

## Pressure B — recurrence does not identify a Series

The current source also contains explicit recurrence classifications that are shared by multiple distinct Series.

So even where recurrence metadata is present:

```text
same recurrence classification
    -/->
same Series
```

The classification remains coarser than recurring-thread identity in the current snapshot.

## Pressure C — missing Series membership stays missing

At least one current Plan record has no explicit Series membership.

This checkpoint deliberately does not compare its description, date, amount, physical shape, or other content to nearby Plans in order to guess a Series.

Observation 064 already established why that would be unsound in general:

```text
Plan content
    -/->
Series membership
```

So the safe operational reading is simply:

```text
explicit Series present  -> membership may be observed
explicit Series absent   -> membership remains unknown here
```

No automatic grouping is earned.

## Executable observer

`tools/private-plan-series-shadow.py` makes this boundary repeatable without exposing private values.

It reports only structural coverage and cross-classification counts. In particular it does not print:

- Plan identities;
- Series identities;
- recurrence labels;
- dates;
- descriptions;
- quantities;
- posting coordinates;
- raw source text.

It verifies that the source digest is unchanged across observation and refuses ambiguous multiple-Series metadata rather than choosing one value.

Public synthetic CI exercises both positive structural counting and the fail-closed multiple-Series case. It also includes a Plan whose content resembles a Series-tagged Plan but lacks explicit Series metadata, and requires that the observer not infer membership from that resemblance.

## Finding

The current real-data checkpoint strengthens Observation 064 operationally:

```text
Series membership
    is retained information in its own right

recurrence classification
    is neither required nor sufficient
    to recover that membership

missing explicit Series membership
    stays missing
```

This does not prove that every future Plan belongs to at most one Series. The current source encoding and observer handle zero-or-one explicit Series field per Plan; multiple fields are treated as new unresolved pressure and fail closed.

It also does not prove that a Series can never change explicit recurrence classification. The current snapshot simply does not exhibit such a case among members that carry recurrence metadata.

## Practical Core impact

None.

```text
Practical Core additions: 0
Persistence additions:     0
CLI additions:             0
wire-format additions:     0
```

No first-class Practical Core `Series`, recurrence engine, Series persistence stream, automatic next-occurrence generation, or universal Plan-to-Series cardinality law is earned.

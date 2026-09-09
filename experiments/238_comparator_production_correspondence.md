# Observation 238 — Does Comparator establish production correspondence?

Status: **ACTIVE — negative correspondence probe**

Research baseline: LOAM `110725804c4141b969d8352cb0eb6b23b150e005`

## Question

After Observation 237 reduced the independent-semantics/production boundary to a
small explicit bridge, can an independent Challenge plus Comparator mechanically
establish that an accepted Solution genuinely uses the production Scheduled
implementation?

## Counterexample

The trusted Challenge deliberately contains no LOAM vocabulary.  Its reviewed
observable is represented by the concrete code `0 = unknown` and states that the
selected absence case yields code `0`.

The Solution has the exact same theorem name and statement, but deliberately does
**not** import LOAM, call `currentScheduledDayEvidenceWithReplacement`, or cross the
Observation 237 bridge.  It proves the statement by `rfl`.

If upstream Comparator accepts this pair with an empty permitted-axiom set, then
Comparator has correctly established statement identity, axiom policy, and kernel
acceptance while simultaneously demonstrating that those properties do **not**
establish production correspondence.

## Interpretation

This is intentionally a negative probe.  A successful Comparator run is evidence
against the stronger architecture proposed after Observation 237:

```text
independent Challenge
        +
production-backed Solution
        +
Comparator
```

The label `production-backed` is not mechanically forced by an implementation-
independent theorem statement.  A production-free Solution can satisfy the same
statement.

Therefore Comparator can protect the Challenge/Solution statement boundary, but it
cannot close the remaining trusted correspondence edge merely by being placed after
an independent Challenge.

## Stop condition

Do not respond by putting LOAM production vocabulary into the trusted Challenge,
adding a generic proof-usage checker, or creating a new verification framework.
Those moves would either reopen coupled semantic drift or create a larger trusted
mechanism than the small bridge found in Observation 237.

If the counterexample is accepted, retain Observation 237's small explicit bridge
as the qualified boundary and treat Comparator as optional statement/axiom/kernel
hardening rather than production-correspondence evidence.

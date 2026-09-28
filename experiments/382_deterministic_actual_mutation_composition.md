# Observation 382 — deterministic Actual mutation composition

Status: **EXECUTABLE PILOT — order-sensitive Correction/Reversal composition; no production architecture change**

Baseline:

```text
LOAM main 0d2e0f3f205596b53ab298fd452cb022957f5867
Observation 380 merged as #1449
Observation 381 merged as #1450
```

## Question

Observation 381 established a small deterministic production-replay layer for Movement publication and idempotent retry.

This belongs to LOAM's **deterministic production-history testing** layer. It is an ordered replay scenario, not a claim of TigerBeetle-style DST, randomized state-space exploration, or a simulated execution environment.

The next question is not merely whether more writers can be called from the same test.

Correction and Actual Reversal have an order-sensitive shared boundary:

```text
Movement
  -> Correction(target -> replacement)
       -> old target is no longer current for Reversal

Movement
  -> Reversal(target -> inverse)
       -> both target and inverse are protected from Correction
       -> a second Reversal is refused
       -> reversal-of-reversal is refused
```

Can one deterministic retained history exercise those interactions through the production household command boundary, survive typed reload after every step, and replay to identical canonical bytes?

## Instrument choice

No new Lean theorem, Alloy model, or TLA+ machine is required for this question.

The semantics are already represented by production writer admission. The missing pressure is implementation composition across several successful and refused writes.

The selected instrument is one Lean executable integration scenario:

```text
Loam/Tests/DeterministicActualMutationScenario.lean
```

## Production logic reused

The scenario does not mock semantic writers. It calls:

```text
HouseholdCommand.recordIdempotent
HouseholdCommand.correctActual
HouseholdCommand.reverseActual
ActualAuthority.loadActual?
NormalizedActualPersistence encode/decode
LocusAdmissionAuthority
ScheduledLifecyclePersistence
```

Reversal receives an explicit empty Scheduled lifecycle authority. Missing Scheduled authority is not silently interpreted as empty.

## Trace

Each isolated replay starts with four ordinary Movement Events.

The mutation trace then performs, in one retained history:

```text
correct A -> A1
reverse B -> B-reversal

reverse stale A                         REFUSE
correct reversal target B              REFUSE
correct reversal endpoint B-reversal   REFUSE

correct current A1 -> A2
reverse stale A1                        REFUSE
reverse current A2

correct reversed A2                     REFUSE

reverse C
reverse C again                         REFUSE
reverse B-reversal                      REFUSE

unbalanced correction D                 REFUSE
correct D -> D1
reverse D1
correct reversed D1                     REFUSE
```

This intentionally includes a correction chain before reversing its final current frontier.

## Checkers

After every successful mutation the scenario requires:

- exactly one new Event;
- exactly one corresponding Correction or Reversal provenance edge;
- original Event retention;
- expected replacement/reversal Event retention;
- exact physical inverse for every successful Reversal;
- typed authority reload;
- canonical encode -> decode -> encode stability;
- on-disk bytes equal the canonical admitted encoding.

After every refused mutation it requires:

```text
actual.loam before == actual.loam after
```

and then performs the same typed/canonical reload checks.

The final expected retained shape is:

```text
base Movement Events       4
successful Corrections     3
successful Reversals       4
--------------------------------
retained Events           11

Correction edges           3
Reversal edges             4
Movement operation rows    4
```

No Relation, Discharge, or Settlement evidence should appear.

## Replay property

The full trace runs twice in distinct household roots.

Both runs must produce identical scenario counters and byte-for-byte identical canonical actual.loam.

This is deterministic replay, not a claim of exhaustive state-space coverage.

## Why this differs from existing tests

The existing Correction and Reversal publisher tests correctly pin many individual writer obligations.

Observation 382 asks a different question:

> Does a sequence of successful and refused writes preserve all prior evidence when the admissibility of the next writer depends on what an earlier writer retained?

That is the niche deterministic production-history testing adds beside isolated regressions.

## Expansion gate

If this scenario qualifies, the next useful family is Settlement because it adds a second kind of stateful frontier:

```text
commitment
-> physical correspondence / non-payment extinguishment
-> revision / retraction
```

Do not add a generic scenario-runner or simulator framework yet. Two Actual mutation writers can still be expressed clearly with an explicit scenario.

A shared scenario-runner abstraction is earned only if adding Settlement or Scheduled recovery reveals genuinely repeated scenario machinery rather than merely repeated test assertions.

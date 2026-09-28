# Observation 383 — deterministic Settlement lifecycle composition

Status: **QUALIFIED EXECUTABLE PILOT — Settlement frontier/revision composition replayed deterministically; no production architecture change**

Baseline:

```text
LOAM main f57f33e71b1b8b9d7825b87feeda2c281bd31b3b
Observation 380 merged as #1449
Observation 381 merged as #1450
Observation 382 merged as #1451
```

## Question

Observation 381 qualified deterministic replay for Movement/idempotency.
Observation 382 qualified order-sensitive composition between Correction and Reversal.

Settlement adds a different kind of stateful frontier:

```text
source Event / Effect
      ↓
commitment
      ↓
physical settlement correspondence
      ↓
commitment correction lineage
      ↓
non-payment extinguishment
      ↓
extinguishment correction / retraction
```

The important question is not whether each writer already has unit coverage.
It is whether one retained history can compose all of those writers while preserving historical settlement provenance, current frontier arithmetic, canonical persistence, and fail-closed refusal behavior.

## Instrument

The selected instrument is one executable Lean integration scenario:

```text
Loam/Tests/DeterministicSettlementScenario.lean
```

No Core, Application, persistence, writer, or household-data production module is changed.

## Initial retained world

Each replay begins with two Actual Events:

```text
source Event
  source Effect in USD

payment Event
  physical JPY Effect
```

An explicit settlement batch then records:

```text
commitment       1000 JPY
physical settled 700 JPY
outstanding      300 JPY
```

The commitment intentionally uses JPY while its source Effect is USD. This keeps the scenario on the already-qualified cross-measure settlement boundary rather than collapsing it into ordinary same-measure movement semantics.

## Trace

The current commitment is corrected from 1000 to 1200. The historical physical correspondence still targets the superseded commitment identity, so the current replacement must nevertheless inherit the 700 settled quantity through commitment lineage:

```text
old commitment 1000
   └─ physical settlement 700
         ↓
correction
         ↓
current commitment 1200
         ↓
outstanding 500
```

The scenario then performs:

```text
amount correction 1000 -> 1200                 SUCCESS
amount correction 1200 -> 600                  REFUSE
unchanged amount correction 1200 -> 1200       REFUSE

non-payment reduction 200, unknown date         SUCCESS
reduction correction 200 -> 150, known date    SUCCESS
reduction retraction                            SUCCESS

impossible reduction date                       REFUSE
retract commitment with live payment evidence   REFUSE

independent commitment 250                      SUCCESS
retract independent commitment                  SUCCESS

retry explicit seed row identities              REFUSE
```

## Checkers

After each successful transition the scenario re-loads canonical Actual evidence and checks the expected current settlement arithmetic.

After every successful or refused step it also checks:

```text
ActualAuthority.loadActual?
encodeNormalizedActual?
decodeNormalizedActual?
re-encode
disk bytes == canonical encoded bytes
```

Every refused operation additionally requires:

```text
actual.loam before == actual.loam after
```

The final raw retained shape must be:

```text
Actual Events                       2
raw commitments                    3
commitment revisions               2
physical correspondences           1
raw extinguishments                2
extinguishment revisions           2
netting contexts                    0
netting members                     0
```

The final current image must still report:

```text
settled       700
extinguished    0
outstanding   500
```

for the corrected current commitment.

That is the central composition invariant of this probe: historical physical settlement survives commitment correction lineage, while retracted non-payment reduction does not remain current.

## Deterministic replay

The complete scenario runs twice in distinct household roots.

Both executions must produce identical counters and byte-for-byte identical final canonical actual.loam.

A passing replay is not a proof of exhaustive behavior. It is an implementation-composition witness with exact reproducibility.

## Executed result

The shared Lean qualification completed successfully:

```text
workflow: Lean Application Qualifications
run:      36371132050
job:      Replay deterministic Settlement lifecycle composition
result:   SUCCESS

amountCorrections:      1
reductions:             1
reductionCorrections:   1
reductionRetractions:   1
commitmentRetractions:  1
refusals:               5
```

The complete history was replayed in two isolated household roots and produced identical final canonical Actual bytes and identical counters.

The final current corrected commitment retained 700 JPY of historical physical settlement through its correction lineage, retained no current extinguishment after reduction retraction, and reported 500 JPY outstanding.

All refused operations preserved canonical Actual bytes exactly.

## Relationship to existing Settlement tests

The existing explicit publisher and friendly action tests already pin individual obligations such as amount correction, extinguishment correction, retraction, malformed date refusal, and dependent commitment refusal.

Observation 383 adds a different pressure:

> all of those operations must coexist in one retained authority generation history, and later frontier arithmetic must continue to interpret earlier evidence correctly.

## Simulator-abstraction checkpoint

After Observations 381-383, three materially different production-history families now repeat the same test-only mechanics:

```text
execute production action
reload typed authority
canonical encode/decode check
refusal => byte-for-byte no mutation
repeat in second root
compare final canonical bytes
```

This is the first point where a tiny test-only helper module may be justified.

However, O383 deliberately does not extract it yet. The explicit third example should qualify first. If it passes, a follow-up compression pass may extract only the mechanically identical helpers while keeping each scenario's semantic trace visible in its own test.

Do not build a generic state-machine DSL, callback framework, property-testing library, or production simulator seam.

## Stop / next gate

If O383 qualifies:

1. record the actual execution result;
2. compare O381/O382/O383 duplicated helper code;
3. extract only test-only canonical/replay helpers if the diff demonstrably shrinks;
4. keep scenario semantics explicit;
5. only then consider Scheduled recovery or controlled publication-fault injection.

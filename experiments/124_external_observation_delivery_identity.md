# Observation 124 — Can duplicate delivery be separated from source observation identity?

## Household question

External systems may deliver the same source record more than once because of retry, polling, webhook redelivery, or importer replay. At the same time, two genuinely distinct source records can have exactly the same visible payload.

The pressure is:

```text
same visible payload delivered twice
```

may mean either:

```text
A, A   -- retry of one source observation
```

or:

```text
A, B   -- two distinct source observations with equal content
```

The question is:

> Can content alone determine whether the household should retain one external observation or two, or is source-observation identity / equivalent correspondence independently observable?

## Why TLA+

This is both an identity-sufficiency and delivery-order question. The second delivery occurs after the first and may be either replay or a new source identity. TLA+ / TLC is therefore the smallest instrument that directly checks both reachable histories and the invariants of an identity-aware ingest boundary.

No concurrent publishers or races are modeled, so SPIN is not yet needed.

## Bounded vocabulary

Two source identities deliberately share one payload:

```text
ContentA = ContentB = same-payload
```

The model keeps:

```text
delivery attempts
    !=
retained source-observation identities
```

Observation A may be delivered twice. Observation B may instead arrive as the second delivery with exactly the same content.

The source identities are bounded scaffolding. They do not assert that every bank provider exposes a stable transaction ID. The semantic point is only that information equivalent to source identity or explicit delivery-to-observation correspondence is required if retry and same-content multiplicity must remain distinguishable.

## Reachable histories

### Retry

```text
first delivery:  A
second delivery: A again

2 delivery attempts
1 retained source observation
```

### Distinct same-content record

```text
first delivery:  A
second delivery: B
ContentA = ContentB

2 delivery attempts
2 retained source observations
```

At payload level both histories look like:

```text
same-payload
same-payload
```

If both are reachable, payload content and delivery count alone are insufficient to decide retained observation multiplicity.

## Qualification target

Positive invariants must hold:

```text
TypeOK
StoredCountMatchesSourceIdentity
DeliveryCountMatchesAttempts
KnownIdentityRequiresDelivery
RetryPreservesSingleObservation
DistinctKeysRemainDistinct
```

Dedicated boundary configurations are deliberately too strong and must fail:

```text
NoRetryHistory
NoDistinctSameContentHistory
IdenticalPayloadDeliveriesAlwaysOneObservation
IdenticalPayloadDeliveriesAlwaysTwoObservations
```

Expected interpretation:

- violation of `NoRetryHistory` shows repeated delivery can leave one retained observation;
- violation of `NoDistinctSameContentHistory` shows equal content can still represent two distinct source observations;
- violating both `IdenticalPayloadDeliveriesAlwaysOneObservation` and `...AlwaysTwoObservations` shows the identical payload stream does not determine observation multiplicity.

## Expected compression boundary

If qualified:

```text
delivery attempt
    !=
external observation identity
```

and:

```text
payload content
+ delivery count

    do not determine

retained observation count
```

A minimal ingest boundary therefore needs information equivalent to:

```text
source observation identity
or
explicit delivery -> retained-observation correspondence
```

when the source contract and household questions require replay to be distinguishable from genuine same-content multiplicity.

This does not imply that a provider-supplied ID is universally trustworthy or stable. Pending -> posted providers may replace identifiers, and sources without stable identity may require adapter-local provenance or later reconciliation policy. Observation 124 only rejects content-only deduplication as a generally sufficient semantic rule.

## Neighboring boundaries

- Observation 121 separates external observation authority from household Actual authority and shows reconciliation is not reconstructible from record content alone.
- Observation 123 separates source pending/posted lifecycle from Actual lifecycle and retains source provenance when current projection is too small.
- Observation 124 stays one layer earlier: before reconciliation, can source delivery itself be collapsed into source observation identity?

Together these pressures suggest three distinct notions that must not be casually collapsed:

```text
delivery attempt
external source observation
household Actual
```

No generic provenance framework is earned yet.

## Boundaries

Observation 124 does not establish:

- a production `ExternalObservation` type;
- a production provider/source ID type;
- a webhook or polling API;
- exactly-once delivery;
- concurrent ingest correctness;
- provider-ID stability across pending -> posted;
- fuzzy duplicate detection;
- automatic reconciliation to Actual;
- retention duration for delivery provenance;
- source correction or deletion semantics;
- cross-provider deduplication;
- a Practical Core or persistence change.

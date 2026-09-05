# Observation 172: relation endpoint identity pressure

## Question

Observations 163–171 earned a directional open-relation semantic axis and a likely covered-validity qualification seam, but deliberately stopped before adding a production relation type.

One of the remaining representation questions is endpoint identity.

The recurring shared-cost case creates concrete pressure:

```text
source Effect A -> Friend owes Household
source Effect B -> same Friend owes Household
later Event      -> discharges one or both relation units
```

If LOAM must answer a per-counterparty question across multiple occurrences, a generic `Outside` marker is too coarse. But that does not automatically earn a universal `Party`, `Person`, Merchant, card-issuer, or contact registry.

The narrower question is:

> What is the smallest stable identity needed at one open-relation endpoint, and what semantics should remain outside that identity?

## Existing Core pressure

LOAM already separates stable opaque identity from presentation and accounting meaning.

`EventId` is an opaque token that does not encode event kind, purpose, settlement state, or accounting role.

`EffectKey` is an opaque per-Event key specifically retained so later overlays can refer to one Effect without using list position or projection coordinates as identity.

Observation 166 therefore already gave the source side a candidate anchor:

```text
(EventId, EffectKey)
```

Observation 172 asks for the corresponding minimum on the counterparty side.

## Observation-local model

The bounded Alloy model introduces only:

```text
Endpoint
  Household
  ExternalEndpoint
```

`ExternalEndpoint` is observation-local opaque identity. It has no built-in person, friend, merchant, issuer, institution, ownership, custody, or account semantics.

The model separately represents:

```text
NameFact
  endpoint -> display label

RelationUnit
  source Effect
  debtor endpoint
  creditor endpoint

Discharge
  later Event
  relation-unit reference
```

It also includes a deliberately coarse projection:

```text
Endpoint -> HouseholdSide | OutsideSide
```

so exact endpoint identity can be compared with aggregate household/outside meaning.

None of these observation-local signatures is a proposed production type.

## Probes

The model asks whether:

1. one stable external endpoint can connect multiple relation units from different source Effects;
2. two distinct external endpoints may share one display label, so presentation text is not identity;
3. one endpoint may be renamed without changing identity;
4. one external endpoint may be debtor in one relation and creditor in another, so relation role is not identity;
5. distinct endpoints may collapse to the same coarse `OutsideSide` projection;
6. a later discharge can name one exact relation unit without repeating its endpoint;
7. coarse side classification fails to identify one endpoint;
8. receivable-like direction fails to identify one counterparty;
9. an endpoint pair fails to identify one relation unit because multiple open units may exist between the same endpoints;
10. a retained relation-unit reference determines the endpoints needed for discharge projection.

## Expected matrix

```text
sameEndpointAcrossMultipleOrigins                    SAT
sameDisplayLabelCanNameDistinctEndpoints             SAT
renamePreservesEndpointIdentity                      SAT
sameEndpointCanAppearInBothDirections                SAT
distinctEndpointsShareCoarseOutsideProjection        SAT
relationUnitIdentityIsEnoughForExactDischarge        SAT
SideDeterminesEndpointIdentity                       SAT counterexample
ReceivableDirectionDeterminesCounterparty            SAT counterexample
EndpointPairDeterminesRelationUnit                    SAT counterexample
RelationReferenceDeterminesDischargeEndpoints        UNSAT counterexample
```

## Candidate boundary

If the matrix holds, the minimum pressure is not a global Party ontology. It is closer to:

```text
relation endpoint identity
  Household
  or
  opaque external identity
```

with presentation and role kept separate:

```text
display name != identity
friend / issuer / merchant role != identity
receivable / payable direction != identity
```

The important scope restriction is that not every merchant or real-world actor needs an endpoint identity merely because it appears in household life.

An external identity is earned when a relation query needs to distinguish or reconnect the same counterparty across relation units. A merchant that only appears as a movement locus does not become a relation endpoint by theorem.

## Aggregate queries remain cheaper

Observation 163 already found that aggregate outside outstanding does not require stable outside-person identity.

Observation 172 preserves that result. Multiple exact external endpoints intentionally collapse to the same `OutsideSide` projection.

So the boundary remains query-driven:

```text
aggregate outside outstanding
  -> exact counterparty identity may be unnecessary

same friend across occurrences
per-counterparty outstanding
per-counterparty settlement history
  -> stable external endpoint identity is required
```

The recurring shared-cost case is the first concrete pressure for the second class of query.

## Discharge remains asymmetric

Observation 166 found that source relation meaning may need Effect precision while a later discharge occurrence can remain Event-scoped.

Observation 172 adds another asymmetry:

```text
relation unit
  owns debtor / creditor endpoint identity

later discharge
  references relation unit
  + later Event
```

The discharge therefore does not need a duplicate counterparty field merely to recover who the relation was between.

This also prevents endpoint pairs from becoming accidental relation identity. Two separate claims against the same friend may coexist, so:

```text
(debtor endpoint, creditor endpoint)
!=
relation-unit identity
```

## What this does not earn

Observation 172 does **not** yet earn:

- a production `Party` or `Person` registry;
- a universal counterparty registry for every merchant or institution;
- a production `RelationEndpoint` structure;
- a built-in `Friend`, `Merchant`, `CardIssuer`, or organization role;
- display-name uniqueness;
- endpoint identity derived from display text;
- automatic contact matching;
- endpoint identity as relation-unit identity;
- endpoint duplication on discharge facts;
- burden quantity partition representation;
- positive-relation-to-none retraction authority;
- relation persistence, CLI, TUI, or historical backfill.

## Production threshold

If this observation qualifies, the next production-representation work should still wait.

The remaining questions are at least:

1. exact quantity-slice / partition representation inside one Effect;
2. explicit authority for revising a retained positive relation to none.

Only after those pressures are fixed should LOAM decide whether an opaque external endpoint token and a relation history have earned production Core representation.

Observation 172 is based directly on main `38f769fd94d918f790e0606b7d466d351e4234f0`, after Observations 163–171 were fixed on main.

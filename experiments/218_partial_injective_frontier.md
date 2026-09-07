# Observation 218 — finite partial-injective frontier factorization

Status: **QUALIFIED PRODUCTION SIMPLIFICATION CANDIDATE**

Research starting point: LOAM `4cf5370a54f2e8aebb37b55077cdb1dee8efc822`
Current production main during final qualification: `0cd1ca1e618dac3bd4eac409602d99d6981ef3fb`

## Question

LOAM deliberately keeps the Practical Core small. That is only a win if the
complexity is removed rather than displaced into Application, Persistence,
canonical data, or UI code.

Observation 218 therefore started from repeated production code and asked:

> Can a small mathematical structure remove duplicated runtime machinery while
> leaving independently meaningful household concepts and local laws intact?

## Repeated production structure

Four semantic families independently contained the same replacement-frontier
mechanics:

```text
Event Correction
ActualValidity Correction
Scheduled Replacement
QuantityBasis Correction
```

Their household meanings are different. Their structural relation is the same:

```text
f : I ⇀ I

partial       each source has at most one successor
injective     each successor has at most one predecessor
closed        represented endpoints exist in the retained carrier
acyclic       repeated application never forms a represented cycle

frontier = carrier \ dom(f)
```

For a finite carrier, such a relation is a collection of disjoint finite paths
plus isolated elements.

## Lean qualification

The theorem-heavy probes establish the structural facts without importing a
general graph framework.

`experiments/218_partial_injective_frontier.lean` proves and exercises:

- executable endpoint uniqueness is exactly source and successor `Nodup`;
- reference closure is exactly membership of every represented endpoint;
- successor lookup is injective when successor identities are `Nodup`;
- every defined finite iterate of that lookup is injective;
- an interior repetition can be cancelled back to a return of the original start;
- frontier membership is exactly carrier membership outside the source domain.

`experiments/218_finite_partial_injection_cycle.lean` closes the remaining cycle
question. Production originally used two different algorithms:

```text
Event / Scheduled                 seen-set traversal
ActualValidity / QuantityBasis    start-return traversal
```

They are not path-locally equivalent on arbitrary deterministic graphs. A lasso
can separate them from a tail start. Under the finite partial-injection premises
used by these production families, however, Lean proves the whole-graph admission
result is equivalent.

The proof uses only small finite ingredients:

```text
injective finite iteration
+ cancellation of repeated endpoints
+ Nodup traces
+ subset of the finite source domain
+ List.Nodup.length_le_of_subset
```

No universal graph ontology is introduced.

## Production-shaped extraction

The shared runtime is deliberately internal to Application:

```text
Loam/Application/ReplacementFrontier.lean
```

It owns only structural mechanics:

```text
Edge
endpointUnique
referencesClosed
acyclic
structurallyAdmissible
isSuperseded
frontier
```

Each semantic family adapts its own retained evidence to `Edge` only where useful.
The extraction is intentionally asymmetric rather than forcing every family into
an identical wrapper shape.

### Event Correction

Shared:

- endpoint uniqueness;
- reference closure;
- cycle admission.

Local:

- `EventCorrection` meaning;
- distinction from multi-parent `EventResolution`;
- public Event frontier and quantity projection;
- the small target-membership helper used by its public membership theorem.

### ActualValidity Correction

Shared:

- endpoint uniqueness;
- reference closure;
- cycle admission;
- frontier filtering.

Local:

- replacement preserves Event identity;
- at most one current frontier fact per Event.

### Scheduled Replacement

`ScheduledReplacementMemory` already carries `sourceNodup` and
`replacementNodup` proof fields, so Application does not re-check endpoint
uniqueness merely for uniformity.

Shared:

- reference closure;
- cycle admission.

Local:

- completion / retirement / replacement terminal compatibility;
- current-open Scheduled result vocabulary;
- raw one-to-one memory admission in Core.

### QuantityBasis Correction

Shared:

- endpoint uniqueness;
- reference closure;
- cycle admission;
- frontier filtering.

Local:

- replacement preserves QuantityCoordinate;
- at most one current basis per coordinate.

## Measured production source delta

Against production main `0cd1ca1e618dac3bd4eac409602d99d6981ef3fb`,
counting only the five affected Application source files:

```text
ReplacementFrontier.lean          +54 /  -0
ActualValidityFrontier.lean        +13 / -52
CorrectionFrontier.lean            +12 / -57
QuantityBasisFrontier.lean         +12 / -58
ScheduledInspection.lean           +14 / -28
------------------------------------------------
production-shaped Application     +105 / -195
net                                      -90 lines
```

The two-family probe had already recovered the shared fixed cost at `-31` lines.
Extending the same narrow structure to all four qualified families improves the
reduction to `-90` lines.

This is the desired scaling behavior: the shared abstraction pays rent as reuse
grows instead of creating an expanding adapter framework.

## Practical qualification

At the four-family checkpoint `d3df0c96d28e8bb82336d5465b1ff112d22161af`:

```text
Observation 218                         SUCCESS
  four-family production-shaped build   SUCCESS
  theorem-heavy Lean probes              SUCCESS

Lean Application                        SUCCESS

Practical Scheduled Replacement Frontier SUCCESS
Practical Actual Validity Correction     SUCCESS
Practical Basis Cut                      SUCCESS
Practical Starting Quantity              SUCCESS
Practical Movement                       SUCCESS
```

The Scheduled practical story specifically preserves:

- valid replacement chains;
- replacement-row permutation invariance;
- missing-endpoint fail-closed behavior;
- cycle refusal;
- completion/replacement conflict refusal;
- retirement/replacement conflict refusal;
- duplicate source refusal;
- duplicate successor refusal;
- persistence round-trip stability.

The other practical workflows exercise the affected Event, ActualValidity, and
QuantityBasis paths through their existing production stories.

## Ownership result

Observation 218 does **not** earn a new Practical Core household concept.

The common structure is implementation mathematics beneath several distinct
semantic families, so the best current home is an intentionally small internal
Application module.

That matters for the original complexity-displacement concern:

```text
bad outcome
small Core
+ four independent Application graph engines

qualified outcome
small Core
+ one 54-line structural Application helper
+ four thin semantic uses
```

The Core stays small without making Application carry four copies of the same
algorithm.

## Deliberate boundaries

### OpenRelation revision stays outside

`RelationRevision` permits:

```text
replacement : Option RelationUnitId
```

where `none` represents explicit retraction. Widening the shared abstraction to
capture this would be abstraction-first design, so Observation 218 does not do it.

### No universal household Relation type

Correction, validity correction, Scheduled replacement, and basis correction
remain separate evidence types. Mathematical sameness of their finite path
mechanics does not identify their household meanings.

### No forced frontier adapter

Where a local target-membership helper remains smaller and clearer, it remains
local. The shared module is not allowed to grow merely to eliminate every small
piece of syntactic similarity.

## Side candidates discovered by the audit

Observation 218 also found other possible mathematical simplifications, but they
remain separate work:

- finite partial-map lookup/proof boilerplate appears in several Core memories;
- free-Abelian quantity semantics are already useful as an observational model,
  but retained Movement representation remains observable;
- information-order / lattice models remain promising for open-world answers,
  but evidence uncertainty and value-level uncertainty must not be collapsed;
- observational closure remains useful as an audit criterion rather than a new
  production framework.

None of these are imported into the replacement-frontier extraction.

## Result

The original hypothesis survives in a stronger, concrete form:

> Slightly stronger mathematics can make LOAM materially smaller when it is used
> to recognize a repeated small structure rather than to enlarge the domain
> vocabulary.

Observation 218 has now demonstrated:

```text
one small structural library
+ four distinct semantic families
+ preserved practical behavior
+ 90 fewer production-shaped Application lines
```

The production promotion criterion is therefore satisfied in principle.
Promotion should keep `ReplacementFrontier` internal to Application, retain the
existing family-specific public entry points, and leave the theorem-heavy probes
as research evidence rather than moving their proof machinery into runtime code.

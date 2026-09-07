# Observation 218 follow-up — production decomposition and cycle-detector pressure

Status: **RESEARCH_ONLY / exact-equivalence gate still open**

Baseline production main: `4cf5370a54f2e8aebb37b55077cdb1dee8efc822`

## Candidate structure

A production audit found the same replacement-frontier topology in four semantic
families:

```text
Event Correction
ActualValidity Correction
Scheduled Replacement
QuantityBasis Correction
```

The shared structural candidate remains:

```text
f : I ⇀ I
partial + injective + closed + acyclic
frontier = carrier \\ dom(f)
```

This does not identify the four household meanings. It factors only the finite
replacement topology beneath them.

## Domain decomposition

### Event Correction

```text
shared
  target uniqueness
  replacement uniqueness
  Event-reference closure
  acyclicity
  frontier = Event carrier minus targets

local
  Correction remains distinct from EventResolution
```

### ActualValidity Correction

```text
shared
  target uniqueness
  replacement uniqueness
  validity-fact-reference closure
  acyclicity
  frontier = fact carrier minus targets

local
  replacement preserves EventId
  frontier EventId uniqueness
```

### Scheduled Replacement

```text
shared
  source uniqueness
  replacement uniqueness
  Scheduled-reference closure
  acyclicity
  replacement source leaves current-open frontier

local lifecycle laws
  completion / retirement reference closure
  replacement terminal compatibility
  completion effective only through retained Actual Event
```

Scheduled endpoint uniqueness is already carried by
`ScheduledReplacementMemory`, so its Application adapter should not re-prove a
law already retained by the typed raw memory.

### QuantityBasis Correction

```text
shared
  target uniqueness
  replacement uniqueness
  basis-reference closure
  acyclicity
  frontier = basis carrier minus targets

local
  replacement preserves QuantityCoordinate
  frontier QuantityCoordinate uniqueness
```

## Two production cycle-detector shapes

Event Correction and Scheduled Replacement use a seen-set traversal:

```text
walk successors
remember every visited identity
reject on any revisit
```

ActualValidity and QuantityBasis use a start-return traversal:

```text
for every represented source s:
  walk successors
  reject when the path returns to s
```

These are not path-locally equivalent for arbitrary deterministic graphs.

The witness

```text
0 -> 1 -> 2 -> 1
```

is rejected by the seen-set walk from `0`, while the start-return walk from `0`
does not return to `0`.

However the witness is **not a partial injection**:

```text
0 -> 1
2 -> 1
```

share successor `1`.

All four production families already reject this shape through replacement
uniqueness. Therefore the remaining production bridge may be proved under the
actually admitted endpoint-unique shape rather than for arbitrary edge lists.

## Universal Lean results now proved

The generic Observation 218 probe establishes the following for arbitrary
identity types with decidable equality.

### Endpoint specification

```text
endpointUnique edges = true
iff
sources(edges).Nodup AND successors(edges).Nodup
```

### Reference-closure specification

```text
referencesClosed carrier edges = true
iff
for every edge e:
  e.superseded ∈ carrier
  e.successor  ∈ carrier
```

### One-step successor injectivity

```text
successors(edges).Nodup
nextSuccessor? edges left  = some endpoint
nextSuccessor? edges right = some endpoint
-------------------------------------------
left = right
```

### Finite-iterate injectivity

For every finite `steps`:

```text
successors(edges).Nodup
advance? edges steps left  = some endpoint
advance? edges steps right = some endpoint
-------------------------------------------
left = right
```

### No external tail into a cycle

The cancellation theorem is proved:

```text
advance? edges prefixSteps start = some repeated
advance? edges (period + prefixSteps) start = some repeated
-----------------------------------------------------------
advance? edges period start = some start
```

under successor endpoint `Nodup`.

This formalizes the partial-injection fact that a distinct external tail cannot
feed an existing cycle without creating a shared successor.

### Start-return factors through cycle existence

The production-style start-return detector has now been factored through a
separate whole-graph predicate:

```text
hasCycleByReturn edges
```

where a represented cycle exists exactly when some represented source returns
to itself within the finite edge-count bound.

Lean proves:

```text
acyclicByStartReturn edges = !hasCycleByReturn edges
```

for arbitrary finite deterministic successor lookup, with no endpoint-uniqueness
premise required for this factorization.

This is important because the two production algorithms no longer need to be
compared directly. The remaining task is to connect the seen-set detector to the
same cycle-existence specification on the admitted production shape.

### Frontier specification

```text
id ∈ frontier carrier edges
iff
id ∈ carrier AND
no represented edge has superseded = id
```

So the generic frontier is exactly `carrier \\ dom(f)` extensionally.

## Bounded witnesses retained

The executable witnesses check:

```text
ordinary chain               accepted by both cycle detectors
simple cycle                 rejected by both
lasso                         path-local algorithms differ
lasso                         rejected by endpoint uniqueness
lasso                         rejected by both whole-graph checks
branching source              rejected
shared successor / merge     rejected
open reference                rejected
```

## Minimal runtime extraction probe

The research now contains a second executable probe:

```text
experiments/218_minimal_frontier_kernel.lean
```

It deliberately strips all proof lemmas, bounded witnesses, explanatory helper
machinery, and production-specific semantic laws. It keeps only:

```text
Edge
endpoint uniqueness
reference closure
successor lookup
bounded return / cycle-free check
structural admission
replacement-domain test
frontier projection
four thin production-shape adapters
```

The complete file is **81 lines**, including imports, namespace boilerplate and
all four adapters.

Its declaration surface is approximately:

```text
9 shared structural declarations
4 adapters
```

The dedicated Observation 218 CI compiles both the theorem-heavy research probe
and this minimal kernel successfully on Lean 4.33.1.

This does not yet prove that production would shrink by exactly 81 lines. Typed
carrier lookup, domain-local preservation laws, and existing public result APIs
must remain. But it materially changes the complexity assessment: the candidate
runtime abstraction is demonstrably small rather than merely mathematically
attractive.

## What remains for seen-set equivalence

The remaining hard bridge is the Event / Scheduled seen-set implementation.
Under endpoint uniqueness, the likely finite-list proof is:

1. every nonterminal visited identity is a represented source;
2. successor injectivity prevents an external tail from entering a cycle;
3. source `Nodup` prevents more than `edges.length` distinct nonterminal source
   visits;
4. therefore seen-set fuel exhaustion cannot occur without a repeat;
5. a repeat corresponds to a represented cycle, connecting the detector to
   `hasCycleByReturn`.

Lean's existing `List.Nodup.length_le_of_subset` is sufficient for the finite
cardinality step, so no general graph-theory dependency appears necessary yet.

If this bridge becomes large despite the small runtime kernel, that proof cost is
still evidence against production promotion. Mathematical sameness alone is not
enough.

## Build-topology side observation

Adding the fourth QuantityBasis adapter initially failed because its imported
module had not been built on the existing probe path. The adapter and algebra
were not at fault. Explicitly building the imported frontier-family modules made
the four-adapter probe pass.

This is relevant to the wider simplification study: semantic decomposition can
leave hidden complexity in module/build topology. Extraction cost therefore
includes dependency topology, not only source-line count.

## Current complexity judgement

Observation 218 has now crossed one important threshold:

```text
mathematical commonality      established strongly
minimal runtime shape         small and executable (81 lines)
start-return specification    universally factored
frontier specification        universally proved
seen-set exact bridge         still open
production deletion delta     not yet measured by an actual replacement patch
```

So the current judgement moves from merely `promising` to
**credible production simplification candidate**, but not yet `promote`.

## Production gate

Still **do not promote** Observation 218.

The remaining gate is:

1. connect the seen-set detector to the same cycle specification on the admitted
   endpoint-unique shape;
2. reconstruct all four production admissions as shared structural mechanics plus
   their local semantic laws;
3. make a no-merge production replacement patch and measure actual deletions,
   dependency fanout, and adapter burden;
4. promote only if that patch is materially smaller and clearer.

The desired result remains:

```text
one tiny structural library
+
four thin semantic adapters
```

not:

```text
one universal framework
+
a forest of proof and adapter obligations
```

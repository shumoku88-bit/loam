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
uniqueness. Therefore the correct equivalence target is conditional:

```text
endpointUnique edges = true ->
  acyclic edges = acyclicByStartReturn edges
```

not unconditional equivalence on arbitrary directed graphs.

## Universal Lean results now proved

The generic Observation 218 probe now establishes the following for arbitrary
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

So represented replacement lookup cannot merge two sources.

### Finite-iterate injectivity

For every finite `steps`:

```text
successors(edges).Nodup
advance? edges steps left  = some endpoint
advance? edges steps right = some endpoint
-------------------------------------------
left = right
```

Injectivity survives arbitrary defined finite iteration.

### No external tail into a cycle

The crucial cancellation theorem is now proved:

```text
advance? edges prefixSteps start = some repeated
advance? edges (period + prefixSteps) start = some repeated
-----------------------------------------------------------
advance? edges period start = some start
```

under successor endpoint `Nodup`.

This formalizes the key partial-injection fact behind the cycle-detector
comparison: if a walk repeats an interior point, injectivity forces the original
start to participate in the same period. A distinct external tail cannot feed an
existing cycle without creating a shared successor.

### Frontier specification

```text
id ∈ frontier carrier edges
iff
id ∈ carrier AND
no represented edge has superseded = id
```

So the generic frontier is exactly `carrier \\ dom(f)` extensionally, not merely
by examples.

## Bounded witnesses retained

The executable witnesses still check:

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

## What remains for cycle equivalence

The difficult conceptual part of the lasso problem is now gone. The remaining
work is finite rather than graph-semantic:

```text
an acyclic partial injection with n represented sources
cannot follow n + 1 source steps without terminating
```

Equivalently, a fuel exhaustion in the seen-set detector must imply a repeated
represented source; under the proved cancellation theorem that repetition then
forces a start return.

A likely small proof route is:

1. expose the finite walk prefix;
2. show every nonterminal visited identity belongs to the `Nodup` source list;
3. show a no-start-return prefix is `Nodup` using finite-iterate injectivity and
   the cancellation theorem;
4. use the list-length bound to rule out `edges.length + 1` distinct represented
   sources;
5. conclude the conditional detector equivalence.

This route deliberately avoids importing a general graph theory framework.
If the finite-list proof becomes large, that itself counts against production
extraction.

## Build-topology side observation

Adding the fourth QuantityBasis adapter initially failed because its imported
module had not been built on the existing probe path. The adapter and algebra
were not at fault. Explicitly building the imported frontier-family modules made
the four-adapter probe pass.

This is relevant to the wider simplification study: semantic decomposition can
leave hidden complexity in module/build topology. Extraction cost therefore
includes dependency topology, not only source-line count.

## Complexity checkpoint

The current research Lean probe is intentionally larger than a production
candidate because it contains:

```text
candidate runtime definitions
four production-shape adapters
bounded positive/negative witnesses
universal equivalence lemmas
research-only explanatory structure
```

At the current checkpoint the file is about 385 lines. That number must **not**
be presented as the size of a future shared library.

The meaningful comparison happens only after the conditional cycle theorem is
finished:

```text
strip bounded witnesses
strip research adapters not needed at runtime
retain the smallest generic runtime + useful proof surface
compare against local machinery actually deleted from four production families
```

If that extracted form is not materially smaller and clearer, keep the local
duplication even though the mathematical structure is shared.

## Production gate

Still **do not promote** Observation 218.

The research has moved from resemblance to several universal laws, but the exact
cycle-detector bridge remains open and the four production admissions have not
yet been reconstructed extensionally from the generic structure plus local laws.

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

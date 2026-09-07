# Observation 218 follow-up — production decomposition and cycle-detector pressure

Status: **RESEARCH_ONLY / exact-equivalence gate still open**

Baseline production main: `4cf5370a54f2e8aebb37b55077cdb1dee8efc822`

## Fourth direct production instance

The first Observation 218 pass named three production families. A second audit
found the same replacement-frontier mechanics in a fourth family:

```text
Loam/Application/QuantityBasisFrontier.lean
```

It independently checks:

```text
unique target
unique replacement
closed references
acyclic replacement paths
frontier = retained bases minus targeted bases
```

and then adds two QuantityBasis-specific laws:

```text
replacement preserves QuantityCoordinate
frontier has at most one basis per QuantityCoordinate
```

This is the same separation already visible in ActualValidity:

```text
shared replacement topology
+
local semantic preservation law
+
local frontier uniqueness law
```

The candidate is therefore repeated in **four** production families, not three.

## Production decomposition matrix

The current audit can be written more sharply as follows.

### Event Correction

```text
shared graph mechanics
  target uniqueness
  replacement uniqueness
  Event-reference closure
  acyclicity
  frontier = Event carrier minus correction targets

local meaning
  Correction remains distinct from EventResolution
```

No extra same-coordinate or same-parent law is needed once the relation has
passed the current Correction admission shape.

### ActualValidity Correction

```text
shared graph mechanics
  target uniqueness
  replacement uniqueness
  validity-fact-reference closure
  acyclicity
  frontier = fact carrier minus correction targets

local laws
  replacement preserves EventId
  frontier EventId uniqueness
```

### Scheduled Replacement

```text
shared graph mechanics
  source uniqueness              already retained by ScheduledReplacementMemory
  replacement uniqueness         already retained by ScheduledReplacementMemory
  Scheduled-reference closure
  acyclicity
  replacement source leaves the current-open frontier

local lifecycle laws
  completion references known Scheduled identity
  retirement references known Scheduled identity
  replacement is terminal-compatible with completion / retirement
  completion becomes effective only through a retained Actual Event
```

Scheduled therefore reuses less of the generic *admission* check at Application
level because endpoint uniqueness is already proved by its raw memory type, but
it still has the same mathematical replacement topology.

### QuantityBasis Correction

```text
shared graph mechanics
  target uniqueness
  replacement uniqueness
  basis-reference closure
  acyclicity
  frontier = basis carrier minus correction targets

local laws
  replacement preserves QuantityCoordinate
  frontier QuantityCoordinate uniqueness
```

## Two production cycle-detector shapes

The audit found two independently implemented algorithms for the same intended
whole-graph property.

### Seen-set traversal

Used by Event Correction and Scheduled Replacement.

Conceptually:

```text
walk successor edges
remember every visited identity
reject on any revisit
```

### Start-return traversal

Used by ActualValidity and QuantityBasis.

Conceptually:

```text
for every represented source s:
  walk successor edges
  reject if the path returns to s
```

This smaller traversal does not remember every intermediate identity.

## Important lasso witness

The updated Lean probe adds:

```text
0 -> 1 -> 2 -> 1
```

When the path starts at `0`:

```text
seen-set traversal       rejects
start-return from 0      does not return to 0 within the bounded walk
```

So the two *path-local* predicates are not equivalent.

But the production-style start-return algorithm runs once from every represented
edge source. It therefore also starts at `1`, which is itself on the cycle, and
rejects the graph.

The Lean witness consequently confirms:

```text
seen-set whole-graph check      rejects the lasso
start-return whole-graph check  rejects the lasso
```

This is an important qualification. The candidate shared concept is a
**whole-graph acyclicity property**, not either traversal implementation.

## What is and is not proved now

Observation 218 currently proves executable bounded witnesses for:

```text
ordinary chain               accepted by both cycle-detector shapes
simple cycle                 rejected by both
lasso                         rejected by both whole-graph checks
branching source              rejected by endpoint uniqueness
shared replacement / merge   rejected by injectivity
open endpoint                 rejected by closure
```

It does **not yet prove** a universal Lean theorem that the two whole-graph cycle
algorithms are extensionally equivalent for every finite represented edge list.

That universal theorem is now a concrete extraction gate.

## Exact-equivalence proof ladder

Do not attempt one giant theorem connecting all four Application modules at once.
The smaller proof order is:

1. **endpoint uniqueness**
   - show the recursive production checks and `Nodup` endpoint formulation are
     extensionally equivalent;

2. **whole-graph acyclicity**
   - prove seen-set and start-return whole-graph checks express the same finite
     deterministic-successor cycle-free property;

3. **reference closure**
   - relate carrier membership to each typed Memory lookup without replacing the
     typed Memory representation;

4. **frontier membership**
   - prove that generic frontier membership is exactly retained carrier
     membership plus absence from the replacement domain;

5. **domain adapters**
   - reconstruct each production admission as shared structural mechanics plus
     its local laws;

6. **complexity audit**
   - count generic definitions / proofs added versus duplicated local machinery
     actually deleted before any production promotion.

## Current production recommendation

Still **do not promote** the abstraction.

The evidence is stronger than the first field trial because four production
families now fit the same decomposition, and the apparently different cycle
algorithms have a precise common intended property.

But promotion is earned only if the universal equivalence proofs remain small.
If proving the generic abstraction requires a large graph-theory framework that
is harder to understand than the four local copies, the correct result is to
keep the duplication.

The desired win is:

```text
one tiny structural theorem library
+
four thin semantic adapters
```

not:

```text
one impressive universal framework
+
a forest of adapter obligations
```

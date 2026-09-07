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

## Important lasso witness — and why it is outside the candidate algebra

The updated Lean probe includes:

```text
0 -> 1 -> 2 -> 1
```

When the path starts at `0`:

```text
seen-set traversal       rejects
start-return from 0      does not return to 0 within the bounded walk
```

So the two *path-local* predicates are not equivalent on an arbitrary finite
deterministic-successor graph.

However this lasso has incoming edges

```text
0 -> 1
2 -> 1
```

and therefore uses replacement identity `1` twice. It violates the
`uniqueReplacements` / `replacementNodup` premise already required by all four
production families before the candidate partial-injection algebra is admitted.

This materially narrows the proof obligation.

For a partial injection, an external tail cannot enter an existing cycle without
creating a shared successor at the entry point. Therefore a repeated node on a
walk should force the original source itself to lie on that cycle.

The generic Lean probe now begins formalizing exactly this fact by proving the
local injectivity lemma:

```text
successor endpoints are Nodup
nextSuccessor? left  = some successor
nextSuccessor? right = some successor
--------------------------------------
left = right
```

If that proof remains small, the cycle-equivalence theorem should be stated under
endpoint uniqueness rather than for arbitrary edge lists.

## What is and is not proved now

Observation 218 has executable bounded witnesses for:

```text
ordinary chain               accepted by both cycle-detector shapes
simple cycle                 rejected by both
lasso                         rejected by both whole-graph checks
lasso                         rejected by endpoint uniqueness itself
branching source              rejected by endpoint uniqueness
shared replacement / merge   rejected by injectivity
open endpoint                 rejected by closure
```

It also attempts the first universal structural lemma needed by the equivalence
proof: successor lookup is injective when represented replacement identities are
Nodup.

It does **not yet prove** the final universal theorem

```text
endpointUnique edges = true ->
  acyclic edges = acyclicByStartReturn edges
```

for every finite represented edge list.

That conditional theorem is now the concrete extraction gate. This is strictly
smaller than the previous unconditional target.

## Exact-equivalence proof ladder

Do not attempt one giant theorem connecting all four Application modules at once.
The smaller proof order is:

1. **endpoint uniqueness**
   - show the recursive production checks and `Nodup` endpoint formulation are
     extensionally equivalent;
   - prove successor lookup injectivity from replacement `Nodup`;

2. **partial-injection cycle shape**
   - show that a walk in a finite partial injection cannot enter a cycle from a
     distinct external tail, because doing so would violate successor injectivity;

3. **conditional cycle-detector equivalence**
   - prove seen-set and start-return traversal agree under endpoint uniqueness;

4. **reference closure**
   - relate carrier membership to each typed Memory lookup without replacing the
     typed Memory representation;

5. **frontier membership**
   - prove that generic frontier membership is exactly retained carrier
     membership plus absence from the replacement domain;

6. **domain adapters**
   - reconstruct each production admission as shared structural mechanics plus
     its local laws;

7. **complexity audit**
   - count generic definitions / proofs added versus duplicated local machinery
     actually deleted before any production promotion.

## Build-topology side observation

Adding the fourth QuantityBasis adapter initially failed the dedicated probe even
though the adapter itself was structurally ordinary. The cause was not a semantic
or type mismatch: `QuantityBasisCorrectionMemory.olean` had not been built on the
probe's existing path. Explicitly building the imported frontier-family modules
made the four-adapter probe pass.

That is a useful secondary observation for the larger simplification study:
semantic decomposition can leave complexity in the build/module graph even when
Core concepts remain small. Production extraction should therefore measure not
only source duplication but also dependency and build-topology cost.

## Current production recommendation

Still **do not promote** the abstraction.

The evidence is stronger than the first field trial because four production
families now fit the same decomposition, and the apparent cycle-algorithm gap is
smaller inside the actually admitted partial-injection class than it first
appeared.

But promotion is earned only if the universal conditional proofs remain small.
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

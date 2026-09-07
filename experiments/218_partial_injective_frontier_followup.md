# Observation 218 follow-up — production decomposition and cycle-detector pressure

Status: **RESEARCH_ONLY / no-merge production-shaped probe / exact-equivalence gate still open**

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

## Universal Lean results now proved

The generic Observation 218 probe establishes the following for arbitrary
identity types with decidable equality.

```text
endpointUnique edges = true
iff
sources(edges).Nodup AND successors(edges).Nodup
```

```text
referencesClosed carrier edges = true
iff
every represented endpoint belongs to carrier
```

Successor lookup is injective when successor identities are `Nodup`, and every
defined finite iterate remains injective. The cancellation theorem then shows
that an external tail cannot enter a cycle without violating successor
injectivity.

Frontier membership is proved extensionally:

```text
id ∈ frontier carrier edges
iff
id ∈ carrier AND id ∉ dom(f)
```

## Cycle detector factorization

Production has two cycle-detector implementations:

```text
Event / Scheduled                 seen-set walk
ActualValidity / QuantityBasis    start-return from every represented source
```

They are not path-locally equivalent on arbitrary deterministic graphs. The
lasso

```text
0 -> 1 -> 2 -> 1
```

separates the path-local checks from source `0`, but also violates replacement
injectivity because successor `1` has two incoming edges.

The start-return whole-graph implementation has now been factored through a
third semantic predicate:

```text
hasCycleByReturn edges
```

Lean proves universally:

```text
acyclicByStartReturn edges = !hasCycleByReturn edges
```

The remaining difficult bridge is therefore only to connect the seen-set
implementation to the same cycle-existence specification on the admitted
endpoint-unique shape.

## Minimal runtime extraction probe

`experiments/218_minimal_frontier_kernel.lean` strips proofs and witnesses and
keeps only the structural runtime plus four adapters.

The complete executable probe is **81 lines**, including imports, namespace
boilerplate and all four adapters. Dedicated Observation 218 CI compiles both
this minimal probe and the theorem-heavy probe on Lean 4.33.1.

## Two-family production-shaped probe

The research branch now goes one step further. It contains a deliberately
**no-merge production-shaped patch**:

```text
Loam/Application/ReplacementFrontier.lean
Loam/Application/ActualValidityFrontier.lean
Loam/Application/QuantityBasisFrontier.lean
```

This changes Application files on the research branch only so that actual source
deletion and adapter burden can be measured. Production `main` remains unchanged.

Only structural mechanics moved into the shared module:

```text
Edge
endpoint uniqueness
reference closure
bounded cycle-free check
supersession-domain membership
frontier filtering
```

The following remain local:

```text
ActualValidity: preserves EventId, frontier EventId uniqueness
QuantityBasis:  preserves QuantityCoordinate, frontier coordinate uniqueness
```

Public Application entry-point names are retained.

### Measured source delta

Compared with the immediately preceding research checkpoint:

```text
ReplacementFrontier.lean          +54
ActualValidityFrontier.lean        +13 / -52
QuantityBasisFrontier.lean         +12 / -58
---------------------------------------------
Application source total           +79 / -110
net                                 -31 lines
```

So the shared runtime's fixed cost is already recovered by only the two
start-return families. This is a materially stronger result than the 81-line
standalone probe: the candidate is source-negative against existing production
machinery before Event Correction or Scheduled Replacement are migrated.

The two adapters also preserve existing public function names; the deleted
surface is predominantly private structural machinery.

This line count is evidence, not the final promotion decision. Exact behavioral
CI and the seen-set bridge still matter more than raw LOC.

## Build and compatibility gates

The dedicated Observation 218 workflow now builds the two modified Application
modules directly before compiling both research probes.

The especially relevant existing production checks are:

```text
Lean Application
Practical Actual Validity Correction
```

A production-shaped promotion is not qualified until those and the dedicated
exact-head check pass on the candidate head.

## Information-order side observation

A parallel read-only audit suggests a separate future lattice/order experiment,
but also supplies an important counterexample against premature unification.

```text
RelationSourceState.unknown
Scheduled day evidence .unknown
```

are evidence-level open-world absence states, while

```text
AttentionDue.dueUndetermined
```

is a value-level statement that due meaning exists but its time is
undetermined.

Therefore a future information-order model must separate at least:

```text
knowledge/evidence axis
value-semantic axis
```

rather than collapsing every constructor named "unknown" into one lattice
point.

## Production gate

Still **do not merge/promote** Observation 218.

Current status:

```text
mathematical commonality             strongly established
minimal runtime shape                small and executable
start-return cycle specification     universally factored
two-family real source delta         -31 Application lines
public entry-point churn             none in the two-family probe
seen-set exact bridge                still open
candidate exact-head production CI   must finish
```

Next gate:

1. obtain green exact-head CI for the production-shaped two-family patch;
2. connect seen-set to the same cycle specification without importing a general
   graph framework;
3. only then prototype Event / Scheduled adapters and measure the four-family
   deletion delta;
4. promote only if the final patch stays materially smaller, clearer, and has no
   new semantic owner outside the domain-local laws.

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

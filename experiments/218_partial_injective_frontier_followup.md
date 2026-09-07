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

The shared structural candidate is:

```text
f : I ⇀ I
partial + injective + closed + acyclic
frontier = carrier \\ dom(f)
```

This does not identify the four household meanings. It factors only the finite
replacement topology beneath them.

## Universal Lean results proved

The theorem-heavy Observation 218 probe establishes, for arbitrary identity
types with decidable equality:

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
defined finite iterate remains injective. A cancellation theorem shows that an
external tail cannot enter a cycle under successor injectivity without creating
a shared successor.

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

The start-return implementation has been factored through a third semantic
predicate:

```text
hasCycleByReturn edges
```

Lean proves universally:

```text
acyclicByStartReturn edges = !hasCycleByReturn edges
```

The two path-local algorithms are not equivalent on arbitrary deterministic
graphs. A lasso can make a tail-started start-return walk miss the interior
cycle. But whole-graph start-return examines every represented source, including
a source on the cycle itself. A small exhaustive finite check also found no
whole-graph mismatch. The remaining Lean task is therefore to connect the
seen-set whole-graph detector to `hasCycleByReturn`; this may not need endpoint
injectivity at all.

## Minimal runtime extraction probe

`experiments/218_minimal_frontier_kernel.lean` strips proofs and witnesses and
keeps only the structural runtime plus four adapters.

The complete executable probe is **81 lines**, including imports, namespace
boilerplate and all four adapters.

## Two-family production-shaped probe

The research branch contains a deliberately **no-merge production-shaped patch**:

```text
Loam/Application/ReplacementFrontier.lean
Loam/Application/ActualValidityFrontier.lean
Loam/Application/QuantityBasisFrontier.lean
```

Production `main` remains unchanged.

Only structural mechanics moved into the shared module:

```text
Edge
endpoint uniqueness
reference closure
bounded cycle-free check
supersession-domain membership
frontier filtering
```

Domain laws remain local:

```text
ActualValidity: preserves EventId, frontier EventId uniqueness
QuantityBasis:  preserves QuantityCoordinate, frontier coordinate uniqueness
```

Existing public Application entry-point names are retained.

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

Thus the shared runtime fixed cost is already recovered by only the two
start-return families.

### Exact-head CI result

At research head `b83ce30545b18a5ad8edede6f52a229810623974`:

```text
Observation 218                    SUCCESS
  build modified ActualValidity    SUCCESS
  build modified QuantityBasis     SUCCESS
  theorem-heavy Lean probe         SUCCESS
  81-line minimal kernel           SUCCESS

Lean Application                   SUCCESS
  build application + umbrella     SUCCESS

Practical Actual Validity Correction  SUCCESS
  date-correction frontier            SUCCESS
  record / correct / re-correct       SUCCESS
  first date on older undated record  SUCCESS
```

This removes the main immediate concern that the source reduction merely moved
complexity into broken module or adapter boundaries.

## Domain decomposition still preserved

### ActualValidity

```text
shared
  target uniqueness
  replacement uniqueness
  reference closure
  acyclicity
  frontier by replacement domain

local
  same-Event replacement
  one frontier fact per Event
```

### QuantityBasis

```text
shared
  target uniqueness
  replacement uniqueness
  reference closure
  acyclicity
  frontier by replacement domain

local
  same-coordinate replacement
  one frontier basis per QuantityCoordinate
```

### Event Correction and Scheduled Replacement

They remain untouched by the production-shaped probe until the seen-set bridge
is justified. Mathematical resemblance alone is not used as permission to
replace their working algorithm.

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

A future information-order model must therefore separate at least:

```text
knowledge/evidence axis
value-semantic axis
```

rather than collapsing every constructor named `unknown` into one lattice point.

## Current judgement

Observation 218 has crossed a meaningful threshold:

```text
mathematical commonality             strongly established
minimal runtime shape                small and executable
start-return cycle specification     universally factored
two-family real source delta         -31 Application lines
public entry-point churn             none in the two-family probe
dedicated exact-head CI              green
Lean Application                     green
ActualValidity practical behavior    green
seen-set exact bridge                still open
```

This is now a **credible production simplification**, not merely a promising
abstraction. It is still not a merge recommendation because Event/Scheduled and
the final placement/ownership question remain open.

## Next gate

1. prove the seen-set whole-graph detector against the same cycle-existence
   specification without importing a general graph framework;
2. if that proof remains small, prototype Event / Scheduled adapters;
3. measure the four-family deletion delta and dependency fanout;
4. decide whether the shared helper belongs as a deliberately internal
   Application structural module rather than a new Practical Core concept;
5. promote only if the final patch stays materially smaller and clearer.

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

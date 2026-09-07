# Observation 218 — finite partial-injective frontier factorization

Status: **FIELD TRIAL / RESEARCH_ONLY**

Baseline: LOAM `4cf5370a54f2e8aebb37b55077cdb1dee8efc822`

## Trigger

LOAM deliberately keeps the Practical Core small, but that is useful only if
complexity is actually removed rather than displaced into Application,
Persistence, canonical authority, or UI code.

A concrete audit of current production code found the same structural frontier
problem independently implemented in several semantic families.

The question is:

> Can one piece of mathematics remove repeated structural machinery while
> leaving each domain's independently meaningful evidence and local laws intact?

This observation deliberately starts from repeated production code rather than
from a desired abstraction.

## Production duplication found

### Event Correction

`Loam/Application/CorrectionFrontier.lean` checks:

- unique correction targets;
- unique correction replacements;
- closed Event references;
- acyclic replacement paths;
- then removes targeted Events from the current frontier.

Its own documentation already identifies the admitted shape as a collection of
**disjoint finite paths**.

### Actual-validity Correction

`Loam/Application/ActualValidityFrontier.lean` independently checks:

- unique correction targets;
- unique correction replacements;
- closed fact references;
- acyclic replacement paths;
- then removes targeted validity facts from the current frontier.

It additionally requires same-Event replacement and one current validity fact
per Event. Those are domain laws, not graph laws.

### Scheduled Replacement

`Loam/Core/ScheduledReplacement.lean` already retains one-to-one replacement
endpoints. `Loam/Application/ScheduledInspection.lean` independently adds:

- closed Scheduled references;
- acyclic replacement paths;
- then removes replacement sources from the current-open frontier.

It additionally checks completion / retirement compatibility. Again, that is a
Scheduled lifecycle law rather than a graph law.

## Small mathematical factor

For a finite identity carrier `I`, the shared structural object is:

```text
f : I ⇀ I
```

with the following restrictions:

```text
partial function      each superseded identity has at most one successor
injective             each successor has at most one predecessor
closed                every endpoint belongs to the retained carrier
acyclic               repeated application of f never returns to a prior identity
```

A finite acyclic partial injection decomposes into disjoint finite directed
paths plus isolated carrier elements.

The structural current frontier is simply:

```text
carrier \ dom(f)
```

That is exactly the operation currently spelled separately as "filter out
correction targets" or "filter out replacement sources".

The companion Lean probe `218_partial_injective_frontier.lean` implements only
this factor and provides adapters for:

```text
EventCorrection       target -> replacement
ActualValidityCorrection
                      target -> replacement
ScheduledReplacement  source -> replacement
```

Bounded witnesses demonstrate admission of a chain and refusal of branching,
merging, cycles, and open references.

## Why this is a better abstraction candidate than a generic domain relation

The proposed factor does **not** say that Correction, Actual-validity correction,
and Scheduled replacement have the same household meaning.

It factors only the graph mechanics they currently duplicate:

```text
endpoint uniqueness
reference closure
acyclic traversal
frontier membership
```

The semantic wrappers remain distinct.

This is important because the following laws remain local:

```text
Event Correction
  Event endpoints must exist
  Resolution remains distinct from merge-shaped Correction

Actual-validity Correction
  replacement preserves Event identity
  frontier has at most one current validity fact per Event

Scheduled Replacement
  completion / retirement / replacement terminal evidence must be compatible
```

So a successful production extraction would reduce machinery without creating a
universal household `Relation` ontology.

## Important near-counterexample: OpenRelation revision

`OpenRelationFrontier` looks similar but is not immediately the same structure.
A `RelationRevision` can contain:

```text
replacement : Option RelationUnitId
```

where `none` is explicit retraction rather than an ordinary successor.

Therefore Observation 218 does **not** classify OpenRelation revision as a direct
instance of the partial-injection factor. It may fit a later extension such as a
partial injection into `Option I`, but introducing that extension now would be
abstraction-first design.

This near-counterexample is useful: the candidate factor has a visible boundary.

## Other mathematical simplification candidates found by the same audit

### 1. Finite partial maps — strong boilerplate candidate

Several Core families independently have the shape:

```text
K ⇀ V
```

represented as a list with a key `Nodup` proof and order-independent lookup:

- `ActualValidityMemory`: `EventId ⇀ Time`
- `CapacityEffectiveMemory`: `CapacityMovementId ⇀ Time`
- `EventDescriptionMemory`: `EventId ⇀ String`
- `AccountingRoleMap`: `LocusId ⇀ AccountingRole`

There is real proof / lookup duplication here.

However, this probably reduces **implementation and proof machinery**, not the
number of household semantic concepts. A future extraction should therefore be
judged as a small reusable library structure, not promoted as a new domain
primitive.

### 2. Free-Abelian / finitely-supported quantity semantics — already observed

This is not new work. Observation 159 already showed that finite
`MovementChange` presentations project to an integer-valued coordinate vector,
with `BalancedMovement` living at the zero-augmentation boundary.

Observations 179, 180, and 191 then connected that projection to preservation
polarity, observational closure, and quotient factorization.

So the right next question is not "can LOAM use free Abelian groups?". It
already can, at the observational boundary.

The production audit also found current code that deliberately observes
`BalancedMovement.changes` representation directly in persistence and interface
paths. Therefore quotient-collapsing the retained list would currently erase an
observable representation distinction. The earlier stop condition remains
correct.

### 3. Information order / lattice — promising, not yet qualified

Two current answer families expose a striking common shape:

```text
OpenRelation source
  unknown
  known-none
  known-positive

Scheduled exact day
  unknown
  due
```

With a future qualified completeness witness, Scheduled could also gain a
truthful negative answer analogous to relation `known-none`.

This suggests a possible information order in which adding evidence refines an
answer rather than mutating domain state.

But the production result types also mix structural refusal states with semantic
answers, and positive evidence may contain multiple retained witnesses. A clean
lattice cannot be claimed until those two axes are separated.

A later bounded observation should test something closer to:

```text
semantic evidence state
  ×
structural admission/refusal
```

rather than turning every current result constructor into a lattice element.

### 4. Galois / observational closure — already available as an audit tool

Observations 179, 180, and 191 give a useful criterion for this simplification
project:

> If a proposed retained field or Application answer is already forced by an
> existing selected observation family, it may be derived rather than retained.

Conversely, if a proposed normalization changes an observation outside the
selected quotient, it is not semantics-preserving for that surface.

This is more immediately useful than adding a generic production Galois
framework.

## Complexity-conservation criterion

A mathematical extraction is useful only when it decreases total conceptual
machinery across the whole system.

For each candidate extraction record:

```text
production families reusing it
new generic concepts introduced
local laws deleted
local laws still required
persistence shapes deleted or unchanged
canonical authorities deleted or unchanged
new proof obligations
new illegal states made representable
```

A smaller Core file with more Application/Data wiring is not a win.

Likewise, fewer source lines with a harder universal framework is not a win.

## Current ranking

```text
HIGH
  finite partial-injective frontier
    repeated three times in production
    clear mathematical boundary
    local semantic laws remain visible

MEDIUM-HIGH
  finite partial-map proof/lookup library
    repeated at least four times
    likely boilerplate reduction
    does not itself reduce semantic fact families

OBSERVED / KEEP AS RESEARCH TOOL
  free-Abelian projection
  preservation polarity
  observational closure
  quotient factorization

PROMISING / NEEDS COUNTEREXAMPLE SEARCH
  information-order / semilattice view of open-world answers

LOW CURRENT VALUE
  generic category-theory framework
  generic universal relation ontology
```

## Result

The initial hypothesis survives in a qualified form:

> More advanced mathematics can simplify LOAM, but the strongest current win is
> not importing a larger mathematical vocabulary into the domain. It is
> recognizing repeated small structures and factoring only their mechanics.

The first concrete candidate is a finite acyclic partial injection whose frontier
is the complement of its domain.

That candidate is narrow enough to explain three independent production
implementations without claiming their household meanings are identical.

## Production gate

Do **not** move Observation 218 into `Loam/Core` or `Loam/Application` from this
field trial alone.

Before extraction, test at least:

1. exact equivalence with Event Correction frontier behavior;
2. exact equivalence with ActualValidity structural checks before its local
   same-Event/current-date laws;
3. exact equivalence with Scheduled replacement graph checks before lifecycle
   compatibility;
4. whether the generic code and proofs are materially smaller / clearer than the
   three local copies;
5. whether OpenRelation revision remains safely outside rather than distorting
   the abstraction to include it.

If those checks fail, keep the duplicated local implementations. Mathematical
elegance alone is not sufficient.

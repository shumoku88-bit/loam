# LOAM household minimum vocabulary checkpoint

Status: implementation-facing reduction after qualified Observations 105–111 and Practical Slice A (A1 + A2) integration

This is not a final schema and not a list of HRA / h-kernel types to recreate.

It asks a smaller question:

> After the whole-household capability survey and the cross-capability Alloy observations, what information currently appears independently observable, what mechanics can be shared underneath it, and what familiar household nouns can remain projections?

The checkpoint follows one rule exposed repeatedly by Observations 105–111:

> Share mechanics where equal structure is sufficient. Keep semantic partitions where erasing them changes household answers.

## 1. Independently observable semantic families

### Actual

Actual records what changed.

LOAM owns this practically as neutral Event / Effect evidence:

```text
Event identity
  Effects
    Locus
    Measure
    exact signed Quantity
```

Balanced Movement is the human-facing recording entrance, not a new Core transaction kind. Multi-Measure Event capability is preserved; generic Events are not forced to be globally balanced.

Observations 092–094 did not earn a built-in production Event temporal field, while Observation 111 earned an occurrence-valid coordinate for historical Consumption routing. Separate typed evidence (`ActualValidity Time`) links `EventId` to a valid coordinate without adding a day field to `Event`.

`spend`, `income`, and `transfer` remain user-facing interpretations of endpoint shape rather than canonical occurrence kinds.

### Scheduled

Scheduled records an expectation that is not yet Actual.

The minimum currently pressured information is:

```text
stable Scheduled identity
scheduled coordinate
neutral quantity-bearing Effects
explicit lifecycle relation evidence
```

Observation 105 rejects replacing lifecycle relation provenance with a mutable open/closed bit or even a status-kind set when successor identity matters.

The Scheduled semantic family remains distinct from Actual because realization linkage is independently observable and cannot be reconstructed from matching content.

### Capacity

Capacity records spending / allocation authority rather than physical holdings.

Observation 106 permits reuse of the signed Effect algebra but requires an explicit semantic distinction from Actual:

```text
same signed Effects mechanics

Actual authority
    !=
Capacity authority
```

A Capacity occurrence can therefore reuse exact quantity arithmetic and movement interaction mechanics without contributing to physical holdings.

Grant, reallocation, and release need not be retained operation kinds for the admitted endpoint shapes.

### Attention

Attention records a household matter that may need action even when no financial occurrence exists yet.

Observation 109 requires more than a generic relation target or a boolean status. The selected household view independently observes:

```text
stable Attention identity
human context
explicit due meaning
  DueOn
  NoDueDate
  DueUndetermined

explicit closure meaning
  Resolved
  Dropped
  + learned / observed coordinate
```

Relations from Attention to Movement or later Attention identities are provenance and do not themselves close the Attention item.

The exact final user-facing words are not fixed by the observation. The information distinctions are.

### Quantity basis

An observed starting quantity is not itself a movement.

The existing practical boundary remains:

```text
QuantityBasis
basis correction
basis cut
```

Do not manufacture historical movement merely to explain a pre-existing quantity.

## 2. Shared mechanics underneath the semantic families

The semantic families above do not require four unrelated engines.

### Signed Effect algebra

Actual and Capacity can share:

```text
Locus-like endpoint / coordinate mechanics
Measure
exact signed Quantity
zero-sum movement qualification where the practical entrance requires it
```

Sharing arithmetic does not grant shared semantic authority.

### Relation record mechanics

Scheduled lifecycle and Attention provenance can reuse low-level mechanics such as:

```text
source identity
target identity?
learned / known coordinate
reference admission
append-oriented publication
```

But relation family and source meaning decide semantics.

Do not introduce one universal canonical `Relation` stream merely because several records have two endpoints.

### Historical routing mechanics

Observation 107 supports one time-indexed storage shape:

```text
subject
effectiveOn
purpose?
```

with explicit subject meaning retained.

The latest visible route is a projection. Current-only routing is too small because it rewrites historical answers.

An explicit route with no Purpose is distinct from absence of routing evidence:

```text
purpose = none
    explicitly unmanaged

no routing evidence
    unrouted / not yet classified
```

### Temporal mechanics

The household evidence should not be forced into one universal `date` field.

Existing LOAM observations already pressure several different questions:

```text
valid / scheduled coordinate
learned / known coordinate
effective-from coordinate
known-through observation horizon
selected day / interval
cycle or report focus
```

Shared temporal helper functions are desirable. Collapsing the meanings is not.

### Identity and correction mechanics

Stable identity, append-only correction, replacement / realization provenance, admission-before-publication, and post-write verification remain reusable infrastructure.

Again, shared mechanics do not imply a single semantic relation ontology.

## 3. What no longer needs its own canonical state by default

The qualified observations let several familiar nouns move out of the retained-state candidate list.

### Scheduled status

Do not store by default:

```text
Open
Completed
Cancelled
Postponed
Advanced
```

Selected views are projected from scheduled evidence, explicit lifecycle relations, time, and knowledge horizon.

### Commitment

Observation 108 supports:

```text
open Scheduled quantity claim
+ historical routing
+ lifecycle history
+ query horizon
    -> Commitment
```

The selected managed / explicitly unmanaged / unrouted Commitment view therefore does not need a second canonical commitment stream.

### Envelope derived values

Keep these as projections unless later operations find a counterexample:

```text
Consumption
Fulfillment
Commitment
Remaining
Headroom
```

Current HRA / h-kernel reality pressure already composes them from Actual, Scheduled, Capacity, routing, and realization evidence.

### Report and Home state

Do not create canonical facts for:

```text
Recent
Daily
Monthly
Cycle
Balance Sheet
Profit & Loss
Planned Payments
Open Issues
Envelope Budget
Household Health
Calendar
Home
```

These are query / composition / presentation surfaces over upstream evidence.

### Conventional Account / Plan / Envelope object graphs

The household capabilities do not currently force HRA / h-kernel's package or object graph into LOAM Core.

`Locus` remains the neutral physical quantity coordinate. Scheduled and Capacity are semantic evidence families, not reasons to turn Locus into an Account object. Envelope observations do not require an Envelope object merely because the UI uses an envelope-shaped word.

## 4. Purpose is a semantic coordinate, not yet an object graph

Historical routing and Capacity require a purpose coordinate.

The current pass does **not** establish whether Purpose and Locus should have completely separate token namespaces or can share an underlying textual token representation.

A conservative practical boundary is:

```text
Locus meaning      typed / explicit
Purpose meaning    typed / explicit

underlying token representation
    may be shared
```

This leaves room for names such as `coffee` to appear naturally in both contexts without asserting that a physical quantity Locus and a capacity Purpose are semantically identical.

Do not add a Purpose registry with extra state until an operation observes that state.

## 5. Attention does not become Scheduled-with-null-effects

A tempting compact representation would be:

```text
Thing
  effects?
  target?
  due?
  closed?
```

Observation 109 gives direct counterpressure to this shape.

Attention relation provenance does not determine closure, `closed` does not determine Resolved vs Dropped, and missing concrete due day does not distinguish NoDueDate from DueUndetermined.

The compact design is therefore not optional-field convergence. It is shared mechanics beneath explicitly different semantic rules.

## 6. Orthogonal overlays stay outside the initial ownership graph

Some household questions need additional evidence but do not justify enlarging the neutral occurrence core.

### Current policy overlays

Examples:

```text
balance-view selection
statement roles
cycle focus
visible / eligible holdings
report ordering
```

When current policy is replaceable, it must not silently rewrite historical meaning.

### Backing topology

Backing answers a different question from Capacity:

```text
what authority exists?
    Capacity

what real holdings support that authority?
    Backing
```

Keep backing topology as an orthogonal candidate overlay until its practical writer / query is observed. Do not encode it into Account or Capacity identity in advance.

### Recurrence / Series

Earlier observations already show that Series membership is not recoverable merely from recurrence fields.

Practical recurrence generation remains deferred. When it is earned, preserve explicit grouping provenance rather than mutating Scheduled identity into a recurrence object graph.

### Attention relation vocabulary

Observation 109 establishes that Attention relation provenance is independent from closure. It does not yet say which durable meanings LOAM needs.

Meanings such as:

```text
concerns
planned-as
planning-withdrawn
realized-as
funded-by
continued-as
```

should be admitted only when ordinary household operations observe the distinction. Do not replace them with a universal tag system pre-emptively.

## 7. The resulting compact picture

The research checkpoint can now be drawn as:

```text
                         shared mechanics
              +--------------------------------+
              | identity / exact Quantity      |
              | signed Effect algebra          |
              | relation record scaffolding    |
              | historical selection           |
              | temporal coordinates           |
              +--------------------------------+
                 |          |          |
                 v          v          v

              Actual     Scheduled   Capacity
                 \          |          /
                  \         |         /
                   +--- projections --+
                         |
             holdings / consumption /
             fulfillment / commitment /
             remaining / headroom

              Attention
                 |
        closure + due + provenance
                 |
            open-attention views

              QuantityBasis
                 |
            starting observation
```

This is intentionally not one sum type.

The semantic families are the information partitions that current household questions can distinguish. The mechanics underneath them are where implementation compactness should be sought.

## 8. Practical Lean direction and realization status

The whole-household research gate is qualified across Observations 105–111. Rather than implementing every family at once, the dependency-respecting vertical sequence is:

```text
A. Capacity evidence + Actual historical routing
      -> Entitlement / Consumption / Remaining
      [PRACTICAL CORE: Slice A1 + A2 implemented in main]

B. Scheduled evidence + lifecycle + Scheduled routing
      -> Planned Payments / Commitment / Headroom
      [QUALIFIED RESEARCH: Observation 105, 107, 108]

C. Attention evidence + due / closure / provenance
      -> Open Issues / realization workflow
      [QUALIFIED RESEARCH: Observation 109]

D. Backing overlay
      -> funded / under-backed household view
      [QUALIFIED CONCEPTUAL OVERLAY]

E. compose the existing projections
      -> Cycle pace / reports / Home / richer TUI
      [DOWNSTREAM PROJECTION]
```

Slice A has reached practical realization in `main`:
- **Slice A1** (PR #244): Typed capacity movement boundary (`Loam.Core.Capacity`, `Loam.Core.CapacityMovement`, `Loam.Core.BalancedMovement`, `Entitlement` projection).
- **Slice A2** (PR #248): Historical Actual routing and capacity consumption (`Loam.Core.HistoricalRouting`, `Loam.Core.ActualValidity`, `Loam.Core.ActualRoutingConsumption`, pure projections `Consumption` and `Remaining`).

Slices B–E remain qualified conceptual directions, not a frozen implementation roadmap. LOAM will not force them into premature practical implementation; their concrete order and shapes will continue to follow real dogfood pressure and formal observations.

Each future practical slice should dogfood before the next one hardens the ownership graph.

The implementation should prefer typed wrappers and small authority boundaries over a generic framework. If two wrappers later prove information-equivalent, their low-level implementation can be merged without erasing their semantic types.

## 9. Stop conditions

Before adding a new canonical family, ask:

```text
Can two worlds agree on all retained evidence
but require different household answers?
```

If no, keep the proposed value as a projection or policy.

Before merging two semantic families, ask:

```text
Can two worlds share the same structural record
but require different interpretation or authority?
```

If yes, share mechanics only and keep the semantic partition.

That pair of questions is the current compactness discipline for the next practical phase.

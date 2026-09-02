# LOAM household compression status

Status: qualified cross-capability checkpoint before practical Lean ownership

This file keeps the whole-household compression results separate from production design. A bounded observation can justify an information boundary without forcing one particular Lean type, persistence file, or UI noun.

## Qualified cross-capability observations

### Observation 105 — Scheduled lifecycle edge

Qualified on PR #237.

A mutable open/closed summary is too small, and even completed/retired/superseded status sets lose successor provenance. Explicit completion, retirement, and successor relation evidence plus scheduled time and the query horizon determine the selected lifecycle views in the bounded model.

User-facing `postpone`, `advance`, and same-day replacement are projections from successor direction rather than retained operation kinds.

### Observation 106 — Actual / Capacity movement plane

Qualified on PR #239, final exact head `5ff7134fb65766a650f5e6162735104e09f27c78`.

One signed Effect algebra can be reused across Actual value movement and Capacity / Entitlement movement, but the semantic plane cannot be erased.

```text
shared Effect algebra      yes
shared semantic meaning    no
stored grant / reallocation / release kind
                           not required by the bounded answers
```

### Observation 107 — shared historical routing shape

Qualified on PR #240, final exact head `3fc5d3c7f5a9eb3ba4ffa85fd3ca673986a75407`.

One historical `subject -> purpose-or-none` record shape can serve Actual-side and Scheduled-side routing, but subject meaning remains necessary. Current routing alone loses historical answers. An explicit later no-purpose record can make a subject unmanaged without rewriting earlier routing.

```text
shared routing history shape     yes
current-only routing table       too small
subject meaning erased           too small
history + subject meaning        sufficient for selected bounded projections
```

### Observation 108 — Scheduled + routing -> Commitment

Qualified on PR #241, final exact head `11d99bbdc79cacf59a000ebfb4a726c03301b141`.

The exact-head Observation 108 workflow executed Alloy 6.2.0 + Sat4j and its expected-result checker successfully after the result note was updated.

The two smaller candidates both had counterexamples:

```text
Scheduled + lifecycle without routing
    too small

Scheduled + routing without lifecycle
    too small
```

The selected Commitment view was determined by:

```text
Scheduled quantity-bearing claims
+ lifecycle history
+ historical routing
+ query day / period horizon
```

No separately retained `Commitment` fact was required for managed, explicitly-unmanaged, or unrouted Commitment in the bounded view. Overdue open claims remained commitments; later-known terminal evidence did not rewrite earlier observation; and period end-exclusive was preserved.

Observation 013 remains intact: physical Actual history does not determine intention. Observation 108 identifies Scheduled evidence as the concrete independent intentional source for this practical projection.

### Observation 109 — Attention lifecycle boundary

Qualified on PR #242, final exact head `6088f55643713431364a1b82bb94c0e9878d7dec`.

The exact-head Observation 109 workflow executed Alloy 6.2.0 + Sat4j and its expected-result checker successfully after the result note was updated.

Scheduled and Attention can reuse source / target / known-through relation mechanics, but they cannot share one target-decoded lifecycle semantics.

```text
shared relation mechanics                         yes
universal relation-implies-closure law             no
Attention relation provenance                      independent from closure
closed boolean                                     too small
optional due date                                  too small
```

An Attention item can relate to a Movement and remain open, or continue as a later Attention identity while the earlier item remains open. `Resolved` vs `Dropped` and `NoDueDate` vs `DueUndetermined` remain independently visible distinctions in the selected household view.

## Cross-observation pattern

Observations 105–109 converge on one repeated compression boundary:

> Reuse algebra, history shape, and temporal mechanics where the household questions do not distinguish them. Preserve the semantic partition whenever erasing it merges worlds that the household questions distinguish.

This rules out both extremes:

```text
copy every HRA / h-kernel domain object
    too much structure by default

universal Thing / Fact / Relation / Status record
    too little semantic separation
```

The compact target is a small number of independently observable semantic families over shared low-level mechanics.

## Qualified minimum-vocabulary checkpoint

The current observations justify retaining these semantic families or information-equivalent distinctions:

```text
quantity-bearing occurrence evidence
  Actual
  Scheduled
  Capacity

starting observation evidence
  QuantityBasis / correction / cut

attention evidence
  Attention identity/content
  explicit due meaning
  explicit closure meaning

cross-cutting evidence
  stable identity
  explicit semantic relation provenance
  historical routing + subject meaning
  temporal coordinates / knowledge horizons
```

This list is an information boundary, not a proposed Lean sum type.

Shared mechanics may sit underneath multiple families:

```text
signed Effect algebra
relation source / target / learned-time scaffolding
historical latest-visible selection
exact quantity arithmetic
append-oriented identity and correction mechanics
```

But a generic helper does not earn generic canonical semantics.

## Projection candidates after qualification

The following still do not require their own retained fact families under the current evidence:

```text
spend / income / transfer operation kinds
Plan open / completed / postponed / advanced status
capacity grant / reallocation / release operation kinds
current routing table
consumption
fulfillment
commitment
remaining
headroom
history windows
overdue / due / upcoming
statement sections
calendar
home
```

Several of these still require implementation and arithmetic qualification. The claim is only that their information can be owned by smaller upstream evidence rather than duplicated as canonical state.

## Orthogonal overlays and unresolved seams

The minimum checkpoint should not absorb every later household concern.

These remain deliberately outside the qualified core boundary until a concrete operation requires them:

```text
replaceable current policy
  balance-view selection
  statement roles
  cycle / report focus

backing topology
  still a separate funding question

recurrence / Series generation
  grouping provenance has earlier observation pressure,
  but practical generation remains deferred

Purpose identity representation
  routing requires a Purpose coordinate,
  but the current pass does not decide whether its token namespace
  should be shared with or distinct from Locus

Attention relation vocabulary
  relation provenance is independent,
  but the exact durable meanings such as concerns / planned-as / funded-by
  should be earned by practical operations rather than universalized now
```

These open seams are reasons to keep extension conservative, not reasons to enlarge the initial practical ownership graph.

## Gate reached

The research gate set before Observations 108 and 109 is now satisfied:

```text
105 Scheduled lifecycle         qualified
106 Actual / Capacity algebra   qualified
107 historical routing         qualified
108 Commitment projection      qualified
109 Attention boundary         qualified
        |
        v
whole-household minimum-vocabulary reduction
        reached
```

The next step may now move toward Lean ownership and persistence, but it should begin with the smallest vertical slice that exercises the qualified boundaries. Do not build all HRA / h-kernel packages at once, and do not add a universal metadata or relation framework.

`HOUSEHOLD_MINIMUM_VOCABULARY.md` records the resulting implementation-facing reduction separately.

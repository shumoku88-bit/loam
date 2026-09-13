# LOAM contrapuntal sketchbook: C2-C5

Status: first broad pass before choosing a deep formal target

Baseline main: `9c4989a9772f7da91a34ab9f6da0544c4f38209e`

This note deliberately stays one level shallower than a formal Observation.
The goal is to hear several candidate relations before choosing one and turning
the first interesting result into another implementation track.

The fixed research rule remains:

> Search for useful laws among existing projections before inventing a new fact,
> report, authority, or UI surface.

For each sketch below, record:

- the participating voices;
- a candidate cross-projection law;
- the smallest visible counterexample;
- what survives after the counterexample;
- household usefulness;
- whether any new canonical evidence appears necessary.

C1 Scheduled realization is documented separately in
`LOAM_COUNTERPOINT_C1_REALIZATION_2026-09.md`.

---

## C2. Stock-flow / transaction-flow coherence

### Existing voices

`TransactionsFlowReview` projects a current dated Event incidence matrix over an
explicit half-open window:

```text
row    = Locus x Measure
column = current Event
cell   = Event.quantityAt(row)
```

`StockFlowReview` takes a selected set of current balance coordinates and the
same correction-aware `ActualReview.Record` world, reconstructs quantities before
the window boundaries, and derives the selected net change inside the window.

The two answers are intentionally not the same report. One preserves Event and
coordinate incidence. The other asks how a selected stock moved across a
boundary.

### Candidate net law

Let `S` be the normalized coordinates in the BalanceReview snapshot supplied to
StockFlow, and let both projections use the same ActualReview records and
`[start, end)` window.

If both projections are defined, the strongest simple candidate is:

```text
StockFlow.netChange
  = sum coordinate in S (TransactionsFlow.rowTotal coordinate)
```

This should be a finite-sum rearrangement, not new accounting semantics.
StockFlow's per-Event selected contribution is the sum over selected coordinates;
TransactionsFlow's row total sums the same Event contributions in the opposite
order.

### Small counterexample to a stronger law

Do not extend the equality from net change to the two-sided activity fields.

For one current Event:

```text
selected A  +100
selected B  -100
```

StockFlow first nets the selected coordinates inside the Event. Its tracked Event
contribution is `0`, so that Event contributes neither to
`increasesAcrossEvents` nor `decreasesAcrossEvents`.

TransactionsFlow preserves coordinate incidence. A and B still expose +100 and
-100 activity and nonzero gross flow.

Therefore:

```text
net coherence      plausible and strong
increase/decrease  not the same decomposition
```

This is desirable. The two views answer different questions without disagreeing
about the net selected change.

### Answerability asymmetry

The views also have different domains of definition.

TransactionsFlow refuses a current quantity-bearing Event with no usable date,
even when that Event touches only coordinates unrelated to a later comparison.
It cannot justify whether that Event belongs inside or outside the requested
window.

StockFlow validates dates only for current Events whose aggregate contribution
to the selected balance coordinates is nonzero. An undated current Event outside
the selected stock can therefore be irrelevant to StockFlow while still making
TransactionsFlow unavailable.

So the useful law must be stated as:

```text
if both projections are defined on the same world and window, then ...
```

not as an equivalence of report availability.

### Why this is interesting

This is a clean example of two voices singing the same underlying change while
retaining different resolution.

It suggests a useful explanation path without creating a new report engine:

```text
Stock-Flow says selected stock changed by q
            |
            v
Transactions Flow can decompose q into the Events and coordinates that produced it
```

### New canonical evidence required?

None visible.

### Formal pressure

Low to medium. The net equality looks cheap enough for Lean once the exact shared
selection boundary is written down. Alloy is probably unnecessary unless a
stronger equivalence is proposed.

---

## C3. Correction propagation

### Existing voices

A valid Event correction relation selects one current correction frontier.
Different production projections then consume that same effective Event world in
different ways:

- BalanceReview sums current quantities at selected coordinates;
- TransactionsFlow selects current dated Events in a window;
- StockFlow sums selected current Event contributions across a window;
- RoleFlow overlays AccountingRole on TransactionsFlow;
- CurrentCoverage routes current Actual contributions to Purpose;
- RoleBalance may use zero-origin, opening support, or a current quantity anchor.

The retained original Event is not erased. Current projections decide whether it
still contributes through the shared correction frontier or through a support
cut.

### Candidate replacement delta law

For a projection `P` that is additive over the current Event frontier and whose
selection context does not otherwise change, one correction

```text
target -> replacement
```

suggests:

```text
Delta P = contribution_P(replacement) - contribution_P(target)
```

The current CorrectionPublisher copies the target's current occurrence date to
the replacement when it publishes the correction. Therefore, immediately after
that publication, a fixed date window that contained the target also contains
the replacement. A later independent Actual-validity correction can change that
condition.

This candidate naturally permits different deltas in different projections:
changing Loci can redistribute AccountingRole or Purpose contributions even when
the replacement remains one balanced Movement.

### Strong counterexample to universal propagation

Current quantity anchors deliberately break the naive rule that every correction
must change current balance.

A current anchor records:

- an asserted current quantity;
- the stable correction roots already reflected by that observation.

When a root is reflected, `CurrentQuantityAnchor.inspectQuantity` excludes the
whole current terminal of that root from the post-anchor delta frontier. A later
correction along the same root therefore remains inside what the observation
already reflected.

This means one correction can legitimately produce:

```text
historical / flow explanation  changes
current anchored quantity      unchanged
```

That is not a synchronization bug. It is a provenance distinction.

A later real-world observation says, in effect:

> Whatever historical explanation is currently preferred for this already
> reflected root, do not count the root again on top of the observed current
> quantity.

### Another useful split

RoleFlow and Purpose Consumption can also react differently to the same
replacement.

AccountingRole is attached to Locus. Actual Purpose routing is historical and is
queried at the Event's valid coordinate. A replacement that changes Loci can
therefore move quantity among roles and Purposes even when the Event remains
balanced and keeps the same occurrence date.

So the interesting object is not one universal correction amount. It is the
pattern of projection deltas.

### Household question hiding here

A future read-only answer could ask:

> What did this correction change, and what remained stable?

For example:

```text
physical current balance    0
selected-window flow      +500
Food consumption          +500
General consumption       -500
Net Worth                    0
```

Those numbers should be derived from the existing projections rather than stored
as a generic CorrectionImpact record.

### New canonical evidence required?

None visible for the basic question. EventCorrection already supplies the
explicit replacement relation.

### Formal pressure

High. This currently looks like the richest candidate because it combines a
simple replacement delta law with meaningful exceptions caused by support
provenance and independent interpretation.

The first formal probe should not prove a generic framework. It should select two
or three concrete production projections and show exactly when their deltas
agree, differ, or stay invariant.

---

## C4. Evidence / answerability monotonicity

### Naive candidate law

A tempting statement is:

```text
more evidence -> at least as many answerable questions
```

The current production semantics show that this is too crude.

### Counterexample 1: overlapping support is not "more support"

RoleBalance has three current-quantity support families:

- zero-origin coverage;
- opening support;
- current quantity anchor.

The current boundary deliberately refuses overlap rather than inventing
precedence between independently justified answers. CurrentQuantityAnchorPublisher
also refuses to publish an assertion for a coordinate already supported by
zero-origin or opening evidence.

So raw set inclusion can turn a previously usable collection of evidence into an
invalid composition.

The correct notion cannot be:

```text
E subset E' => answerability(E) subset answerability(E')
```

without first defining compatibility.

### Counterexample 2: append-only history can invalidate a current witness

Opening support names one retained Event as the opening witness for a coordinate.
RoleBalance validates that this witness is still one current Event on the
correction frontier.

If that Event later becomes the target of a correction, the raw original remains
retained but it is no longer current. The old opening-support witness can stop
justifying the current balance answer.

Thus retained evidence can grow while current answerability shrinks.

This is an important distinction:

```text
retained history may grow monotonically
current justified claims need not
```

### Counterexample 3: some interpretation cannot be added retroactively yet

The current AccountingRole publisher qualifies only a first role assignment to
an admitted Locus before that Locus has appeared in retained Actual or Scheduled
quantity evidence. Role replacement and retroactive role history are deliberately
unqualified.

Therefore an already-used unresolved Locus is not currently guaranteed to admit
"one more role fact" as a monotone repair operation.

### Counterexample 4: current observation is a replacement image

A current quantity anchor is not an append-only history of observations. A new
reconciliation session replaces the complete current anchor image. No anchor
identity or revision graph is retained yet.

Again, there is no useful global partial order obtained merely by counting facts.

### What survives

The promising idea is narrower:

> Answerability may be monotone under a compatible extension of one qualified
> evidence interpretation, while remaining intentionally non-monotone across
> authority replacement, correction, and conflicting support families.

That is a research statement, not yet a production abstraction.

Concrete local questions are better than introducing lattice vocabulary now:

- If one previously unsupported coordinate gains exactly one compatible support,
  which current balance questions become defined?
- If AccountingRole is already fixed before use, which report questions gain
  classification without changing quantity answers?
- If an Event is added outside a current anchor's reflected root cut, which
  anchored quantities advance by that Event delta?
- If a correction changes an opening witness, which answers must become unknown
  until support is repaired?

### Why this is interesting

This sketch warns against a seductive but false abstraction: "all LOAM evidence
forms one monotone information lattice."

LOAM currently mixes several different epistemic behaviors on purpose:

- append-only historical relations;
- replaceable current observations;
- replaceable query/presentation policy;
- support witnesses whose validity depends on the current correction frontier.

The distinctions may be more valuable than a universal order.

### New canonical evidence required?

None for the observation itself.

### Formal pressure

Medium to high, but only after selecting one local compatibility relation.
Alloy may be useful for finding the smallest world where naive monotonicity fails
or a restricted monotonicity law survives.

---

## C5. Physical backing / assigned capacity conservation

### Existing voices

CycleFunding composes two independently meaningful current answers:

```text
budgetableBacking  = sum of explicitly selected current physical balances
remainingAssigned  = sum max(Purpose.remaining, 0)
residual            = budgetableBacking - remainingAssigned
```

Managed Scheduled Commitment is already inside CurrentCoverage and is not
subtracted a second time from `remainingAssigned`.

### Always-true delta identity

For two defined snapshots with the same interpretation boundary:

```text
Delta residual = Delta backing - Delta assigned
```

This is algebra, not yet a household discovery.

The interesting question is when a real household transition forces:

```text
Delta backing = Delta assigned
```

and therefore preserves the residual.

### Candidate ordinary-spending conservation

A routed Actual expense can preserve the residual when all of the following hold:

1. the payment reduces the explicitly selected physical backing by `q`;
2. the Actual contribution increases Consumption for one currently positive
   assigned Purpose by `q`;
3. no Capacity entitlement changes in the same comparison;
4. the Purpose's `remaining` does not cross the zero clamp;
5. no other selected backing contribution changes the physical sum.

Then:

```text
Delta backing  = -q
Delta assigned = -q
Delta residual = 0
```

This says that spending already covered by an assignment can consume physical
backing and assigned capacity together without changing the unassigned residual.

### Small counterexamples

#### Crossing zero

`remainingAssigned` sums `max(remaining, 0)` per Purpose.
Once a Purpose is already at or below zero, additional Consumption no longer
reduces assigned capacity by the full spend amount.

Physical backing can continue to fall, so residual conservation breaks exactly
at the overrun boundary.

#### Paying from unselected backing

If Consumption rises but the paying physical coordinate is outside the explicit
funding selection:

```text
Delta backing  = 0
Delta assigned = -q
Delta residual = +q
```

This is not necessarily wrong. It says the configured backing pool did not fund
that physical outflow.

#### Income or new external backing

An inflow into selected backing with no simultaneous positive Capacity assignment
raises residual. Therefore residual is not wealth or profit. It is a relation
between selected physical backing and still-positive assigned capacity.

#### Selection topology

Funding selection is explicit and role-neutral. If the caller selects both sides
of a balanced Movement, the selected physical delta may net to zero even though
one household-facing account fell. Conservation laws must refer to the explicit
selection, not inferred Asset semantics.

### Why this is interesting

Residual may be useful as a discrepancy signal between two independent planes:

```text
physical backing
normative assignment
```

When ordinary expected spending preserves it, a change in residual can highlight
something structurally different:

- new backing;
- new allocation;
- overrun;
- payment outside the selected backing pool;
- correction or reclassification;
- a deliberately unusual funding selection.

This is potentially useful, but it must not be promoted to safe-to-spend or
funding authority.

### New canonical evidence required?

None visible.

### Formal pressure

Medium. The useful law is piecewise because of `max(remaining, 0)` and explicit
selection. A small executable Lean probe is probably cheaper than Alloy for the
first pass.

---

# Cross-sketch comparison

| Candidate | Core shape | Smallest interesting break | Household surprise | New retained fact? | Current pull |
| --- | --- | --- | --- | --- | --- |
| C1 realization | contribution moves from Scheduled to Actual | same total, different Purpose/Locus/time contribution | high | no | high |
| C2 stock/flow | restriction and finite sums commute for net | two-sided activity does not commute with Event-level netting | medium | no | medium |
| C3 correction | replacement delta across projections | reflected current-anchor root stays invariant | very high | no | very high |
| C4 answerability | partial projections have compatibility domains | more raw evidence can conflict or invalidate a witness | high, more epistemic | no | high |
| C5 funding | residual compares deltas from two planes | zero clamp / unselected backing / selection topology | medium-high | no | medium |

The strongest observation after one broad pass is that there is not one single
conservation law hiding everywhere. There are at least three recurring forms.

## Form A: delta transfer

C1, C3, and C5 all ask how one transition changes several independently derived
quantities.

```text
transition in retained evidence
        |
        +-> Delta projection A
        +-> Delta projection B
        +-> Delta projection C
```

The interesting law is often a difference between contributions, not equality of
whole objects.

## Form B: projection coherence

C2 asks whether two different projections commute with restriction and summation.
The views remain different even when a shared net is provably identical.

```text
same Event world
   |           |
   v           v
matrix      stock-flow
   |           |
restrict       |
+ sum          |
   +---- same net? ----+
```

## Form C: domain of definition

C4 reminds us that every voice is a partial projection. UNKNOWN and refusal are
part of the semantics, not presentation noise.

A cross-projection law is meaningful only after stating when each side is
justified.

---

# Working synthesis

A useful research picture now looks like this:

```text
retained evidence world E

P1 : E ->? balance
P2 : E ->? transaction flow
P3 : E ->? stock-flow
P4 : E ->? purpose coverage
P5 : E ->? role balance
...

one admitted transition E -> E'

observe:
  which Pi are defined before and after?
  which Delta Pi agree?
  which Delta Pi differ?
  which Pi intentionally remain invariant?
  what independent evidence explains the difference?
```

The `->?` is important. These are partial projections with explicit evidence
requirements.

This picture is a research lens only. Do not create a generic `Projection`,
`DeltaVector`, `Impact`, or universal household state type from it. First keep
solving concrete exercises.

# Provisional priority after the broad pass

The broad pass changes the immediate priority slightly.

C1 remains an excellent user-facing realization exercise, but C3 now exposes the
richest LOAM-specific behavior:

> One correction can change historical explanation, Purpose consumption, and
> role flow while leaving a later observed current quantity unchanged because
> support provenance cuts the Event root differently.

C1, C3, and C4 therefore appear to form one promising cluster:

```text
expectation / interpretation / observation
              under
     later evidence transitions
```

C2 is a cleaner coherence theorem and may become a cheap qualification once the
selection boundary is written down.

C5 is useful but more dependent on current funding policy and the positive
remaining clamp, so it should not set the overall research vocabulary yet.

# Next exploration step

Before adding production behavior, deepen the C1/C3/C4 cluster with a tiny set of
explicit worlds:

1. Scheduled -> matching Actual, same Purpose contribution.
2. Scheduled -> equal total Actual, different Purpose contribution.
3. Correct one unanchored Actual and observe flow, balance, and coverage deltas.
4. Correct one root already reflected by a current anchor and compare the same
   projections.
5. Correct an opening-supported Event and observe the answerability boundary.

The desired result is not a generic framework. It is a small counterexample map
showing which voices move together and why.

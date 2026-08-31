# Practical Core audit after Observations 066–071

This is a checkpoint audit, not Observation 072.

Observations 066–071 form one external-accounting-pressure sub-arc. The purpose of this audit is to ask what that sub-arc actually requires of the Practical Lean Core, Persistence, and CLI before LOAM continues to invent more experimental vocabulary.

## Audit question

The six observations separated:

```text
historical valuation
    != acquisition basis

aggregate holding
    != quantity-bearing disposal provenance

valid allocation
    != policy-selected attribution
    != explicitly retained attribution

current policy
    != retained historical attribution

retained attribution
    != policy provenance

stable policy identity
    != historical policy definition
```

The audit asks:

> Did any of those distinctions earn a new practical primitive, persistence stream, CLI command, or generic abstraction now?

The answer at this checkpoint is **no**.

That is a substantive result. The observations constrain future implementations without forcing LOAM to mirror the nouns used by mature accounting products.

## Observation-by-observation pressure

| Observation | Earned bounded distinction | Existing practical boundary it pressures | New practical representation earned now? |
| --- | --- | --- | --- |
| 066 | valuation history does not determine acquisition basis | `Rate` must remain neutral and must not silently stand in for acquisition provenance | No |
| 067 | aggregate holding and source-set views can lose quantity-bearing disposal provenance | already-earned `EffectKey` can serve as a provenance endpoint in the selected vocabulary | No |
| 068 | a deterministic policy output is not automatically an independently retained source relation | numeric `Allocation` / `RecipientAssignment` must not be reused merely because the shapes look similar | No |
| 069 | a later current-policy change must not rewrite a retained historical attribution | current derived views and retained historical meaning remain distinct | No |
| 070 | retained attribution plus current policy does not determine historical policy provenance | provenance would need to survive only if a future practical query asks which policy selected the answer | No |
| 071 | stable policy identity plus current definition and retained attribution does not determine the historical definition | mutable policy identity would need historical-definition information only if that distinction becomes part of the practical vocabulary | No |

## Practical Core audit

### `Rate` remains correctly narrow

The practical `Rate` is an exact Measure-to-Measure relation. It deliberately does not claim that it is a market price, valuation authority, acquisition basis, or time-stable fact.

Observation 066 therefore strengthens the existing boundary rather than changing the type:

```text
Rate
    can answer a supplied comparison relation

Rate
    must not silently mean acquisition provenance
```

No `CostBasis` type is earned.

### `EffectKey` already provides the identity pressure needed by Observation 067

Observation 052 had already earned stable Effect identity before coordinate collapse. The practical `EffectKey` exists so later overlays can refer to one Effect without using list position or `(Locus, Measure)` as identity.

Observation 067 finds that the bounded disposal questions can use that already-earned identity as an endpoint:

```text
Disposal Effect
    -> Acquisition Effect
    -> Quantity
```

The observation does not establish that every acquisition is one practical Effect, nor that every future domain can avoid a distinct Lot identity. It only means the selected vocabulary does not force another identity layer now.

No `Lot` type is earned.

### `Allocation` and `RecipientAssignment` remain numeric infrastructure

The practical allocation modules answer an exact arithmetic question: split indivisible quanta and bind those parts to caller-supplied recipient identities.

Observations 067–068 contain quantity-bearing relations too, but similar mathematics is not enough to identify domain meaning.

In particular:

```text
numeric allocation
    !=
disposal provenance

numeric placement policy
    !=
historical source attribution
```

Reusing the existing modules as disposal semantics would be premature coupling.

No disposal API or disposal-policy type is earned.

### The physical core does not grow

The practical physical shape remains:

```text
Event
  -> Effect identity
       -> Locus
       -> Measure
       -> Quantity
```

Observations 066–071 add provenance and policy questions around that shape. They do not add a new physical coordinate.

### No generic relation abstraction is earned

Several experiments now use explicit relations: Correction, Resolution, Plan realization, Series membership, refund provenance, acquisition basis, disposal provenance, and policy provenance.

That does not imply one universal practical `Relation` object.

The current concrete semantic modules still carry different laws and different operational pressure. A generic abstraction should wait until practical duplication, not experimental resemblance, requires it.

## Persistence audit

Current Event persistence already preserves stable Event identity, every `EffectKey`, Locus, Measure, and exact Quantity. Aggregate projections therefore do not destroy Effect identity at the persistence boundary.

That is enough to remain compatible with the endpoint lesson of Observation 067.

What is **not** yet earned:

```text
basis stream
disposal-provenance stream
policy stream
policy-version stream
lot store
```

The reason is not that these distinctions are meaningless. It is that LOAM has no practical acquisition/basis/disposal workflow that currently needs to publish, reload, query, correct, or coordinate them.

Observations 070–071 are explicitly conditional:

> If a future practical query must answer which historical policy behavior selected an attribution, some information-equivalent representation of that behavior must survive.

That condition does not itself choose a persistence representation.

## CLI audit

The CLI still has no practical acquisition-basis, disposal-provenance, or policy workflow.

Adding commands now would make the experimental vocabulary operational before the practical use case has been earned.

No CLI addition is warranted by Observations 066–071.

## Redundancy audit

### Observation 068 versus Observation 047

Observation 047 already showed that an underlying candidate structure and a selection policy can be independent.

Observation 068 is not a re-run of that result. It asks the additional question exposed by Observation 067:

```text
policy-selected quantity attribution
    !=
independently retained quantity-bearing source relation
```

The explicit conformance boundary is the new part.

### Observation 069 versus Observation 034

Observation 034 already showed that a latest relation cannot generally answer a historical relation query.

Observation 069 applies that temporal lesson to a new retained object exposed by 067–068: a quantity-bearing disposal attribution selected while policy is mutable.

It is domain-specific evidence, not a new universal time theorem.

### Observations 070–071

These two observations are useful because they close two remaining reconstruction shortcuts:

```text
retained attribution
    -> historical policy
```

and:

```text
stable policy identity + current definition
    -> historical policy definition
```

Both shortcuts fail in the bounded models.

But the next obvious chain of metadata questions would have sharply diminishing value without a concrete practical query. Authority, approval, governance, authorship, and further policy metadata are therefore not automatic Observation 072 candidates.

## Sub-arc decision

The external accounting pressure sub-arc from 066 through 071 is **closed at this checkpoint**.

Practical changes earned by the whole sub-arc:

```text
Practical Core additions: 0
Persistence additions:     0
CLI additions:             0
wire-format additions:     0
```

Existing boundaries strengthened:

```text
Rate neutrality
stable Effect identity before aggregation
overlay meaning separate from numeric shape
retained historical meaning separate from current derived view
policy provenance conditional on the questions an application retains
```

## What would reopen this area

This area should reopen only when concrete practical pressure appears, for example:

- LOAM gains a real acquisition/disposal workflow that must answer source-specific basis questions;
- a practical caller must retain and reload quantity-bearing disposal provenance;
- a user-visible query must explain which policy selected a historical attribution;
- a practical policy can be edited in place while old decisions must remain explainable;
- correction, conflict, or publication semantics are needed for one of these new relation kinds.

At that point the next observation should be driven by the operation or query that cannot be answered, not by a familiar accounting noun.

## Checkpoint

The useful outcome of Observations 066–071 is therefore not a larger core.

It is a sharper rule for future growth:

> Preserve a distinction when a retained practical question can observe it. Do not promote the distinction into the Practical Core merely because a bounded experiment proved that the distinction can exist.

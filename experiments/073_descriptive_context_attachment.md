# Observation 073 — Does descriptive context have one attachment scope?

## Question

Observation 072 established that the practical quantity-placement fact does not determine all of the human-facing context a person may expect to remember.

It deliberately left the missing context unnamed:

```text
Merchant
Place
Purpose
Category
Counterparty
Description
Note
```

may be different future meanings rather than one field.

Before naming any of them, Observation 073 asks a narrower structural question:

> If descriptive context is retained, is one attachment scope enough, or can context attached to a whole Event vary independently from context attached to an individual Effect within that Event?

This matters because the current practical Event can contain several Effects. A future human-facing event might be recognizable as one whole occurrence while different Effects within it answer different finer-grained questions.

## Bounded model

The physical shape is deliberately tiny and fixed across both worlds:

```text
one Event
  ├─ FirstEffect
  └─ SecondEffect
```

The model adds no merchant, purpose, category, account, transaction kind, time, or accounting role.

It introduces only an experiment-local opaque `Context` identity and two independent attachment relations:

```text
eventContext  : Event  -> lone Context
effectContext : Effect -> lone Context
```

The same Event/Effect structure is shared by both worlds. Only the context relations may vary.

A helper predicate `uniformWithEvent` represents the compression hypothesis that every Effect simply inherits the context attached to its Event:

```text
effect context = parent Event context
```

That is tested as an explicit additional law rather than assumed by the representation.

## Observed Alloy result

Alloy 6.2.0 + Sat4j produced the expected boundary:

```text
representativeSplitAttachment                    SAT
sameEventContextDifferentEffectContext            SAT
sameEffectContextDifferentEventContext            SAT
splitEffectsNeedNotShareContext                   SAT
eventAndEffectCanDisagree                         SAT
uniformConformanceAllowsCompression               SAT
PhysicalShapeDeterminesContext                    SAT counterexample
EventContextDeterminesEffectContext               SAT counterexample
EffectContextDeterminesEventContext               SAT counterexample
UniformConformanceMakesEventContextSufficient     UNSAT counterexample
SplitContextCannotConformToSingleEventContext     UNSAT counterexample
```

The same physical Event/Effect shape therefore admits worlds where Event-level context stays fixed while Effect-level context changes, and worlds where Effect-level context stays fixed while Event-level context changes.

One Event may also contain Effects with different contexts. Such a split-context world cannot satisfy the compression law that every Effect simply inherits one Event context.

Conversely, when that uniform-conformance law is explicitly imposed, the same Event context does determine the Effect contexts in this bounded model.

## Finding

The bounded distinction is:

```text
context attached to the whole Event
    !=
context attached to an individual Effect
```

Neither attachment scope determines the other merely from the physical Event/Effect structure.

A single Event-level context can be sufficient only under an additional semantic law:

```text
all Effect context = parent Event context
```

That law is not a free representation compression. It rules out observable split-context worlds.

Likewise, Effect-level context alone does not reconstruct an independently retained whole-Event context.

So if a future human vocabulary needs both questions, attachment scope itself is information that must remain distinguishable. This does **not** imply that LOAM should store two concrete fields. A generic attachment relation or several typed overlays could preserve the same distinction; representation remains open.

## Deliberate boundary

The model still does not tell us what any Context means.

In particular, this observation does **not** earn:

```text
Merchant
Place
Purpose
Category
Counterparty
Description
Note
```

It also does not decide whether future practical representation should use:

- fields on Event or Effect;
- one generic attachment relation;
- several typed relations;
- an external annotation layer;
- or no retained descriptive context until stronger dogfood pressure appears.

The observation is about attachment scope only.

## Practical Core impact

None yet.

Observation 073 adds no Practical Core type, Persistence format, CLI prompt, or wire-format field. The next practical step should still be driven by a concrete human question that requires one of these retained contexts rather than by the existence of the bounded model alone.

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

## Expected pressure

The model asks for witnesses where:

- the same Event context coexists with different Effect context;
- the same Effect context coexists with different Event context;
- two Effects of one Event carry distinct contexts;
- an Effect context disagrees with its Event context.

It then checks whether either attachment relation determines the other.

The intended boundary is not that LOAM must store two concrete context fields. The narrower question is whether collapsing all descriptive context to one Event-level value, or all descriptive context to Effect-level values, is information-preserving for a future vocabulary that can ask both scopes.

## Deliberate boundary

Even if the bounded model separates Event-level from Effect-level attachment, it does not tell us what any Context means.

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

None unless a later practical question actually requires one of these context distinctions.

No Practical Core, Persistence, CLI, or wire-format change is proposed by Observation 073.

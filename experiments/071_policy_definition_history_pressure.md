# Observation 071 — Does stable policy identity determine historical policy behavior?

## Question

Observation 070 established that a retained attribution does not determine which behaviorally distinguishable policy produced it.

Observation 071 asks the next and deliberately final question in this policy/provenance sub-arc:

> If one stable policy identity keeps the same name while its definition changes through time, can that identity, the current definition, and the retained attribution reconstruct which definition was in force when the attribution was selected?

The observation does not assume a `PolicyVersion` type or a persistence format. It asks whether stable identity alone preserves enough historical meaning when the behavior behind that identity is mutable.

## Why TLA+ / TLC

The distinction depends on reachable histories rather than only static structure.

We need to compare two paths that can converge on the same visible present:

```text
history A
  definitionA
  -> record attribution
  -> change to definitionB

history B
  definitionB
  -> record attribution
```

Both paths should be able to end with the same:

```text
Policy identity
current definition
retained attribution
```

while differing in the definition that actually selected the historical attribution.

TLA+ therefore adds a distinct answer here. Alloy is not added because the relevant pressure is the reachable update history of one stable identity.

## Minimal state

The policy identity is intentionally constant in every state:

```text
PolicyIdentity = disposalPolicy
```

Only three values are mutable:

```text
currentDefinition
recordedAttribution
recordedDefinition
```

There are two experiment-local definitions:

```text
definitionA
definitionB
```

They agree on the historical case:

```text
historicalCase
  definitionA -> earlier3_later1
  definitionB -> earlier3_later1
```

but differ on another case:

```text
distinguishingCase
  definitionA -> earlier3_later1
  definitionB -> earlier1_later3
```

So a retained `earlier3_later1` answer does not identify the definition merely by numerical coincidence, while the definitions are still behaviorally distinct.

`RecordDisposal` snapshots both the selected attribution and the definition that selected it.

`ChangeDefinition` changes only the current definition behind the same stable policy identity.

`recordedDefinition` is an experiment-local oracle used to ask what information a projected representation would lose. Its presence in this model does not yet mean production LOAM must store a version field.

## Positive safety result

TLC 2.19 / TLA+ tools 1.7.4 checked the complete bounded state graph:

```text
2 initial states
10 states generated
6 distinct states found
0 states left on queue
complete state graph depth 3
```

No error was found for:

```text
TypeOK
HistoricalCaseCollides
DefinitionsAreBehaviorallyDistinct
RecordedPairConforms
RecordedAttributionNeverRewrites
RecordedDefinitionNeverRewrites
```

So the model simultaneously preserves three intended facts:

1. the two definitions can produce the same historical attribution;
2. they remain behaviorally distinct on another case;
3. once a historical selection is retained, neither its attribution nor the definition oracle is rewritten by a later definition change.

## Boundary A — old definition behind the current definition

The first deliberately false reconstruction hypothesis says that the visible projection

```text
stable Policy identity
+ current definitionB
+ retained earlier3_later1
```

forces the historical definition to have been `definitionB`.

TLC rejects that invariant with this trace:

```text
State 1
currentDefinition   = definitionA
recordedAttribution = none
recordedDefinition  = none

State 2  RecordDisposal
currentDefinition   = definitionA
recordedAttribution = earlier3_later1
recordedDefinition  = definitionA

State 3  ChangeDefinition
currentDefinition   = definitionB
recordedAttribution = earlier3_later1
recordedDefinition  = definitionA
```

The stable policy identity never changed. Only its current definition changed.

## Boundary B — the same visible projection with a different history

The opposite reconstruction hypothesis says that the same visible projection forces the historical definition to have been `definitionA`.

TLC also rejects that invariant:

```text
State 1
currentDefinition   = definitionB
recordedAttribution = none
recordedDefinition  = none

State 2  RecordDisposal
currentDefinition   = definitionB
recordedAttribution = earlier3_later1
recordedDefinition  = definitionB
```

So the same projected present can correspond to either historical definition.

## Finding

The bounded separation is:

```text
stable policy identity
    !=
historical policy definition
```

and more strongly:

```text
stable policy identity
+ current definition
+ retained historical attribution

        does not determine

historical policy definition
```

when one identity is allowed to change behavior through time and different definitions can agree on the particular historical case.

This is not merely the Observation 069 result under another name. Observation 069 changed from one policy identity to another current policy. Observation 071 holds the policy identity fixed and changes the behavior associated with that identity.

The practical risk is therefore narrower and different:

> A durable policy name or identity is not sufficient historical provenance if the meaning behind that identity can be edited in place.

## Relation to Observation 070

Observation 070 established:

```text
retained historical attribution
    !=
policy provenance
```

Observation 071 sharpens the provenance side:

```text
policy identity
    !=
the policy definition that was historically in force
```

So if future questions ask why an attribution was selected, retaining only a stable policy name can still lose information when that name's behavior changes.

## What is not earned

Observation 071 does **not** establish:

- a Practical Core `Policy` type;
- a Practical Core `PolicyVersion` type;
- semantic version numbers;
- a particular version identifier format;
- that every policy must be immutable forever;
- that every historical attribution must store a policy version;
- that a complete executable policy snapshot is the required representation;
- policy validity intervals;
- policy authority, authorship, approval, or governance semantics;
- FIFO, LIFO, average-cost, specific-identification, tax, or inventory law;
- policy persistence or a new wire format;
- correction or supersession semantics for policy definitions;
- a first-class Lot or CostBasis type;
- gain/loss calculation.

The strongest earned statement remains conditional on the retained vocabulary:

> If a future query must distinguish which historical behavior under a stable policy identity selected an attribution, then mutable policy identity plus the current definition and retained attribution are insufficient. Some information-equivalent representation of the historical definition must survive.

That representation could be an immutable definition identity, a version reference, a content-addressed definition, a snapshot, or another equivalent encoding. Observation 071 does not choose among them.

## Practical Core boundary

No Practical Lean Core, Persistence, CLI, or wire-format change is earned by this observation.

## Sub-arc checkpoint

Observations 066–071 have now separated:

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

This is a useful stopping point.

Before extending the chain with policy authority, approval, governance, or further metadata, LOAM should audit what Observations 066–071 actually require of the Practical Core. If the answer remains "no new practical primitive yet," that is itself a substantive result rather than a reason to manufacture another observation.

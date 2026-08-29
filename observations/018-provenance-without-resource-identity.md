# Observation 018 — Provenance Without Resource Identity

## Question

Can explanation and event-specific commitment undo be supported with provenance/event identity while resource Units remain anonymous?

Observation 017 showed that a Purpose-local anonymous household vocabulary can remain behaviorally closed without persistent resource Unit identity.

Observation 018 asks whether explanation forces resource identity back into the model, or whether a different kind of identity is enough.

## Model

The resource side contains no resource Unit identity.

There are only two Purposes with finite anonymous capacity:

```text
Purpose -> capacity
Purpose -> committed quantity
Purpose -> available quantity
```

Commitment provenance is represented separately by four event identities:

```text
e0 e1 -> p0
e2 e3 -> p1
```

Each active event contributes one commitment quantum to its Purpose in this deliberately small model.

Current committed quantity is derived from active provenance events:

```text
committed(p) = number of active events whose Purpose is p
```

The explanation projection is:

```text
explanation(p) = active event identities whose Purpose is p
```

The operational vocabulary is:

```text
commit(event)
undo(event)
```

No resource identity is introduced by either operation.

## Positive execution

TLA+ tools 1.7.4 / TLC 2.19 exhaustively explored the active-event state space.

```text
1 initial state
65 states generated
16 distinct states found
0 states left on queue
complete state graph depth: 5
```

The following invariants held in every reachable state:

```text
TypeOK
CapacityOK
ExplanationMatchesAggregate
CauseVisible
UndoEnabledExactlyActive
TargetedUndoRemovesExactlyOne
```

Therefore, in this finite model, event identity is enough to answer which commitments explain a Purpose's currently committed quantity and to target exactly one commitment for undo.

The targeted-undo check also verifies that undoing one active event reduces only that event's Purpose by one commitment quantum and leaves the other Purpose unchanged.

## Aggregate boundary

Two fixed worlds are included:

```text
left active provenance  = {e0}
right active provenance = {e1}
```

Both `e0` and `e1` belong to the same Purpose, so the two worlds have identical Purpose-level committed quantities.

TLC rejects the claim that aggregate state determines explanation:

```text
AggregateDeterminesExplanation  violated in the initial state
```

The same witness also rejects the claim that aggregate state determines event-specific undo:

```text
AggregateDeterminesNamedUndo  violated in the initial state
```

`undo(e0)` is meaningful in the left world and not in the right world even though their anonymous household aggregates are identical.

## Finding

Resource identity and provenance identity are different semantic demands.

The household resource can remain anonymous while explanation and event-specific undo retain identity only for the events that created the current constraint.

A concise reading is:

> Identity should attach to what the vocabulary needs to name, not automatically to the resource being accounted for.

Observation 017 removed persistent resource Unit identity from the anonymous household boundary. Observation 018 does not bring it back. Instead, explanation introduces a narrower identity boundary around provenance events.

This suggests a possible separation:

```text
anonymous household quantities
        |
        v
operational aggregate state

identified provenance events
        |
        v
explanation / targeted undo
```

The two views can refer to the same household commitments without assigning identities to pieces of money.

## Why TLA+ was enough

The question is about repeated activation and event-specific undo, so transition semantics are the distinct work required here.

No Alloy or J is added because the finite collision is already explicit and no quotient geometry needs surveying. No Lean is added because no new general theorem beyond the existing sufficiency/recoverability observations has yet emerged. No miniKanren is added because there is no backward synthesis question.

## Boundary of the claim

This is deliberately small:

- two Purposes;
- capacity two per Purpose;
- four commitment event identities;
- each event contributes one indivisible commitment quantum;
- no partial undo;
- no arbitrary event amounts;
- no due dates;
- no causal chains between events;
- no persistence or append-only law;
- no resource consumption or reassignment in this observation;
- no claim that event identity is globally minimal for every explanation vocabulary.

The result does not yet show that a production provenance log can be append-only, that reversal should replace undo, or that every useful household explanation can be reconstructed from these event records.

## Consequence for the implementation-language question

Observation 018 weakens the case that the quantitative core needs identity-rich structures.

An aggregate core may remain close to Purpose × Quantity projections, which keeps array-oriented implementations plausible.

At the same time, explanation and targeted correction create an identified relational layer around provenance events. That layer may favor stronger algebraic data, typed relations, or explicit event records.

The final language question may therefore be less "array language or typed language?" and more:

> can one language express both the anonymous quantitative projection and the identified provenance boundary without making either one unnatural?

## Next pressure point

The current model mutates an `active` set directly.

Ask whether provenance itself can remain append-only:

```text
commit event
reversal event referring to commit event
        |
        v
current active commitments
```

If current commitment and explanation can both be derived from an append-only event history, then identified provenance may be the retained source while anonymous household state remains projection.

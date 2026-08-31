# Observation 072 — Does a spend-shaped quantity fact determine what the person meant to remember?

## Question

The first practical `record` dogfood exposed internal projection language directly. A live user naturally answered:

```text
Where?    スーパー
Change?   1280
Measure?  wallet
```

`Change?` was not understood; a number was entered only after the interface rejected non-numeric input. The later `spend` entrance fixed the action boundary by asking only:

```text
Paid from? wallet
Amount?    1280
```

and mapping that action onto the existing neutral practical fact:

```text
wallet / jpy / -1280
```

That interaction is now understandable, but one piece of the first answer disappeared: `スーパー`.

Observation 072 asks:

> Does the retained Event/Effect quantity fact determine the human context that made the event recognizable to the person recording it?

The observation deliberately does **not** decide whether `スーパー` is a merchant, place, purpose, category, description, note, counterparty, or some combination of those meanings.

## Why no Alloy, TLA+, or new Lean law

This pressure is an information-separation question, not yet a structural constraint, temporal protocol, or arithmetic law.

A two-world witness is enough. Adding a formal tool here would restate a distinction already visible in the retained information rather than answer a harder question.

## Two-world witness

Consider two possible worlds with the same practical Event representation:

```text
EventId   = record-1
EffectKey = effect-1
Locus     = wallet
Measure   = jpy
Quantity  = -1280
```

In world A, the person meant to retain:

```text
スーパー
```

In world B, imagine the same amount paid from the same wallet but the person meant to retain a different recognizable context, for example:

```text
薬局
```

The second value is only a counterfactual witness, not additional user data.

The Practical Core representation can be identical in both worlds because:

- `EventId` is opaque identity and does not encode purpose or description;
- `EffectKey` is opaque effect identity;
- `Locus` says where the quantity effect is observed, not where a purchase occurred or what it concerned;
- `Measure` says what quantity is measured;
- `Quantity` says how much changed.

Therefore:

```text
Event identity
+ Effect identity
+ Locus
+ Measure
+ Quantity

        does not determine

human descriptive context
```

## Finding

The dogfood evidence earns one narrow distinction:

```text
quantity-placement fact
    !=
what made the event recognizable to the person
```

More specifically, the existing `Locus` coordinate must not be overloaded to carry this information. The user's `スーパー` answer showed that ordinary language such as “where?” can point to a different axis than LOAM's quantity locus.

This is also why encoding `スーパー` into `EventId` would be semantically dishonest. Identity must remain usable even when two events have the same description, and changing a description must not silently become a different occurrence merely because its token changed.

## What is not earned

Observation 072 does **not** yet earn any of these Practical Core primitives:

```text
Merchant
Place
Purpose
Category
Counterparty
Description
Note
```

One live answer is insufficient to determine which of those distinctions future questions actually require. They may also turn out to be several independent relations rather than one field.

The observation only establishes that the currently retained quantity fact cannot reconstruct all human-facing context that a recorder may naturally expect to preserve.

## Practical consequence

`loam spend` should remain narrow for now:

```text
Paid from?
Amount?
```

It successfully translates one familiar action into the neutral Core without inventing new domain ontology.

The missing `スーパー` information should stay visible as unresolved pressure rather than being smuggled into `Locus`, `EventId`, or another existing token.

A useful next question is not “which field should we add?” but:

> Which later questions does the person actually want `スーパー` to answer?

Examples might eventually distinguish “where did I pay?”, “what was this for?”, “show similar events”, or simply “help me recognize this record”. Until dogfooding separates those questions, the smaller model is preferable.

## Practical Core impact

None yet.

No Core type, persistence format, CLI prompt, Alloy model, TLA+ model, or Lean theorem is added by this observation.

# Observation 003 — History-Sensitive Futures

## Question

Can two histories converge to exactly the same current Unit placement, yet differ in whether a future operation is enabled because that operation refers to continuity through time?

Observations 001 and 002 established a representational boundary. Observation 003 asks whether the lost history can become behaviorally relevant.

## Why TLA+ enters here

The question is no longer only whether a finite structure exists. It asks about a reachable state and the actions enabled from that state.

`TLA+` is therefore introduced for the first time in loam. Alloy and J remain responsible for the earlier structural and projection observations; they are not duplicated here.

## Model

`tla/HistorySensitiveFutures.tla` follows two histories over two Units and two Purposes.

Besides current placement, each history carries a small summary:

- `leftStayed`
- `rightStayed`

A Unit remains in that set only while it has stayed at the target Purpose continuously since the beginning of the modeled history.

The two histories begin with different placements and then take one `Converge` step to the same complete placement:

```text
[u0 |-> p0, u1 |-> p1]
```

After convergence, not merely the counts but the complete current `Unit -> Purpose` functions are equal.

## Two kinds of future action

The model provides a control action and a history-sensitive action.

### Presence-based action

`LeftPresenceUse` and `RightPresenceUse` depend only on whether the current placement contains a Unit at the target Purpose.

The invariant

```text
SameCurrentImpliesSamePresenceEnabled
```

is checked before the history-sensitive hypothesis. It survives the explored behavior.

### Continuity-based action

`LeftContinuityUse` and `RightContinuityUse` require `u0` to have remained continuously at the target Purpose.

Their enabledness is observed with TLA+'s `ENABLED` operator, not approximated by a separately named boolean.

The hypothesis is:

```text
SameCurrentImpliesSameEnabled
```

If current placement alone were sufficient for this future rule, two equal current placements would give the same enabledness.

## TLC counterexample

TLC 2.19 from the TLA+ 1.7.4 tools finds a two-state counterexample.

Initial state:

```text
leftPlace   = [u0 |-> p0, u1 |-> p1]
leftStayed  = {u0}

rightPlace  = [u0 |-> p1, u1 |-> p0]
rightStayed = {u1}
```

After `Converge`:

```text
leftPlace   = [u0 |-> p0, u1 |-> p1]
rightPlace  = [u0 |-> p0, u1 |-> p1]

leftStayed  = {u0}
rightStayed = {}
```

At this point the complete current placement is identical on both sides.

The presence-based action has the same enabledness on both sides, but the continuity-sensitive action does not:

- Left can satisfy the continuity condition for `u0`.
- Right cannot.

TLC therefore violates `SameCurrentImpliesSameEnabled` as expected.

## Finding

For operations whose semantics depend only on current state, the current state can be sufficient.

For an operation whose semantics explicitly depend on continuity through prior states, even exact current Unit placement is insufficient unless some history or adequate history summary survives.

This is a conditional information-boundary result. It does **not** establish that household budgeting ought to make continuity significant. The history-sensitive action is deliberately introduced to test what follows *if* a future domain rule cares about continuity.

The important distinction is therefore not simply:

```text
state vs history
```

but:

```text
future vocabulary that is current-state-sensitive
vs
future vocabulary that is history-sensitive
```

Only the second forces additional temporal information to remain observable.

## Next question

How small can the surviving temporal summary be while preserving every future distinction that a chosen operation vocabulary can observe?

That asks whether full history is unnecessary and whether a minimal sufficient state can be discovered instead.

This remains naturally an Alloy + TLA+ question for now:

- Alloy can search alternative summary structures.
- TLA+ can test whether those summaries preserve future behavior.

J becomes useful again if many candidate summaries need to be compared as projections. Lean 4 should wait until a stable general law emerges. miniKanren should wait until there is a genuine reverse-search question.

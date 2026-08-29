# Observation 019: Append-only provenance

## Question

Can current commitment state remain a derived projection of an append-only provenance history rather than mutable primary state?

Observation 018 showed that resource quantities can remain anonymous while commitment event identity supports explanation and targeted undo. This observation asks whether undo itself can stop mutating current state and become another event in history.

## Model

The model keeps two views side by side.

The proposed primary representation is an append-only sequence of named provenance events:

- `Commit(c)` appends a commitment event.
- `Reverse(r)` appends a reversal event whose `ReverseTarget[r]` names an active commitment event.
- no earlier event is removed or rewritten.

From that history the model derives:

- `ActiveFromHistory`
- Purpose-local committed quantity
- Purpose-local available quantity
- current explanation as the still-active commitment event identities

A mutable `oracleActive` set is retained only as a comparison oracle. It is updated in the ordinary destructive style and is not proposed as primary data.

The temporal property `HistoryOnlyExtends` requires every next history to have the previous history as a prefix.

The model has four commitment events and four reversal events. Because the finite event vocabulary can be exhausted, deadlock checking is disabled; terminal histories are intentional finite endpoints, not semantic failures.

## Executed result

TLA+ tools 1.7.4 / TLC 2.19 completed the positive model with no error:

```text
1 initial state
7,365 states generated
7,365 distinct states found
0 states left on queue
complete state graph depth: 9
```

The following properties held throughout the complete reachable state graph:

```text
TypeOK
ProjectionMatchesOracle
CapacityOK
CurrentExplanationMatchesAggregate
AvailableMatchesOracle
ReversalKeepsCause
TargetedReverseIsExact
HistoryOnlyExtends
```

Thus, in this finite model, the append-only history projection agrees with the mutable active-state oracle for current commitments, current explanation, and available quantity while the history itself only grows by appending events.

## Boundary: the present does not reconstruct the past

A separate boundary model fixes two histories:

```text
leftHistory  = <<>>
rightHistory = <<"c0", "r0">>
```

Both have the same current projection:

- no active commitment,
- zero committed quantity at every Purpose,
- the same current explanation.

But the histories are not equal. TLC therefore violates `CurrentProjectionDeterminesHistory` immediately in the initial state.

So the information flow is intentionally one-way:

```text
append-only provenance history
        |
        v
current commitments / explanation / availability
```

The current projection can be derived from history, but the history cannot in general be reconstructed from the current projection.

## Finding

> A reversible present need not require mutable provenance.

For this model, a named reversal event can preserve the earlier commitment event while changing the derived present. Current household state can therefore be a projection of append-only provenance rather than a separately authoritative mutable record.

This does not mean the history is merely an implementation log. The boundary witness shows that it retains distinctions that the current projection deliberately forgets.

## What this does not establish

This observation does not claim:

- that all household facts should be event-sourced,
- that append-only storage is always operationally preferable,
- that four commit and four reversal events cover realistic histories,
- that concurrent writers or distributed ordering are solved,
- that reversal chains, corrections, reclassification, or schema evolution are settled,
- that a particular database, serialization format, or implementation language follows from the model.

It also does not yet establish whether reversal events themselves need durable identity beyond their reference to earlier provenance events.

## Tool choice

TLA+ alone is used because the question is specifically about histories, append-only transitions, reversal behavior, and preservation of projections over reachable states. Alloy, J, Lean, and miniKanren are not added because this observation does not currently require a distinct structural counterexample search, quantitative quotient view, general theorem, or backward synthesis result.

## Next pressure point

Can corrections remain append-only when the correction changes not only active/inactive status but the meaning of an earlier event, for example its Purpose or quantity, while explanation remains truthful about both the original observation and the later correction?

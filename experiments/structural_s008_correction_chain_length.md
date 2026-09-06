# Structural S008 — correction-chain length independence

Status: **OBSERVING / UNTESTED**

Structural specimen: **S008**

## Question

Application 007 already demonstrated representative correction-frontier behavior for:

```text
A -> B -> C
X -> Y
U
```

and production `CorrectionFrontier` now admits disjoint finite paths rather than only one Correction.

S008 asks whether an important frontier property still depends on those short specimens:

> For an admitted finite linear Correction chain of arbitrary length, does exactly the terminal Event from that chain remain in the current frontier?

The pressure is history length, not a request for more graph semantics.

## Current production structure

`Loam.Application.correctionFrontierMemory?` first requires `correctionFrontierAdmissible`, which rejects:

- missing endpoints;
- repeated targets / sibling Corrections;
- repeated replacements / implicit multi-parent merge;
- cycles.

For a successful frontier, the implementation then removes every remembered Event that appears as a Correction target.

That suggests a stronger and smaller route than checking lengths 1, 2, 3, 4 separately:

```text
successful frontier membership
  = remembered Event
    AND not targeted by any retained Correction
```

If this law is proved directly against production semantics, path length disappears from frontier membership.

## Lean probe

This branch adds one proof-only theorem to the existing Application module:

```text
correctionFrontierMemory?_mem_iff
```

It states that whenever `correctionFrontierMemory?` returns `some frontier`:

```text
event ∈ frontier.events
  <->
event ∈ events.events
  AND
no retained Correction targets event.id
```

No runtime branch or data representation changes.

`Loam/Observations/StructuralS008.lean` then proves:

```text
arbitrary_linear_chain_terminal_only
```

for an arbitrary finite `List Event` selected as one admitted chain. Under the chain-local conditions:

- the terminal belongs to the chain;
- every chain Event is remembered;
- every nonterminal chain Event is targeted by some retained Correction;
- the terminal Event is not targeted;

exactly the terminal Event from that chain belongs to the successful production frontier.

The theorem has no fixed chain-length bound.

## Mapping witness

A direct production specimen also checks a longer chain than Application 007:

```text
A -> B -> C -> D -> E
```

with quantities:

```text
A  10
B  20
C  30
D  40
E  50
```

The expected correction-aware quantity is exactly `50`, the terminal Event quantity.

This concrete witness is only a bridge back to the executable production projection. The arbitrary-list theorem carries the structural result.

## Expected qualification

If dedicated Structural S008 Lean CI succeeds, the narrow finding is:

```text
successful admitted Correction frontier
  + finite linear chain of arbitrary length
      -> frontier contribution from that chain is terminal-only
```

The reason is not a recursive last-wins rule. Once admission succeeds, membership is determined by explicit target evidence.

## Boundaries

S008 does **not** introduce or qualify:

- a generic graph framework;
- arbitrary directed-graph semantics;
- winner semantics for sibling Corrections;
- multi-parent Correction merge semantics;
- missing-endpoint recovery policy;
- cycle repair;
- chronology or list-position authority;
- EventResolution integration;
- persistence changes;
- CLI/TUI behavior;
- new canonical household facts.

Branching, merging, dangling references, and cycles remain outside the admitted premise and continue to fail closed.

The Application change is theorem-only: it exposes a law already implemented by the current frontier selector and changes no runtime result.

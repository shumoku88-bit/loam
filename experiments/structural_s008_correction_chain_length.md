# Structural S008 — correction-chain length independence

Status: **DONE / SURVIVED**

Structural specimen: **S008**

## Question

Application 007 demonstrated representative correction-frontier behavior for:

```text
A -> B -> C
X -> Y
U
```

S008 asked whether the current terminal-selection result was only a short-history specimen, or whether successful frontier membership is independent of finite Correction-chain length.

The pressure was history length, not a request for more graph semantics.

## Production law

`Loam.Application.correctionFrontierMemory?` first requires `correctionFrontierAdmissible`, which rejects:

- missing endpoints;
- repeated targets / sibling Corrections;
- repeated replacements / implicit multi-parent merge;
- cycles.

For a successful frontier, the implementation removes every remembered Event that appears as a Correction target.

This branch exposes that already-existing runtime behavior as the proof-only theorem:

```text
correctionFrontierMemory?_mem_iff
```

For any successful frontier:

```text
event ∈ frontier.events
  <->
event ∈ events.events
  AND
no retained Correction targets event.id
```

No path-length term occurs in the characterization.

## Structural consequence

`Loam/Observations/StructuralS008.lean` proves:

```text
arbitrary_linear_chain_terminal_only
```

for an arbitrary finite `List Event` selected as one admitted path witness. Under the local conditions:

- the terminal belongs to the selected list;
- every selected Event is remembered;
- every nonterminal selected Event is targeted by some retained Correction;
- the terminal Event is not targeted;

exactly the terminal Event from that selected list belongs to the successful production frontier.

The theorem deliberately does not encode a second adjacency / graph representation for the list. Whether the retained Corrections are admissible is delegated to the existing production frontier. The structural result is stronger and smaller: once admission succeeds, target evidence determines membership and path length disappears.

## Production mapping witness

The same Lean module checks a longer concrete production path than Application 007:

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

The existing `quantityAtCorrectionFrontier?` returns exactly `50`, the terminal Event quantity.

This specimen maps the general membership law back to the executable quantity projection. It is not the basis of the unbounded result.

## Qualification

Dedicated Structural S008 Lean CI completed **SUCCESS** on exact executable branch head:

```text
11684a1c112b032f6df04542551f4ebfa79d7e62
```

workflow run:

```text
34008008290
```

The successful job compiled:

- the production `correctionFrontierMemory?_mem_iff` theorem;
- `StructuralS008.arbitrary_linear_chain_terminal_only`;
- the five-Event / four-Correction production quantity witness.

An earlier run failed only because the first observation proof used an unavailable `by_contra` tactic in the minimal import environment. The production membership theorem had already compiled in that run. Replacing the proof script with `by_cases` changed no statement or runtime semantics.

## Finding

S008 survives at the selected boundary:

```text
successful admitted Correction frontier
  -> remembered untargeted Events survive
  -> remembered targeted Events do not survive
```

Therefore, for any selected finite admitted path whose nonterminal Events are targets and terminal Event is untargeted:

```text
frontier contribution from that path = terminal only
```

The important reason is not recursive last-wins traversal. It is the simpler production law:

```text
frontier membership
  factors through
explicit Correction target evidence
```

So increasing an admitted linear path from length 1 to 2, 3, 4, or any other finite length does not introduce another frontier-selection degree of freedom.

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

The Application change is theorem-only. It exposes a law already implemented by the current frontier selector and changes no runtime result.

## Production impact

None.

No new retained fact, type, persistence syntax, writer behavior, or projection is introduced.

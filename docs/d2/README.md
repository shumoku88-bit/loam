# D2 structural audit projections

LOAM uses D2 as a complementary visual audit instrument beside DRAKON.

The two views have deliberately different jobs:

```text
DRAKON
  execution order
  decisions and refusal paths
  retry / recovery flow

D2
  structural topology
  ownership / authority relationships
  shared roots and divergent consumers
  proof-obligation / dependency shape
```

D2 does **not** replace DRAKON, and neither diagram family is semantic authority. Production source, retained evidence, formal models, proofs, and qualification results remain authoritative. Committed `.d2` files are inspectable audit projections over that evidence; generated SVG / ASCII output is disposable.

D2 is also not a production or steady-state CI dependency. Install the CLI when rendering or inspecting these projections locally.

## When to use which view

Use DRAKON when the main question is:

- what runs first or next;
- where an operation refuses;
- how a retry or recovery path behaves;
- which local branch leads to which outcome.

Use D2 when the main question is:

- what depends on what;
- which authorities are read or written;
- where ownership is shared without semantic authority being merged;
- which consumers share a semantic root but require different payloads or obligations;
- whether a proof / obligation DAG exposes a structural distinction that procedural flow obscures.

Do not produce both views mechanically. A second projection must answer a distinct audit question.

## Accepted projection 1: Current Actual target comparison

`current_actual_target_comparison.d2` projects the same evidence already recorded by:

- `docs/research/CURRENT_ACTUAL_TARGET_OBLIGATION_DAG.md`;
- `docs/drakon/build_current_actual_target_audit_map.py`.

The useful structural distinction is that Correction and Reversal consume the retained Event payload after the shared correction-current root, while Date correction consumes Event identity only. The projection therefore makes shared semantics visible without implying that one shared runtime helper is justified.

DRAKON remains the stronger view for exact target-selection order and refusal routing.

## Accepted projection 2: Scheduled / Actual ownership topology

`scheduled_actual_ownership_topology.d2` projects a materially different kind of evidence: several production operations share one fixed ownership mechanic while retaining different semantic authority responsibilities.

The shared mechanic is intentionally small:

```text
Scheduled writer ownership
        ->
Actual writer ownership
```

Creation, replacement, completion, cancellation, reversal, and initial AccountingRole publication do not thereby become one semantic operation. They read and mutate different authorities for different reasons. AccountingRole additionally extends the ownership order through current-quantity-anchor and role ownership.

This projection makes the distinction between shared lock mechanics and separate semantic authority easier to inspect than a procedural flow diagram.

## Render

Install the D2 CLI and verify it first:

```sh
d2 version
```

From the repository root, render every committed D2 projection to both SVG and ASCII:

```sh
sh docs/d2/render.sh
```

Outputs are written under the already-ignored `scratch/d2/` tree with matching base names, for example:

```text
scratch/d2/current_actual_target_comparison.svg
scratch/d2/current_actual_target_comparison.txt
scratch/d2/scheduled_actual_ownership_topology.svg
scratch/d2/scheduled_actual_ownership_topology.txt
```

On macOS, render and open all SVG projections in Safari:

```sh
sh docs/d2/render.sh --open
```

The renderer uses ELK and an explicit SVG scale so local browser zoom and scrolling remain useful.

## Maintenance rule

Keep D2 small and question-driven.

- Do not mirror every DRAKON map.
- Do not add a generic diagram framework merely because two renderers exist.
- Do not infer a shared runtime abstraction merely from a visually shared node or edge.
- Prefer source-derived or proof-derived distinctions over presentation convenience.
- Add a D2 projection only when topology, ownership, authority, or obligation shape is itself under inspection.

The two accepted projections establish that D2 can expose distinct information in materially different audit subjects. If repeated future use creates real duplication between DRAKON builders and D2 sources, then test a small neutral observation representation from which both can be projected. That shared representation is not required yet.

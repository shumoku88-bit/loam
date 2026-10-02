# LOAM Observatory v0 hypothesis

Date: 2026-10-03  
Status: **current interaction experiment; GPU-first, read-only, replaceable**

## 1. Purpose

LOAM's production TUI already owns ordinary household operation well: recording,
correction, scheduled maintenance, navigation, and dense textual review.

The GUI should therefore not reproduce those workflows in a window.

LOAM Observatory exists for questions that benefit materially from a spatial GPU
surface:

- Where am I inside the current pension cycle?
- Where did pressure accumulate across the cycle?
- Which future obligations bend the remaining path?
- What evidence produced this visible quantity?
- How does an aggregate unfold into provenance and authority?

The first instrument is **Pension Orbit**. The second is **X-Ray**.

## 2. Semantic boundary

Observatory is downstream of LOAM's existing Review / Presentation answers.

```text
Core / Authority / Application / Review / Presentation
                         |
                         v
              renderer-neutral scene snapshot
                         |
                         v
                Observatory renderer
```

The renderer must not:

- read canonical household files as an independent accounting engine;
- derive balances, Daily Pace, Scheduled meaning, or provenance by itself;
- mutate household authority;
- invent missing evidence;
- make GPU layout state canonical.

The scene snapshot is a projection. Operational household data remains unchanged.

## 3. Product split

```text
Production TUI
  record / correct / maintain / operate

LOAM Observatory
  observe / navigate / compare / explain
```

Observatory v0 is intentionally read-only.

If a user wants to change household facts, the correct route remains the TUI or
an existing qualified command boundary.

## 4. Pension Orbit

The pension cycle is not a pie chart. It is a temporal path.

One complete orbit represents the interval from one pension-cycle boundary to
the next. Time determines position along the path.

At distance, the scene answers the whole-cycle question:

- previous boundary;
- today;
- next boundary;
- Actual density behind today;
- Scheduled pressure ahead of today;
- selected event markers;
- current usable-per-day answer.

As the camera approaches, semantic zoom reveals progressively finer evidence:

```text
cycle
  -> month / week region
  -> day
  -> event / transaction
  -> evidence entry point
```

The orbit may use depth, width, deformation, particles, opacity, and lighting to
encode presentation meaning, but those mappings must remain explainable and
must never replace exact text on selection.

## 5. X-Ray

X-Ray begins from a selected visible answer or event.

It expands the selected object into its contributing LOAM evidence. Depth should
carry semantic meaning rather than arbitrary force-directed graph layout.

Candidate depth order:

```text
visible household concept
    -> review / presentation answer
    -> movement / scheduled / quantity structure
    -> authority / provenance
    -> retained evidence
```

X-Ray must preserve explicit unknown / incomplete states. A missing relation is
not drawn as a guessed one.

## 6. Renderer architecture

The durable boundary is renderer-neutral. No current GPU library is household
semantics.

The first implementation may use Tauri as a replaceable desktop shell and may
evaluate modern WebGPU-capable renderers. A short implementation spike should
choose the renderer based on:

- visual quality;
- camera and picking quality;
- WebGPU behavior on supported hardware;
- graceful fallback on older hardware;
- profiling and debugging quality;
- maintenance cost;
- ability to keep business logic outside the renderer.

A later native GPU renderer must be able to consume the same conceptual scene
snapshot without changing LOAM household meaning.

## 7. Visual standard

This experiment is not justified by merely being three-dimensional.

Do not keep it if the result is a conventional dashboard with decorative depth.

The target is a quiet scientific instrument:

- nearly full-screen spatial canvas;
- minimal persistent chrome;
- restrained labels that appear with focus;
- smooth camera movement;
- high-quality lighting and depth cues;
- adaptive quality rather than a separate low-quality design;
- exact values available on selection;
- no neon-console ornament for its own sake.

## 8. v0 implementation order

1. Define the smallest renderer-neutral Pension Orbit snapshot.
2. Render one real pension cycle from LOAM read answers.
3. Add camera focus, picking, and semantic zoom.
4. Add adaptive GPU quality and measure frame behavior on real hardware.
5. Reach the intended visual bar for Orbit.
6. Only then add X-Ray.

Do not build a menu system, recording forms, settings application, or duplicate
report catalog first.

## 9. Acceptance criteria

Orbit v0 survives only if:

- it consumes qualified LOAM read answers rather than reconstructing household semantics;
- a real pension cycle is navigable as one coherent spatial object;
- past, today, and future obligations are distinguishable without opening separate report screens;
- selecting a point exposes exact text and identity;
- camera movement remains usable on the current household machine through adaptive quality;
- the experience is materially unavailable in the production TUI.

X-Ray is a separate acceptance gate after Orbit.

## 10. Kill criteria

Retire or redesign the experiment if:

- 3D is decorative rather than explanatory;
- ordinary TUI tasks migrate into Observatory without a spatial reason;
- renderer code begins recreating Review calculations;
- the scene snapshot becomes a second canonical household schema;
- GPU effects obscure exact quantities or provenance;
- maintaining the visualization costs more than the distinct household answer it provides.

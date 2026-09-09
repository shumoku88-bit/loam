# Household operating mode

Status: current from 2026-09-09 until explicitly replaced.

This document describes the present relationship between LOAM, HRA, and real household data.

## Operational authority

LOAM is the current day-to-day household system and the operational authority for ordinary recording.

New household events are recorded in LOAM during normal use. The selected LOAM data and manifest authorities therefore carry operational household meaning, not only research or dogfood meaning.

HRA is no longer the parallel day-to-day authority. It remains useful as historical implementation, migration provenance, and comparison material where a concrete question requires it.

## Current LOAM data

Selected `loam-data` objects, manifests, and configuration are current household data.

The implementation may continue to change substantially, but changes to operational data need an explicit migration, reconstruction, or other qualified transition that preserves the household meaning being carried forward. Do not delete or regenerate current household data merely because a different representation would be cleaner.

This distinction is important:

```text
implementation shape
    may change freely when the result is qualified

operational data representation
    may change through an explicit migration or reconstruction

household facts
    must not be silently invented, discarded, or altered
```

If evidence required for a migration or historical claim is unavailable, fail closed rather than guessing.

## HRA is historical reference, not LOAM ontology

HRA may still supply historical evidence, comparison answers, or useful interaction ideas. It is not a schema that LOAM must reproduce.

Do not automatically import HRA concepts, file shapes, package boundaries, report sections, or vocabulary into LOAM Core. Do not build a synchronization layer merely to keep the two systems structurally identical.

A temporary importer, replay, comparison, or parity tool is justified when it answers a concrete migration or research question. Retire it when that question no longer requires it.

## Comparison claims are explicit

No general HRA ↔ LOAM parity is assumed.

When work claims parity, state the observable boundary being compared, such as exact quantity, retained identity, occurrence time, correction behavior, scheduled state, or report classification. Passing one boundary does not imply full-system equivalence.

Historical research documents may describe an earlier HRA-authority phase. Those statements remain historical records and do not override this current operating policy.

## Development rhythm

The intended rhythm is now:

```text
real life
    -> record operationally in LOAM
    -> use the system normally
    -> change code when a concrete need or simplification appears
    -> migrate operational data explicitly when representation changes require it
    -> keep historical research claims scoped to their evidence
```

There is no requirement to keep adding features when ordinary use does not expose a need.

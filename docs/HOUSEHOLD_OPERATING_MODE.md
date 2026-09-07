# Household operating mode

Status: current from 2026-09-07 until an explicit replacement or cutover.

This document fixes the present relationship between HRA, LOAM, and real household data. It is an operating constraint for current development, not a claim that the arrangement is permanent.

## Operational authority

HRA is the current day-to-day household system and the operational authority for ordinary recording.

New real household events continue to be recorded in HRA during normal use. If a practical household answer is needed and HRA and LOAM disagree, the disagreement is not resolved merely by treating LOAM as newer or more experimental.

## LOAM is parallel real-data dogfood

LOAM remains a real household system under active construction, not a synthetic-only prototype.

Real household events may also be recorded in LOAM during ordinary development, including through the user, ChatGPT, terminal AI, or other explicit LOAM entrances. This parallel recording exists to pressure the design with real events while the whole stack is still changeable.

Exact mirroring of every HRA record is not a standing requirement. A particular experiment may require parity, complete replay, or reconciliation, but that requirement must be stated for that experiment.

Divergence between HRA and LOAM can itself be useful evidence about missing concepts, awkward recording paths, information loss, or accidental coupling.

## What `canonical` means inside LOAM now

A selected LOAM object, manifest generation, or `loam-data` artifact may be canonical **for the current LOAM experiment**. It is not, during this operating mode, the final operational authority for household reality.

Therefore all of the following remain redesignable:

- Core and Application concepts;
- persistence and wire formats;
- identifiers and naming;
- writer and admission protocols;
- manifest and authority layouts;
- routing and classification evidence;
- TUI / CLI interaction contracts;
- LOAM canonical household data itself;
- LOAM-local migration and provenance machinery.

A clearer model may rewrite, regenerate, replace, or delete these instead of carrying compatibility forward.

## Destructive redesign does not mean invented history

The freedom to destroy LOAM representations is architectural freedom, not permission to silently manufacture household facts.

When a change claims something about real household history, identity, quantity, occurrence, provenance, or parity with HRA, keep or reconstruct enough evidence to justify that claim. Fail closed when the required evidence is unavailable.

Conversely, do not preserve an obsolete LOAM artifact merely because deleting it would lose continuity that no current research question observes. HRA can remain the operational source from which a later LOAM representation is reconstructed when that is the smaller and clearer path.

## HRA is pressure, not LOAM ontology

HRA is allowed to supply real events, comparison answers, and reconstruction evidence without becoming LOAM's schema.

Do not automatically import HRA concepts, file shapes, package boundaries, report sections, or vocabulary into LOAM Core. Do not build a permanent synchronization layer merely to keep the two systems structurally identical.

A temporary importer, replay, comparison, or parity tool is justified when it answers a concrete research or reconstruction question. Retire it when the question no longer requires it.

## Comparison claims are explicit

No general HRA ↔ LOAM parity is assumed.

When work claims parity, state the observable boundary being compared, such as exact quantity, retained identity, occurrence time, correction behavior, scheduled state, report classification, or another named projection. Passing one boundary does not imply full-system equivalence.

## Returning LOAM to operational authority

LOAM does not become the day-to-day authority again merely because it becomes convenient to use.

A future return requires an explicit cutover decision. That cutover should name the authoritative HRA snapshot or reconciliation boundary, establish whatever current LOAM evidence is required, qualify the intended operational paths, and then update this document and the standing policy together.

Until that happens, the intended rhythm is:

```text
real life
    -> record operationally in HRA
    -> also exercise LOAM with real events when useful
    -> redesign any LOAM layer, including canonical data
    -> use evidence only as strongly as the current claim requires
    -> keep searching for the smaller coherent system
```

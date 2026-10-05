# Let's Kakeibo interaction study

Date: 2026-10-01  
Status: **condensed current checkpoint — detailed archaeology retired to Git history**

This directory keeps the smallest current synthesis from the completed Let's家計簿
interaction-study cycle.

The study asked which interaction ideas from a long-lived desktop household
application remain useful when LOAM keeps its own authority, provenance,
correction, Scheduled, Movement, and Measure semantics.

## Current retained artifacts

- [LESSONS_FOR_LOAM_DESK.md](LESSONS_FOR_LOAM_DESK.md) — the distilled interaction conclusions that still matter to LOAM.
- [SOURCES.md](SOURCES.md) — source catalog and provenance for the external-product study.
- [LOAM Observatory v0](../LOAM_OBSERVATORY_V0_HYPOTHESIS.md) — the current forward-facing visualization hypothesis.

## Durable findings

The completed study found a few recurring interaction ideas worth keeping as
hypotheses rather than requirements:

- a chronological household table is a strong daily-work center;
- date navigation should be cheap and local;
- repeated entry can reuse visible, explicit proposals without inventing meaning;
- important aggregates should drill back to contributing evidence;
- future household obligations can be shown together while preserving their
  distinct underlying semantics;
- interaction habits can remain stable even when implementation machinery is
  replaced underneath them.

These findings are summarized in `LESSONS_FOR_LOAM_DESK.md`. They are not a
request to clone Let's家計簿 or to import its data model into LOAM.

## Retired detailed material

The first archaeology cycle, the separate Desk TUI experiment, and the
conventional GUI experiment are complete. Their detailed working material has
been graduated from the live repository surface to Git history, including:

- layout and feature inventories;
- interaction and input-mechanics deep dives;
- reporting, longevity, rewrite, portability, and package-inspection notes;
- extracted-help analysis and implementation-lineage notes;
- exploratory LOAM translation notes;
- completed Desk TUI / GUI shell hypotheses;
- the first-cycle open-question ledger.

No production code, canonical household data, semantic authority, test, or CI
contract depends on those retired documents.

For exact pre-distillation detail, inspect Git history at or before:

```text
3d998d9a0dabbe33c77522bddb8bea45b54087ed
cleanup: graduate completed research checkpoints to Git history (#1851)
```

## Research rule

Further Let's家計簿 archaeology should be demand-driven. Reopen detailed research
only when a concrete LOAM interaction question cannot be answered from the
retained synthesis, sources, current production behavior, or Git history.

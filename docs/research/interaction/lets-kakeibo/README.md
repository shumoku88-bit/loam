# Let's Kakeibo interaction study

Date: 2026-10-01  
Status: **compressed historical checkpoint; detailed archaeology graduated to Git history**

This directory preserves the surviving conclusions and provenance from the
Let's家計簿 interaction study. The first archaeology cycle, Desk TUI experiment,
and conventional GUI experiment are complete.

The detailed intermediate inventories, help reconstructions, package inspection,
translation notes, and retired shell hypotheses were removed from the live tree
on 2026-10-05 after their surviving meaning was consolidated here and in the
research conclusion. They remain available in Git history at:

```text
3d998d9a0dabbe33c77522bddb8bea45b54087ed
```

## Retained surfaces

- [LESSONS_FOR_LOAM_DESK.md](LESSONS_FOR_LOAM_DESK.md) — durable interaction
  conclusions and explicit do-not-copy boundaries.
- [SOURCES.md](SOURCES.md) — source catalog and provenance for the historical
  observations.
- [LOAM Observatory v0](../LOAM_OBSERVATORY_V0_HYPOTHESIS.md) — current
  forward-facing shell hypothesis.

## Surviving conclusions

The strongest ideas worth carrying forward are:

1. keep chronological household evidence central rather than replacing it with
   disconnected dashboard cards;
2. make date and evidence navigation cheaper than mode switching;
3. let useful aggregates lead back to the evidence that produced them;
4. keep household semantics stable underneath replaceable TUI/GUI shells.

Historical transfer storage semantics, hidden cell magic, direct editing of
derived balances, and automatic mutation during preview/cancel are not LOAM
design targets.

The separate Desk TUI was retired because it did not differ enough from the
production TUI. The conventional ledger-style GUI was also retired because
ordinary recording and inspection remained better served by the production TUI.

## Research lifecycle

Further Let's家計簿 archaeology is demand-driven only. Reopen the historical
material when a concrete current design question needs source evidence.

This study is interaction evidence, not household authority or a production UI
specification.

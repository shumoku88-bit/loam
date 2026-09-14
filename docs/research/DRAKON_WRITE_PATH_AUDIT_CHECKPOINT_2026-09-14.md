# DRAKON Write-Path Audit Checkpoint — 2026-09-14

## Status fixed at this checkpoint

Baseline main:

`5f5f0a23b4b66387f5c47447e132ec6117f51d0b`

Latest merged DRAKON atlas PR:

- #841 `docs(drakon): expand cross-path write atlas`

Immediately preceding architecture / compression PRs:

- #837 `refactor(movement): make admission own sparse Effect identity`
- #839 `docs(drakon): add macro architecture audit gate`
- #840 `refactor(movement): keep publication surface-neutral`

Open PRs at the time of this checkpoint: none.

This document freezes the current audit conclusions before further production refactoring.

---

## 1. Why this checkpoint matters

LOAM reached this point through several complementary forms of evidence.

Lean 4 and the earlier formal-method work established strong local semantic laws, typed boundaries, explicit failure conditions, and regression evidence. They made it possible to remove distinctions without guessing whether household meaning had changed.

DRAKON added a different kind of visibility: whole-path topology at a scale that both a human and a repository-aware AI can inspect together. It exposes where a semantic rule sits, which paths repeat the same mechanics, where an authority boundary changes, and where equal-looking boxes actually obey different recovery laws.

The current working interpretation is therefore:

> Formal methods made aggressive simplification safe enough to attempt; DRAKON made architectural placement and cross-path repetition visible enough to choose the right simplification.

DRAKON does not replace Lean, tests, or the repository as evidence. It appears to be the missing visual layer that closes the loop between formal semantics and whole-system architecture review.

---

## 2. Audit method now in use

The current review loop is:

```text
formal / typed semantic laws
        ↓
DRAKON whole-path observation
        ↓
visible seam, repetition, or awkward boundary
        ↓
repository-wide caller / authority / invariant check
        ↓
00 Architecture Audit Gate
        ↓
smallest justified production change
        ↓
Lean regression / qualification / CI
        ↓
DRAKON becomes smaller or clearer
```

A diagram is evidence for investigation, not proof by itself.

Repeated visual shape is never sufficient reason to merge semantics.

---

## 3. Macro architecture laws retained during micro-audit

The `00 Architecture Audit Gate` remains the required macro guardrail.

In particular, local compression must not spend these capabilities:

- minimal independent canonical evidence;
- explicit Measure separation and no implicit cross-Measure valuation;
- presentation-neutral semantics for TUI / future GUI / Web / AI adapters;
- high-level frontend ignorance of canonical paths, locks, durable identity allocation, serialization, and recovery mechanics;
- independent semantic authorities even when mechanics are shared;
- explicit unknown / incomplete state rather than collapsing it to zero / empty / false;
- fail-closed publication and preservation of operational household continuity;
- reports and answers remaining derived projections unless new independent evidence is required;
- locale-specific policy remaining at the edge so LOAM can be Japan-friendly without becoming Japan-bound;
- additive extension rather than weakening existing semantic laws for new features;
- conservative Core promotion only after repeated independent semantic pressure.

The Core-promotion rule remains:

```text
one feature needs it
    -> keep local

multiple independent uses need the same semantic thing
    -> shared-boundary candidate

same shape but different authority / meaning
    -> share mechanics only

same semantic primitive + independent reason to exist
    -> only then consider moving inward
```

The threshold is evidential, not numerical.

---

## 4. Map-driven refactors already resolved

### 4.1 Sparse Effect identity moved into Movement admission

The first detailed `10.2 Authoritative Movement Publish` / `10.3 Movement Admission` comparison showed that collector-local EffectKey canonicalization lived outside semantic admission.

Before #837, preview and authoritative publication could ask admission about different draft shapes.

#837 moved sparse Effect identity canonicalization into `MovementAdmission.admit?`, so only Relation-referenced EffectKeys earn durable identity. The same PR also:

- reduced `MovementAdmission.Admitted` to `world + eventId`;
- removed unused relation / discharge result echoes and duplicate Event result data;
- introduced `ActualAuthority.movementWorld` as the pure representation boundary from retained Actual evidence plus current Locus admission policy into `MovementAdmission.World`;
- added regressions for both anonymous unreferenced temporary keys and Relation-earned retained identity.

This was the first confirmed production compression found directly from the DRAKON map.

### 4.2 Presentation callback removed from Movement publication

The next DRAKON view made `beforePublish` visibly anomalous inside the authoritative publication corridor.

Repository inspection showed one production consumer, no post-callback user decision, and no independent cross-surface semantic need.

#840 therefore:

- removed the publisher-level presentation callback;
- retained the scriptable Movement CLI;
- routed the CLI through `HouseholdCommand.record`;
- kept publication presentation-neutral.

This was the second completed map-driven compression.

---

## 5. Cross-path atlas result

#841 expanded the DRAKON map to place three independent production paths at the same visual scale:

```text
Record Movement
Correct Actual
Complete Scheduled
```

### Record Movement

```text
Actual + current Locus policy
    -> Movement-specific admission
    -> one complete Actual generation
```

### Correction

```text
Actual + current Locus policy
    -> correction-specific admission
    -> one complete Actual generation
```

### Scheduled Completion

```text
Scheduled lifecycle + Actual + current Locus policy
    -> completion-specific Actual admission
    -> publish Scheduled terminal first
    -> publish Actual second
    -> retry interrupted completion with stable Actual identity
```

The important conclusion is negative as well as positive:

> Record and Correction share a one-Actual publication topology. Scheduled Completion does not. A generic semantic publisher must not be introduced merely because the lower-level staging and ownership shapes look similar.

Scheduled Completion owns independent semantics:

- two semantic authorities;
- fixed lock ordering;
- current-open Scheduled resolution;
- stable completion EventId selection;
- one-to-one terminal endpoint ownership;
- Scheduled-first / Actual-second publication order;
- retained terminal evidence remaining inert if Actual publication is interrupted;
- retry using the same Actual identity.

These are not accidental mechanics.

---

## 6. Newly confirmed audit finding: sparse Effect identity still diverges across paths

The `12.2 Completion Actual Admission` diagram exposed a second sparse-identity seam.

`MovementAdmission.admit?` now performs:

```text
raw draft
    -> canonicalizeDraft
    -> validateDraft
    -> Event construction
```

But Scheduled Completion currently performs the equivalent of:

```text
raw Movement draft
    -> validateDraft
    -> Event.ofEffects? using completion-selected EventId
```

without first applying the same collector-local EffectKey canonicalization.

Because Scheduled Completion currently refuses Relation / Discharge drafts, there is no independent Relation evidence that can earn durable Effect identity. Yet collector-produced EffectKeys can still reach the completion Event construction path.

Correction has the same architectural risk: the correction replacement Event is built directly from `draft.effects`, while the TUI correction editor reuses Record's collector mechanics.

Current semantic expectation:

> Collector-local Effect identity should not become durable merely because the same practical Movement enters through Correction or Scheduled Completion instead of Record. Durable Effect identity must remain earned by independent semantic evidence.

This is now a **confirmed production audit target**, but the exact shared primitive and regression shape are not fixed by this checkpoint.

Preferred direction to investigate:

- extract the smallest pure sparse-Effect-identity canonicalization mechanism;
- keep it out of neutral `Core.Event` unless Core itself owns that law;
- reuse it from Record, Correction, and Scheduled Completion admission paths;
- add regressions that demonstrate unreferenced collector keys disappear in all three paths.

Do not solve this by merging the three publishers.

---

## 7. Strong mechanics-sharing candidate: Movement world construction

Record already uses:

`ActualAuthority.movementWorld`

as the pure representation boundary:

```text
ActualEvidence + current LocusAdmissionVocabulary
    -> MovementAdmission.World
```

Scheduled Completion still reconstructs the same world shape manually after loading the same two independent authorities.

This is a strong candidate for direct reuse because:

- the source semantic authorities remain separate;
- no new authority is created;
- the resulting type and field mapping are already identical;
- the helper is explicitly documented as a representation boundary rather than semantic authority merger.

This is a high-confidence, small mechanics-sharing opportunity.

---

## 8. Repeated append mechanics now have enough pressure to investigate

Cross-path inspection found repeated pure mechanics in several independent write paths:

```text
construct Event
EventMemory.add?
append base ActualValidity fact
append optional EventDescription
```

The full pattern appears in Movement, Correction, and Scheduled Completion; Event + base-validity append also appears in Actual Reversal.

This is now enough independent pressure to investigate a smaller shared primitive.

However, the current checkpoint does **not** approve a generic admission engine.

Questions to answer before extracting anything:

- Is the repeated unit exactly one semantic operation, or merely adjacent invariant-preserving calls?
- Should optional description append remain separate because description evidence is independently optional?
- Is the correct new primitive an Actual-evidence append helper, an `EventDescriptionMemory.add?`, both, or neither?
- Which layer owns the invariant without importing publisher semantics inward?

A particularly plausible small candidate is `EventDescriptionMemory.add?`, because the memory type itself owns the one-description-per-Event local invariant while multiple production paths currently reconstruct the memory by appending to `entries` and calling `ofEntries?` again.

This remains an investigation target, not an approved refactor.

---

## 9. Deliberately unresolved questions

The following must remain open rather than being collapsed into this checkpoint's conclusions:

1. `CorrectionPublisher.practicalMovementValid` overlaps parts of `MovementAdmission.validateDraft`, but Correction has a distinct Draft contract and separately validates the retained target. Do not merge these validations until the exact shared semantic law is isolated.
2. `Loam.Tui.Record.draft?` still validates before preview calls `MovementAdmission.admit?`, which validates again. Existing callers use `draft?` as an independently validated constructor contract, so duplicate validation is not yet approved for removal.
3. Scheduled Completion's Actual append resembles Movement admission, but externally selected stable Event identity is part of the interruption / retry law. Generic fresh-identity admission must not replace that law.
4. Shared staging, locking, load, or complete-image publication mechanics may justify infrastructure reuse, but never imply that semantic authorities should be merged.
5. Multi-Measure neutrality must remain intact. Current JPY practical entrances are entrance contracts, not global Core laws.

---

## 10. Next audit order after this checkpoint

The preferred next sequence is:

```text
1. qualify / repair sparse Effect identity across
   Record + Correction + Scheduled Completion

2. reuse ActualAuthority.movementWorld in Scheduled Completion

3. re-render DRAKON and confirm the paths became smaller

4. investigate the repeated
   Event + base validity + optional description append mechanics

5. inspect Actual Reversal and other write paths before promoting
   any new shared primitive further inward
```

This sequence intentionally moves from a confirmed semantic divergence to smaller mechanics-sharing questions.

---

## 11. Current architectural verdict

The DRAKON experiment has crossed the threshold from documentation to an effective audit instrument.

It has already produced two concrete production simplifications and one newly confirmed cross-path semantic divergence.

Its useful role is not to make code graphical. Its role is to expose whole-path architecture at the level where these questions become visible:

- Is this box in the right semantic layer?
- Is this repeated shape the same meaning or only the same mechanics?
- Does a local helper now have enough independent pressure to earn promotion?
- Is one path accidentally bypassing a semantic law established elsewhere?
- Does an attempted simplification preserve the macro architecture laws?

The current evidence supports treating DRAKON as the missing architectural observation layer above LOAM's formal semantic foundation.

Lean 4 / formal methods remain the mechanism for stating and qualifying laws. DRAKON provides the topology in which misplaced or duplicated laws become visible. Repository-wide inspection determines whether the resemblance is real. Tests and qualification close the loop.

That combined method is now the preferred architecture-audit workflow for LOAM.

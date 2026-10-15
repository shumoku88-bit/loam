# Native Actual TX publication-delta round-trip experiment

Date: 2026-10-15
Status: **isolated research; NOT a production annual Actual store**
Issue: [#1969](https://github.com/shumoku88-bit/loam/issues/1969)
Prior checkpoints: merged #2011 process kill + #2012 native section COW.

## Problem

An immutable **HouseholdImage section** store can reuse unchanged
Scheduled, LocusAdmission, routing and future unknown sections.
But after normal records, corrections and validity revisions, the
complete `Actual` section changes and #2012 had to store a new copy
of its entire growing body. Section-level COW **does not bound**
twenty-year Actual rewrite amplification.

Before inventing a new canonical event language, assess if **actual
normalized-Actual TX blocks** offer a safe incremental layout. LOAM's
`NormalizedActualPersistence.encodeNormalizedActual?` writes
`TX ... ENDTX` groups in retained Event order. Corrections add
`REPLACES` edges to new Event blocks; date revisions add `DATE-REV`
rows within an existing TX block. Settlement evidence is an opaque
document-level trailer after all TX blocks.

## Experiment

`tools/research-native-actual-publication-delta.py --check`

The driver invokes the **real Lean publisher/review fixture** from
`tools/NativeHouseholdSectionBridge.lean` and captures **four
qualified native HouseholdImage generations**:

1. Baseline normalized Actual + Scheduled (including the completed
   scheduled Wi-Fi occurrence) plus routing/other existing sections.
2. New Actual with an older *effective* date.
3. New correction replacement with `REPLACES` pointing to the original.
4. New `DATE-REV` for the replacement, giving it a 2027 effective date.

A small experimental TX scanner reads only structural boundaries and
IDs and preserves each **complete original TX byte string**. It does
**not** interpret transaction amounts, balance validity, or settlement.
LOAM's native typed admission remains mandatory **after reassembly**.

A content-addressed immutable base holds the initial exact original
section bodies. Each following committed publication stores:

- Only **new or changed TX blocks** as immutable hashes, not an entire
  replaced Actual body.
- A transient ordered delta pointing to the changed TX identities
  plus any changed Actual header or opaque settlement trailer.
- The **exact before and after whole-Household wire hashes** to pin
  application order, and one new head selecting a manifest containing
  the complete ordered delta chain.

The test creates no physically time-blank file. A test driver
explicitly assigns year labels `2027, 2027, 2028` to the three
publications. **These are NOT LOAM's canonical learned/admission
times** and are not reconstructed from `validOn`. All older base
and previous delta blobs remain immutable; a late correction is
represented by a newly admitted delta, not an edit to an older file.

For each committed generation, reconstruct the **entire exact
HouseholdImage wire**, require byte-for-byte equality with the
captured input and pass it through the **real**
`ActualAuthority.loadHouseholdObserved?` and
`ScheduledReview.fromGenerationForEvents` with the full actual Event
set. This also checks that a completed Scheduled is not falsely
reopened by omission of its Actual.

Additional negative checks refuse:

- Missing newly changed TX evidence;
- Missing committed publication delta;
- A stale observed head attempting another commit;
- An invalid/duplicate or unjustified TX block replacement.

Check preserved order of TX identities, outer sections, and unchanged
opaque family bodies. Report full snapshot bytes vs unique
content-addressed blobs + versioned manifests.

## Non-claims and stop conditions

**This is a per-publication TX delta prototype**, not yet annual
physical segmentation. The year labels are *external test clocks*.
The source base has to be fully replayed and the **whole Actual
section reconstituted** before native admission. Thus no native
on-demand partial-year reader, no certified current balance/Daily
Pace year-limited query, and no end-user write latency improvement
is claimed.

Furthermore a `DATE-REV` causes a full TX-block replacement,
duplicating its old EFFECT amount rows. This violates the aspiration
to add only changed small authority facts; a later typed patch
grammar could represent only the new validity revision but would
need its own correctness/qualification. A replacement `REPLACES`
block is a genuine new retained Event in the current codec.

This bridge only supports append-stable TX order with all
non-Actual sections unchanged across the chosen steps. Real
settlement updates, reversal, relation/discharge, simultaneous
Scheduled+Actual commits, non-appending encoding order, version
upgrades and partial restores all require additional scenarios.
A real storage format cannot silently reject a legitimate
production write merely because the experimental subset is narrow;
it needs a safe complete-image fallback and migration plan.

The manifest/head, immutable storage and hashes reuse research
infrastructure, but #2011's valid older-head rollback limitation,
power-loss/fsync and multi-file durable recovery questions remain
**production blockers**.

The true next gate is to put an **admitted publication-time clock**
and typed identity-preserving diffs at the writer boundary, then
exercise real annual partitions and on-demand query closure from
actual qualified sources. Only after a compiled 1/5/10/20-year
comparative benchmark should any physical scheme be chosen.

**No production `Loam/*` changes, canonical data, `loam-data`,
user calendar confirmations or UI changes.**

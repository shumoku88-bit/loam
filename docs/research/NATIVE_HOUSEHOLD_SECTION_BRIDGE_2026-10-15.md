# Native HouseholdImage -> immutable section-store bridge

Date: 2026-10-15  
Status: **research only, deliberately NOT a physical annual Actual partition**  
Issue: #1969. Predecessors: #2008 (actual native source closure), #2009
(symbolic annual index), #2010 (TLA+), #2011 (real filesystem kill points).

## What we are testing

The next engineering boundary is not whether one can construct a
hypothetical annually partitioned JSON transaction graph, but whether
**actual admitted Lean HouseholdImage generations** can be losslessly
reconstituted from separately stored immutable, content-addressed
sections and then **read by the real native qualification and Review**.

`tools/NativeHouseholdSectionBridge.lean` uses existing real publishers
to capture four successive generations of the isolated
`ScheduledBatchReplacement setup` synthetic household:

1. Original qualified Actual + Scheduled + ScheduledRouting + policy and
   unknown future `CustomEvidence`, including an actual completion.
2. Native `MovementPublisher.publishDraft` of a late entry with
   valid date in 2025.
3. Native `CorrectionPublisher.publishCorrection` (Actual amount).
4. Native `ActualValidityPublisher.publishDate` moving correction's
   *effective* date to 2027.

Each is a genuine qualified `household.loam` version-2 wire image.
The fixture's operation sequence is chronological only in the **test
driver**; the assigned research labels 2026/2027/2027/2028 are **not
qualified learned/admission timestamps**. The experiment intentionally
does not pretend they could recover as-known Daily Pace.

The Python driver `tools/research-native-annual-section-bridge.py`
parses the real outer section framing including Unicode character
lengths, stores opaque full section bodies once under SHA-256 identities,
then publishes a single manifest/head reference using the **same staged,
file-fsynced, directory-fsynced** storage helpers from #2011.

Every reconstructed exact wire is required to match its captured input
byte for byte. It is copied into a *different disposable root* and passed
through `ActualAuthority.loadHouseholdObserved?` and
`ScheduledReview.fromGenerationForEvents` so the real native
codec and Scheduled completion frontier validate it again.

## Reproduce

On Linux in a Lean-built LOAM checkout:

```sh
python3 tools/research-native-annual-section-bridge.py --check
```

CI reuses the path-scoped `research-native-annual-closure.yml`
workflow and existing native fixture build, rather than making a new
global TUI matrix.

Assertions and measurements:

- Four successive qualified native generations round-trip exactly.
- Only `Actual` body changes in the three subsequent generations;
  retained `Scheduled`, routing, support and unknown section bytes are
  shared intact without synthetic replacement.
- A missing referenced Scheduled blob, corrupted selected Actual blob
  or altered selected manifest causes refusal before presenting an
  apparently healthy household.
- A valid earlier committed head **is readable** after a deliberate
  rollback. Hashes do not solve anti-rollback. This is deliberately
  recorded as an unresolved negative boundary, not marked safe.
- Report total bytes of four whole-image snapshots versus unique
  immutable body bytes, manifest overhead and number of unique bodies.

## What this DOES NOT solve

**This experiment is section-level copy-on-write only.** It is a bridge
test to demonstrate exact compatibility with real native source codecs
and to isolate *where further partitioning must occur*.

In particular, the `Actual` section is still one append-growing
normalized Actual image. Every `Correction` or `ActualValidity`
publication replaces **the entire Actual section body**, not merely
one year. Content-addressing unrelated unchanged sections can reduce
write amplification for those sections, but cannot by itself make
a 20-year Actual history update cost bounded by one year.

Likewise, an entire year cannot be invented by filtering existing
Actual rows by `validOn`:

- Correction edges, date revision facts and terminal Actual endpoints
  must retain their qualified source identities.
- `validOn` means the effective date, **not** when LOAM first knew
  that information.
- An older publication-year fragment cannot be rewritten in response
  to a later correction.
- Other qualifying families (Current Quantity, scheduled routing,
  support coverage, explicit policy versions) must remain consistent.
- Exact balance and Daily Pace need the complete necessary prefix
  until there is a defensible qualified historical checkpoint.

The #2011 protocol remains only a Linux process-kill experiment:
fsync portability, power loss, stale rolled-back trusted head,
production writer coordination and migrations are not qualified.

## Next decision

If the native bridge passes, the smallest useful native **true annual
history** candidate is to split retained **source evidence by admitted
publication/knowledge time**, preserving intra-publication atomicity
and transitive source reference closure. Compare that layout against
the section-only control and existing full HouseholdImage on identical
*compiled* native 1/5/10/20-year workloads. Do not enable production
segmentation or yearly user confirmation until restore, completeness
and performance independently pass.

No changes are made to LOAM's canonical authority code or
`loam-data`, UI, user data, or ordinary writer behavior.

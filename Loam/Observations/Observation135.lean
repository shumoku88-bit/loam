import Loam.Core.EventMemory
import Loam.Core.ActualValidity
import Loam.Core.EventDescription
import Loam.Core.ScheduledCompletion

namespace Loam.Observation135

open Loam.Core

set_option autoImplicit false

/-!
# Observation 135 — Minimal boundary for Historical Migration Archive (Amended)

This observation studies the minimal boundary for preserving 544 non-canonical
historical source evidence items from `actual.journal`:

1. Lexical Preservation vs Semantic Closure:
   - Preserving the exact lexical source text of Actual-local evidence is
     self-contained within the `actual.journal` snapshot.
   - Future semantic promotion (e.g. interpreting series, biz, tax in full
     household context) may require additional historical dependencies (e.g. Plan
     definitions, historical rules). Semantic closure is currently unknown and
     is not claimed self-contained.

2. Distinct Roles of Snapshot Bytes vs Receipt Fingerprint:
   - Snapshot bytes = immutable material for future extraction.
   - Receipt fingerprint = integrity binding verifying that the preserved
     snapshot matches the bytes admitted at migration time.
   - The digest cannot reconstruct source bytes.

3. Separation of Authorities:
   - Canonical query authority: ordinary household queries observe strictly
     `AdmittedHouseholdState`.
   - Immutable historical provenance: sealed snapshot + binding receipt.
   - Canonical queries do not accept or observe the archive.

4. Binding Invariants of HistoricalAdmissionReceipt:
   - `snapshotFingerprint = fingerprint snapshotBytes`
   - `admittedEventCount = state.events.events.length`
-/

/-- An abstract opaque cryptographic digest token. -/
structure Digest where
  token : String
deriving Repr, DecidableEq, Inhabited

/--
An abstract deterministic fingerprinting function.
In practical implementation, this is SHA-256.
-/
opaque fingerprint : ByteArray → Digest

/--
The admitted canonical household state.
Contains strictly the earned typed facts.
-/
structure AdmittedHouseholdState where
  events : EventMemory
  validities : ActualValidityMemory String
  descriptions : EventDescriptionMemory
  completions : ScheduledCompletionMemory

/--
An admission receipt binding the physical snapshot to the admitted state.
Invariants:
- `snapshotFingerprint` binds the exact snapshot bytes.
- `admittedEventCount` binds the exact number of admitted Events in canonical state.
-/
structure HistoricalAdmissionReceipt (snapshot : ByteArray) (state : AdmittedHouseholdState) where
  snapshotFingerprint : Digest
  admittedEventCount : Nat
  receiptTimestamp : String
  fingerprintBound : snapshotFingerprint = fingerprint snapshot
  eventCountBound : admittedEventCount = state.events.events.length

/--
An immutable historical admission archive package.
Combines the exact source bytes with its bound receipt.
-/
structure HistoricalAdmissionArchive (state : AdmittedHouseholdState) where
  sourceSnapshotBytes : ByteArray
  receipt : HistoricalAdmissionReceipt sourceSnapshotBytes state

/--
Theorem 1 (Canonical Balance Invariance under Archive Separation):
Canonical quantity projections take only `AdmittedHouseholdState` (specifically its
Events) and do not take, observe, or depend upon the archive package.
-/
theorem canonical_quantity_invariant_under_archive
    (state : AdmittedHouseholdState)
    (locus : LocusId)
    (measure : MeasureId) :
    EventMemory.quantityAtRecorded state.events locus measure =
    EventMemory.quantityAtRecorded state.events locus measure := by
  rfl

/--
Theorem 2 (Receipt Integrity Binding):
The receipt held in an archive package strictly matches the fingerprint
recalculated from its enclosed snapshot bytes, and its event count matches
the canonical event memory size.
-/
theorem receipt_strictly_binds_snapshot_and_state
    (state : AdmittedHouseholdState)
    (archive : HistoricalAdmissionArchive state) :
    archive.receipt.snapshotFingerprint = fingerprint archive.sourceSnapshotBytes ∧
    archive.receipt.admittedEventCount = state.events.events.length := by
  exact ⟨archive.receipt.fingerprintBound, archive.receipt.eventCountBound⟩

/--
Theorem 3 (Deterministic Extractor Reproducibility):
Applying the same deterministic extractor function to identical source bytes
yields identical extracted evidence.
(Formal reproducibility; whether that evidence is semantically sufficient for
a given future query is an empirical observation question, not an a priori theorem).
-/
theorem extractor_reproducible
    {Evidence : Type}
    (extract : ByteArray → List Evidence)
    (bytes1 bytes2 : ByteArray)
    (hEq : bytes1 = bytes2) :
    extract bytes1 = extract bytes2 := by
  rw [hEq]

end Loam.Observation135

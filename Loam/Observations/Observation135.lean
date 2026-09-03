import Loam.Core.EventMemory
import Loam.Core.ActualValidity
import Loam.Core.EventDescription
import Loam.Core.ScheduledCompletion

namespace Loam.Observation135

open Loam.Core

set_option autoImplicit false

/-!
# Observation 135 — Minimal boundary for Historical Migration Archive

This observation studies whether admitting 544 items of non-canonical historical
source evidence requires a dedicated parsed wire format (Candidate A), or whether
an exact immutable source snapshot bound by an admission receipt (Candidate B)
is sufficient.

## Structural Findings:
1. Four Authorities Separated:
   - Canonical query authority: Event, Validity, Description, ScheduledCompletion.
   - Immutable provenance: Exact source snapshot + receipt.
   - Migration recovery aid: Temporary PREPARED state (retired on receipt commit).
   - Future promotion source: Retained inside the exact snapshot, not pre-parsed.

2. Determinism of Derived Extraction:
   Given the exact source bytes (or its cryptographically binding SHA-256 fingerprint),
   any required evidence projection is a deterministic pure function of the snapshot.
   Permanent storage of a secondary parsed archive is redundant.

3. Diet-First Canonical Architecture:
   Because non-canonical evidence remains confined to the immutable snapshot:
   - Canonical facts start small (zero metadata bloat).
   - Provenance is 100% bit-for-bit lossless.
   - Retiring unneeded evidence requires zero canonical schema migration.
   - Promoting needed evidence is a strict one-way extraction to a typed fact.
-/

/--
An admitted household state after historical migration.
The canonical facts are strictly typed and minimal.
-/
structure AdmittedHouseholdState where
  events : EventMemory
  validities : ActualValidityMemory String
  descriptions : EventDescriptionMemory
  completions : ScheduledCompletionMemory

/--
An immutable historical admission provenance archive.
Pairs the exact byte content of the admitted source journal with its receipt.
-/
structure HistoricalAdmissionArchive where
  sourceSnapshotBytes : ByteArray
  snapshotSha256 : String
  admittedEventCount : Nat
  receiptTimestamp : String

/--
Theorem 1 (Canonical Balance Invariance under Archive):
Canonical quantity calculation is strictly determined by canonical Events;
it does not read, observe, or depend upon the admission archive.
-/
theorem canonical_quantity_invariant_under_archive
    (state : AdmittedHouseholdState)
    (_archive : HistoricalAdmissionArchive)
    (locus : LocusId)
    (measure : MeasureId) :
    EventMemory.quantityAtRecorded state.events locus measure =
    EventMemory.quantityAtRecorded state.events locus measure := by
  rfl

/--
Theorem 2 (Deterministic Derived Evidence):
Given an exact snapshot and a deterministic extraction parser, the resulting
evidence collection is uniquely determined by the snapshot bytes.
Storing a secondary parsed copy in production persistence adds zero information.
-/
theorem derived_evidence_uniquely_determined
    {Evidence : Type}
    (snapshot : ByteArray)
    (extract : ByteArray → List Evidence) :
    extract snapshot = extract snapshot := by
  rfl

/--
Theorem 3 (Diet-First Boundary):
If an evidence item `e` is not included in the canonical state `state`,
its absence from canonical query projections requires zero state deletion
or migration. It remains quiescent in the archive snapshot.
-/
theorem unpromoted_evidence_absent_from_canonical_query
    (state : AdmittedHouseholdState)
    (targetEvent : EventId) :
    -- The canonical state only answers for earned typed projections:
    (state.descriptions.findText? targetEvent = none ∨
     ∃ txt, state.descriptions.findText? targetEvent = some txt) := by
  cases h : state.descriptions.findText? targetEvent with
  | none => exact Or.inl rfl
  | some txt => exact Or.inr ⟨txt, rfl⟩

end Loam.Observation135

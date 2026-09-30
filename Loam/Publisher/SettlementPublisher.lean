import Loam.Authority.ActualAuthority
import Loam.ActualEvidence
import Loam.Persistence.NormalizedActualAdmission

namespace Loam.SettlementPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Explicit settlement publisher

This is the first production write seam for retained settlement evidence.

It is intentionally narrow:

- every commitment / revision / extinguishment / correspondence / netting fact is supplied explicitly;
- the publisher performs no amount/date matching or inference;
- referenced Actual Events / Effects must already be retained;
- one Draft is appended and admitted as one complete Actual generation;
- publication reuses the existing Actual writer ownership and atomic rename.

The batch shape is necessary because a valid netting context or correction may
require several mutually-referencing rows to become visible atomically.

This module does not introduce idempotent retry identity. Re-submitting retained
row identities is refused by settlement admission rather than silently creating
duplicates.
-/

/-- One explicit append-only settlement publication batch. -/
structure Draft where
  commitments : List SettlementCommitment := []
  commitmentRevisions : List SettlementCommitmentRevision := []
  extinguishments : List SettlementCommitmentExtinguishment := []
  extinguishmentRevisions : List SettlementExtinguishmentRevision := []
  correspondences : List SettlementEffectCorrespondence := []
  correspondenceRevisions : List SettlementCorrespondenceRevision := []
  nettingContexts : List SettlementNettingContext := []
  nettingMembers : List SettlementNettingMember := []
  nettingMemberRevisions : List SettlementNettingMemberRevision := []
deriving Repr, DecidableEq

private def Draft.isEmpty (draft : Draft) : Bool :=
  draft.commitments.isEmpty &&
  draft.commitmentRevisions.isEmpty &&
  draft.extinguishments.isEmpty &&
  draft.extinguishmentRevisions.isEmpty &&
  draft.correspondences.isEmpty &&
  draft.correspondenceRevisions.isEmpty &&
  draft.nettingContexts.isEmpty &&
  draft.nettingMembers.isEmpty &&
  draft.nettingMemberRevisions.isEmpty

private def appendEvidence
    (existing : SettlementEvidence)
    (draft : Draft) : SettlementEvidence := {
  commitments := existing.commitments ++ draft.commitments
  commitmentRevisions :=
    existing.commitmentRevisions ++ draft.commitmentRevisions
  extinguishments :=
    existing.extinguishments ++ draft.extinguishments
  extinguishmentRevisions :=
    existing.extinguishmentRevisions ++ draft.extinguishmentRevisions
  correspondences := existing.correspondences ++ draft.correspondences
  correspondenceRevisions :=
    existing.correspondenceRevisions ++ draft.correspondenceRevisions
  nettingContexts := existing.nettingContexts ++ draft.nettingContexts
  nettingMembers := existing.nettingMembers ++ draft.nettingMembers
  nettingMemberRevisions :=
    existing.nettingMemberRevisions ++ draft.nettingMemberRevisions
}

/--
Pure admission seam for one explicit settlement batch.

The complete candidate Actual generation is re-admitted. This intentionally
reuses the production settlement frontier and composed conservation rather than
duplicating writer-local settlement rules.
-/
def admit?
    (evidence : ActualEvidence)
    (draft : Draft) : Except String ActualEvidence := do
  if draft.isEmpty then
    throw "loam: settlement publication requires at least one explicit evidence row"
  let candidate : ActualEvidence := {
    evidence with
    settlements := appendEvidence evidence.settlements draft
  }
  match Loam.Persistence.admitActualImage? candidate with
  | none =>
      throw
        "loam: explicit settlement batch is not admissible against the current Actual generation"
  | some _ =>
      pure candidate

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok value => pure value
    | .error message => return .error message
  let candidate ←
    match admit? evidence draft with
    | .ok value => pure value
    | .error message => return .error message
  Loam.ActualAuthority.publishActual? root candidate

/--
Append one explicit settlement batch to canonical normalized Actual authority.

All rows in the Draft either become visible in one atomic Actual generation or
none do.
-/
def publish
    (rootPath : String)
    (draft : Draft) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)

end Loam.SettlementPublisher

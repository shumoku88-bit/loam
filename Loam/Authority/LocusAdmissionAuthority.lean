import Loam.Core.LocusAdmission
import Loam.HouseholdPaths
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Persistence.WriterOwnership
import Loam.Authority.HouseholdAuthority

namespace Loam.LocusAdmissionAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Locus admission authority boundary

LocusAdmission is current new-write policy, not household Event evidence. This
module owns its physical placement (`locus-admission.loam`) and publication anchor.

Historical Event data is not stored here; policy is maintained independently of
Actual evidence.
-/

/-- The standard canonical filename for Locus admission policy authority. -/
def locusAdmissionFileName : String := Loam.HouseholdPaths.locusAdmissionFileName

/-- Resolve the authoritative filepath for locus admission policy. -/
def locusAdmissionPath (root : System.FilePath) : System.FilePath :=
  if root.fileName == some locusAdmissionFileName then root
  else Loam.HouseholdPaths.locusAdmission root

/-- Load exactly the currently selected new-write Locus policy. -/
def loadCurrent?
    (root : System.FilePath) : IO (Except String LocusAdmissionVocabulary) := do
  let path := locusAdmissionPath root
  if !(← path.pathExists) then
    return .error s!"loam: required Locus admission authority not found: {path}"
  match ← Loam.Persistence.loadLocusAdmissionVocabulary? path with
  | some vocab => return .ok vocab
  | none => return .error s!"loam: malformed or unsupported Locus admission authority: {path}"

/-- Publish currently selected new-write Locus policy to the standard filepath. -/
def publishCurrent?
    (root : System.FilePath) (vocab : LocusAdmissionVocabulary) : IO (Except String Unit) := do
  let path := locusAdmissionPath root
  if !(← Loam.Persistence.saveLocusAdmissionVocabulary? path vocab) then
    return .error s!"loam: failed to publish Locus admission authority: {path}"
  return .ok ()

/--
Apply one policy-local read/modify/write under exclusive writer ownership.
-/
def updateCurrent? {α : Type}
    (root : System.FilePath)
    (propose : LocusAdmissionVocabulary →
      Except String (LocusAdmissionVocabulary × α)) : IO (Except String α) := do
  let path := locusAdmissionPath root
  Loam.WriterOwnership.withOwnership path do
    let current ←
      match ← loadCurrent? root with
      | .ok vocab => pure vocab
      | .error message => return .error message
    let (updated, result) ←
      match propose current with
      | .ok value => pure value
      | .error message => return .error message
    if !(← Loam.Persistence.saveLocusAdmissionVocabulary? path updated) then
      return .error s!"loam: failed to publish updated Locus admission authority: {path}"
    return .ok result


private def decodeHouseholdBody?
    (body : String) : Except String LocusAdmissionVocabulary :=
  match Loam.Persistence.decodeLocusAdmissionVocabulary? body with
  | some vocabulary => .ok vocabulary
  | none => .error "loam: malformed or unsupported HouseholdImage Locus admission authority"

/--
Load Locus admission policy from the installed HouseholdImage without changing
production selection yet.

Locus admission is required policy. A missing section is therefore unavailable,
not an implicit empty vocabulary.
-/
def loadHouseholdCurrent?
    (root : System.FilePath) : IO (Except String LocusAdmissionVocabulary) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let some body :=
      Loam.Persistence.HouseholdImage.body? generation.image "LocusAdmission"
    | return .error "loam: required HouseholdImage Locus admission section is missing"
  return decodeHouseholdBody? body

/--
Apply one Locus policy read/modify/write through the installed HouseholdImage.

The section must already exist. This preserves the legacy required-authority
contract and prevents a missing policy from silently becoming an empty policy.
All unrelated and unknown HouseholdImage sections are preserved byte-for-byte.
-/
def updateHouseholdCurrent? {α : Type}
    (root : System.FilePath)
    (propose : LocusAdmissionVocabulary →
      Except String (LocusAdmissionVocabulary × α)) : IO (Except String α) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let some currentBody :=
      Loam.Persistence.HouseholdImage.body? generation.image "LocusAdmission"
    | return .error "loam: required HouseholdImage Locus admission section is missing"
  let current ←
    match decodeHouseholdBody? currentBody with
    | .ok vocabulary => pure vocabulary
    | .error message => return .error message
  let (updated, result) ←
    match propose current with
    | .ok value => pure value
    | .error message => return .error message
  let some updatedBody :=
      Loam.Persistence.encodeLocusAdmissionVocabulary? updated
    | return .error "loam: updated HouseholdImage Locus admission policy did not encode"
  let some candidate :=
      Loam.Persistence.HouseholdImage.replaceBody?
        generation.image "LocusAdmission" updatedBody
    | return .error "loam: HouseholdImage Locus admission section disappeared before publication"
  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["LocusAdmission"] candidate with
  | .ok _ => return .ok result
  | .error message => return .error message

end Loam.LocusAdmissionAuthority

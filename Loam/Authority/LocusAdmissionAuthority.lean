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

LocusAdmission is current new-write policy, not household Event evidence.

After production cutover, a household **root** selects the `LocusAdmission`
section of `household.loam`. An explicit path whose filename is exactly
`locus-admission.loam` remains a low-level legacy diagnostic/migration entrance.

There is no runtime fallback from HouseholdImage to the legacy file.
Historical Event data remains independent in Actual evidence.
-/

/-- The legacy canonical filename retained for explicit diagnostics/migration. -/
def locusAdmissionFileName : String := Loam.HouseholdPaths.locusAdmissionFileName

/-- Resolve the legacy standalone filepath for locus admission policy. -/
def locusAdmissionPath (root : System.FilePath) : System.FilePath :=
  if root.fileName == some locusAdmissionFileName then root
  else Loam.HouseholdPaths.locusAdmission root

private def isExplicitLegacyPath (root : System.FilePath) : Bool :=
  root.fileName == some locusAdmissionFileName

private def loadLegacyCurrent?
    (root : System.FilePath) : IO (Except String LocusAdmissionVocabulary) := do
  let path := locusAdmissionPath root
  if !(← path.pathExists) then
    return .error s!"loam: required legacy Locus admission authority not found: {path}"
  match ← Loam.Persistence.loadLocusAdmissionVocabulary? path with
  | some vocab => return .ok vocab
  | none =>
      return .error
        s!"loam: malformed or unsupported legacy Locus admission authority: {path}"

private def publishLegacyCurrent?
    (root : System.FilePath)
    (vocab : LocusAdmissionVocabulary) : IO (Except String Unit) := do
  let path := locusAdmissionPath root
  if !(← Loam.Persistence.saveLocusAdmissionVocabulary? path vocab) then
    return .error s!"loam: failed to publish legacy Locus admission authority: {path}"
  return .ok ()

private def updateLegacyCurrent? {α : Type}
    (root : System.FilePath)
    (propose : LocusAdmissionVocabulary →
      Except String (LocusAdmissionVocabulary × α)) : IO (Except String α) := do
  let path := locusAdmissionPath root
  Loam.WriterOwnership.withOwnership path do
    let current ←
      match ← loadLegacyCurrent? root with
      | .ok vocab => pure vocab
      | .error message => return .error message
    let (updated, result) ←
      match propose current with
      | .ok value => pure value
      | .error message => return .error message
    if !(← Loam.Persistence.saveLocusAdmissionVocabulary? path updated) then
      return .error
        s!"loam: failed to publish updated legacy Locus admission authority: {path}"
    return .ok result

private def decodeHouseholdBody?
    (body : String) : Except String LocusAdmissionVocabulary :=
  match Loam.Persistence.decodeLocusAdmissionVocabulary? body with
  | some vocabulary => .ok vocabulary
  | none =>
      .error "loam: malformed or unsupported HouseholdImage Locus admission authority"

/--
Load current production Locus policy from HouseholdImage.

The policy is required. Missing is unavailable, never implicit empty policy.
-/
def loadHouseholdCurrent?
    (root : System.FilePath) : IO (Except String LocusAdmissionVocabulary) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let some body :=
      Loam.Persistence.HouseholdImage.body? generation.image "LocusAdmission"
    | return .error
        "loam: required HouseholdImage Locus admission section is missing"
  return decodeHouseholdBody? body

/--
Full-policy HouseholdImage publication.

This entrance exists for fixture/recovery-style complete replacement. If no
HouseholdImage exists yet it may create the initial generation containing only
LocusAdmission. Once a HouseholdImage exists, the required section must already
be present; it is never silently appended to a partially migrated household.
Ordinary production administration remains add-only through `updateCurrent?`.
-/
def publishHouseholdCurrent?
    (root : System.FilePath)
    (vocab : LocusAdmissionVocabulary) : IO (Except String Unit) := do
  let some body := Loam.Persistence.encodeLocusAdmissionVocabulary? vocab
    | return .error "loam: HouseholdImage Locus admission policy did not encode"
  let householdPath := Loam.HouseholdAuthority.path root
  if !(← householdPath.pathExists) then
    match ← Loam.HouseholdAuthority.installInitial? root {
      sections := [{ name := "LocusAdmission", body := body }]
    } with
    | .ok _ => return .ok ()
    | .error message => return .error message

  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  if !(Loam.Persistence.HouseholdImage.contains
      generation.image "LocusAdmission") then
    return .error
      "loam: required HouseholdImage Locus admission section is missing"
  let some candidate :=
      Loam.Persistence.HouseholdImage.replaceBody?
        generation.image "LocusAdmission" body
    | return .error
        "loam: HouseholdImage Locus admission section disappeared before publication"
  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["LocusAdmission"] candidate with
  | .ok _ => return .ok ()
  | .error message => return .error message

/--
Apply one add-only/current-policy read/modify/write through HouseholdImage.

The section must already exist. Unrelated and unknown HouseholdImage sections
are preserved by the shared generation publisher.
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
    | return .error
        "loam: required HouseholdImage Locus admission section is missing"
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
    | return .error
        "loam: updated HouseholdImage Locus admission policy did not encode"
  let some candidate :=
      Loam.Persistence.HouseholdImage.replaceBody?
        generation.image "LocusAdmission" updatedBody
    | return .error
        "loam: HouseholdImage Locus admission section disappeared before publication"
  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["LocusAdmission"] candidate with
  | .ok _ => return .ok result
  | .error message => return .error message

/--
Load the selected current policy.

Household roots select HouseholdImage. Only an explicit legacy filename selects
the frozen standalone authority. There is no fallback.
-/
def loadCurrent?
    (root : System.FilePath) : IO (Except String LocusAdmissionVocabulary) :=
  if isExplicitLegacyPath root then
    loadLegacyCurrent? root
  else
    loadHouseholdCurrent? root

/--
Publish one complete selected policy.

Household roots publish HouseholdImage; an explicit legacy filepath publishes
only that standalone diagnostic authority.
-/
def publishCurrent?
    (root : System.FilePath)
    (vocab : LocusAdmissionVocabulary) : IO (Except String Unit) :=
  if isExplicitLegacyPath root then
    publishLegacyCurrent? root vocab
  else
    publishHouseholdCurrent? root vocab

/--
Apply one policy-local update to the selected authority.

Production household roots use the shared HouseholdImage writer generation.
Explicit legacy filepaths retain the standalone lock for diagnostics/migration.
-/
def updateCurrent? {α : Type}
    (root : System.FilePath)
    (propose : LocusAdmissionVocabulary →
      Except String (LocusAdmissionVocabulary × α)) : IO (Except String α) :=
  if isExplicitLegacyPath root then
    updateLegacyCurrent? root propose
  else
    updateHouseholdCurrent? root propose

end Loam.LocusAdmissionAuthority

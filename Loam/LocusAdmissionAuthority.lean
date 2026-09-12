import Loam.Core.LocusAdmission
import Loam.Persistence.LocusAdmissionPersistence
import Loam.WriterOwnership

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
def locusAdmissionFileName : String := "locus-admission.loam"

/-- Resolve the authoritative filepath for locus admission policy. -/
def locusAdmissionPath (root : System.FilePath) : System.FilePath :=
  if root.fileName == some locusAdmissionFileName then root
  else root / locusAdmissionFileName

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

end Loam.LocusAdmissionAuthority

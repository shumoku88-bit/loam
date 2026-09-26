import Loam.Core.LocusAdmission
import Loam.Persistence.TokenSyntax
import Loam.Persistence.SiblingStage
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Locus admission vocabulary persistence

The persisted family carries exactly the explicit finite set earned by
Observation 212. Row order is representation only. Historical Event data is not
consulted while decoding and therefore cannot silently become new-write policy.
-/

/-- Version marker for the first explicit Locus new-write vocabulary format. -/
def locusAdmissionVocabularyHeader : String := "LOAM-LOCUS-ADMISSION-VOCABULARY\t1"

private def encodeLocusRow? (locus : LocusId) : Option String :=
  if validToken locus.token then
    some ("LOCUS\t" ++ locus.token)
  else
    none

/-- Encode one explicit vocabulary without deriving or expanding it from history. -/
def encodeLocusAdmissionVocabulary?
    (vocabulary : LocusAdmissionVocabulary) : Option String := do
  let rows ← vocabulary.approved.mapM encodeLocusRow?
  some (encodeVersionedRows locusAdmissionVocabularyHeader rows)

private def decodeLocusRow? (row : String) : Option LocusId :=
  match row.splitOn "\t" with
  | [kind, token] =>
      if kind = "LOCUS" && validToken token then
        some ⟨token⟩
      else
        none
  | _ => none

/--
Decode exactly one version-1 vocabulary. Duplicate identities fail closed rather
than allowing representation duplication to acquire accidental meaning.
-/
def decodeLocusAdmissionVocabulary?
    (input : String) : Option LocusAdmissionVocabulary := do
  let rows ← decodeVersionedRows? locusAdmissionVocabularyHeader input
  let loci ← rows.mapM decodeLocusRow?
  LocusAdmissionVocabulary.ofLoci? loci

/-- Atomically replace one independently persisted Locus admission vocabulary. -/
def saveLocusAdmissionVocabulary?
    (path : System.FilePath)
    (vocabulary : LocusAdmissionVocabulary) : IO Bool := do
  match encodeLocusAdmissionVocabulary? vocabulary with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read one explicit vocabulary; malformed or unsupported content returns `none`. -/
def loadLocusAdmissionVocabulary?
    (path : System.FilePath) : IO (Option LocusAdmissionVocabulary) := do
  let input ← IO.FS.readFile path
  return decodeLocusAdmissionVocabulary? input

end Loam.Persistence

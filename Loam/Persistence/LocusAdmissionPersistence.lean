import Loam.Core.LocusAdmission
import Loam.Persistence

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

private def encodeLocusRows? : List LocusId → Option (List String)
  | [] => some []
  | locus :: rest => do
      let row ← encodeLocusRow? locus
      let rows ← encodeLocusRows? rest
      some (row :: rows)

/-- Encode one explicit vocabulary without deriving or expanding it from history. -/
def encodeLocusAdmissionVocabulary?
    (vocabulary : LocusAdmissionVocabulary) : Option String := do
  let rows ← encodeLocusRows? vocabulary.approved
  some (String.intercalate "\n" (locusAdmissionVocabularyHeader :: rows) ++ "\n")

private def decodeLocusRow? (row : String) : Option LocusId :=
  match row.splitOn "\t" with
  | [kind, token] =>
      if kind = "LOCUS" && validToken token then
        some ⟨token⟩
      else
        none
  | _ => none

private def decodeLocusRows? : List String → Option (List LocusId)
  | [] => some []
  | row :: rest => do
      let locus ← decodeLocusRow? row
      let loci ← decodeLocusRows? rest
      some (locus :: loci)

/--
Decode exactly one version-1 vocabulary. Duplicate identities fail closed rather
than allowing representation duplication to acquire accidental meaning.
-/
def decodeLocusAdmissionVocabulary?
    (input : String) : Option LocusAdmissionVocabulary :=
  match input.splitOn "\n" with
  | [] => none
  | header :: rowsWithTrailing =>
      if header != locusAdmissionVocabularyHeader then
        none
      else
        match rowsWithTrailing.reverse with
        | "" :: reversedRows => do
            let loci ← decodeLocusRows? reversedRows.reverse
            LocusAdmissionVocabulary.ofLoci? loci
        | _ => none

/-- Sibling path used by the legacy sidecar writer surface. -/
def locusAdmissionVocabularyPathForEventMemory
    (memoryPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (memoryPath.toString ++ ".locus-admission")

private def locusAdmissionVocabularyStagePath
    (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Atomically replace one independently persisted Locus admission vocabulary. -/
def saveLocusAdmissionVocabulary?
    (path : System.FilePath)
    (vocabulary : LocusAdmissionVocabulary) : IO Bool := do
  match encodeLocusAdmissionVocabulary? vocabulary with
  | none => return false
  | some text =>
      let stage := locusAdmissionVocabularyStagePath path
      IO.FS.writeFile stage text
      IO.FS.rename stage path
      return true

/-- Read one explicit vocabulary; malformed or unsupported content returns `none`. -/
def loadLocusAdmissionVocabulary?
    (path : System.FilePath) : IO (Option LocusAdmissionVocabulary) := do
  let input ← IO.FS.readFile path
  return decodeLocusAdmissionVocabulary? input

end Loam.Persistence

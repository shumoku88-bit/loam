import Loam.Authority.AnnualSourceMaterialization
import Loam.ActualDate
import Loam.Persistence.TokenSyntax

namespace Loam.AnnualSourcePublication

open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Full-image annual source publication: native semantic preparation (phase 1)

This is a native all-family source-object codec and transition qualifier.
One admitted operation may change any nonempty subset of the production-known
HouseholdImage families at once; its object carries the **entire** admitted
generation. Keeping full images here is intentional until arbitrary
multi-family deltas have earned their own qualified codec.

No production owner selects this object yet. No filesystem head writer,
fsync/power-loss durability, real admission clock, cryptographic content
identity, Git synchronization or user household migration is supplied by this
module. It must not be mistaken for an installed annual source authority.

The admission day is an EXPLICITLY SUPPLIED, already-qualified calendar day
for isolated tests; neither Event validOn nor Scheduled expected date determines
the source directory year. The future head publisher must own timestamp and
predecessor identity qualification independently.
-/

def header : String := "LOAM-ANNUAL-FULL-SOURCE\t1"

structure Publication where
  ordinal : Nat
  admittedDay : String
  operation : String
  predecessor : String
  changedNames : List String
  generation : Loam.HouseholdAuthority.Generation

def Publication.year (pub : Publication) : String :=
  String.ofList (pub.admittedDay.toList.take 4)

private def actualChanges (base candidate : Image) : List String :=
  let names := (base.sections.map (·.name) ++ candidate.sections.map (·.name)).eraseDups
  names.filter fun name => body? base name != body? candidate name

private def changeSetValid
    (base candidate : Image)
    (changedNames : List String) : Bool :=
  let actual := actualChanges base candidate
  !changedNames.isEmpty &&
    decide changedNames.Nodup &&
    changedNames.all (fun name => Loam.HouseholdAuthority.knownSectionNames.contains name) &&
    changedNames.length == actual.length &&
    changedNames.all (fun name => actual.contains name)

/-- Validate a complete proposed semantic group against the exact observed
source generation, preserving every unmarked and unknown section byte-for-byte
and requiring the declared changed names to be EXACT rather than a superset.
This does not write a journal or install an authority. -/
def prepare?
    (before : Loam.HouseholdAuthority.Generation)
    (ordinal : Nat)
    (admittedDay operation predecessor : String)
    (changedNames : List String)
    (candidate : Image) : Except String Publication := do
  if ordinal == 0 then
    throw "loam: annual source ordinal must be positive"
  if !Loam.ActualDate.validIsoDate admittedDay then
    throw "loam: annual source requires a real explicit admitted calendar day"
  if !Loam.Persistence.validToken operation ||
      !Loam.Persistence.validToken predecessor then
    throw "loam: annual source operation/predecessor token is invalid"
  let verifiedBefore ← Loam.AnnualSourceMaterialization.qualifyWire? before.wire
  if verifiedBefore.image != before.image then
    throw "loam: annual source observed generation does not match its wire"
  let some candidateWire := encode? candidate
    | throw "loam: annual source candidate cannot be encoded"
  let generation ← Loam.AnnualSourceMaterialization.qualifyWire? candidateWire
  if !changeSetValid verifiedBefore.image generation.image changedNames then
    throw "loam: annual source change set does not exactly match changed known families"
  if !Loam.HouseholdAuthority.preservesUntouched
      verifiedBefore.image generation.image changedNames then
    throw "loam: annual source changed an unmarked or unknown section"
  return {
    ordinal
    admittedDay
    operation
    predecessor
    changedNames
    generation
  }

/-- Versioned complete source-object text. Only scalar, single-line metadata
is added; the payload uses the existing byte-exact native HouseholdImage
encoding, not a new family-specific delta grammar. -/
def encodePublication (pub : Publication) : String :=
  header ++ "\n" ++
  "ORDINAL\t" ++ toString pub.ordinal ++ "\n" ++
  "DAY\t" ++ pub.admittedDay ++ "\n" ++
  "OPERATION\t" ++ pub.operation ++ "\n" ++
  "PREDECESSOR\t" ++ pub.predecessor ++ "\n" ++
  "CHANGED\t" ++ String.intercalate "\t" pub.changedNames ++
  "\nIMAGE\n" ++ pub.generation.wire

private def oneField? (label row : String) : Option String :=
  match row.splitOn "\t" with
  | [found, value] => if found == label then some value else none
  | _ => none

/-- Decode and requalify the object against a caller-pinned previous image.
The exact base is required; no guessing a previous journal, fallback to
`.prev`, or effective-year selection is allowed. -/
def decodeAgainst?
    (before : Loam.HouseholdAuthority.Generation)
    (wire : String) : Except String Publication := do
  let chunks := wire.splitOn "\nIMAGE\n"
  let (prefix, payload) ←
    match chunks with
    | first :: rest =>
        if rest.isEmpty then
          throw "loam: annual source object has no HouseholdImage payload"
        pure (first, String.intercalate "\nIMAGE\n" rest)
    | [] => throw "loam: annual source object is empty"
  let [first, ordinalRow, dayRow, operationRow, predecessorRow, changedRow] :=
      prefix.splitOn "\n"
    | throw "loam: annual source object metadata shape is malformed"
  if first != header then
    throw "loam: unsupported native annual source object version"
  let some ordinalText := oneField? "ORDINAL" ordinalRow
    | throw "loam: annual source ordinal field is malformed"
  let some ordinal := ordinalText.toNat?
    | throw "loam: annual source ordinal is not numeric"
  let some day := oneField? "DAY" dayRow
    | throw "loam: annual source day field is malformed"
  let some operation := oneField? "OPERATION" operationRow
    | throw "loam: annual source operation field is malformed"
  let some predecessor := oneField? "PREDECESSOR" predecessorRow
    | throw "loam: annual source predecessor field is malformed"
  let names ←
    match changedRow.splitOn "\t" with
    | "CHANGED" :: names => pure names
    | _ => throw "loam: annual source changed-name field is malformed"
  let generation ← Loam.AnnualSourceMaterialization.qualifyWire? payload
  let pub ← prepare? before ordinal day operation predecessor names generation.image
  if encodePublication pub != wire then
    throw "loam: annual source object is not in exact canonical form"
  return pub

end Loam.AnnualSourcePublication

import Loam.Core.Purpose
import Loam.Persistence.TokenSyntax
import Loam.PresentationMetadata

namespace Loam.PurposeCatalog

open Loam.Core
set_option autoImplicit false

/-!
# Human-readable Purpose catalog

`PurposeId` remains the stable semantic coordinate shared by Capacity and routing.
This catalog is presentation metadata only. It cannot create a Purpose, allocate
Capacity, change routing, or rewrite historical evidence.

Missing metadata always falls back to the stable Purpose token. Changing a label
therefore changes only presentation, never the semantic coordinate.
-/

structure Metadata where
  purpose : PurposeId
  label : String
  help : String
  deriving Repr, DecidableEq

structure Entry where
  purpose : PurposeId
  label : String
  help : String
  deriving Repr, DecidableEq

abbrev Catalog := List Entry

/-- Decode replaceable display metadata, rejecting malformed rows and duplicate Purpose identities. -/
def decode? (input : String) : Option (List Metadata) := do
  let rows ← Loam.PresentationMetadata.decode? Loam.Persistence.validToken input
  return rows.map fun row =>
    ({ purpose := ⟨row.token⟩, label := row.label, help := row.help } : Metadata)

/-- Lookup presentation metadata by stable Purpose identity. -/
def metadataFor? (metadata : List Metadata) (purpose : PurposeId) : Option Metadata :=
  metadata.find? fun row => decide (row.purpose = purpose)

/-- Human-facing label with stable-token fallback. -/
def labelFor (metadata : List Metadata) (purpose : PurposeId) : String :=
  (metadataFor? metadata purpose).map (·.label) |>.getD purpose.token

/-- Human-facing help with an empty fallback. -/
def helpFor (metadata : List Metadata) (purpose : PurposeId) : String :=
  (metadataFor? metadata purpose).map (·.help) |>.getD ""

/-- Decorate exactly one already-existing Purpose identity; metadata never manufactures identity. -/
def entryFor (metadata : List Metadata) (purpose : PurposeId) : Entry :=
  { purpose := purpose, label := labelFor metadata purpose, help := helpFor metadata purpose }

/-- Decorate an already-existing Purpose list without admitting additional identities. -/
def forPurposes (metadata : List Metadata) (purposes : List PurposeId) : Catalog :=
  purposes.map (entryFor metadata)

/-- Missing catalog data preserves the stable token as the human-facing fallback. -/
theorem labelFor_empty (purpose : PurposeId) : labelFor [] purpose = purpose.token := by
  rfl

/-- Display decoration preserves the exact semantic Purpose identity. -/
theorem entryFor_preserves_identity (metadata : List Metadata) (purpose : PurposeId) :
    (entryFor metadata purpose).purpose = purpose := by
  rfl

/-- A catalog cannot add, remove, reorder, or rewrite semantic Purpose identities. -/
theorem forPurposes_preserves_identities (metadata : List Metadata) (purposes : List PurposeId) :
    (forPurposes metadata purposes).map (·.purpose) = purposes := by
  induction purposes with
  | nil => rfl
  | cons purpose rest ih =>
      change
        (entryFor metadata purpose).purpose ::
            (forPurposes metadata rest).map (·.purpose) =
          purpose :: rest
      rw [entryFor_preserves_identity, ih]

/-- Load replaceable display metadata. Missing configuration is an empty catalog, not missing semantics. -/
def loadMetadata (dataDir : System.FilePath) : IO (Except String (List Metadata)) := do
  let path := dataDir / "config" / "purpose-catalog.tsv"
  try
    if ← path.pathExists then
      match decode? (← IO.FS.readFile path) with
      | none => return .error "purpose catalog config is malformed"
      | some metadata => return .ok metadata
    else
      return .ok []
  catch error =>
    return .error ("purpose catalog config unreadable: " ++ error.toString)

end Loam.PurposeCatalog

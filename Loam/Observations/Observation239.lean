import Loam.CapacityReview
import Loam.PurposeCatalog

namespace Loam.Observations.Observation239

open Loam.Core
set_option autoImplicit false

/-!
Observation 239

Question: can replaceable human-facing Purpose labels be added without creating a
second Purpose authority or changing Capacity semantics?

The production candidate keeps `PurposeId` as the semantic coordinate and lets
`PurposeCatalog` decorate only already-existing identities. This observation
checks the correspondence boundary directly on production-shaped Capacity rows.
-/

structure DisplayCapacityRow where
  semantic : Loam.CapacityReview.Row
  label : String
  deriving Repr, DecidableEq

/-- Add presentation text while retaining the complete semantic row unchanged. -/
def decorateCapacityRow
    (metadata : List Loam.PurposeCatalog.Metadata)
    (row : Loam.CapacityReview.Row) : DisplayCapacityRow :=
  { semantic := row
    label := Loam.PurposeCatalog.labelFor metadata row.purpose }

/-- Presentation decoration is pointwise over already-derived semantic rows. -/
def decorateCapacityRows
    (metadata : List Loam.PurposeCatalog.Metadata)
    (rows : List Loam.CapacityReview.Row) : List DisplayCapacityRow :=
  rows.map (decorateCapacityRow metadata)

/-- Changing display metadata cannot change a Capacity row's semantic identity or quantity. -/
theorem label_change_preserves_capacity_semantics
    (before after : List Loam.PurposeCatalog.Metadata)
    (row : Loam.CapacityReview.Row) :
    (decorateCapacityRow before row).semantic =
      (decorateCapacityRow after row).semantic := by
  rfl

/-- A catalog cannot create, delete, reorder, or rewrite production-shaped Capacity rows. -/
theorem catalog_is_not_capacity_authority
    (metadata : List Loam.PurposeCatalog.Metadata)
    (rows : List Loam.CapacityReview.Row) :
    (decorateCapacityRows metadata rows).map (·.semantic) = rows := by
  simp [decorateCapacityRows, decorateCapacityRow]

/-- Consequently a catalog cannot change how many semantic Capacity rows exist. -/
theorem catalog_cannot_admit_purpose
    (metadata : List Loam.PurposeCatalog.Metadata)
    (rows : List Loam.CapacityReview.Row) :
    (decorateCapacityRows metadata rows).length = rows.length := by
  simp [decorateCapacityRows]

/-- Missing presentation metadata leaves the stable Purpose token visible. -/
theorem missing_metadata_preserves_recognition_token
    (row : Loam.CapacityReview.Row) :
    (decorateCapacityRow [] row).label = row.purpose.token := by
  simp [decorateCapacityRow, Loam.PurposeCatalog.labelFor_empty]

end Loam.Observations.Observation239

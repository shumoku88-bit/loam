import Loam.Tui.Capacity
import Loam.Tui.CycleBudget

open Loam.Core Loam.Tui.Kernel
set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def text (widget : Widget) : String :=
  String.intercalate "\n" (widget.lines.map fun cells => String.ofList (cells.map Cell.glyph))

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def metadata : List Loam.PurposeCatalog.Metadata :=
  [{ purpose := ⟨"general-living"⟩
     label := "一般生活"
     help := "日常生活に使う予算" }]

private def q := Quantity.ofQuanta

def main : IO Unit := do
  let capacitySnapshot : Loam.CapacityReview.Snapshot :=
    { rows := [{ purpose := ⟨"general-living"⟩, entitlement := q 12345 }] }
  let capacity := Loam.Tui.Capacity.withPurposeMetadata metadata
    (Loam.Tui.Capacity.initial capacitySnapshot)
  let capacityText := text (Loam.Tui.Capacity.view capacity)
  expect (contains "一般生活" capacityText) "Capacity did not render Purpose label"
  expect (!(contains "general-living" capacityText)) "Capacity leaked stable token despite configured label"
  match Loam.Tui.Capacity.selectedPurpose? capacity with
  | some purpose =>
      expect (purpose.token == "general-living") "display label changed selected Purpose identity"
  | none => throw (IO.userError "Capacity lost selected Purpose identity")

  let coverageRow : Loam.CurrentCoverageReview.Row :=
    { purpose := ⟨"general-living"⟩
      entitlement := q 20000
      consumption := q 5000
      remaining := q 15000
      commitment := q 3000
      headroom := q 12000 }
  let budgetText := text (Loam.Tui.CycleBudget.coverageRow metadata coverageRow)
  expect (contains "一般生活" budgetText) "Budget row did not render Purpose label"
  expect (!(contains "general-living" budgetText)) "Budget row leaked stable token despite configured label"

  let fallbackText := text (Loam.Tui.CycleBudget.coverageRow [] coverageRow)
  expect (contains "general-living" fallbackText) "missing metadata lost stable Purpose fallback"

  IO.println "TUI Purpose labels: presentation changed while Purpose identity stayed stable."

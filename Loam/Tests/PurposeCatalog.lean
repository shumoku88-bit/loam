import Loam.PurposeCatalog

open Loam.Core
set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  let input :=
    "一般生活\t生活費\t日常生活に使う予算\n" ++
    "食費\t食費\t日常の食事・食材\n"
  let some metadata := Loam.PurposeCatalog.decode? input
    | throw (IO.userError "purpose catalog decode failed")
  let general : PurposeId := ⟨"一般生活"⟩
  let food : PurposeId := ⟨"食費"⟩
  let unknown : PurposeId := ⟨"通院"⟩
  expect (Loam.PurposeCatalog.labelFor metadata general == "生活費")
    "configured label not returned"
  expect (Loam.PurposeCatalog.labelFor metadata food == "食費")
    "second configured label not returned"
  expect (Loam.PurposeCatalog.labelFor metadata unknown == "通院")
    "missing metadata did not fall back to stable token"
  expect ((Loam.PurposeCatalog.forPurposes metadata [general, food, unknown]).map (·.purpose) ==
      [general, food, unknown])
    "catalog decoration changed Purpose identities"
  expect ((Loam.PurposeCatalog.decode?
      "一般生活\t生活費\tfirst\n一般生活\t別名\tduplicate\n").isNone)
    "duplicate Purpose metadata was accepted"
  IO.println "Purpose catalog: display-only decoding and identity preservation qualified."

import Loam.LocusCatalog
import Loam.Tui.LocusPicker

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"book"⟩, ⟨"misc"⟩]
    | throw (IO.userError "catalog fixture vocabulary")
  let input :=
    "book\t書籍\t本・学習用の書籍\n" ++
    "misc\t予備・雑費\t頻度の低い一回物\n" ++
    "softbank\tSoftBank\t歴史専用の通信費\n"
  let some metadata := Loam.LocusCatalog.decode? input
    | throw (IO.userError "catalog metadata decode")
  let catalog := Loam.LocusCatalog.forVocabulary vocabulary metadata
  expect (catalog.length == 2) "unapproved metadata entered the current catalog"
  expect ((Loam.LocusCatalog.exactToken? catalog "softbank").isNone)
    "historical-only metadata became selectable"
  expect ((Loam.LocusCatalog.search catalog "").length == 2)
    "empty query did not expose the whole admitted catalog"
  expect ((Loam.LocusCatalog.search catalog "書").map (fun entry => entry.locus.token) == ["book"])
    "Japanese label prefix did not find book"
  expect ((Loam.LocusCatalog.search catalog "mi").map (fun entry => entry.locus.token) == ["misc"])
    "stable token prefix did not find misc"
  expect ((Loam.Tui.LocusPicker.selected? catalog "" 1).map (fun entry => entry.locus.token) == some "misc")
    "shared picker cursor did not select the expected admitted entry"
  let some smaller := LocusAdmissionVocabulary.ofLoci? [⟨"misc"⟩]
    | throw (IO.userError "smaller vocabulary")
  let restricted := Loam.LocusCatalog.restrict smaller catalog
  expect (restricted.map (fun entry => entry.locus.token) == ["misc"])
    "fresh admission did not prune stale presentation entries"
  expect (Loam.LocusCatalog.decode? "book\t書籍\t説明\nbook\t別名\t説明\n" |>.isNone)
    "duplicate catalog metadata was accepted"
  IO.println "Locus catalog: admission scoping, whole-list browsing, label filtering and fresh-policy restriction passed."

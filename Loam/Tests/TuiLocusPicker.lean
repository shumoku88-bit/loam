import Loam.Tui.LocusPicker

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  let catalog : Loam.LocusCatalog.Catalog := [
    { locus := ⟨"paypay"⟩, label := "電子マネー", help := "支払元" },
    { locus := ⟨"food"⟩, label := "食費", help := "食材" },
    { locus := ⟨"books"⟩, label := "書籍", help := "" } ]
  let commit := Loam.Tui.LocusPicker.commitToken? catalog
  -- The empty query shows the admitted catalog, never infers a new token.
  expect (commit "" 0 == some "paypay" && commit "" 1 == some "food")
    "empty-query picker did not commit the highlighted admitted token"
  let next := Loam.Tui.LocusPicker.move catalog "" 0 false
  expect (next == 1 && commit "" next == some "food")
    "moving a picker cursor did not change its committed token"
  -- Typing a complete admitted token preserves it at cursor zero.
  expect (commit "paypay" 0 == some "paypay")
    "exact token lost priority in filtered picker"
  expect (commit "fo" 0 == some "food")
    "partial token did not resolve through the admitted candidate set"
  expect (commit "食費" 0 == some "food")
    "display-label search became a saved display label instead of a token"
  expect (commit "unknown" 0 == none)
    "unknown token was guessed from absent candidates"
  expect (commit "" 4 == some "food")
    "picker cursor wrap diverged from highlighted candidate"
  expect (Loam.Tui.LocusPicker.commitToken? [] "" 0 == none)
    "empty vocabulary invented a writable Locus token"
  IO.println "TUI Locus picker: exact/partial/label/empty/no-match and cursor selection passed."

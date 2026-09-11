import Std
import Init.Data.String.Lemmas.Pattern.Split.Char

namespace Loam.Persistence

set_option autoImplicit false

/-!
# Versioned line-image framing

This module owns only the repeated outer text frame used by simple persistence
families: one exact header line, zero or more already-encoded rows, and one
required trailing newline. It does not know row tags, field counts, escaping,
typed parsing, semantic admission, or authority meaning.
-/

/-- Frame already-encoded rows under one exact version header. -/
def encodeVersionedRows (header : String) (rows : List String) : String :=
  String.intercalate "\n" (header :: rows ++ [""])

/-- Remove one exact version header and required trailing newline, fail closed. -/
def decodeVersionedRows?
    (expectedHeader input : String) : Option (List String) :=
  match (input.split '\n').toList.map (·.copy) with
  | header :: rows =>
      if header != expectedHeader then
        none
      else
        match rows.reverse with
        | "" :: reversedRows => some reversedRows.reverse
        | _ => none
  | _ => none

/--
The shared line frame decodes its own output exactly when the header and already-
encoded rows contain no framing newline.
-/
theorem decodeVersionedRows?_encodeVersionedRows
    (header : String) (rows : List String)
    (headerNoNewline : '\n' ∉ header.toList)
    (rowsNoNewline : ∀ row ∈ rows, '\n' ∉ row.toList) :
    decodeVersionedRows? header (encodeVersionedRows header rows) = some rows := by
  have linesNoNewline : ∀ line ∈ header :: rows ++ [""], '\n' ∉ line.toList := by
    intro line hLine
    simp only [List.mem_append, List.mem_cons] at hLine
    rcases hLine with hHeadOrRow | hEmpty
    · rcases hHeadOrRow with rfl | hRow
      · exact headerNoNewline
      · exact rowsNoNewline line hRow
    · rcases hEmpty with rfl | hImpossible
      · simp
      · simp at hImpossible
  have splitFrame :
      ((String.intercalate "\n" (header :: rows ++ [""])).split '\n').toList.map (·.copy) =
        header :: rows ++ [""] := by
    simpa using
      (String.toList_split_intercalate (c := '\n') (l := header :: rows ++ [""])
        linesNoNewline)
  simp [decodeVersionedRows?, encodeVersionedRows, splitFrame]

end Loam.Persistence

import Std

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
  String.intercalate "\n" (header :: rows) ++ "\n"

/-- Remove one exact version header and required trailing newline, fail closed. -/
def decodeVersionedRows?
    (expectedHeader input : String) : Option (List String) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header != expectedHeader then
        none
      else
        match rows.reverse with
        | "" :: reversedRows => some reversedRows.reverse
        | _ => none
  | _ => none

end Loam.Persistence

import Std

namespace Loam.PresentationMetadata

/-! Shared text mechanics for replaceable human-facing `token / label / help` rows.
Household identity, admission, authority, I/O, and presentation policy stay with callers. -/

structure Row where
  token : String
  label : String
  help : String
  deriving Repr, DecidableEq

private def decodeRow? (validToken : String → Bool) (row : String) : Option Row :=
  match row.splitOn "\t" with
  | [token, label, help] =>
      if validToken token && !label.isEmpty && !help.isEmpty then
        some { token := token, label := label, help := help }
      else none
  | _ => none

/-- Decode three-column metadata, ignoring one trailing newline and rejecting duplicate tokens. -/
def decode? (validToken : String → Bool) (input : String) : Option (List Row) := do
  let raw := input.splitOn "\n"
  let body :=
    match raw.reverse with
    | "" :: rest => rest.reverse
    | _ => raw
  let rows ← body.mapM (decodeRow? validToken)
  if (rows.map fun row => row.token).Nodup then some rows else none

end Loam.PresentationMetadata

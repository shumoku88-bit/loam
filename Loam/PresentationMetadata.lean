import Std

namespace Loam.PresentationMetadata

set_option autoImplicit false

/-!
# Presentation metadata row mechanics

This module owns only the shared text mechanics for replaceable human-facing
metadata rows. It does not define household identity, admission, authority,
persistence history, or presentation policy.

The current row shape is exactly three tab-separated fields:

```text
<stable-token><TAB><label><TAB><help>
```

Callers supply the stable-token admission predicate. Duplicate stable tokens are
rejected and one optional trailing newline is ignored.
-/

structure Row where
  token : String
  label : String
  help : String
  deriving Repr, DecidableEq

private def dropOneTrailingEmpty : List String → List String
  | rows =>
      match rows.reverse with
      | "" :: rest => rest.reverse
      | _ => rows

private def decodeRow? (validToken : String → Bool) (row : String) : Option Row :=
  match row.splitOn "\t" with
  | [token, label, help] =>
      if validToken token && !label.isEmpty && !help.isEmpty then
        some { token := token, label := label, help := help }
      else none
  | _ => none

private def uniqueTokens : List Row → Bool
  | [] => true
  | row :: rest =>
      !(rest.any fun other => other.token == row.token) && uniqueTokens rest

/-- Decode one display-metadata image without assigning domain meaning to its token. -/
def decode? (validToken : String → Bool) (input : String) : Option (List Row) := do
  let rows ← (dropOneTrailingEmpty (input.splitOn "\n")).mapM (decodeRow? validToken)
  if uniqueTokens rows then some rows else none

end Loam.PresentationMetadata

import Loam.Core.Measure
import Std

namespace Loam.Core

set_option autoImplicit false

/-!
# Minimal persistence boundary

The first practical persisted value is one runtime `SomeAmount`: a stable
measure identity together with an exact signed quantity.

The text format is deliberately tiny and versioned:

```text
LOAM-AMOUNT<TAB>1
<measure-token><TAB><signed-decimal-quanta>
```

A persisted measure token is an opaque identity token, not a display name. To
keep this first format unambiguous without introducing an escaping layer, the
persistence boundary admits only nonempty tokens without tab or line-break
characters.

Filesystem failures remain ordinary `IO` exceptions. Malformed or unsupported
file contents return `none` from `decode?` / `load?`.
-/

namespace Persistence

/-- Version marker for the first persisted LOAM amount format. -/
def amountHeader : String := "LOAM-AMOUNT\t1"

/-- Whether a runtime measure token is representable by the first text format. -/
def validMeasureToken (token : String) : Bool :=
  !token.isEmpty &&
    !token.contains '\t' &&
    !token.contains '\n' &&
    !token.contains '\r'

/-- Encode one runtime amount without changing its exact quanta. -/
def encode? (amount : SomeAmount) : Option String :=
  let token := amount.measure.token
  if validMeasureToken token then
    some (amountHeader ++ "\n" ++ token ++ "\t" ++
      toString amount.quantity.quanta ++ "\n")
  else
    none

/-- Decode one value from the exact version-1 text shape. -/
def decode? (input : String) : Option SomeAmount :=
  match input.splitOn "\n" with
  | [header, row, trailing] =>
      if header = amountHeader then
        if trailing = "" then
          match row.splitOn "\t" with
          | [token, quantaText] =>
              if validMeasureToken token then
                match quantaText.toInt? with
                | some quanta =>
                    some (SomeAmount.ofQuantity
                      ⟨token⟩ (Quantity.ofQuanta quanta))
                | none => none
              else
                none
          | _ => none
        else
          none
      else
        none
  | _ => none

/--
Write one amount to a UTF-8 file when its measure token is admitted by the
format. Returns `false` only for an unrepresentable token; filesystem failures
remain `IO` exceptions.
-/
def save? (path : System.FilePath) (amount : SomeAmount) : IO Bool := do
  match encode? amount with
  | some text =>
      IO.FS.writeFile path text
      return true
  | none =>
      return false

/--
Read and decode one UTF-8 amount file. Malformed contents return `none`;
filesystem failures remain `IO` exceptions.
-/
def load? (path : System.FilePath) : IO (Option SomeAmount) := do
  let input ← IO.FS.readFile path
  return decode? input

end Persistence

end Loam.Core

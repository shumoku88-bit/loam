import Loam.Core.Measure
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows
import Std

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Runtime amount persistence

This module owns only the versioned wire representation for one runtime
`SomeAmount`. It preserves measure identity and exact signed quanta without
assigning currency, valuation, or cross-measure semantics.
-/

/-- Version marker for the first persisted LOAM amount format. -/
def amountHeader : String := "LOAM-AMOUNT\t1"

/-- Encode one runtime amount without changing its exact quanta. -/
def encode? (amount : SomeAmount) : Option String :=
  let token := amount.measure.token
  if validToken token then
    some (encodeVersionedRows amountHeader [token ++ "\t" ++ toString amount.quantity.quanta])
  else
    none

/-- Decode one amount from the exact version-1 text shape. -/
def decode? (input : String) : Option SomeAmount :=
  match input.splitOn "\n" with
  | [header, row, trailing] =>
      if header = amountHeader then
        if trailing = "" then
          match row.splitOn "\t" with
          | [token, quantaText] =>
              if validToken token then
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

end Loam.Persistence

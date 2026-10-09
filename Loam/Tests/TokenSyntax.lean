import Loam.Persistence.TokenSyntax
import Loam.Tests.Support

namespace Loam.Tests.TokenSyntax

open Loam.Tests.Support
set_option autoImplicit false

private def reference (token : String) : Bool :=
  !token.isEmpty && !token.contains '\t' && !token.contains '\n' && !token.contains '\r'

private def check (token : String) : IO Unit :=
  expect (Loam.Persistence.validToken token == reference token)
    ("single-pass token predicate changed syntax: " ++ reprStr token)

def main : IO Unit := do
  let alphabet := ["", "a", "é", "😀", " ", ":", "\t", "\n", "\r",
    String.singleton (Char.ofNat 0), String.singleton (Char.ofNat 0x200b)]
  for a in alphabet do
    for b in alphabet do
      for c in alphabet do check (a ++ b ++ c)
  -- Ordinary controls other than the three framing delimiters must not acquire
  -- new restrictions merely because all/contains use different traversal APIs.
  for code in List.range 128 do
    let scalar := String.singleton (Char.ofNat code)
    for prefixText in ["", "a", "é😀"] do
      for suffixText in ["", "z", "😀é"] do check (prefixText ++ scalar ++ suffixText)
  let long := String.join (List.replicate 1024 "é😀abc")
  check long
  for delimiter in ["\t", "\n", "\r"] do
    check (delimiter ++ long)
    check (long ++ delimiter)
    check (long ++ delimiter ++ long)
  expect (!Loam.Persistence.validToken "") "empty token was invented as representable"
  expect (Loam.Persistence.validToken " ") "opaque token syntax invented a trim policy"
  IO.println "Token syntax: original predicate parity across ASCII, Unicode, controls, empty and long tokens passed."

end Loam.Tests.TokenSyntax

def main : IO Unit := Loam.Tests.TokenSyntax.main

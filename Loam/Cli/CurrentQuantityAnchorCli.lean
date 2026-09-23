import Loam.CurrentQuantityAnchorPublisher
import Loam.Persistence.TokenSyntax
import Std

namespace Loam.CurrentQuantityAnchorCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "Publish one complete current quantity observation image:\n" ++
  "  loam current-quantity-anchor LOCUS MEASURE QUANTITY [LOCUS MEASURE QUANTITY ...]\n\n" ++
  "LOAM_DATA_DIR selects the household data root; otherwise ../loam-data is used."

private def parseAssertion?
    (locusToken measureToken quantityToken : String) :
    Except String Loam.CurrentQuantityAnchor.Assertion := do
  if !Loam.Persistence.validToken locusToken then
    throw "loam: current quantity anchor locus must be a nonempty single-line token"
  if !Loam.Persistence.validToken measureToken then
    throw "loam: current quantity anchor measure must be a nonempty single-line token"
  let some quanta := quantityToken.toInt?
    | throw "loam: current quantity anchor quantity must be an integer"
  return {
    coordinate := ⟨⟨locusToken⟩, ⟨measureToken⟩⟩
    quantity := Quantity.ofQuanta quanta
  }

private def parseTriples? :
    List String → Except String (List Loam.CurrentQuantityAnchor.Assertion)
  | [] => pure []
  | locusToken :: measureToken :: quantityToken :: rest => do
      let assertion ← parseAssertion? locusToken measureToken quantityToken
      return assertion :: (← parseTriples? rest)
  | _ =>
      throw "loam: current quantity anchor observations must be LOCUS MEASURE QUANTITY triples"

/--
Parse only the human-facing representation of quantities observed together.
Coordinate uniqueness and every reconciliation law remain the publisher's job.
-/
def parseAssertions?
    (args : List String) : Except String (List Loam.CurrentQuantityAnchor.Assertion) := do
  if args.isEmpty then
    throw "loam: current quantity anchor requires at least one observed quantity"
  parseTriples? args

/-- Resolve the canonical household root without adding another domain input. -/
private def resolveDataDir : IO (Except String String) := do
  match ← IO.getEnv "LOAM_DATA_DIR" with
  | some path =>
      if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
      return .ok path
  | none => return .ok "../loam-data"

/--
Publish one replaceable current reconciliation image. The CLI parses only
`Locus × Measure × observed Quantity`; the publisher derives the shared Event
root cut, enforces support-family separation, owns persistence, and serializes
concurrent replacement.
-/
def run (args : List String) : IO UInt32 := do
  let assertions ←
    match parseAssertions? args with
    | .error message =>
        IO.eprintln message
        IO.eprintln usage
        return 2
    | .ok parsed => pure parsed
  let rootPath ←
    match ← resolveDataDir with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok path => pure path
  match ← Loam.CurrentQuantityAnchorPublisher.publish rootPath assertions with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok () =>
      IO.println
        ("Published current quantity anchor for " ++
          toString assertions.length ++ " observed coordinate(s).")
      return 0

end Loam.CurrentQuantityAnchorCli

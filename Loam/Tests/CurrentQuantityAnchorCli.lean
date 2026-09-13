import Loam.Cli.CurrentQuantityAnchorCli

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error error => throw (IO.userError (message ++ ": " ++ error))

private def assertion (locus measure : String) (quanta : Int) :
    Loam.CurrentQuantityAnchor.Assertion := {
  coordinate := ⟨⟨locus⟩, ⟨measure⟩⟩
  quantity := Quantity.ofQuanta quanta
}

private def rejected {α : Type} (value : Except String α) : Bool :=
  match value with
  | .error _ => true
  | .ok _ => false

def main : IO Unit := do
  let parsed ← requireOk
    (Loam.CurrentQuantityAnchorCli.parseAssertions?
      ["debt", "jpy", "-70", "cash", "jpy", "120"])
    "current quantity anchor CLI triples"
  expect
    (decide (parsed = [assertion "debt" "jpy" (-70), assertion "cash" "jpy" 120]))
    "CLI changed locus, measure, quantity, or observation order"

  let duplicates ← requireOk
    (Loam.CurrentQuantityAnchorCli.parseAssertions?
      ["debt", "jpy", "-70", "debt", "jpy", "-70"])
    "duplicate-coordinate CLI syntax"
  expect (duplicates.length == 2)
    "CLI started enforcing anchor coordinate uniqueness instead of delegating semantics"

  expect
    (rejected (Loam.CurrentQuantityAnchorCli.parseAssertions? []))
    "CLI admitted an empty current quantity observation image"
  expect
    (rejected (Loam.CurrentQuantityAnchorCli.parseAssertions? ["debt", "jpy"]))
    "CLI admitted a partial observation triple"
  expect
    (rejected (Loam.CurrentQuantityAnchorCli.parseAssertions? ["debt\tbad", "jpy", "1"]))
    "CLI admitted a nonrepresentable locus token"
  expect
    (rejected (Loam.CurrentQuantityAnchorCli.parseAssertions? ["debt", "jpy\n", "1"]))
    "CLI admitted a nonrepresentable measure token"
  expect
    (rejected (Loam.CurrentQuantityAnchorCli.parseAssertions? ["debt", "jpy", "1.5"]))
    "CLI admitted a noninteger observed quantity"

  IO.println
    "Current Quantity Anchor CLI: triple syntax qualified without adding reconciliation semantics."

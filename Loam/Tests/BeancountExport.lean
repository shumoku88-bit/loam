import Loam.BeancountExport

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def eventOf
    (id : String)
    (effects : List Effect) : IO Event := do
  requireSome (Event.ofEffects? ⟨id⟩ effects) ("event admission failed: " ++ id)

def main : IO Unit := do
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := ⟨"smbc"⟩, role := .asset }
      , { locus := ⟨"food"⟩, role := .expense }
      , { locus := ⟨"book"⟩, role := .expense }
      ])
    "role fixture"

  let splitEvent ← eventOf "event-split"
    [ Effect.ofAnonymousQuantity
        ⟨"smbc"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-1000))
    , Effect.ofAnonymousQuantity
        ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 700)
    , Effect.ofAnonymousQuantity
        ⟨"book"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 300)
    ]
  let entry : Loam.ActualJournalProjection.Entry := {
    event := splitEvent
    validOn := "2026-09-15"
    description := some "Food \"and\" book\nsplit"
  }

  let .ok rendered := Loam.BeancountExport.render? roles [entry]
    | throw (IO.userError "balanced Beancount export refused")

  expect (contains "2026-09-15 open Assets:Loam-smbc JPY" rendered)
    "Asset Open directive missing"
  expect (contains "2026-09-15 open Expenses:Loam-food JPY" rendered)
    "Food Open directive missing"
  expect (contains "2026-09-15 open Expenses:Loam-book JPY" rendered)
    "Book Open directive missing"
  expect
    (contains "2026-09-15 * \"Food \\\"and\\\" book split\"" rendered)
    "transaction description was not safely quoted"
  expect (contains "  loam_event_id: \"event-split\"" rendered)
    "LOAM Event identity metadata missing"
  expect (contains "  Assets:Loam-smbc  -1000 JPY" rendered)
    "Asset posting missing"
  expect (contains "    loam_locus: \"smbc\"" rendered)
    "LOAM Locus metadata missing"
  expect (contains "    loam_measure: \"jpy\"" rendered)
    "LOAM Measure metadata missing"
  expect (contains "  Expenses:Loam-food  700 JPY" rendered)
    "food split missing"
  expect (contains "  Expenses:Loam-book  300 JPY" rendered)
    "book split missing"

  let unresolved ← eventOf "event-unresolved"
    [ Effect.ofAnonymousQuantity
        ⟨"smbc"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100))
    , Effect.ofAnonymousQuantity
        ⟨"unknown"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    ]
  let unresolvedEntry : Loam.ActualJournalProjection.Entry := {
    event := unresolved
    validOn := "2026-09-16"
    description := none
  }
  match Loam.BeancountExport.render? roles [unresolvedEntry] with
  | .ok _ =>
      throw (IO.userError "unresolved AccountingRole was silently exported")
  | .error message =>
      expect (contains "explicit AccountingRole for Loci: unknown" message)
        "unresolved-role refusal did not name the missing Locus"

  let unbalanced ← eventOf "event-unbalanced"
    [ Effect.ofAnonymousQuantity
        ⟨"smbc"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100))
    , Effect.ofAnonymousQuantity
        ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 99)
    ]
  let unbalancedEntry : Loam.ActualJournalProjection.Entry := {
    event := unbalanced
    validOn := "2026-09-17"
    description := none
  }
  match Loam.BeancountExport.render? roles [unbalancedEntry] with
  | .ok _ =>
      throw (IO.userError "unbalanced Event was exported")
  | .error message =>
      expect (contains "per-Measure balance" message)
        "unbalanced refusal did not explain the boundary"

  let collisionRoles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := ⟨"a:b"⟩, role := .asset }
      , { locus := ⟨"a-b"⟩, role := .asset }
      ])
    "collision role fixture"
  let collisionEvent ← eventOf "event-collision"
    [ Effect.ofAnonymousQuantity
        ⟨"a:b"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100))
    , Effect.ofAnonymousQuantity
        ⟨"a-b"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    ]
  let collisionEntry : Loam.ActualJournalProjection.Entry := {
    event := collisionEvent
    validOn := "2026-09-18"
    description := none
  }
  match Loam.BeancountExport.render? collisionRoles [collisionEntry] with
  | .ok _ =>
      throw (IO.userError "target account-name collision was exported")
  | .error message =>
      expect (contains "target account collision" message)
        "target collision refusal did not explain the boundary"

  IO.println
    "Beancount export: split postings, metadata, quoting, role refusal, balance refusal, and target collision checks passed."

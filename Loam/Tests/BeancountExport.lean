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

  expect (contains "option \"operating_currency\" \"JPY\"" rendered)
    "operating_currency option missing in strict export"
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

  -- Partial export tests
  let multiUnresolved ← eventOf "event-multi-unresolved"
    [ Effect.ofAnonymousQuantity
        ⟨"smbc"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-200))
    , Effect.ofAnonymousQuantity
        ⟨"zebra_unknown"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    , Effect.ofAnonymousQuantity
        ⟨"alpha_unknown"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    ]
  let multiUnresolvedEntry : Loam.ActualJournalProjection.Entry := {
    event := multiUnresolved
    validOn := "2026-09-19"
    description := some "Secret household transfer detail 12345"
  }

  let partialEntries := [entry, unresolvedEntry, multiUnresolvedEntry]
  let .ok partialRes := Loam.BeancountExport.renderPartial? roles partialEntries
    | throw (IO.userError "partial export failed")

  expect (partialRes.exportedCount == 1)
    "partial export exportedCount should be 1"
  expect (partialRes.skippedCount == 2)
    "partial export skippedCount should be 2"

  -- Beancount output should contain exported transaction but NOT skipped ones
  expect (contains "option \"operating_currency\" \"JPY\"" partialRes.beancount)
    "operating_currency option missing in partial export"
  expect (contains "loam_event_id: \"event-split\"" partialRes.beancount)
    "partial beancount should contain split event"
  expect (!contains "event-unresolved" partialRes.beancount)
    "partial beancount must not contain unresolved event"
  expect (!contains "event-multi-unresolved" partialRes.beancount)
    "partial beancount must not contain multi-unresolved event"
  expect (!contains "alpha_unknown" partialRes.beancount)
    "partial beancount must not contain unresolved accounts"

  -- Report assertions
  expect (contains "Exported current Events: 1" partialRes.report)
    "report should include exported count"
  expect (contains "Skipped current Events: 2" partialRes.report)
    "report should include skipped count"
  expect (contains "  alpha_unknown: 1 Events" partialRes.report)
    "report should include alpha_unknown"
  expect (contains "  unknown: 1 Events" partialRes.report)
    "report should include unknown"
  expect (contains "  zebra_unknown: 1 Events" partialRes.report)
    "report should include zebra_unknown"

  -- Privacy verification: report must not leak description or amounts
  expect (!contains "Secret household transfer detail" partialRes.report)
    "report must not leak transaction description"
  expect (!contains "12345" partialRes.report)
    "report must not leak amounts or identifiers"

  -- In skippedEvents, loci must be sorted
  match partialRes.skippedEvents with
  | [s1, s2] =>
      expect (s1.eventId == ⟨"event-unresolved"⟩) "first skipped event id"
      expect (s2.eventId == ⟨"event-multi-unresolved"⟩) "second skipped event id"
      expect (s2.unresolvedLoci == [⟨"alpha_unknown"⟩, ⟨"zebra_unknown"⟩])
        "unresolved loci within skipped event must be sorted"
  | _ => throw (IO.userError "expected 2 skipped events in result")

  -- Partial mode must still reject unbalanced events
  match Loam.BeancountExport.renderPartial? roles [unbalancedEntry] with
  | .ok _ =>
      throw (IO.userError "partial mode silently accepted unbalanced Event")
  | .error message =>
      expect (contains "per-Measure balance" message)
        "partial mode must enforce balance"

  -- Partial mode must still reject target account collisions for exported events
  match Loam.BeancountExport.renderPartial? collisionRoles [collisionEntry] with
  | .ok _ =>
      throw (IO.userError "partial mode silently accepted collision")
  | .error message =>
      expect (contains "target account collision" message)
        "partial mode must enforce target account collision refusal"

  -- Multi-currency operating_currency determinism and completeness test
  let multiCurrencyRoles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := ⟨"smbc"⟩, role := .asset }
      , { locus := ⟨"food"⟩, role := .expense }
      , { locus := ⟨"wise_usd"⟩, role := .asset }
      , { locus := ⟨"book_usd"⟩, role := .expense }
      , { locus := ⟨"book"⟩, role := .expense }
      ])
    "multi-currency roles"
  let usdEvent ← eventOf "event-usd"
    [ Effect.ofAnonymousQuantity
        ⟨"wise_usd"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-50))
    , Effect.ofAnonymousQuantity
        ⟨"book_usd"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 50)
    ]
  let usdEntry : Loam.ActualJournalProjection.Entry := {
    event := usdEvent
    validOn := "2026-09-15"
    description := none
  }
  let multiRendered ←
    match Loam.BeancountExport.render? multiCurrencyRoles [entry, usdEntry] with
    | .ok rendered => pure rendered
    | .error message => throw (IO.userError ("multi-currency export failed: " ++ message))
  expect (contains "option \"operating_currency\" \"JPY\"" multiRendered)
    "JPY operating_currency missing in multi-currency export"
  expect (contains "option \"operating_currency\" \"USD\"" multiRendered)
    "USD operating_currency missing in multi-currency export"

  IO.println
    "Beancount export: split postings, metadata, quoting, role refusal, balance refusal, target collision, partial export, and operating_currency checks passed."

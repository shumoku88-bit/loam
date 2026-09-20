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

  -- Suspense mode tests
  let .ok suspenseRes := Loam.BeancountExport.renderSuspense? roles partialEntries
    | throw (IO.userError "suspense export failed")

  expect (suspenseRes.exportedCount == 3)
    "suspense export exportedCount should be 3 (all events retained)"
  expect (suspenseRes.unresolvedEffectCount == 3)
    "suspense export unresolvedEffectCount should be 3"

  -- Beancount output should contain all events and proper postings
  expect (contains "option \"operating_currency\" \"JPY\"" suspenseRes.beancount)
    "operating_currency option missing in suspense export"
  expect (contains "open Equity:Loam-Unresolved JPY" suspenseRes.beancount)
    "Equity:Loam-Unresolved Open directive missing"
  expect (contains "open Assets:Loam-smbc JPY" suspenseRes.beancount)
    "Asset Open directive missing in suspense export"
  expect (contains "loam_event_id: \"event-split\"" suspenseRes.beancount)
    "split event missing in suspense export"
  expect (contains "loam_event_id: \"event-unresolved\"" suspenseRes.beancount)
    "unresolved event missing in suspense export"
  expect (contains "loam_event_id: \"event-multi-unresolved\"" suspenseRes.beancount)
    "multi-unresolved event missing in suspense export"

  -- Postings and metadata assertions
  expect (contains "  Assets:Loam-smbc  -100 JPY" suspenseRes.beancount)
    "resolved posting preserved in suspense export"
  expect (contains "  Equity:Loam-Unresolved  100 JPY" suspenseRes.beancount)
    "unresolved posting projected to Equity:Loam-Unresolved"
  expect (contains "    loam_unresolved_locus: \"unknown\"" suspenseRes.beancount)
    "unresolved locus metadata missing for unknown"
  expect (contains "    loam_unresolved_locus: \"alpha_unknown\"" suspenseRes.beancount)
    "unresolved locus metadata missing for alpha_unknown"
  expect (contains "    loam_unresolved_locus: \"zebra_unknown\"" suspenseRes.beancount)
    "unresolved locus metadata missing for zebra_unknown"

  -- Suspense report assertions
  expect (contains "Beancount suspense projection" suspenseRes.report)
    "report header missing"
  expect (contains "Exported current Events: 3" suspenseRes.report)
    "report exported count missing"
  expect (contains "Unresolved Effects projected to suspense: 3" suspenseRes.report)
    "report unresolved effects count missing"
  expect (contains "  alpha_unknown: 1 Effects" suspenseRes.report)
    "report alpha_unknown missing"
  expect (contains "  unknown: 1 Effects" suspenseRes.report)
    "report unknown missing"
  expect (contains "  zebra_unknown: 1 Effects" suspenseRes.report)
    "report zebra_unknown missing"
  expect (contains "  all current Events retained" suspenseRes.report)
    "report summary retained line missing"
  expect (contains "  unresolved roles were NOT inferred" suspenseRes.report)
    "report non-inference statement missing"
  expect (contains "  Equity:Loam-Unresolved is target scaffolding only" suspenseRes.report)
    "report target scaffolding statement missing"

  -- Privacy verification: report must not leak description or amounts
  expect (!contains "Secret household transfer detail" suspenseRes.report)
    "suspense report must not leak transaction description"
  expect (!contains "12345" suspenseRes.report)
    "suspense report must not leak transaction identifier/amount"

  -- Suspense mode must still reject unbalanced events
  match Loam.BeancountExport.renderSuspense? roles [unbalancedEntry] with
  | .ok _ =>
      throw (IO.userError "suspense mode silently accepted unbalanced Event")
  | .error message =>
      expect (contains "per-Measure balance" message)
        "suspense mode must enforce balance"

  -- Suspense mode must reject collision with technical suspense account
  let collisionSuspenseRoles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := ⟨"Unresolved"⟩, role := .equity }
      , { locus := ⟨"food"⟩, role := .expense }
      ])
    "collision suspense roles"
  let collisionSuspenseEvent ← eventOf "event-suspense-collision"
    [ Effect.ofAnonymousQuantity
        ⟨"Unresolved"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100))
    , Effect.ofAnonymousQuantity
        ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    ]
  let collisionSuspenseEntry : Loam.ActualJournalProjection.Entry := {
    event := collisionSuspenseEvent
    validOn := "2026-09-18"
    description := none
  }
  match Loam.BeancountExport.renderSuspense? collisionSuspenseRoles [collisionSuspenseEntry] with
  | .ok _ =>
      throw (IO.userError "suspense collision was silently accepted")
  | .error message =>
      expect (contains "collision" message)
        "suspense collision refusal did not explain boundary"

  IO.println
    "Beancount export: split postings, metadata, quoting, role refusal, balance refusal, target collision, partial export, operating_currency, and suspense export checks passed."

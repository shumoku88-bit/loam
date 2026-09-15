import Loam.CurrentQuantityAnchorPublisher
import Loam.RoleBalanceReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error error => throw (IO.userError (message ++ ": " ++ error))

private def effect (key locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

def main : IO Unit := do
  let old ← requireSome
    (Event.ofEffects? ⟨"old-root"⟩ [effect "old-effect" "debt" (-40)])
    "old root"
  let replacement ← requireSome
    (Event.ofEffects? ⟨"old-replacement"⟩ [effect "replacement-effect" "debt" (-50)])
    "replacement"
  let later ← requireSome
    (Event.ofEffects? ⟨"later-root"⟩ [effect "later-effect" "debt" 10])
    "later root"
  let events ← requireSome
    (EventMemory.ofEvents? [old, replacement, later])
    "event memory"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [{ target := old.id, replacement := replacement.id }])
    "correction memory"

  let debt : EffectCoordinate := ⟨⟨"debt"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let assertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-70) }
  let cashAssertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := cash, quantity := Quantity.ofQuanta 25 }

  let roots ← requireSome
    (Loam.Application.correctionRootIds? events corrections)
    "admitted correction roots"
  expect (roots.contains old.id) "stable correction root disappeared"
  expect (roots.contains later.id) "untouched Event was not its own root"
  expect (!roots.contains replacement.id) "replacement terminal became a second root"

  -- The observation happened after old-root was already reflected but before later-root.
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [old.id] [assertion])
    "manual anchor"
  let some anchored ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections anchor debt)
    "anchored quantity"
    | throw (IO.userError "anchored assertion disappeared")
  expect (anchored.quanta == -60)
    "covered corrected root was counted again or later delta was lost"

  -- Several assertions from one observation share the same reflected-root cut.
  let multiAnchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [old.id] [assertion, cashAssertion])
    "multi-coordinate anchor"
  let bulk ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantities events corrections multiAnchor [debt, cash])
    "shared anchor quantities"
  match bulk with
  | [some bulkDebt, some bulkCash] =>
      expect (bulkDebt.quanta == anchored.quanta)
        "bulk anchor changed debt quantity"
      expect (bulkCash.quanta == 25)
        "bulk anchor changed independent cash assertion"
  | _ => throw (IO.userError "bulk anchor did not preserve selected coordinates")

  -- Without the explicit cut, the same scalar assertion double-counts the corrected old root.
  let noCut ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [] [assertion])
    "uncut anchor"
  let some uncut ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections noCut debt)
    "uncut quantity"
    | throw (IO.userError "uncut assertion disappeared")
  expect (uncut.quanta == -110) "root cut stopped being independently observable"

  -- A writer observing the quantity now snapshots every currently represented stable root.
  let nowAssertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := anchored }
  let published ← requireOk
    (Loam.CurrentQuantityAnchorPublisher.propose?
      events corrections ZeroOriginCoverage.empty OpeningSupportMap.empty [nowAssertion])
    "publisher proposal"
  expect (published.reflectedRoots.contains old.id) "publisher omitted corrected root"
  expect (published.reflectedRoots.contains later.id) "publisher omitted untouched root"
  let some publishedQuantity ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections published debt)
    "published anchored quantity"
    | throw (IO.userError "published assertion disappeared")
  expect (publishedQuantity.quanta == anchored.quanta)
    "new reconciliation session did not preserve the observed current quantity"

  let encoded ← requireSome
    (Loam.Persistence.encodeCurrentQuantityAnchor? anchor)
    "anchor encoding"
  let decoded ← requireSome
    (Loam.Persistence.decodeCurrentQuantityAnchor? encoded)
    "anchor decoding"
  expect (decide (decoded = anchor)) "anchor persistence roundtrip changed"

  expect
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      [old.id, old.id] [assertion]).isNone
    "duplicate reflected root was admitted"
  expect
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      [old.id] [assertion, assertion]).isNone
    "duplicate asserted coordinate was admitted"

  let ghostAnchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [⟨"ghost-root"⟩] [assertion])
    "ghost anchor structure"
  expect
    (match Loam.CurrentQuantityAnchor.inspectQuantity events corrections ghostAnchor debt with
      | .error _ => true
      | .ok _ => false)
    "unknown reflected root did not fail closed"

  let covered ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [debt])
    "overlap coverage"
  expect
    (match Loam.CurrentQuantityAnchorPublisher.propose?
      events corrections covered OpeningSupportMap.empty [nowAssertion] with
      | .error _ => true
      | .ok _ => false)
    "publisher invented precedence over zero-origin support"

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments? [
      { locus := ⟨"debt"⟩, role := .liability },
      { locus := ⟨"cash"⟩, role := .asset }
    ])
    "role map"
  let roleEvidence : Loam.BalanceReview.Evidence := {
    events := events
    corrections := corrections
    coverage := ZeroOriginCoverage.empty
  }
  let roleSnapshot ← requireOk
    (Loam.RoleBalanceReview.project
      roleEvidence OpeningSupportMap.empty anchor roles)
    "role balance anchor composition"
  let some debtRow := roleSnapshot.rows.find? fun row => row.coordinate = debt
    | throw (IO.userError "anchored debt did not enter RoleBalance")
  expect (debtRow.quantity.quanta == -60)
    "RoleBalance changed current-anchor quantity"
  expect
    (!(roleSnapshot.unsupportedBalances.any fun row => row.coordinate = debt))
    "anchored debt remained unsupported"

  let multiRoleSnapshot ← requireOk
    (Loam.RoleBalanceReview.project
      roleEvidence OpeningSupportMap.empty multiAnchor roles)
    "role balance shared anchor composition"
  let some multiDebt := multiRoleSnapshot.rows.find? fun row => row.coordinate = debt
    | throw (IO.userError "shared anchored debt did not enter RoleBalance")
  let some multiCash := multiRoleSnapshot.rows.find? fun row => row.coordinate = cash
    | throw (IO.userError "shared anchored cash did not enter RoleBalance")
  expect (multiDebt.quantity.quanta == -60)
    "RoleBalance shared cut changed debt quantity"
  expect (multiCash.quantity.quanta == 25)
    "RoleBalance shared cut changed cash quantity"

  expect
    (match Loam.RoleBalanceReview.project
      { roleEvidence with coverage := covered }
      OpeningSupportMap.empty anchor roles with
      | .error _ => true
      | .ok _ => false)
    "RoleBalance selected a winner for overlapping support families"

  IO.println
    "Current Quantity Anchor: shared root cut, correction stability, persistence and RoleBalance composition qualified."

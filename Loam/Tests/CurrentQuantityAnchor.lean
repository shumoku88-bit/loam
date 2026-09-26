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
  let locusAdmission ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [⟨"debt"⟩, ⟨"cash"⟩])
    "current Locus admission vocabulary"

  let debt : EffectCoordinate := ⟨⟨"debt"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let typo : EffectCoordinate := ⟨⟨"detb"⟩, ⟨"jpy"⟩⟩
  let assertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-70) }
  let cashAssertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := cash, quantity := Quantity.ofQuanta 25 }
  let typoAssertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := typo, quantity := Quantity.ofQuanta (-70) }

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
      events corrections locusAdmission ZeroOriginCoverage.empty
      OpeningSupportMap.empty [nowAssertion])
    "publisher proposal"
  let publishedGroup ← requireSome published.singleGroup? "publisher single group"
  expect (publishedGroup.reflectedRoots.contains old.id) "publisher omitted corrected root"
  expect (publishedGroup.reflectedRoots.contains later.id) "publisher omitted untouched root"
  let some publishedQuantity ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections published debt)
    "published anchored quantity"
    | throw (IO.userError "published assertion disappeared")
  expect (publishedQuantity.quanta == anchored.quanta)
    "new reconciliation session did not preserve the observed current quantity"

  -- Retained anchor evidence may still describe a historical/read-only Locus, but a
  -- new publication cannot create a canonical quantity coordinate outside current admission.
  let historicalOnly ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [old.id] [typoAssertion])
    "historical-only anchor evidence"
  expect
    ((Loam.CurrentQuantityAnchor.Evidence.assertionFor? historicalOnly typo).isSome)
    "retained anchor structure unexpectedly depended on current admission"
  expect
    (match Loam.CurrentQuantityAnchorPublisher.propose?
      events corrections locusAdmission ZeroOriginCoverage.empty
      OpeningSupportMap.empty [typoAssertion] with
      | .error _ => true
      | .ok _ => false)
    "publisher admitted an unapproved Locus through current quantity evidence"

  let encoded ← requireSome
    (Loam.Persistence.encodeCurrentQuantityAnchor? anchor)
    "anchor encoding"
  let decoded ← requireSome
    (Loam.Persistence.decodeCurrentQuantityAnchor? encoded)
    "anchor decoding"
  expect (decide (decoded = anchor)) "anchor persistence roundtrip changed"

  -- Version-1 one-cut images remain readable as one semantic group.
  let legacyText :=
    Loam.Persistence.encodeVersionedRows
      "LOAM-CURRENT-QUANTITY-ANCHOR\t1"
      ["ROOT\told-root", "ASSERT\tdebt\tjpy\t-70"]
  let legacy ← requireSome
    (Loam.Persistence.decodeCurrentQuantityAnchor? legacyText)
    "version-1 anchor compatibility"
  expect (decide (legacy = anchor))
    "version-1 anchor did not lift into one reconciliation group"

  -- A later independently observed coordinate gets a new group while the older
  -- coordinate keeps its prior cut and therefore its prior current answer.
  let incremental ← requireOk
    (Loam.CurrentQuantityAnchorPublisher.proposeUpdate?
      events corrections locusAdmission ZeroOriginCoverage.empty
      OpeningSupportMap.empty anchor [cashAssertion])
    "incremental anchor proposal"
  expect (incremental.groups.length == 2)
    "later independent observation did not preserve the older group"
  let some incrementalDebt ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections incremental debt)
    "incremental debt quantity"
    | throw (IO.userError "incremental update lost prior debt support")
  let some incrementalCash ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections incremental cash)
    "incremental cash quantity"
    | throw (IO.userError "incremental update lost new cash support")
  expect (incrementalDebt.quanta == anchored.quanta)
    "adding a later coordinate changed the prior anchored answer"
  expect (incrementalCash.quanta == cashAssertion.quantity.quanta)
    "new reconciliation group changed its observed quantity"

  -- Re-observing one coordinate moves only that coordinate to the newest cut.
  let revisedDebt : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-55) }
  let reobserved ← requireOk
    (Loam.CurrentQuantityAnchorPublisher.proposeUpdate?
      events corrections locusAdmission ZeroOriginCoverage.empty
      OpeningSupportMap.empty incremental [revisedDebt])
    "re-observed anchor proposal"
  expect (reobserved.groups.length == 2)
    "re-observation did not drop the emptied old group"
  let some reobservedDebt ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections reobserved debt)
    "re-observed debt quantity"
    | throw (IO.userError "re-observation lost debt support")
  let some retainedCash ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections reobserved cash)
    "retained cash quantity"
    | throw (IO.userError "re-observation lost unrelated cash support")
  expect (reobservedDebt.quanta == -55)
    "re-observed coordinate did not move to the new cut"
  expect (retainedCash.quanta == cashAssertion.quantity.quanta)
    "re-observing debt changed unrelated cash support"

  let duplicateGroupA ← requireSome
    (Loam.CurrentQuantityAnchor.Group.ofLists? [old.id] [assertion])
    "duplicate-group A"
  let duplicateGroupB ← requireSome
    (Loam.CurrentQuantityAnchor.Group.ofLists? [old.id, later.id] [assertion])
    "duplicate-group B"
  expect
    (Loam.CurrentQuantityAnchor.Evidence.ofGroups?
      [duplicateGroupA, duplicateGroupB]).isNone
    "one coordinate was admitted into two live reconciliation groups"

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
      events corrections locusAdmission covered OpeningSupportMap.empty [nowAssertion] with
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
    "Current Quantity Anchor: grouped cuts, incremental observation, v1 compatibility, current Locus admission, correction stability, persistence and RoleBalance composition qualified."

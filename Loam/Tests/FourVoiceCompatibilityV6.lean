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

private def yen : MeasureId := ⟨"jpy"⟩
private def debt : EffectCoordinate := ⟨⟨"debt"⟩, yen⟩

private def debtAdmission : LocusAdmissionVocabulary :=
  { approved := [debt.locus], nodup := by simp }

private def event? (id : String) (amount : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩
    [Effect.ofQuantity ⟨id ++ "-effect"⟩ debt.locus debt.measure
      (Quantity.ofQuanta amount)]

private def emptyCorrections : IO EventCorrectionMemory :=
  requireSome (EventCorrectionMemory.ofCorrections? []) "empty correction memory"

private def debtRoles : IO AccountingRoleMap :=
  requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := debt.locus, role := .liability }])
    "debt roles"

private def findDebtRow?
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Option Loam.RoleBalanceReview.Row :=
  snapshot.rows.find? fun row => row.coordinate = debt

private def hasUnsupportedDebt (snapshot : Loam.RoleBalanceReview.Snapshot) : Bool :=
  snapshot.unsupportedBalances.any fun row => row.coordinate = debt

/--
V6a: compatible evidence can increase answerability. An Event coordinate with a
known role but no quantity support is visible as unsupported; explicit current
OpeningSupport turns it into one justified balance row.
-/
private def compatibleSupportAddsAnswer : IO Unit := do
  let opening ← requireSome (event? "v6a-opening" (-100)) "V6a opening"
  let events ← requireSome (EventMemory.ofEvents? [opening]) "V6a events"
  let corrections ← emptyCorrections
  let roles ← debtRoles
  let evidence : Loam.BalanceReview.Evidence :=
    { events := events, corrections := corrections, coverage := ZeroOriginCoverage.empty }
  let anchor := Loam.CurrentQuantityAnchor.Evidence.empty

  let before ← requireOk
    (Loam.RoleBalanceReview.project evidence OpeningSupportMap.empty anchor roles)
    "V6a before"
  expect (hasUnsupportedDebt before)
    "V6a unsupported coordinate disappeared before support"
  expect (findDebtRow? before).isNone
    "V6a unsupported coordinate already had a balance answer"

  let support ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := debt, openingEvent := opening.id }])
    "V6a opening support"
  let after ← requireOk
    (Loam.RoleBalanceReview.project evidence support anchor roles)
    "V6a after"
  let row ← requireSome (findDebtRow? after) "V6a supported debt row"
  expect (row.quantity.quanta == -100)
    "V6a opening support did not add the expected current answer"
  expect (!hasUnsupportedDebt after)
    "V6a supported coordinate remained unsupported"

/--
V6b: retained evidence can grow while an existing answer disappears. Once the
opening witness is corrected away from the current frontier, the old support is
stale and RoleBalance refuses to guess that the replacement inherited it.
-/
private def staleWitnessRemovesAnswer : IO Unit := do
  let opening ← requireSome (event? "v6b-opening" (-100)) "V6b opening"
  let replacement ← requireSome (event? "v6b-replacement" (-120)) "V6b replacement"
  let events0 ← requireSome (EventMemory.ofEvents? [opening]) "V6b events0"
  let events1 ← requireSome
    (EventMemory.ofEvents? [opening, replacement]) "V6b events1"
  let corrections0 ← emptyCorrections
  let corrections1 ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := opening.id, replacement := replacement.id }])
    "V6b corrections1"
  let support ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := debt, openingEvent := opening.id }])
    "V6b opening support"
  let roles ← debtRoles
  let anchor := Loam.CurrentQuantityAnchor.Evidence.empty
  let evidence0 : Loam.BalanceReview.Evidence :=
    { events := events0, corrections := corrections0, coverage := ZeroOriginCoverage.empty }
  let evidence1 : Loam.BalanceReview.Evidence :=
    { events := events1, corrections := corrections1, coverage := ZeroOriginCoverage.empty }

  let before ← requireOk
    (Loam.RoleBalanceReview.project evidence0 support anchor roles)
    "V6b before"
  let beforeRow ← requireSome (findDebtRow? before) "V6b before debt row"
  expect (beforeRow.quantity.quanta == -100) "V6b initial answer"

  expect
    (match Loam.RoleBalanceReview.project evidence1 support anchor roles with
      | .error _ => true
      | .ok _ => false)
    "V6b added correction evidence did not invalidate the stale opening witness"

/--
V6c: answerability can be restored, but only by a new explicit support claim.
The correction relation alone does not migrate OpeningSupport to its replacement.
-/
private def explicitResupportRestoresAnswer : IO Unit := do
  let opening ← requireSome (event? "v6c-opening" (-100)) "V6c opening"
  let replacement ← requireSome (event? "v6c-replacement" (-120)) "V6c replacement"
  let events ← requireSome
    (EventMemory.ofEvents? [opening, replacement]) "V6c events"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := opening.id, replacement := replacement.id }])
    "V6c corrections"
  let replacementSupport ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := debt, openingEvent := replacement.id }])
    "V6c replacement support"
  let roles ← debtRoles
  let evidence : Loam.BalanceReview.Evidence :=
    { events := events, corrections := corrections, coverage := ZeroOriginCoverage.empty }

  let restored ← requireOk
    (Loam.RoleBalanceReview.project evidence replacementSupport
      Loam.CurrentQuantityAnchor.Evidence.empty roles)
    "V6c restored"
  let row ← requireSome (findDebtRow? restored) "V6c restored debt row"
  expect (row.quantity.quanta == -120)
    "V6c explicit replacement support did not restore the current answer"

/--
V6d: two independently meaningful support families on one coordinate are not
"more support". The reader fails closed, and the CurrentQuantityAnchor publisher
also refuses to create the overlapping image.
-/
private def overlappingSupportRemovesAnswer : IO Unit := do
  let opening ← requireSome (event? "v6d-opening" (-100)) "V6d opening"
  let events ← requireSome (EventMemory.ofEvents? [opening]) "V6d events"
  let corrections ← emptyCorrections
  let support ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := debt, openingEvent := opening.id }])
    "V6d opening support"
  let roles ← debtRoles
  let evidence : Loam.BalanceReview.Evidence :=
    { events := events, corrections := corrections, coverage := ZeroOriginCoverage.empty }
  let emptyAnchor := Loam.CurrentQuantityAnchor.Evidence.empty
  let before ← requireOk
    (Loam.RoleBalanceReview.project evidence support emptyAnchor roles)
    "V6d before"
  expect (findDebtRow? before).isSome "V6d opening-supported answer missing"

  let assertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-100) }
  let overlappingAnchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [opening.id] [assertion])
    "V6d overlapping anchor"

  expect
    (match Loam.RoleBalanceReview.project evidence support overlappingAnchor roles with
      | .error _ => true
      | .ok _ => false)
    "V6d reader invented precedence between opening and current-anchor support"
  expect
    (match Loam.CurrentQuantityAnchorPublisher.propose?
      events corrections debtAdmission ZeroOriginCoverage.empty support [assertion] with
      | .error _ => true
      | .ok _ => false)
    "V6d publisher admitted overlapping opening/current-anchor support"

/--
V6e: raw correction facts can increase while every current-balance answer becomes
unavailable. A branching correction relation is retainable raw evidence but does
not justify one current frontier, so RoleBalance refuses the whole projection.
-/
private def unresolvedCorrectionTopologyRemovesAnswer : IO Unit := do
  let old ← requireSome (event? "v6e-old" (-100)) "V6e old"
  let replacementA ← requireSome (event? "v6e-a" (-110)) "V6e replacement A"
  let replacementB ← requireSome (event? "v6e-b" (-120)) "V6e replacement B"
  let events0 ← requireSome (EventMemory.ofEvents? [old]) "V6e events0"
  let events1 ← requireSome
    (EventMemory.ofEvents? [old, replacementA, replacementB]) "V6e events1"
  let corrections0 ← emptyCorrections
  let corrections1 ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [ { target := old.id, replacement := replacementA.id }
      , { target := old.id, replacement := replacementB.id } ])
    "V6e branching raw corrections"
  let coverage ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [debt]) "V6e zero-origin coverage"
  let roles ← debtRoles
  let evidence0 : Loam.BalanceReview.Evidence :=
    { events := events0, corrections := corrections0, coverage := coverage }
  let evidence1 : Loam.BalanceReview.Evidence :=
    { events := events1, corrections := corrections1, coverage := coverage }

  let before ← requireOk
    (Loam.RoleBalanceReview.project evidence0 OpeningSupportMap.empty
      Loam.CurrentQuantityAnchor.Evidence.empty roles)
    "V6e before"
  let row ← requireSome (findDebtRow? before) "V6e before debt row"
  expect (row.quantity.quanta == -100) "V6e initial zero-origin answer"

  expect
    (match Loam.RoleBalanceReview.project evidence1 OpeningSupportMap.empty
      Loam.CurrentQuantityAnchor.Evidence.empty roles with
      | .error _ => true
      | .ok _ => false)
    "V6e unresolved branching corrections still produced a current answer"

/--
V6f: the same non-overlap rule also applies between zero-origin and OpeningSupport.
The reader must not silently choose zero-origin simply because its projection is
listed first. Observation of this seam during V6 tightened the implementation to
match the already documented support-separation rule.
-/
private def zeroOriginOpeningOverlapFailsClosed : IO Unit := do
  let opening ← requireSome (event? "v6f-opening" (-100)) "V6f opening"
  let events ← requireSome (EventMemory.ofEvents? [opening]) "V6f events"
  let corrections ← emptyCorrections
  let coverage ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [debt]) "V6f zero-origin coverage"
  let support ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := debt, openingEvent := opening.id }])
    "V6f opening support"
  let roles ← debtRoles
  let evidence : Loam.BalanceReview.Evidence :=
    { events := events, corrections := corrections, coverage := coverage }

  expect
    (match Loam.RoleBalanceReview.project evidence support
      Loam.CurrentQuantityAnchor.Evidence.empty roles with
      | .error _ => true
      | .ok _ => false)
    "V6f reader silently preferred zero-origin over opening support"


def main : IO Unit := do
  compatibleSupportAddsAnswer
  staleWitnessRemovesAnswer
  explicitResupportRestoresAnswer
  overlappingSupportRemovesAnswer
  unresolvedCorrectionTopologyRemovesAnswer
  zeroOriginOpeningOverlapFailsClosed
  IO.println
    "Four-voice V6: answerability grows under compatible support, can shrink when retained evidence invalidates a witness or creates incompatible/undecidable support, and is restored only by new evidence that explicitly re-qualifies the claim; all current support-family overlaps fail closed rather than inventing precedence."
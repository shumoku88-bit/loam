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

private def debt : EffectCoordinate := ⟨⟨"debt"⟩, ⟨"jpy"⟩⟩

private def debtAdmission : LocusAdmissionVocabulary :=
  { approved := [debt.locus], nodup := by simp }

private def effect (key : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ debt.locus debt.measure (Quantity.ofQuanta quanta)

private def event? (id key : String) (quanta : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩ [effect key quanta]

private def anchoredQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (anchor : Loam.CurrentQuantityAnchor.Evidence) : IO Int := do
  let some quantity ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections anchor debt)
    "anchored quantity"
    | throw (IO.userError "anchor no longer supports debt")
  pure quantity.quanta

private def freshAnchor
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (observed : Int) : IO Loam.CurrentQuantityAnchor.Evidence := do
  let assertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta observed }
  requireOk
    (Loam.CurrentQuantityAnchorPublisher.propose?
      events corrections debtAdmission ZeroOriginCoverage.empty
      OpeningSupportMap.empty [assertion])
    "fresh observation proposal"

private def oldAnchor?
    (reflected : List EventId)
    (observed : Int) : Option Loam.CurrentQuantityAnchor.Evidence :=
  Loam.CurrentQuantityAnchor.Evidence.ofLists?
    reflected
    [{ coordinate := debt, quantity := Quantity.ofQuanta observed }]

private def worldA : IO (EventMemory × EventCorrectionMemory × EventId) := do
  let old ← requireSome (event? "v5-old" "v5-old-effect" (-40)) "V5 old"
  let replacement ← requireSome
    (event? "v5-replacement" "v5-replacement-effect" (-50)) "V5 replacement"
  let later ← requireSome (event? "v5-later" "v5-later-effect" 10) "V5 later"
  let events ← requireSome
    (EventMemory.ofEvents? [old, replacement, later]) "V5 events"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement.id }])
    "V5 corrections"
  pure (events, corrections, old.id)

/--
V5a: one prior observed-present projection and one fresh observation can both be
well-formed while disagreeing numerically. The difference is derivable, but no
production status object is created by the comparison.
-/
private def numericDisagreementIsVisible : IO Unit := do
  let (events, corrections, oldRoot) ← worldA
  let old ← requireSome (oldAnchor? [oldRoot] (-70)) "V5a old anchor"
  let derived ← anchoredQuantity events corrections old
  expect (derived == -60) "V5a prior observed-present projection"

  let fresh ← freshAnchor events corrections (-55)
  let observed ← anchoredQuantity events corrections fresh
  expect (observed == -55) "V5a fresh observation"
  expect (observed - derived == 5) "V5a disagreement residual"
  expect (old.reflectedRoots != fresh.reflectedRoots)
    "V5a fresh observation did not establish a new cut"

/-- V5b: the same machinery also admits exact agreement without a special status. -/
private def numericAgreementIsVisible : IO Unit := do
  let (events, corrections, oldRoot) ← worldA
  let old ← requireSome (oldAnchor? [oldRoot] (-70)) "V5b old anchor"
  let derived ← anchoredQuantity events corrections old
  let fresh ← freshAnchor events corrections derived
  let observed ← anchoredQuantity events corrections fresh
  expect (derived == -60 && observed == -60) "V5b agreement values"
  expect (observed - derived == 0) "V5b zero residual"

/--
V5c: the same +5 residual can arise from a different retained decomposition.
The residual alone therefore does not identify a cause or choose which evidence
should be changed.
-/
private def sameResidualDifferentEvidence : IO Unit := do
  let (eventsA, correctionsA, rootA) ← worldA
  let oldA ← requireSome (oldAnchor? [rootA] (-70)) "V5c old anchor A"
  let derivedA ← anchoredQuantity eventsA correctionsA oldA
  let freshA ← freshAnchor eventsA correctionsA (-55)
  let observedA ← anchoredQuantity eventsA correctionsA freshA

  let oldBEvent ← requireSome (event? "v5b-old" "v5b-old-effect" (-20)) "V5c old B"
  let replacementB ← requireSome
    (event? "v5b-replacement" "v5b-replacement-effect" (-30)) "V5c replacement B"
  let laterB ← requireSome (event? "v5b-later" "v5b-later-effect" (-5)) "V5c later B"
  let eventsB ← requireSome
    (EventMemory.ofEvents? [oldBEvent, replacementB, laterB]) "V5c events B"
  let correctionsB ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := oldBEvent.id, replacement := replacementB.id }])
    "V5c corrections B"
  let oldB ← requireSome (oldAnchor? [oldBEvent.id] (-55)) "V5c old anchor B"
  let derivedB ← anchoredQuantity eventsB correctionsB oldB
  let freshB ← freshAnchor eventsB correctionsB (-55)
  let observedB ← anchoredQuantity eventsB correctionsB freshB

  expect (derivedA == -60 && observedA == -55) "V5c world A values"
  expect (derivedB == -60 && observedB == -55) "V5c world B values"
  expect (observedA - derivedA == 5 && observedB - derivedB == 5)
    "V5c residuals differ"
  let some frontierA :=
      Loam.Application.quantityAtCorrectionFrontier?
        eventsA correctionsA debt.locus debt.measure
    | throw (IO.userError "V5c frontier A")
  let some frontierB :=
      Loam.Application.quantityAtCorrectionFrontier?
        eventsB correctionsB debt.locus debt.measure
    | throw (IO.userError "V5c frontier B")
  expect (frontierA.quanta != frontierB.quanta)
    "V5c fixtures accidentally retained the same history decomposition"

/--
V5d: existing RoleBalance can consume either complete anchor image and therefore
show either current quantity, but it does not arbitrate between two competing
observation images or retain a reconciliation decision.
-/
private def downstreamProjectionDoesNotArbitrate : IO Unit := do
  let (events, corrections, oldRoot) ← worldA
  let old ← requireSome (oldAnchor? [oldRoot] (-70)) "V5d old anchor"
  let fresh ← freshAnchor events corrections (-55)
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments? [{ locus := debt.locus, role := .liability }])
    "V5d role map"
  let evidence : Loam.BalanceReview.Evidence := {
    events := events
    corrections := corrections
    coverage := ZeroOriginCoverage.empty
  }
  let oldSnapshot ← requireOk
    (Loam.RoleBalanceReview.project evidence OpeningSupportMap.empty old roles)
    "V5d old RoleBalance"
  let freshSnapshot ← requireOk
    (Loam.RoleBalanceReview.project evidence OpeningSupportMap.empty fresh roles)
    "V5d fresh RoleBalance"
  let some oldRow := oldSnapshot.rows.find? fun row => row.coordinate = debt
    | throw (IO.userError "V5d old row")
  let some freshRow := freshSnapshot.rows.find? fun row => row.coordinate = debt
    | throw (IO.userError "V5d fresh row")
  expect (oldRow.quantity.quanta == -60) "V5d old downstream quantity"
  expect (freshRow.quantity.quanta == -55) "V5d fresh downstream quantity"
  expect (oldRow.quantity != freshRow.quantity)
    "V5d downstream projection erased disagreement"


def main : IO Unit := do
  numericDisagreementIsVisible
  numericAgreementIsVisible
  sameResidualDifferentEvidence
  downstreamProjectionDoesNotArbitrate
  IO.println
    "Four-voice V5: prior observed-present projections and fresh observations can disagree by an exact residual, but the residual does not identify cause or authority; downstream balance projection preserves whichever complete anchor image it is given rather than inventing reconciliation precedence."
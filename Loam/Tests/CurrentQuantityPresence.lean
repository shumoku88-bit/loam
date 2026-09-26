import Loam.CurrentQuantityPresence
import Loam.Persistence.CurrentQuantityPresencePersistence
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
  let debt : EffectCoordinate := ⟨⟨"debt"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩

  let opening ← requireSome
    (Event.ofEffects? ⟨"opening"⟩ [effect "opening-debt" "debt" (-100)])
    "opening event"
  let unrelated ← requireSome
    (Event.ofEffects? ⟨"unrelated"⟩ [effect "unrelated-cash" "cash" 10])
    "unrelated event"
  let laterUnrelated ← requireSome
    (Event.ofEffects? ⟨"later-unrelated"⟩ [effect "later-cash" "cash" 5])
    "later unrelated event"
  let laterDebt ← requireSome
    (Event.ofEffects? ⟨"later-debt"⟩ [effect "later-debt-effect" "debt" 10])
    "later debt event"

  let noCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [])
    "empty corrections"
  let observedEvents ← requireSome
    (EventMemory.ofEvents? [opening, unrelated])
    "observed events"
  let unrelatedLaterEvents ← requireSome
    (EventMemory.ofEvents? [opening, unrelated, laterUnrelated])
    "events with unrelated later activity"
  let changedLaterEvents ← requireSome
    (EventMemory.ofEvents? [opening, unrelated, laterDebt])
    "events with later debt activity"

  let presence ← requireSome
    (Loam.CurrentQuantityPresence.Evidence.ofLists?
      [opening.id, unrelated.id] [debt])
    "presence evidence"

  expect
    (← requireOk
      (Loam.CurrentQuantityPresence.inspectCurrentPresence
        observedEvents noCorrections presence debt)
      "current presence")
    "presence disappeared at its observation frontier"

  expect
    (← requireOk
      (Loam.CurrentQuantityPresence.inspectCurrentPresence
        unrelatedLaterEvents noCorrections presence debt)
      "presence after unrelated activity")
    "unrelated later activity invalidated current presence"

  expect
    (!(← requireOk
      (Loam.CurrentQuantityPresence.inspectCurrentPresence
        changedLaterEvents noCorrections presence debt)
      "presence after coordinate activity"))
    "later activity on the coordinate failed to invalidate exact current presence knowledge"

  expect
    (!(← requireOk
      (Loam.CurrentQuantityPresence.inspectCurrentPresence
        observedEvents noCorrections presence cash)
      "unasserted presence"))
    "unasserted coordinate gained presence evidence"

  let encoded ← requireSome
    (Loam.Persistence.encodeCurrentQuantityPresence? presence)
    "presence encoding"
  let decoded ← requireSome
    (Loam.Persistence.decodeCurrentQuantityPresence? encoded)
    "presence decoding"
  expect (decide (decoded = presence))
    "current quantity presence persistence roundtrip changed evidence"

  expect
    (Loam.CurrentQuantityPresence.Evidence.ofLists?
      [opening.id] [debt, debt]).isNone
    "duplicate present coordinate was admitted"

  let ghost ← requireSome
    (Loam.CurrentQuantityPresence.Evidence.ofLists? [⟨"ghost"⟩] [debt])
    "ghost presence"
  expect
    (match Loam.CurrentQuantityPresence.inspectCurrentPresence
      observedEvents noCorrections ghost debt with
      | .error _ => true
      | .ok _ => false)
    "unknown reflected root did not fail closed"

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments? [
      { locus := ⟨"debt"⟩, role := .liability },
      { locus := ⟨"cash"⟩, role := .asset }
    ])
    "role map"
  let roleEvidence : Loam.BalanceReview.Evidence := {
    events := observedEvents
    corrections := noCorrections
    coverage := ZeroOriginCoverage.empty
  }
  let roleSnapshot ← requireOk
    (Loam.RoleBalanceReview.projectWithPresence
      roleEvidence OpeningSupportMap.empty
      Loam.CurrentQuantityAnchor.Evidence.empty presence roles)
    "role balance with current presence"

  expect
    (roleSnapshot.knownPresentBalances.any fun row =>
      decide (row.coordinate = debt ∧ row.role = some .liability))
    "known-present debt did not enter its dedicated frontier"
  expect
    (!(roleSnapshot.unsupportedBalances.any fun row => row.coordinate = debt))
    "known-present debt remained fully unsupported"
  expect
    (roleSnapshot.unsupportedBalances.any fun row => row.coordinate = cash)
    "unrelated unsupported coordinate disappeared"

  let exactAssertion : Loam.CurrentQuantityAnchor.Assertion := {
    coordinate := debt
    quantity := Quantity.ofQuanta (-100)
  }
  let exactAnchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      [opening.id, unrelated.id] [exactAssertion])
    "exact anchor"
  expect
    (match Loam.RoleBalanceReview.projectWithPresence
      roleEvidence OpeningSupportMap.empty exactAnchor presence roles with
      | .error _ => true
      | .ok _ => false)
    "RoleBalance invented precedence between exact and amount-unknown current evidence"

  IO.println
    "Current Quantity Presence: temporal presence, persistence, RoleBalance refinement and overlap refusal passed."

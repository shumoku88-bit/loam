import Loam.CurrentQuantityAnchor
import Loam.CurrentQuantityAnchorPublisher
import Loam.Application.CorrectionFrontier

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

private def quantityAtFrontier
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : IO Int := do
  let some quantity :=
      Loam.Application.quantityAtCorrectionFrontier?
        events corrections debt.locus debt.measure
    | throw (IO.userError "frontier quantity unavailable")
  pure quantity.quanta

private def anchoredQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (anchor : Loam.CurrentQuantityAnchor.Evidence) : IO Int := do
  let some quantity ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events corrections anchor debt)
    "anchored quantity"
    | throw (IO.userError "anchor no longer supports debt")
  pure quantity.quanta

/--
V4a: changing only the terminal inside a reflected stable root changes ordinary
history but leaves the already observed current quantity unchanged.
-/
private def coveredRootTerminalChanges : IO Unit := do
  let old ← requireSome (event? "covered-old" "covered-old-effect" (-40)) "covered old"
  let replacement1 ← requireSome
    (event? "covered-r1" "covered-r1-effect" (-50)) "covered replacement1"
  let later ← requireSome (event? "covered-later" "covered-later-effect" 10) "covered later"
  let baseEvents ← requireSome
    (EventMemory.ofEvents? [old, replacement1, later]) "covered base events"
  let baseCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement1.id }])
    "covered base corrections"
  let assertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-70) }
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [old.id] [assertion])
    "covered anchor"

  let beforeHistory ← quantityAtFrontier baseEvents baseCorrections
  let beforePresent ← anchoredQuantity baseEvents baseCorrections anchor
  expect (beforeHistory == -40) "V4a base history"
  expect (beforePresent == -60) "V4a base observed present"

  let replacement2 ← requireSome
    (event? "covered-r2" "covered-r2-effect" (-80)) "covered replacement2"
  let changedEvents ← requireSome
    (EventMemory.ofEvents? [old, replacement1, replacement2, later])
    "covered changed events"
  let changedCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [ { target := old.id, replacement := replacement1.id }
      , { target := replacement1.id, replacement := replacement2.id } ])
    "covered changed corrections"
  let afterHistory ← quantityAtFrontier changedEvents changedCorrections
  let afterPresent ← anchoredQuantity changedEvents changedCorrections anchor
  expect (afterHistory == -70) "V4a corrected history did not change"
  expect (afterPresent == -60) "V4a covered correction moved observed present"
  expect (beforeHistory != afterHistory && beforePresent == afterPresent)
    "V4a failed to separate corrected history from observed present"

/--
V4b: a root outside the reflected cut remains a genuine delta. Correcting that
root changes the current anchored quantity.
-/
private def uncoveredRootCorrectionMovesPresent : IO Unit := do
  let old ← requireSome (event? "outside-old" "outside-old-effect" (-40)) "outside old"
  let replacement ← requireSome
    (event? "outside-r" "outside-r-effect" (-50)) "outside replacement"
  let later ← requireSome (event? "outside-later" "outside-later-effect" 10) "outside later"
  let baseEvents ← requireSome
    (EventMemory.ofEvents? [old, replacement, later]) "outside base events"
  let baseCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement.id }])
    "outside base corrections"
  let assertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-70) }
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [old.id] [assertion])
    "outside anchor"
  let before ← anchoredQuantity baseEvents baseCorrections anchor
  expect (before == -60) "V4b base anchored quantity"

  let laterReplacement ← requireSome
    (event? "outside-later-r" "outside-later-r-effect" 25)
    "outside later replacement"
  let changedEvents ← requireSome
    (EventMemory.ofEvents? [old, replacement, later, laterReplacement])
    "outside changed events"
  let changedCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [ { target := old.id, replacement := replacement.id }
      , { target := later.id, replacement := laterReplacement.id } ])
    "outside changed corrections"
  let after ← anchoredQuantity changedEvents changedCorrections anchor
  expect (after == -45) "V4b uncovered root correction did not move present"
  expect (after - before == 15) "V4b uncovered correction delta"

/-- V4c: a wholly new root after the observation is also a genuine delta. -/
private def newRootAfterObservationMovesPresent : IO Unit := do
  let old ← requireSome (event? "new-old" "new-old-effect" (-40)) "new old"
  let replacement ← requireSome
    (event? "new-r" "new-r-effect" (-50)) "new replacement"
  let baseEvents ← requireSome
    (EventMemory.ofEvents? [old, replacement]) "new base events"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement.id }])
    "new corrections"
  let assertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-70) }
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [old.id] [assertion])
    "new anchor"
  let before ← anchoredQuantity baseEvents corrections anchor
  expect (before == -70) "V4c base observed present"

  let later ← requireSome (event? "new-later" "new-later-effect" 10) "new later"
  let changedEvents ← requireSome
    (EventMemory.ofEvents? [old, replacement, later]) "new changed events"
  let after ← anchoredQuantity changedEvents corrections anchor
  expect (after == -60) "V4c new root was not added as delta"

/--
V4d: if later evidence changes the stable-root identity itself, the old anchor
must not guess that its cut migrated. It fails closed.
-/
private def changedStableRootFailsClosed : IO Unit := do
  let old ← requireSome (event? "root-old" "root-old-effect" (-40)) "root old"
  let replacement ← requireSome
    (event? "root-r" "root-r-effect" (-50)) "root replacement"
  let baseEvents ← requireSome
    (EventMemory.ofEvents? [old, replacement]) "root base events"
  let baseCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement.id }])
    "root base corrections"
  let assertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-70) }
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [old.id] [assertion])
    "root anchor"
  let before ← anchoredQuantity baseEvents baseCorrections anchor
  expect (before == -70) "V4d base observed present"

  let predecessor ← requireSome
    (event? "root-predecessor" "root-predecessor-effect" 0)
    "root predecessor"
  let changedEvents ← requireSome
    (EventMemory.ofEvents? [predecessor, old, replacement])
    "root changed events"
  let changedCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [ { target := predecessor.id, replacement := old.id }
      , { target := old.id, replacement := replacement.id } ])
    "root changed corrections"
  expect
    (match Loam.CurrentQuantityAnchor.inspectQuantity
      changedEvents changedCorrections anchor debt with
      | .error _ => true
      | .ok _ => false)
    "V4d anchor silently migrated to a different stable root"

/--
V4e: a fresh observation creates a new complete cut; it does not mutate the old
anchor into a historical revision.
-/
private def freshObservationCreatesNewCut : IO Unit := do
  let old ← requireSome (event? "fresh-old" "fresh-old-effect" (-40)) "fresh old"
  let replacement ← requireSome
    (event? "fresh-r" "fresh-r-effect" (-50)) "fresh replacement"
  let later ← requireSome (event? "fresh-later" "fresh-later-effect" 10) "fresh later"
  let events ← requireSome
    (EventMemory.ofEvents? [old, replacement, later]) "fresh events"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement.id }])
    "fresh corrections"
  let oldAssertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta (-70) }
  let oldAnchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [old.id] [oldAssertion])
    "fresh old anchor"
  let current ← anchoredQuantity events corrections oldAnchor
  expect (current == -60) "V4e current before fresh observation"

  let newAssertion : Loam.CurrentQuantityAnchor.Assertion :=
    { coordinate := debt, quantity := Quantity.ofQuanta current }
  let freshAnchor ← requireOk
    (Loam.CurrentQuantityAnchorPublisher.propose?
      events corrections debtAdmission ZeroOriginCoverage.empty
      OpeningSupportMap.empty [newAssertion])
    "fresh observation proposal"
  expect (freshAnchor.reflectedRoots.contains old.id)
    "V4e fresh cut omitted covered old root"
  expect (freshAnchor.reflectedRoots.contains later.id)
    "V4e fresh cut omitted then-current later root"
  let freshCurrent ← anchoredQuantity events corrections freshAnchor
  expect (freshCurrent == current) "V4e fresh observation changed observed quantity"
  expect (oldAnchor.reflectedRoots != freshAnchor.reflectedRoots)
    "V4e fresh observation mutated no boundary at all"


def main : IO Unit := do
  coveredRootTerminalChanges
  uncoveredRootCorrectionMovesPresent
  newRootAfterObservationMovesPresent
  changedStableRootFailsClosed
  freshObservationCreatesNewCut
  IO.println
    "Four-voice V4: observed present is stable under terminal changes inside reflected stable roots, while uncovered/new roots remain deltas and stable-root identity changes fail closed; a fresh observation creates a new cut rather than revising the old one."

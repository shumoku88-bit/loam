import Std

set_option autoImplicit false

namespace Loam.Application007

abbrev EventId := String

structure EventContribution where
  id : EventId
  quantity : Int
deriving Repr, DecidableEq

structure Correction where
  target : EventId
  replacement : EventId
deriving Repr, DecidableEq

private def eventPresent (events : List EventContribution) (id : EventId) : Bool :=
  events.any fun event => event.id == id

private def targetUsed (corrections : List Correction) (id : EventId) : Bool :=
  corrections.any fun correction => correction.target == id

private def uniqueEventIds : List EventContribution → Bool
  | [] => true
  | event :: rest =>
      !(rest.any fun other => other.id == event.id) && uniqueEventIds rest

private def uniqueTargets : List Correction → Bool
  | [] => true
  | correction :: rest =>
      !(rest.any fun other => other.target == correction.target) && uniqueTargets rest

private def closedReferences
    (events : List EventContribution)
    (corrections : List Correction) : Bool :=
  corrections.all fun correction =>
    eventPresent events correction.target && eventPresent events correction.replacement

private def nextReplacement? : List Correction → EventId → Option EventId
  | [], _ => none
  | correction :: rest, id =>
      if correction.target == id then
        some correction.replacement
      else
        nextReplacement? rest id

private def pathAcyclicFrom
    (corrections : List Correction)
    (start : EventId) : Nat → EventId → Bool
  | 0, _ => true
  | fuel + 1, current =>
      match nextReplacement? corrections current with
      | none => true
      | some next =>
          if next == start then
            false
          else
            pathAcyclicFrom corrections start fuel next

private def acyclic (corrections : List Correction) : Bool :=
  corrections.all fun correction =>
    pathAcyclicFrom corrections correction.target corrections.length correction.target

/--
The deliberately small frontier admission used by this probe.

It admits only a finite correction forest with:
- unique Event identity;
- closed Event references;
- at most one outgoing correction per target Event;
- no correction cycle.

This does not choose among sibling corrections. Siblings are rejected before a
frontier is projected.
-/
def frontierAdmissible
    (events : List EventContribution)
    (corrections : List Correction) : Bool :=
  uniqueEventIds events &&
    uniqueTargets corrections &&
    closedReferences events corrections &&
    acyclic corrections

/--
Current frontier Events are exactly remembered Events that are not superseded
as correction targets. Replacement Events already exist in the remembered
Event collection, so they are retained rather than added again.
-/
def frontierEvents
    (events : List EventContribution)
    (corrections : List Correction) : List EventContribution :=
  events.filter fun event => !(targetUsed corrections event.id)

private def sumQuantity (events : List EventContribution) : Int :=
  events.foldl (fun total event => total + event.quantity) 0

/--
Project one already-selected locus/measure quantity through an admitted
correction frontier.

`none` means the correction facts do not yet justify one current quantity.
-/
def effectiveQuantity?
    (events : List EventContribution)
    (corrections : List Correction) : Option Int :=
  if frontierAdmissible events corrections then
    some (sumQuantity (frontierEvents events corrections))
  else
    none

private def sampleEvents : List EventContribution :=
  [ { id := "a", quantity := 100 }
  , { id := "b", quantity := 80 }
  , { id := "c", quantity := 90 }
  , { id := "x", quantity := -20 }
  , { id := "y", quantity := -15 }
  , { id := "u", quantity := 5 }
  ]

private def independentChains : List Correction :=
  [ { target := "a", replacement := "b" }
  , { target := "b", replacement := "c" }
  , { target := "x", replacement := "y" }
  ]

private def branching : List Correction :=
  [ { target := "a", replacement := "b" }
  , { target := "a", replacement := "c" }
  ]

private def cyclic : List Correction :=
  [ { target := "a", replacement := "b" }
  , { target := "b", replacement := "a" }
  ]

private def dangling : List Correction :=
  [ { target := "a", replacement := "missing" } ]

/-- A linear chain and an independent chain can coexist with an untouched Event. -/
example :
    frontierEvents sampleEvents independentChains =
      [ { id := "c", quantity := 90 }
      , { id := "y", quantity := -15 }
      , { id := "u", quantity := 5 }
      ] := by
  native_decide

/-- The admitted multi-chain frontier yields one current quantity. -/
example : effectiveQuantity? sampleEvents independentChains = some 80 := by
  native_decide

/-- Correction list order is representation only for this admitted specimen. -/
example :
    effectiveQuantity? sampleEvents independentChains =
      effectiveQuantity? sampleEvents independentChains.reverse := by
  native_decide

/-- Sibling corrections do not silently become two simultaneous replacements. -/
example : effectiveQuantity? sampleEvents branching = none := by
  native_decide

/-- A correction cycle does not collapse to an empty or arbitrary frontier. -/
example : effectiveQuantity? sampleEvents cyclic = none := by
  native_decide

/-- Missing Event endpoints remain fail-closed. -/
example : effectiveQuantity? sampleEvents dangling = none := by
  native_decide

end Loam.Application007

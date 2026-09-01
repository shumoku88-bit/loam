import Std

set_option autoImplicit false

namespace Loam.Application008

abbrev BasisFactId := String
abbrev EventId := String
abbrev LocusId := String
abbrev MeasureId := String

structure Coordinate where
  locus : LocusId
  measure : MeasureId
deriving Repr, DecidableEq, BEq

/--
One experiment-local quantity basis fact.

This is deliberately not an Event contribution. It says how much quantity is
already represented at one coordinate when this bounded application image
begins. The name and shape are probe vocabulary, not yet production Core.
-/
structure QuantityBasisFact where
  id : BasisFactId
  coordinate : Coordinate
  quantity : Int
deriving Repr, DecidableEq, BEq

/--
One already-effective Event contribution at one selected coordinate.

Application 008 does not reopen correction-frontier semantics. Its Event input
stands for the contributions that the existing correction-aware projection has
already selected.
-/
structure EventContribution where
  eventId : EventId
  coordinate : Coordinate
  quantity : Int
deriving Repr, DecidableEq, BEq

private def uniqueBasisIds : List QuantityBasisFact → Bool
  | [] => true
  | fact :: rest =>
      !(rest.any fun other => other.id == fact.id) && uniqueBasisIds rest

private def uniqueBasisCoordinates : List QuantityBasisFact → Bool
  | [] => true
  | fact :: rest =>
      !(rest.any fun other => other.coordinate == fact.coordinate) &&
        uniqueBasisCoordinates rest

/--
The first basis image refuses two simultaneous starting quantities for the same
locus/measure coordinate. It also keeps explicit fact identity unique.

This is intentionally narrower than a future append-only revision history for
basis facts; Application 008 only qualifies one selected starting image.
-/
def basisAdmissible (basis : List QuantityBasisFact) : Bool :=
  uniqueBasisIds basis && uniqueBasisCoordinates basis

private def basisQuantityAt
    (basis : List QuantityBasisFact)
    (coordinate : Coordinate) : Int :=
  basis.foldl
    (fun total fact =>
      if fact.coordinate == coordinate then total + fact.quantity else total)
    0

private def eventQuantityAt
    (events : List EventContribution)
    (coordinate : Coordinate) : Int :=
  events.foldl
    (fun total event =>
      if event.coordinate == coordinate then total + event.quantity else total)
    0

/--
Compose one admitted starting basis with already-effective Event contributions.

`none` means the selected basis image itself is ambiguous. No list position is
used as authority and no Event is reclassified as a starting quantity.
-/
def quantityWithBasis?
    (basis : List QuantityBasisFact)
    (events : List EventContribution)
    (coordinate : Coordinate) : Option Int :=
  if basisAdmissible basis then
    some (basisQuantityAt basis coordinate + eventQuantityAt events coordinate)
  else
    none

private def bankJpy : Coordinate := ⟨"bank", "jpy"⟩
private def walletJpy : Coordinate := ⟨"wallet", "jpy"⟩

private def sampleBasis : List QuantityBasisFact :=
  [ { id := "basis-bank", coordinate := bankJpy, quantity := 100000 } ]

private def alternativeBasis : List QuantityBasisFact :=
  [ { id := "basis-bank-alt", coordinate := bankJpy, quantity := 125000 } ]

private def duplicateCoordinateBasis : List QuantityBasisFact :=
  [ { id := "basis-bank-a", coordinate := bankJpy, quantity := 100000 }
  , { id := "basis-bank-b", coordinate := bankJpy, quantity := 1 }
  ]

private def duplicateIdBasis : List QuantityBasisFact :=
  [ { id := "same-basis", coordinate := bankJpy, quantity := 100000 }
  , { id := "same-basis", coordinate := walletJpy, quantity := 2000 }
  ]

private def sampleEvents : List EventContribution :=
  [ { eventId := "income-1", coordinate := bankJpy, quantity := 20000 }
  , { eventId := "spend-1", coordinate := bankJpy, quantity := -5000 }
  , { eventId := "transfer-1", coordinate := bankJpy, quantity := -10000 }
  , { eventId := "transfer-1", coordinate := walletJpy, quantity := 10000 }
  ]

/-- A starting basis plus later effective changes yields the expected holding. -/
example : quantityWithBasis? sampleBasis sampleEvents bankJpy = some 105000 := by
  native_decide

/-- A coordinate without a basis still receives its effective Event changes. -/
example : quantityWithBasis? sampleBasis sampleEvents walletJpy = some 10000 := by
  native_decide

/-- Forgetting the basis exactly recovers the Event-only quantity for this image. -/
example : quantityWithBasis? [] sampleEvents bankJpy = some 5000 := by
  native_decide

/-- The same Event history can produce a different holding when the starting fact differs. -/
example : quantityWithBasis? alternativeBasis sampleEvents bankJpy = some 130000 := by
  native_decide

/-- Two simultaneous bases at one coordinate do not silently double count. -/
example : quantityWithBasis? duplicateCoordinateBasis sampleEvents bankJpy = none := by
  native_decide

/-- Basis fact identity remains explicit and unique in the selected image. -/
example : quantityWithBasis? duplicateIdBasis sampleEvents bankJpy = none := by
  native_decide

end Loam.Application008

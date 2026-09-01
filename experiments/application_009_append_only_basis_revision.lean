import Std

set_option autoImplicit false

namespace Loam.Application009

abbrev BasisId := String
abbrev Locus := String
abbrev Measure := String

structure Coordinate where
  locus : Locus
  measure : Measure
deriving Repr, DecidableEq

structure BasisFact where
  id : BasisId
  coordinate : Coordinate
  quantity : Int
deriving Repr, DecidableEq

structure BasisCorrection where
  target : BasisId
  replacement : BasisId
deriving Repr, DecidableEq

private def basisPresent (bases : List BasisFact) (id : BasisId) : Bool :=
  bases.any fun basis => basis.id == id

private def targetUsed (corrections : List BasisCorrection) (id : BasisId) : Bool :=
  corrections.any fun correction => correction.target == id

private def uniqueBasisIds : List BasisFact → Bool
  | [] => true
  | basis :: rest =>
      !(rest.any fun other => other.id == basis.id) && uniqueBasisIds rest

private def uniqueTargets : List BasisCorrection → Bool
  | [] => true
  | correction :: rest =>
      !(rest.any fun other => other.target == correction.target) && uniqueTargets rest

private def uniqueCoordinates : List BasisFact → Bool
  | [] => true
  | basis :: rest =>
      !(rest.any fun other => other.coordinate == basis.coordinate) && uniqueCoordinates rest

private def closedReferences
    (bases : List BasisFact)
    (corrections : List BasisCorrection) : Bool :=
  corrections.all fun correction =>
    basisPresent bases correction.target && basisPresent bases correction.replacement

private def basisById? : List BasisFact → BasisId → Option BasisFact
  | [], _ => none
  | basis :: rest, id =>
      if basis.id == id then some basis else basisById? rest id

private def preservesCoordinate
    (bases : List BasisFact)
    (corrections : List BasisCorrection) : Bool :=
  corrections.all fun correction =>
    match basisById? bases correction.target, basisById? bases correction.replacement with
    | some target, some replacement => target.coordinate == replacement.coordinate
    | _, _ => false

private def nextReplacement? : List BasisCorrection → BasisId → Option BasisId
  | [], _ => none
  | correction :: rest, id =>
      if correction.target == id then
        some correction.replacement
      else
        nextReplacement? rest id

private def pathAcyclicFrom
    (corrections : List BasisCorrection)
    (start : BasisId) : Nat → BasisId → Bool
  | 0, _ => true
  | fuel + 1, current =>
      match nextReplacement? corrections current with
      | none => true
      | some next =>
          if next == start then
            false
          else
            pathAcyclicFrom corrections start fuel next

private def acyclic (corrections : List BasisCorrection) : Bool :=
  corrections.all fun correction =>
    pathAcyclicFrom corrections correction.target corrections.length correction.target

/--
Remembered basis facts that have not themselves been corrected.

Old basis facts stay in memory. Only the current projection removes correction
targets, exactly as an append-only revision frontier should.
-/
def frontierBases
    (bases : List BasisFact)
    (corrections : List BasisCorrection) : List BasisFact :=
  bases.filter fun basis => !(targetUsed corrections basis.id)

/--
The deliberately small admission boundary for append-only basis correction.

Raw memory may contain several historical basis facts at one coordinate. What
must stay unique is the admitted *frontier* at that coordinate.

This probe additionally keeps every correction within one locus/measure
coordinate. Correcting a mistaken coordinate is intentionally left for later.
-/
def frontierAdmissible
    (bases : List BasisFact)
    (corrections : List BasisCorrection) : Bool :=
  uniqueBasisIds bases &&
    uniqueTargets corrections &&
    closedReferences bases corrections &&
    preservesCoordinate bases corrections &&
    acyclic corrections &&
    uniqueCoordinates (frontierBases bases corrections)

private def quantityAtFrontier
    (frontier : List BasisFact)
    (coordinate : Coordinate) : Int :=
  frontier.foldl
    (fun total basis =>
      if basis.coordinate == coordinate then basis.quantity else total)
    0

/--
Return the current basis quantity at one coordinate, or `none` when remembered
basis/correction facts do not justify one unambiguous current frontier.

A valid coordinate with no basis contributes exact zero.
-/
def currentBasisQuantity?
    (bases : List BasisFact)
    (corrections : List BasisCorrection)
    (coordinate : Coordinate) : Option Int :=
  if frontierAdmissible bases corrections then
    some (quantityAtFrontier (frontierBases bases corrections) coordinate)
  else
    none

/--
Compose an admitted current basis with an already-effective Event contribution.
The Event side remains an independent input and is not rewritten by a basis
correction.
-/
def currentQuantity?
    (bases : List BasisFact)
    (corrections : List BasisCorrection)
    (coordinate : Coordinate)
    (effectiveEventQuantity : Int) : Option Int :=
  match currentBasisQuantity? bases corrections coordinate with
  | some basisQuantity => some (basisQuantity + effectiveEventQuantity)
  | none => none

private def bankJpy : Coordinate := ⟨"bank", "jpy"⟩
private def walletJpy : Coordinate := ⟨"wallet", "jpy"⟩

private def correctedBankBases : List BasisFact :=
  [ { id := "bank-v1", coordinate := bankJpy, quantity := 100000 }
  , { id := "bank-v2", coordinate := bankJpy, quantity := 95000 }
  , { id := "wallet-v1", coordinate := walletJpy, quantity := 10000 }
  ]

private def correctedBank : List BasisCorrection :=
  [ { target := "bank-v1", replacement := "bank-v2" } ]

private def chainedBankBases : List BasisFact :=
  [ { id := "bank-v1", coordinate := bankJpy, quantity := 100000 }
  , { id := "bank-v2", coordinate := bankJpy, quantity := 95000 }
  , { id := "bank-v3", coordinate := bankJpy, quantity := 97000 }
  ]

private def chainedBank : List BasisCorrection :=
  [ { target := "bank-v1", replacement := "bank-v2" }
  , { target := "bank-v2", replacement := "bank-v3" }
  ]

private def siblingBank : List BasisCorrection :=
  [ { target := "bank-v1", replacement := "bank-v2" }
  , { target := "bank-v1", replacement := "bank-v3" }
  ]

private def cyclicBank : List BasisCorrection :=
  [ { target := "bank-v1", replacement := "bank-v2" }
  , { target := "bank-v2", replacement := "bank-v1" }
  ]

private def danglingBank : List BasisCorrection :=
  [ { target := "bank-v1", replacement := "missing" } ]

private def duplicateTerminalBank : List BasisFact :=
  [ { id := "bank-a", coordinate := bankJpy, quantity := 100000 }
  , { id := "bank-b", coordinate := bankJpy, quantity := 95000 }
  ]

private def coordinateChangingBases : List BasisFact :=
  [ { id := "bank-v1", coordinate := bankJpy, quantity := 100000 }
  , { id := "wallet-v2", coordinate := walletJpy, quantity := 100000 }
  ]

private def coordinateChangingCorrection : List BasisCorrection :=
  [ { target := "bank-v1", replacement := "wallet-v2" } ]

/-- Historical duplicates at one coordinate are allowed when only one survives. -/
example : frontierAdmissible correctedBankBases correctedBank = true := by
  native_decide

/-- The old basis remains remembered, but the frontier contains the replacement. -/
example :
    frontierBases correctedBankBases correctedBank =
      [ { id := "bank-v2", coordinate := bankJpy, quantity := 95000 }
      , { id := "wallet-v1", coordinate := walletJpy, quantity := 10000 }
      ] := by
  native_decide

/-- A corrected bank basis projects the replacement quantity. -/
example : currentBasisQuantity? correctedBankBases correctedBank bankJpy = some 95000 := by
  native_decide

/-- Basis correction does not rewrite the independent Event contribution. -/
example : currentQuantity? correctedBankBases correctedBank bankJpy 5000 = some 100000 := by
  native_decide

/-- A linear append-only correction chain has one current basis tip. -/
example : currentBasisQuantity? chainedBankBases chainedBank bankJpy = some 97000 := by
  native_decide

/-- Correction-list representation order does not choose the current basis. -/
example :
    currentBasisQuantity? chainedBankBases chainedBank bankJpy =
      currentBasisQuantity? chainedBankBases chainedBank.reverse bankJpy := by
  native_decide

/-- Two uncorrected terminal bases at one coordinate remain ambiguous. -/
example : currentBasisQuantity? duplicateTerminalBank [] bankJpy = none := by
  native_decide

/-- Sibling corrections do not silently choose one replacement. -/
example : currentBasisQuantity? chainedBankBases siblingBank bankJpy = none := by
  native_decide

/-- A correction cycle fails closed. -/
example : currentBasisQuantity? correctedBankBases cyclicBank bankJpy = none := by
  native_decide

/-- A missing replacement endpoint fails closed. -/
example : currentBasisQuantity? correctedBankBases danglingBank bankJpy = none := by
  native_decide

/-- This narrow probe does not yet permit a correction to move the basis coordinate. -/
example :
    currentBasisQuantity?
      coordinateChangingBases coordinateChangingCorrection bankJpy = none := by
  native_decide

/-- With no basis facts, the old Event-only quantity is recovered exactly. -/
example : currentQuantity? [] [] bankJpy 5000 = some 5000 := by
  native_decide

end Loam.Application009

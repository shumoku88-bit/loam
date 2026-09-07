import Loam.Application.BasisCut
import Loam.BalanceViewConfig
import Loam.MovementManifestAuthority
import Loam.Persistence.BasisCutPersistence
import Loam.Persistence.QuantityBasisCorrectionPersistence
import Loam.Persistence.QuantityBasisPersistence

namespace Loam.BalanceReview

open Loam.Core

set_option autoImplicit false

/-!
# Shared production balance review

This boundary answers the existing replaceable balance-view question from the
current Movement manifest plus the independent quantity-basis evidence streams.
It does not turn `Locus` into `Account`, invent accounting roles, or silently
fall back to retired Movement sidecars.
-/

structure Row where
  coordinate : EffectCoordinate
  quantity : Quantity
  deriving Repr, DecidableEq

structure Snapshot where
  rows : List Row
  deriving Repr, DecidableEq

private def addCoordinateIfAbsent
    (coordinates : List EffectCoordinate)
    (coordinate : EffectCoordinate) : List EffectCoordinate :=
  if coordinate ∈ coordinates then coordinates else coordinates ++ [coordinate]

private def normalizeCoordinates
    (coordinates : List EffectCoordinate) : List EffectCoordinate :=
  coordinates.foldl addCoordinateIfAbsent []

private def collectRows
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (basisCut : Loam.Application.BasisCut) :
    List EffectCoordinate → Except String (List Row)
  | [] => .ok []
  | coordinate :: rest =>
      match Loam.Application.BasisCut.inspectCurrentQuantityWithBasisCut?
          events eventCorrections bases basisCorrections basisCut
          coordinate.locus coordinate.measure with
      | none => .error "loam: balances unavailable: basis-cut roots are not admitted"
      | some answer =>
          match answer with
          | .current quantity =>
              match collectRows events eventCorrections bases basisCorrections basisCut rest with
              | .error message => .error message
              | .ok later => .ok ({ coordinate := coordinate, quantity := quantity } :: later)
          | .basisMissing =>
              .error
                ("loam: balances unavailable: starting balance missing for " ++
                  coordinate.locus.token ++ " / " ++ coordinate.measure.token)
          | .basisFrontierRequired =>
              .error
                "loam: balances unavailable: starting-balance revisions do not justify one frontier"
          | .missingEventCorrectionEndpoint =>
              .error "loam: balances unavailable: correction references are not closed"
          | .eventFrontierRequired =>
              .error
                "loam: balances unavailable: event corrections do not justify one frontier"

/--
Project one already-loaded balance view. Even an empty selected view still checks
that the basis-correction evidence admits one frontier, matching the practical
line balance entrance's fail-closed order.
-/
def project
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (basisCut : Loam.Application.BasisCut)
    (coordinates : List EffectCoordinate) : Except String Snapshot := do
  let some _ := Loam.Application.admittedQuantityBasisFrontier? bases basisCorrections
    | throw "loam: balances unavailable: starting-balance revisions do not justify one frontier"
  let rows ← collectRows
    events eventCorrections bases basisCorrections basisCut (normalizeCoordinates coordinates)
  return { rows := rows }

private def loadEventCorrections
    (path : System.FilePath) : IO (Except String EventCorrectionMemory) := do
  if ← path.pathExists then
    match ← Loam.Persistence.loadEventCorrectionMemory? path with
    | some memory => return .ok memory
    | none => return .error "loam: malformed or unsupported correction-memory file"
  else
    match EventCorrectionMemory.ofCorrections? [] with
    | some memory => return .ok memory
    | none => return .error "loam: could not construct empty correction memory"

private def loadBases
    (path : System.FilePath) : IO (Except String QuantityBasisMemory) := do
  if ← path.pathExists then
    match ← Loam.Persistence.loadQuantityBasisMemory? path with
    | some memory => return .ok memory
    | none => return .error "loam: malformed or unsupported quantity-basis file"
  else
    match QuantityBasisMemory.ofBases? [] with
    | some memory => return .ok memory
    | none => return .error "loam: could not construct empty quantity-basis memory"

private def loadBasisCorrections
    (path : System.FilePath) : IO (Except String QuantityBasisCorrectionMemory) := do
  if ← path.pathExists then
    match ← Loam.Persistence.loadQuantityBasisCorrectionMemory? path with
    | some memory => return .ok memory
    | none => return .error "loam: malformed or unsupported quantity-basis correction file"
  else
    match QuantityBasisCorrectionMemory.ofCorrections? [] with
    | some memory => return .ok memory
    | none => return .error "loam: could not construct empty quantity-basis correction memory"

/--
Load the production household balance answer from the current authority topology.

Movement Effects come only from the selected manifest. Quantity basis,
basis-correction, basis-cut, Event correction, and replaceable view policy remain
their existing independent files. Missing optional relation/config streams keep
their established empty meaning; malformed configured evidence refuses.
-/
def loadSnapshot
    (dataDir manifestRoot : System.FilePath) : IO (Except String Snapshot) := do
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? manifestRoot with
    | .error message => return .error message
    | .ok world => pure world
  let eventCorrections ←
    match ← loadEventCorrections (dataDir / "corrections.loam") with
    | .error message => return .error message
    | .ok memory => pure memory
  let bases ←
    match ← loadBases (dataDir / "basis.loam") with
    | .error message => return .error message
    | .ok memory => pure memory
  let basisCorrections ←
    match ← loadBasisCorrections (dataDir / "basis-corrections.loam") with
    | .error message => return .error message
    | .ok memory => pure memory
  let basisCut ←
    match ← Loam.BasisCutPersistence.load? (dataDir / "basis-cut.tsv") with
    | none => return .error "loam: malformed or unsupported basis-cut file"
    | some cut => pure cut
  let coordinates ←
    match ← Loam.BalanceViewConfig.load? (dataDir / "balance-view.tsv") with
    | none => return .error "loam: malformed or unsupported balance-view config"
    | some selected => pure selected
  return project world.events eventCorrections bases basisCorrections basisCut coordinates

end Loam.BalanceReview

import Loam.ActualAuthority
import Loam.Application.ZeroOriginQuantity
import Loam.BalanceViewConfig
import Loam.Persistence.ZeroOriginCoveragePersistence

namespace Loam.BalanceReview

open Loam.Core

set_option autoImplicit false

/-!
# Shared production balance review

This boundary answers the existing replaceable balance-view question from the
selected Movement manifest plus independent zero-origin coverage evidence.
It does not turn `Locus` into `Account`, infer completeness from presentation,
or silently fall back to retired Movement sidecars.
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
    (coverage : ZeroOriginCoverage) :
    List EffectCoordinate → Except String (List Row)
  | [] => .ok []
  | coordinate :: rest =>
      match Loam.Application.inspectZeroOriginQuantity
          coverage events eventCorrections coordinate with
      | .current quantity =>
          match collectRows events eventCorrections coverage rest with
          | .error message => .error message
          | .ok later => .ok ({ coordinate := coordinate, quantity := quantity } :: later)
      | .coverageMissing =>
          .error
            ("loam: balances unavailable: zero-origin coverage missing for " ++
              coordinate.locus.token ++ " / " ++ coordinate.measure.token)
      | .missingEventCorrectionEndpoint =>
          .error "loam: balances unavailable: correction references are not closed"
      | .eventFrontierRequired =>
          .error
            "loam: balances unavailable: event corrections do not justify one frontier"

/--
Project one already-loaded balance view. Presentation duplicates are normalized,
but zero-origin membership remains an independent evidence requirement.
-/
def project
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coverage : ZeroOriginCoverage)
    (coordinates : List EffectCoordinate) : Except String Snapshot := do
  let rows ← collectRows
    events eventCorrections coverage (normalizeCoordinates coordinates)
  return { rows := rows }

private def loadCoverage
    (path : System.FilePath) : IO (Except String ZeroOriginCoverage) := do
  if ← path.pathExists then
    match ← Loam.Persistence.loadZeroOriginCoverage? path with
    | some coverage => return .ok coverage
    | none => return .error "loam: malformed or unsupported zero-origin coverage file"
  else
    return .ok ZeroOriginCoverage.empty

/-- Shared physical evidence, independent of display or funding selection. -/
structure Evidence where
  events : EventMemory
  corrections : EventCorrectionMemory
  coverage : ZeroOriginCoverage

/-- Load authoritative Actual evidence and independent zero-origin evidence. -/
def loadEvidence
    (dataDir actualRoot : System.FilePath) : IO (Except String Evidence) := do
  let path :=
    if actualRoot.fileName == some Loam.ActualAuthority.actualFileName then actualRoot
    else Loam.ActualAuthority.actualPath actualRoot
  let actualEvidence ←
    match ← Loam.ActualAuthority.loadActualFile? path with
    | .ok ev => pure ev
    | .error message =>
        match ← Loam.ActualAuthority.loadActual? dataDir with
        | .ok ev => pure ev
        | .error _ => return .error message
  let coverage ←
    match ← loadCoverage (dataDir / "zero-origin-coverage.loam") with
    | .error message => return .error message
    | .ok evidence => pure evidence
  return .ok {
    events := actualEvidence.events
    corrections := actualEvidence.corrections
    coverage := coverage
  }

/--
Load the production balance-view question. Missing zero-origin evidence does not
invent a zero balance; balance-view.tsv selects display coordinates only.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath) : IO (Except String Snapshot) := do
  let evidence ←
    match ← loadEvidence dataDir actualRoot with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let coordinates ←
    match ← Loam.BalanceViewConfig.load? (dataDir / "config" / "balance-view.tsv") with
    | none => return .error "loam: malformed or unsupported balance-view config"
    | some selected => pure selected
  return project evidence.events evidence.corrections evidence.coverage coordinates

end Loam.BalanceReview

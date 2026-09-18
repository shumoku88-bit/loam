import Loam.ActualAuthority
import Loam.Application.CorrectionFrontier
import Loam.BalanceViewConfig
import Loam.Persistence.ZeroOriginCoveragePersistence

namespace Loam.BalanceReview

open Loam.Core

set_option autoImplicit false

/-!
# Shared production balance review

This boundary answers the existing replaceable balance-view question from the
selected Actual authority plus independent zero-origin coverage evidence.
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

private def coverageError (coordinate : EffectCoordinate) : String :=
  "loam: balances unavailable: zero-origin coverage missing for " ++
    coordinate.locus.token ++ " / " ++ coordinate.measure.token

/--
Resolve the one correction-aware Event world shared by every selected balance row.
The caller controls when this obligation is forced so zero-origin refusal ordering
stays identical to the row-local inspection path.
-/
private def quantityBasis
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory) : Except String EventMemory :=
  match eventCorrections.corrections with
  | [] => .ok events
  | _ =>
      if Loam.Application.correctionReferencesClosed events eventCorrections then
        match Loam.Application.correctionFrontierMemory? events eventCorrections with
        | some frontier => .ok frontier
        | none =>
            .error
              "loam: balances unavailable: event corrections do not justify one frontier"
      else
        .error "loam: balances unavailable: correction references are not closed"

/--
Project rows after one correction-aware quantity basis has been admitted.
Coverage remains coordinate-local and is still checked left-to-right.
-/
private def collectRowsFromBasis
    (basis : EventMemory)
    (coverage : ZeroOriginCoverage) :
    List EffectCoordinate → Except String (List Row)
  | [] => .ok []
  | coordinate :: rest =>
      if coverage.covers coordinate then
        let quantity :=
          EventMemory.quantityAtRecorded basis coordinate.locus coordinate.measure
        match collectRowsFromBasis basis coverage rest with
        | .error message => .error message
        | .ok later => .ok ({ coordinate := coordinate, quantity := quantity } :: later)
      else
        .error (coverageError coordinate)

/--
Project one balance view from an already-admitted current Event basis.

This is the canonical read path after crossing ActualAuthority.Image. It keeps
zero-origin coverage as an independent coordinate gate but does not reconstruct
Correction admission that normalized Actual loading has already established.
-/
private def projectFromAdmittedBasis
    (basis : EventMemory)
    (coverage : ZeroOriginCoverage)
    (coordinates : List EffectCoordinate) : Except String Snapshot := do
  let rows ← collectRowsFromBasis basis coverage coordinates.eraseDups
  return { rows := rows }

/--
Project one already-loaded balance view. Presentation duplicates are normalized,
but zero-origin membership remains an independent evidence requirement.

For a non-empty selection, the first coordinate's coverage gate remains ahead of
correction admission. Once that gate succeeds, one correction-aware Event basis
is shared by every row. This preserves the former refusal order while avoiding
per-coordinate reconstruction of the same correction frontier.
-/
def project
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coverage : ZeroOriginCoverage)
    (coordinates : List EffectCoordinate) : Except String Snapshot :=
  match coordinates.eraseDups with
  | [] => .ok { rows := [] }
  | first :: rest =>
      if coverage.covers first then
        match quantityBasis events eventCorrections with
        | .error message => .error message
        | .ok basis =>
            let firstQuantity :=
              EventMemory.quantityAtRecorded basis first.locus first.measure
            match collectRowsFromBasis basis coverage rest with
            | .error message => .error message
            | .ok later =>
                .ok {
                  rows := { coordinate := first, quantity := firstQuantity } :: later
                }
      else
        .error (coverageError first)

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

/-- Load the exact selected Actual authority and independent zero-origin evidence. -/
def loadEvidence
    (dataDir actualRoot : System.FilePath) : IO (Except String Evidence) := do
  let path :=
    if actualRoot.fileName == some Loam.ActualAuthority.actualFileName then actualRoot
    else Loam.ActualAuthority.actualPath actualRoot
  let actualEvidence ←
    match ← Loam.ActualAuthority.loadActualFile? path with
    | .ok ev => pure ev
    | .error message => return .error message
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
  let path :=
    if actualRoot.fileName == some Loam.ActualAuthority.actualFileName then actualRoot
    else Loam.ActualAuthority.actualPath actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? path with
    | .ok image => pure image
    | .error message => return .error message
  let coverage ←
    match ← loadCoverage (dataDir / "zero-origin-coverage.loam") with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let coordinates ←
    match ← Loam.BalanceViewConfig.load? (dataDir / "config" / "balance-view.tsv") with
    | none => return .error "loam: malformed or unsupported balance-view config"
    | some selected => pure selected
  return projectFromAdmittedBasis image.currentEvents coverage coordinates

end Loam.BalanceReview

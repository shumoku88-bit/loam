import Loam.Authority.ActualAuthority
import Loam.Review.HistoricalBalanceReview

namespace Loam.OpeningPositionReview

open Loam.Core

set_option autoImplicit false

/-!
# Derived accounting opening position

This boundary gives a household accounting name to one already-qualified
historical quantity question:

> what exact quantities were present at the start of this Accounting Epoch day?

The answer is derived from `HistoricalBalanceReview`. It introduces no new
quantity authority, no persisted opening-balance file, and no generated Actual
Event.

A coordinate is therefore answerable here only when the existing historical
review can justify it through either exact zero-origin reconstruction or the
bounded-history + exact-current-anchor route. `OpeningSupport` remains a narrow
current-balance witness and does not silently become historical completeness.

This separation lets external projections render conventional opening balances
without making those target-side rows canonical LOAM facts.
-/

/-- Opening-position rows are exactly the already-qualified historical rows. -/
abbrev Row := Loam.HistoricalBalanceReview.Row

/-- Exact quantities at one explicit Accounting Epoch start-of-day boundary. -/
structure Snapshot where
  accountingEpoch : String
  rows : List Row
deriving Repr, DecidableEq

/--
Derive one opening position from already-admitted Actual and historical support.

The Accounting Epoch is a query boundary, not separately persisted evidence.
-/
def project
    (image : Loam.ActualAuthority.Image)
    (evidence : Loam.HistoricalBalanceReview.Evidence)
    (accountingEpoch : String)
    (coordinates : List EffectCoordinate) :
    Except String Snapshot := do
  let historical ←
    Loam.HistoricalBalanceReview.projectStartOfDay
      image evidence accountingEpoch coordinates
  return {
    accountingEpoch := historical.startOfDay
    rows := historical.rows
  }

/-- Derive an opening position while reusing one caller-owned Actual image. -/
def loadFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image)
    (accountingEpoch : String)
    (coordinates : List EffectCoordinate) :
    IO (Except String Snapshot) := do
  let evidence ←
    match ← Loam.HistoricalBalanceReview.loadEvidence dataDir with
    | .error message => return .error message
    | .ok evidence => pure evidence
  return project image evidence accountingEpoch coordinates

/-- Load one admitted Actual image and derive an opening position. -/
def load
    (dataDir actualRoot : System.FilePath)
    (accountingEpoch : String)
    (coordinates : List EffectCoordinate) :
    IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadFromActualImage dataDir image accountingEpoch coordinates

end Loam.OpeningPositionReview

import Loam.ActualDate
import Loam.Core.RoutingEffective
import Loam.Persistence.ActualRoutingPersistence
import Loam.WriterOwnership

namespace Loam.ActualRoutingPublisher

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Shared Actual routing publication

Actual routing is historical evidence attaching one Purpose decision to a Locus
from an explicit routing-effective coordinate. This module owns the shared
presentation-neutral writer used by administration surfaces without introducing
a Purpose registry or a second routing engine.

The publisher preserves the existing Actual-routing write contract:
- missing storage may be initialized as an empty history by the writer;
- malformed existing storage fails closed;
- duplicate `(LocusId, effectiveOn)` coordinates are rejected;
- publication occurs under WriterOwnership;
- earlier routing assertions are never edited in place.
-/

inductive Target where
  | managed (purpose : PurposeId)
  | unmanaged
deriving Repr, DecidableEq

structure Draft where
  locus : LocusId
  effectiveOn : RoutingEffective String
  target : Target
deriving Repr, DecidableEq

structure Receipt where
  locus : LocusId
  effectiveOn : RoutingEffective String
  target : Target
deriving Repr, DecidableEq

private def loadHistoryOrEmpty?
    (path : System.FilePath) : IO (Option ActualRoutingHistory) := do
  if ← path.pathExists then
    loadActualRoutingHistory? path
  else
    return RoutingHistory.ofEntries? []

private def validateEffective : RoutingEffective String → Bool
  | .initial => true
  | .dated date => Loam.ActualDate.validIsoDate date

private def publishUnlocked
    (routingFile : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  let history ←
    match ← loadHistoryOrEmpty? routingFile with
    | some history => pure history
    | none => return .error "loam: malformed or unsupported Actual routing authority"
  let purpose : Option PurposeId :=
    match draft.target with
    | .managed p => some p
    | .unmanaged => none
  let entry : RoutingEntry LocusId (RoutingEffective String) := {
    subject := draft.locus
    effectiveOn := draft.effectiveOn
    purpose := purpose
  }
  match RoutingHistory.ofEntries? (history.entries ++ [entry]) with
  | none =>
      return .error "loam: Actual routing already has evidence at this locus/effective coordinate"
  | some updated =>
      if ← saveActualRoutingHistory? routingFile updated then
        return .ok {
          locus := draft.locus
          effectiveOn := draft.effectiveOn
          target := draft.target
        }
      else
        return .error "loam: Actual routing evidence could not be published"

/-- Publish one explicit Actual routing assertion under routing-authority ownership. -/
def publish
    (routingPath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if routingPath.isEmpty then
    return .error "loam: routing path must not be empty"
  if !validToken draft.locus.token then
    return .error "loam: routing Locus must be a nonempty single-line token"
  if !validateEffective draft.effectiveOn then
    return .error "loam: routing effective date must be a real calendar date in YYYY-MM-DD form"
  match draft.target with
  | .managed purpose =>
      if !validToken purpose.token then
        return .error "loam: route must be 'managed PURPOSE' or 'unmanaged'"
  | .unmanaged => pure ()
  let routingFile := System.FilePath.mk routingPath
  Loam.WriterOwnership.withOwnership routingFile
    (publishUnlocked routingFile draft)

end Loam.ActualRoutingPublisher

import Loam.ActualDate
import Loam.Core.RoutingEffective
import Loam.Persistence.ActualRoutingPersistence
import Loam.Authority.ActualRoutingAuthority

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
- earlier routing assertions are never edited in place.

The same pure proposal is used by standalone legacy publication and the
HouseholdImage adapter so storage topology cannot change routing admission.
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

private def validateEffective : RoutingEffective String → Bool
  | .initial => true
  | .dated date => Loam.ActualDate.validIsoDate date

private def validateDraft? (draft : Draft) : Except String Unit := do
  if !validToken draft.locus.token then
    throw "loam: routing Locus must be a nonempty single-line token"
  if !validateEffective draft.effectiveOn then
    throw "loam: routing effective date must be a real calendar date in YYYY-MM-DD form"
  match draft.target with
  | .managed purpose =>
      if !validToken purpose.token then
        throw "loam: route must be 'managed PURPOSE' or 'unmanaged'"
  | .unmanaged => pure ()

/-- Pure Actual-routing proposal shared across physical storage topologies. -/
private def propose?
    (history : ActualRoutingHistory)
    (draft : Draft) : Except String ActualRoutingHistory := do
  let purpose : Option PurposeId :=
    match draft.target with
    | .managed p => some p
    | .unmanaged => none
  let entry : RoutingEntry LocusId (RoutingEffective String) := {
    subject := draft.locus
    effectiveOn := draft.effectiveOn
    purpose := purpose
  }
  let some updated := history.add? entry
    | throw "loam: Actual routing already has evidence at this locus/effective coordinate"
  return updated

/--
Publish one explicit Actual routing assertion through an explicit standalone
legacy path.

This remains the current production/diagnostic entrance until a later explicit
HouseholdImage cutover. Missing legacy storage may be created on first write.
-/
def publish
    (routingPath : String)
    (draft : Draft) : IO (Except String Unit) := do
  match validateDraft? draft with
  | .ok () => pure ()
  | .error message => return .error message
  if routingPath.isEmpty then
    return .error "loam: routing path must not be empty"
  let routingFile := System.FilePath.mk routingPath
  Loam.ActualRoutingAuthority.updateLegacyCurrent? routingFile fun history => do
    let updated ← propose? history draft
    return (updated, ())

/--
Publish one Actual routing assertion into the HouseholdImage ActualRouting
section.

This is an adapter-qualification entrance only. Production HouseholdCommand and
Review selection remain on the legacy routing file until a later explicit
cutover. Missing HouseholdImage ActualRouting may be created on first write,
matching the existing writer contract.
-/
def publishHousehold
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  match validateDraft? draft with
  | .ok () => pure ()
  | .error message => return .error message
  if root.toString.isEmpty then
    return .error "loam: data root must not be empty"
  Loam.ActualRoutingAuthority.updateHouseholdCurrent? root fun history => do
    let updated ← propose? history draft
    return (updated, ())

end Loam.ActualRoutingPublisher

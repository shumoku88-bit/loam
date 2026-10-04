import Loam.Core.ScheduledRouting
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.Persistence.WriterOwnership
import Loam.Authority.HouseholdAuthority

namespace Loam.ScheduledRoutingAuthority

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Scheduled routing authority adapter

This boundary qualifies the existing Scheduled routing payload for two physical
topologies without changing routing semantics.

Production household selection uses the required `ScheduledRouting` section
of HouseholdImage. Explicit standalone paths remain only for legacy diagnostics
and migration qualification.

A missing HouseholdImage section is unavailable, not implicit empty history.
-/

private def decodeBody?
    (body : String) : Except String (ScheduledRoutingHistory String) :=
  match decodeScheduledRoutingHistory? body with
  | some history => .ok history
  | none =>
      .error "loam: malformed or unsupported HouseholdImage Scheduled routing authority"

def loadLegacyCurrent?
    (path : System.FilePath) :
    IO (Except String (ScheduledRoutingHistory String)) := do
  if !(← path.pathExists) then
    return .error "loam: Scheduled routing authority is missing"
  match ← loadScheduledRoutingHistory? path with
  | some history => return .ok history
  | none => return .error "loam: malformed or unsupported Scheduled routing authority"

def updateLegacyCurrent? {α : Type}
    (path : System.FilePath)
    (propose : ScheduledRoutingHistory String →
      Except String (ScheduledRoutingHistory String × α)) :
    IO (Except String α) :=
  Loam.WriterOwnership.withOwnership path do
    let current ←
      match ← loadLegacyCurrent? path with
      | .ok history => pure history
      | .error message => return .error message
    let (updated, result) ←
      match propose current with
      | .ok value => pure value
      | .error message => return .error message
    if ← saveScheduledRoutingHistory? path updated then
      return .ok result
    return .error "loam: Scheduled routing evidence could not be published"

/--
Load the required ScheduledRouting section from one installed HouseholdImage.
-/
def loadHouseholdCurrent?
    (root : System.FilePath) :
    IO (Except String (ScheduledRoutingHistory String)) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let some body := body? generation.image "ScheduledRouting"
    | return .error "loam: required HouseholdImage Scheduled routing section is missing"
  return decodeBody? body

/--
Apply one routing-local read/modify/publish operation through HouseholdImage.

The section must already exist. The shared generation publisher rechecks the
observed wire under the one HouseholdImage writer lock, rejects stale writers,
and preserves every unmarked section byte-for-byte.
-/
def updateHouseholdCurrent? {α : Type}
    (root : System.FilePath)
    (propose : ScheduledRoutingHistory String →
      Except String (ScheduledRoutingHistory String × α)) :
    IO (Except String α) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let some currentBody := body? generation.image "ScheduledRouting"
    | return .error "loam: required HouseholdImage Scheduled routing section is missing"
  let current ←
    match decodeBody? currentBody with
    | .ok history => pure history
    | .error message => return .error message
  let (updated, result) ←
    match propose current with
    | .ok value => pure value
    | .error message => return .error message
  let some updatedBody := encodeScheduledRoutingHistory? updated
    | return .error "loam: updated HouseholdImage Scheduled routing evidence did not encode"
  let some candidate :=
      replaceBody? generation.image "ScheduledRouting" updatedBody
    | return .error "loam: HouseholdImage Scheduled routing section disappeared before publication"
  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["ScheduledRouting"] candidate with
  | .ok _ => return .ok result
  | .error message => return .error message

end Loam.ScheduledRoutingAuthority

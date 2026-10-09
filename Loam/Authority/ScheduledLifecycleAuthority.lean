import Loam.Authority.HouseholdAuthority
import Loam.HouseholdPaths
import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.ScheduledLifecycleAuthority

open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Scheduled lifecycle Household authority

This boundary qualifies the existing complete Scheduled lifecycle payload for
HouseholdImage without changing Scheduled semantics.

Production cutover remains separate. The Scheduled section is required at this
boundary, matching the existing standalone lifecycle contract: missing authority
is an error, and malformed present evidence fails closed.

Publication replaces exactly the Scheduled section against one observed
Household generation. Unmarked and unknown sections are preserved by
HouseholdAuthority, and stale observed generations are refused.
-/

structure Observed where
  generation : Loam.HouseholdAuthority.Generation
  lifecycle : ScheduledLifecycleImage

private def decodeBody?
    (body : String) : Except String ScheduledLifecycleImage :=
  match decodeScheduledLifecycleImage? body with
  | some lifecycle => .ok lifecycle
  | none =>
      .error "loam: malformed or unsupported HouseholdImage Scheduled lifecycle authority"

/-- Load the required legacy standalone Scheduled lifecycle authority. -/
def loadLegacyCurrent?
    (path : System.FilePath) : IO (Except String ScheduledLifecycleImage) := do
  if !(← path.pathExists) then
    return .error "loam: Scheduled lifecycle authority is missing"
  match ← loadScheduledLifecycleImage? path with
  | some lifecycle => return .ok lifecycle
  | none =>
      return .error "loam: Scheduled lifecycle authority is malformed or unsupported"

/-- Decode required lifecycle evidence from a caller-owned qualified generation. -/
def decodeGeneration?
    (generation : Loam.HouseholdAuthority.Generation) : Except String ScheduledLifecycleImage := do
  let some body := body? generation.image "Scheduled"
    | throw "loam: required HouseholdImage Scheduled lifecycle section is missing"
  decodeBody? body

/-- Load the required Scheduled section from one exact HouseholdImage generation. -/
def loadHouseholdObserved?
    (root : System.FilePath) : IO (Except String Observed) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let lifecycle ←
    match decodeGeneration? generation with
    | .ok lifecycle => pure lifecycle
    | .error message => return .error message
  return .ok { generation, lifecycle }

/-- Load only the current Household Scheduled lifecycle value. -/
def loadHouseholdCurrent?
    (root : System.FilePath) : IO (Except String ScheduledLifecycleImage) := do
  match ← loadHouseholdObserved? root with
  | .ok observed => return .ok observed.lifecycle
  | .error message => return .error message

/-- Publish one proposed Scheduled lifecycle against the exact observed Household generation. -/
def publishObserved?
    (root : System.FilePath)
    (observed : Observed)
    (proposed : ScheduledLifecycleImage) :
    IO (Except String Loam.HouseholdAuthority.Generation) := do
  let some currentBody := encodeScheduledLifecycleImage? observed.lifecycle
    | return .error "loam: observed Scheduled lifecycle did not re-encode"
  let some proposedBody := encodeScheduledLifecycleImage? proposed
    | return .error "loam: proposed Scheduled lifecycle did not encode"
  if currentBody == proposedBody then
    return .ok observed.generation
  let some candidate :=
      replaceBody? observed.generation.image "Scheduled" proposedBody
    | return .error "loam: HouseholdImage Scheduled lifecycle section disappeared before publication"
  Loam.HouseholdAuthority.publishObserved?
    root observed.generation.wire ["Scheduled"] candidate

end Loam.ScheduledLifecycleAuthority

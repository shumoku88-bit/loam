import Loam.Authority.HouseholdAuthority
import Loam.Persistence.AccountingRolePersistence

namespace Loam.AccountingRoleAuthority

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# AccountingRole Household authority

Production AccountingRole evidence is the required `AccountingRole` section of
one installed HouseholdImage generation.

This boundary deliberately does not select or fall back to the frozen standalone
`accounting-role.loam`. Explicit low-level diagnostic/export entrances may keep
using that legacy file directly.

Missing Household AccountingRole evidence is unavailable, malformed present
evidence fails closed, and publication replaces only this section against the
exact generation that was observed.
-/

structure Observed where
  generation : Loam.HouseholdAuthority.Generation
  roles : AccountingRoleMap

/-- Decode required AccountingRole evidence from one already-loaded generation. -/
def decodeGeneration?
    (generation : Loam.HouseholdAuthority.Generation) :
    Except String AccountingRoleMap := do
  let some body := body? generation.image "AccountingRole"
    | throw "loam: required HouseholdImage AccountingRole section is missing"
  let some roles := decodeAccountingRoleMap? body
    | throw "loam: malformed or unsupported HouseholdImage AccountingRole authority"
  return roles

/-- Load required AccountingRole evidence together with its exact Household generation. -/
def loadHouseholdObserved?
    (root : System.FilePath) : IO (Except String Observed) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let roles ←
    match decodeGeneration? generation with
    | .ok roles => pure roles
    | .error message => return .error message
  return .ok { generation, roles }

/-- Load only the current production AccountingRole relation from HouseholdImage. -/
def loadHouseholdCurrent?
    (root : System.FilePath) : IO (Except String AccountingRoleMap) := do
  match ← loadHouseholdObserved? root with
  | .ok observed => return .ok observed.roles
  | .error message => return .error message

/--
Publish one proposed AccountingRole relation against the exact observed Household
generation.

The section must already exist. Unknown and unrelated sections are preserved by
HouseholdAuthority, which also retains stale-generation refusal and `.prev`
publication behavior.
-/
def publishObserved?
    (root : System.FilePath)
    (observed : Observed)
    (proposed : AccountingRoleMap) :
    IO (Except String Loam.HouseholdAuthority.Generation) := do
  let some currentBody := body? observed.generation.image "AccountingRole"
    | return .error "loam: required HouseholdImage AccountingRole section is missing"
  let some proposedBody := encodeAccountingRoleMap? proposed
    | return .error "loam: proposed HouseholdImage AccountingRole authority did not encode"
  if currentBody == proposedBody then
    return .ok observed.generation
  let some candidate :=
      replaceBody? observed.generation.image "AccountingRole" proposedBody
    | return .error
        "loam: HouseholdImage AccountingRole section disappeared before publication"
  Loam.HouseholdAuthority.publishObserved?
    root observed.generation.wire ["AccountingRole"] candidate

end Loam.AccountingRoleAuthority

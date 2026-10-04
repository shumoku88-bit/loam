import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.WriterOwnership
import Loam.Authority.HouseholdAuthority

namespace Loam.ActualRoutingAuthority

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Actual routing authority adapter

This boundary qualifies the existing Actual-routing payload for standalone legacy
storage and the installed HouseholdImage without changing routing semantics.

The read contract and write contract intentionally differ:

- required reads treat missing routing evidence as unavailable;
- publication may create the first routing history from semantic empty history.

Production selection has not moved yet. Explicit standalone paths remain the
current production/diagnostic entrance until a later cutover, while
HouseholdImage-specific functions operate only on the `ActualRouting` section.
-/

private def decodeBody?
    (body : String) : Except String ActualRoutingHistory :=
  match decodeActualRoutingHistory? body with
  | some history => .ok history
  | none =>
      .error "loam: malformed or unsupported HouseholdImage Actual routing authority"

private def emptyHistory? : Except String ActualRoutingHistory :=
  match RoutingHistory.ofEntries? [] with
  | some history => .ok history
  | none => .error "loam: empty Actual routing history could not be admitted"

/-- Load one required explicit legacy Actual-routing authority. -/
def loadLegacyRequired?
    (path : System.FilePath) : IO (Except String ActualRoutingHistory) := do
  if !(← path.pathExists) then
    return .error "loam: Actual routing authority is missing"
  match ← loadActualRoutingHistory? path with
  | some history => return .ok history
  | none => return .error "loam: malformed or unsupported Actual routing authority"

private def loadLegacyOrEmpty?
    (path : System.FilePath) : IO (Except String ActualRoutingHistory) := do
  if !(← path.pathExists) then
    return emptyHistory?
  match ← loadActualRoutingHistory? path with
  | some history => return .ok history
  | none => return .error "loam: malformed or unsupported Actual routing authority"

/--
Apply one legacy-file routing read/modify/publish operation.

Missing legacy storage starts from semantic empty history, preserving the
existing ActualRoutingPublisher first-write contract.
-/
def updateLegacyCurrent? {α : Type}
    (path : System.FilePath)
    (propose : ActualRoutingHistory →
      Except String (ActualRoutingHistory × α)) :
    IO (Except String α) :=
  Loam.WriterOwnership.withOwnership path do
    let current ←
      match ← loadLegacyOrEmpty? path with
      | .ok history => pure history
      | .error message => return .error message
    let (updated, result) ←
      match propose current with
      | .ok value => pure value
      | .error message => return .error message
    if ← saveActualRoutingHistory? path updated then
      return .ok result
    return .error "loam: Actual routing evidence could not be published"

/--
Load the required ActualRouting section from one installed HouseholdImage.

A missing section remains unavailable for required readers and is not silently
relabelled as empty routing evidence.
-/
def loadHouseholdRequired?
    (root : System.FilePath) : IO (Except String ActualRoutingHistory) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let some body := body? generation.image "ActualRouting"
    | return .error "loam: required HouseholdImage Actual routing section is missing"
  return decodeBody? body

/--
Apply one Actual-routing read/modify/publish operation through HouseholdImage.

If the section is absent, publication starts from semantic empty history and
creates the section. If present, it must decode successfully. Publication uses
the shared HouseholdImage stale-generation check and preserves every unmarked
section byte-for-byte.
-/
def updateHouseholdCurrent? {α : Type}
    (root : System.FilePath)
    (propose : ActualRoutingHistory →
      Except String (ActualRoutingHistory × α)) :
    IO (Except String α) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message

  let currentBody? := body? generation.image "ActualRouting"
  let current ←
    match currentBody? with
    | some body =>
        match decodeBody? body with
        | .ok history => pure history
        | .error message => return .error message
    | none =>
        match emptyHistory? with
        | .ok history => pure history
        | .error message => return .error message

  let (updated, result) ←
    match propose current with
    | .ok value => pure value
    | .error message => return .error message

  let some updatedBody := encodeActualRoutingHistory? updated
    | return .error "loam: updated HouseholdImage Actual routing evidence did not encode"

  let candidate ←
    match currentBody? with
    | some _ =>
        match replaceBody? generation.image "ActualRouting" updatedBody with
        | some image => pure image
        | none =>
            return .error
              "loam: HouseholdImage Actual routing section disappeared before publication"
    | none =>
        match appendSection? generation.image
            { name := "ActualRouting", body := updatedBody } with
        | some image => pure image
        | none =>
            return .error
              "loam: HouseholdImage Actual routing section could not be created"

  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["ActualRouting"] candidate with
  | .ok _ => return .ok result
  | .error message => return .error message

end Loam.ActualRoutingAuthority

import Loam.Application.CurrentQuantityAnchor
import Loam.Application.CurrentQuantityPresence
import Loam.Core.BoundedHistorySupport
import Loam.Authority.HouseholdAuthority
import Loam.HouseholdPaths
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.CurrentQuantityPresencePersistence
import Loam.Persistence.BoundedHistorySupportPersistence

namespace Loam.CurrentSupportAuthority

open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Current support Household authority

This boundary owns only the shared physical generation for the three current
quantity support families:

- CurrentQuantityAnchor;
- CurrentQuantityPresence;
- BoundedHistorySupport.

Their semantic proposal rules stay in their existing application/publisher
modules. This boundary does not infer support, widen absence semantics, or create
a generic repository abstraction.

All three families preserve their existing optional-reader contract: an absent
section means semantic empty evidence. A malformed present section fails closed.

Production cutover is intentionally separate. This adapter first qualifies one
coherent read generation and atomic multi-section publication.
-/

structure Snapshot where
  anchor : Loam.CurrentQuantityAnchor.Evidence
  presence : Loam.CurrentQuantityPresence.Evidence
  bounded : Loam.BoundedHistorySupport.Evidence

structure Observed where
  generation : Loam.HouseholdAuthority.Generation
  snapshot : Snapshot

private def decodeAnchorOrEmpty?
    (image : Image) : Except String Loam.CurrentQuantityAnchor.Evidence :=
  match body? image "CurrentQuantityAnchor" with
  | none => .ok Loam.CurrentQuantityAnchor.Evidence.empty
  | some body =>
      match decodeCurrentQuantityAnchor? body with
      | some evidence => .ok evidence
      | none =>
          .error
            "loam: malformed or unsupported HouseholdImage current quantity anchor authority"

private def decodePresenceOrEmpty?
    (image : Image) : Except String Loam.CurrentQuantityPresence.Evidence :=
  match body? image "CurrentQuantityPresence" with
  | none => .ok Loam.CurrentQuantityPresence.Evidence.empty
  | some body =>
      match decodeCurrentQuantityPresence? body with
      | some evidence => .ok evidence
      | none =>
          .error
            "loam: malformed or unsupported HouseholdImage current quantity presence authority"

private def decodeBoundedOrEmpty?
    (image : Image) : Except String Loam.BoundedHistorySupport.Evidence :=
  match body? image "BoundedHistorySupport" with
  | none => .ok Loam.BoundedHistorySupport.Evidence.empty
  | some body =>
      match decodeBoundedHistorySupport? body with
      | some evidence => .ok evidence
      | none =>
          .error
            "loam: malformed or unsupported HouseholdImage bounded historical support authority"

private def decodeSnapshot? (image : Image) : Except String Snapshot := do
  let anchor ← decodeAnchorOrEmpty? image
  let presence ← decodePresenceOrEmpty? image
  let bounded ← decodeBoundedOrEmpty? image
  return { anchor, presence, bounded }

/-- Load all three legacy files with their established missing-as-empty semantics. -/
def loadLegacyOrEmpty?
    (root : System.FilePath) : IO (Except String Snapshot) := do
  let anchorPath := Loam.HouseholdPaths.currentQuantityAnchor root
  let presencePath := Loam.HouseholdPaths.currentQuantityPresence root
  let boundedPath := Loam.HouseholdPaths.boundedHistorySupport root

  let anchor ←
    if ← anchorPath.pathExists then
      match ← loadCurrentQuantityAnchor? anchorPath with
      | some evidence => pure evidence
      | none =>
          return .error
            "loam: current quantity anchor authority is malformed or unsupported"
    else
      pure Loam.CurrentQuantityAnchor.Evidence.empty

  let presence ←
    if ← presencePath.pathExists then
      match ← loadCurrentQuantityPresence? presencePath with
      | some evidence => pure evidence
      | none =>
          return .error
            "loam: current quantity presence authority is malformed or unsupported"
    else
      pure Loam.CurrentQuantityPresence.Evidence.empty

  let bounded ←
    if ← boundedPath.pathExists then
      match ← loadBoundedHistorySupport? boundedPath with
      | some evidence => pure evidence
      | none =>
          return .error
            "loam: bounded historical support authority is malformed or unsupported"
    else
      pure Loam.BoundedHistorySupport.Evidence.empty

  return .ok { anchor, presence, bounded }

/--
Load one coherent HouseholdImage generation and decode the three current-support
families from that exact generation.
-/
def loadHousehold?
    (root : System.FilePath) : IO (Except String Observed) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let snapshot ←
    match decodeSnapshot? generation.image with
    | .ok snapshot => pure snapshot
    | .error message => return .error message
  return .ok { generation, snapshot }

private def withBody?
    (image : Image)
    (name body : String) : Option Image :=
  if contains image name then
    replaceBody? image name body
  else
    appendSection? image { name := name, body := body }

private structure Encoded where
  anchor : String
  presence : String
  bounded : String

private def encodeSnapshot? (snapshot : Snapshot) : Except String Encoded := do
  let some anchor := encodeCurrentQuantityAnchor? snapshot.anchor
    | throw "loam: current quantity anchor encoder rejected admitted evidence"
  let some presence := encodeCurrentQuantityPresence? snapshot.presence
    | throw "loam: current quantity presence encoder rejected admitted evidence"
  let some bounded := encodeBoundedHistorySupport? snapshot.bounded
    | throw "loam: bounded historical support encoder rejected admitted evidence"
  return { anchor, presence, bounded }

private def applyChangedBody?
    (image : Image)
    (changed : Bool)
    (name body : String) : Option Image :=
  if changed then withBody? image name body else some image

/--
Publish a proposed current-support snapshot against one exact observed
HouseholdImage generation.

Only semantically changed support families are physically replaced/appended.
If the proposal is a semantic no-op, no Household generation is written and the
observed generation is returned unchanged.

A stale observed Household generation is refused by HouseholdAuthority.
-/
def publishObserved?
    (root : System.FilePath)
    (observed : Observed)
    (proposed : Snapshot) :
    IO (Except String Loam.HouseholdAuthority.Generation) := do
  let currentEncoded ←
    match encodeSnapshot? observed.snapshot with
    | .ok encoded => pure encoded
    | .error message => return .error message
  let proposedEncoded ←
    match encodeSnapshot? proposed with
    | .ok encoded => pure encoded
    | .error message => return .error message

  let anchorChanged := currentEncoded.anchor != proposedEncoded.anchor
  let presenceChanged := currentEncoded.presence != proposedEncoded.presence
  let boundedChanged := currentEncoded.bounded != proposedEncoded.bounded

  let changedNames :=
    (if anchorChanged then ["CurrentQuantityAnchor"] else []) ++
    (if presenceChanged then ["CurrentQuantityPresence"] else []) ++
    (if boundedChanged then ["BoundedHistorySupport"] else [])

  if changedNames.isEmpty then
    return .ok observed.generation

  let some candidate0 :=
      applyChangedBody?
        observed.generation.image anchorChanged
        "CurrentQuantityAnchor" proposedEncoded.anchor
    | return .error "loam: CurrentQuantityAnchor section could not be installed"
  let some candidate1 :=
      applyChangedBody?
        candidate0 presenceChanged
        "CurrentQuantityPresence" proposedEncoded.presence
    | return .error "loam: CurrentQuantityPresence section could not be installed"
  let some candidate2 :=
      applyChangedBody?
        candidate1 boundedChanged
        "BoundedHistorySupport" proposedEncoded.bounded
    | return .error "loam: BoundedHistorySupport section could not be installed"

  Loam.HouseholdAuthority.publishObserved?
    root observed.generation.wire changedNames candidate2

end Loam.CurrentSupportAuthority

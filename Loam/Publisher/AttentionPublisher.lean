import Loam.ActualDate
import Loam.Authority.HouseholdAuthority
import Loam.Core.AttentionMemory
import Loam.FreshNumberedToken
import Loam.Persistence.AttentionPersistence
import Loam.Persistence.WriterOwnership

namespace Loam.AttentionPublisher

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Shared Attention publication

Attention remains one complete retained image of items plus explicit closure
evidence. This publisher owns production mutation of that image without adding
priority, taxonomy, selected-day membership, mutable status, or relation
provenance.

Missing storage may be bootstrapped as an empty image by the first writer.
Malformed existing storage fails closed. Every mutation re-reads the authority
under `WriterOwnership` before admission and complete-image publication.
-/

structure AddDraft where
  context : String
  due : AttentionDue String
deriving Repr, DecidableEq

structure CloseDraft where
  attention : AttentionId
  knownOn : String
  kind : AttentionClosureKind
deriving Repr, DecidableEq

private def emptyImage? : Option (AttentionMemory String × AttentionClosureMemory String) := do
  let items ← AttentionMemory.ofItems? []
  let closures ← AttentionClosureMemory.ofClosures? []
  pure (items, closures)

private def loadImageOrEmpty?
    (path : System.FilePath) : IO (Option (AttentionMemory String × AttentionClosureMemory String)) := do
  if ← path.pathExists then
    loadAttentionMemory? path
  else
    return emptyImage?

private def freshId (items : AttentionMemory String) : AttentionId :=
  let used := items.items.map (fun item => item.id.token)
  ⟨Loam.firstUnusedNumberedToken "attention-" used 1⟩

private theorem freshId_fresh (items : AttentionMemory String) :
    freshId items ∉ items.items.map Attention.id := by
  intro hId
  have hToken :=
    Loam.firstUnusedNumberedToken_fresh
      "attention-" (items.items.map (fun item => item.id.token)) 1
  apply hToken
  simp only [List.mem_map] at hId ⊢
  rcases hId with ⟨existing, hExisting, hEq⟩
  refine ⟨existing, hExisting, ?_⟩
  simpa [freshId] using congrArg AttentionId.token hEq

private def validDue : AttentionDue String → Bool
  | .dueOn date => Loam.ActualDate.validIsoDate date
  | .noDueDate => true
  | .dueUndetermined => true

private def proposeAdd
    (items : AttentionMemory String)
    (closures : AttentionClosureMemory String)
    (draft : AddDraft) :
    (AttentionMemory String × AttentionClosureMemory String) × AttentionId :=
  let id := freshId items
  let item : Attention String := { id := id, context := draft.context, due := draft.due }
  let updatedItems := AttentionMemory.addFresh items item (by
    change id ∉ items.items.map Attention.id
    exact freshId_fresh items)
  ((updatedItems, closures), id)

private def addUnlocked
    (path : System.FilePath)
    (draft : AddDraft) : IO (Except String AttentionId) := do
  let (items, closures) ←
    match ← loadImageOrEmpty? path with
    | some image => pure image
    | none => return .error "loam: malformed or unsupported Attention authority"
  let ((updatedItems, updatedClosures), id) := proposeAdd items closures draft
  if ← saveAttentionMemory? path updatedItems updatedClosures then
    return .ok id
  else
    return .error "loam: Attention evidence could not be published"

/-- Add one new open Attention item under authority ownership. -/
def add
    (pathText : String)
    (draft : AddDraft) : IO (Except String AttentionId) := do
  if pathText.isEmpty then
    return .error "loam: Attention path must not be empty"
  if !validDue draft.due then
    return .error "loam: Attention due date must be a real calendar date in YYYY-MM-DD form"
  let path := System.FilePath.mk pathText
  Loam.WriterOwnership.withOwnership path (addUnlocked path draft)

private def proposeClose?
    (items : AttentionMemory String)
    (closures : AttentionClosureMemory String)
    (draft : CloseDraft) :
    Except String (AttentionMemory String × AttentionClosureMemory String) := do
  if (AttentionMemory.findById? items draft.attention).isNone then
    throw "loam: Attention closure target is not retained"
  let closure : AttentionClosure String := {
    attention := draft.attention
    knownOn := draft.knownOn
    kind := draft.kind
  }
  let some updatedClosures := AttentionClosureMemory.add? closures closure
    | throw "loam: Attention item is already closed"
  pure (items, updatedClosures)

private def closeUnlocked
    (path : System.FilePath)
    (draft : CloseDraft) : IO (Except String Unit) := do
  let (items, closures) ←
    match ← loadImageOrEmpty? path with
    | some image => pure image
    | none => return .error "loam: malformed or unsupported Attention authority"
  let (updatedItems, updatedClosures) ←
    match proposeClose? items closures draft with
    | .ok image => pure image
    | .error message => return .error message
  if ← saveAttentionMemory? path updatedItems updatedClosures then
    return .ok ()
  else
    return .error "loam: Attention closure could not be published"

/-- Resolve or drop one retained open Attention item under authority ownership. -/
def close
    (pathText : String)
    (draft : CloseDraft) : IO (Except String Unit) := do
  if pathText.isEmpty then
    return .error "loam: Attention path must not be empty"
  if !Loam.ActualDate.validIsoDate draft.knownOn then
    return .error "loam: Attention closure date must be a real calendar date in YYYY-MM-DD form"
  let path := System.FilePath.mk pathText
  Loam.WriterOwnership.withOwnership path (closeUnlocked path draft)


private def householdImageOrEmpty?
    (generation : Loam.HouseholdAuthority.Generation) :
    Option (AttentionMemory String × AttentionClosureMemory String) :=
  match Loam.Persistence.HouseholdImage.body? generation.image "Attention" with
  | some body => Loam.Persistence.decodeAttentionMemory? body
  | none => emptyImage?

private def withAttentionBody?
    (image : Loam.Persistence.HouseholdImage.Image)
    (body : String) :
    Option Loam.Persistence.HouseholdImage.Image :=
  if Loam.Persistence.HouseholdImage.contains image "Attention" then
    Loam.Persistence.HouseholdImage.replaceBody? image "Attention" body
  else
    Loam.Persistence.HouseholdImage.appendSection? image {
      name := "Attention"
      body := body
    }

/--
Add one Attention through an already-installed HouseholdImage generation.

This is the production HouseholdImage Attention publication path after the
authority cutover. Low-level explicit-file diagnostics may still use the legacy
path-based publisher when intentionally operating on a standalone file.
-/
def addHousehold
    (root : System.FilePath)
    (draft : AddDraft) : IO (Except String AttentionId) := do
  if !validDue draft.due then
    return .error "loam: Attention due date must be a real calendar date in YYYY-MM-DD form"

  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let (items, closures) ←
    match householdImageOrEmpty? generation with
    | some image => pure image
    | none => return .error "loam: malformed or unsupported Attention authority"

  let ((updatedItems, updatedClosures), id) := proposeAdd items closures draft
  let some body := Loam.Persistence.encodeAttentionMemory? updatedItems updatedClosures
    | return .error "loam: Attention evidence could not be encoded"
  let some candidate := withAttentionBody? generation.image body
    | return .error "loam: Attention section could not be installed"

  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["Attention"] candidate with
  | .ok _ => return .ok id
  | .error message => return .error message

/--
Resolve or drop Attention through an already-installed HouseholdImage generation.

An absent Attention section has the same write meaning as absent legacy storage:
there is no retained closure target, so close fails rather than inventing an
empty configured section.
-/
def closeHousehold
    (root : System.FilePath)
    (draft : CloseDraft) : IO (Except String Unit) := do
  if !Loam.ActualDate.validIsoDate draft.knownOn then
    return .error "loam: Attention closure date must be a real calendar date in YYYY-MM-DD form"

  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let (items, closures) ←
    match householdImageOrEmpty? generation with
    | some image => pure image
    | none => return .error "loam: malformed or unsupported Attention authority"

  let (updatedItems, updatedClosures) ←
    match proposeClose? items closures draft with
    | .ok image => pure image
    | .error message => return .error message
  let some body := Loam.Persistence.encodeAttentionMemory? updatedItems updatedClosures
    | return .error "loam: Attention closure could not be encoded"
  let some candidate := withAttentionBody? generation.image body
    | return .error "loam: Attention section could not be installed"

  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["Attention"] candidate with
  | .ok _ => return .ok ()
  | .error message => return .error message

end Loam.AttentionPublisher

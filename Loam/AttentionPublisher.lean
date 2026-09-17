import Loam.ActualDate
import Loam.Core.AttentionMemory
import Loam.FreshNumberedToken
import Loam.Persistence.AttentionPersistence
import Loam.WriterOwnership

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
  let used := items.items.map (fun item => item.id.token)
  have hToken :
      Loam.firstUnusedNumberedToken "attention-" used 1 ∉ used :=
    Loam.firstUnusedNumberedToken_fresh "attention-" used 1
  intro hId
  apply hToken
  simp only [List.mem_map] at hId ⊢
  rcases hId with ⟨existing, hExisting, hEq⟩
  refine ⟨existing, hExisting, ?_⟩
  simpa [freshId, used] using congrArg AttentionId.token hEq

private def validDue : AttentionDue String → Bool
  | .dueOn date => Loam.ActualDate.validIsoDate date
  | .noDueDate => true
  | .dueUndetermined => true

private def addUnlocked
    (path : System.FilePath)
    (draft : AddDraft) : IO (Except String AttentionId) := do
  let (items, closures) ←
    match ← loadImageOrEmpty? path with
    | some image => pure image
    | none => return .error "loam: malformed or unsupported Attention authority"
  let id := freshId items
  let item : Attention String := { id := id, context := draft.context, due := draft.due }
  let updatedItems := AttentionMemory.addFresh items item (by
    simpa [item, id] using freshId_fresh items)
  if ← saveAttentionMemory? path updatedItems closures then
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

private def closeUnlocked
    (path : System.FilePath)
    (draft : CloseDraft) : IO (Except String Unit) := do
  let (items, closures) ←
    match ← loadImageOrEmpty? path with
    | some image => pure image
    | none => return .error "loam: malformed or unsupported Attention authority"
  if (AttentionMemory.findById? items draft.attention).isNone then
    return .error "loam: Attention closure target is not retained"
  if (AttentionClosureMemory.findByAttention? closures draft.attention).isSome then
    return .error "loam: Attention item is already closed"
  let closure : AttentionClosure String := {
    attention := draft.attention
    knownOn := draft.knownOn
    kind := draft.kind
  }
  let some updatedClosures := AttentionClosureMemory.add? closures closure
    | return .error "loam: Attention closure could not be admitted"
  if ← saveAttentionMemory? path items updatedClosures then
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

end Loam.AttentionPublisher

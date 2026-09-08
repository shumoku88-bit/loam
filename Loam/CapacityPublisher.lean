import Loam.ActualDate
import Loam.Application.CapacityInspection
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence
import Loam.WriterOwnership

namespace Loam.CapacityPublisher

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Capacity publisher

This module owns the surface-independent practical write boundary for one dated
JPY Capacity movement. It deliberately stores no grant / transfer / return kind:
those remain interpretations of the two typed endpoints.

Publication preserves the existing fail-closed ordering used by the practical
CLI: effective-coordinate evidence is published first, then Capacity authority.
If the second publication fails, the effective entry is inert because no
Capacity movement with that identity exists; later writes refuse incomplete
evidence and require explicit recovery rather than guessing the missing movement.
-/

structure Draft where
  effectiveOn : String
  source : CapacityCoordinate
  destination : CapacityCoordinate
  quanta : Int
  deriving Repr, DecidableEq

structure Receipt where
  movement : CapacityMovementId
  effectiveOn : String
  source : CapacityCoordinate
  destination : CapacityCoordinate
  quanta : Int
  deriving Repr, DecidableEq

/-- Stable presentation token for one minimal Capacity coordinate. -/
def coordinateToken : CapacityCoordinate → String
  | .unallocated => "unallocated"
  | .purpose purpose => purpose.token

/-- Parse the minimal shared endpoint vocabulary without introducing a Purpose registry. -/
def parseCoordinate? (token : String) : Option CapacityCoordinate :=
  if token = "unallocated" then
    some .unallocated
  else if Loam.Persistence.validToken token then
    some (.purpose ⟨token⟩)
  else
    none

/-- Pure shape checks shared by frontends; current entitlement is checked under ownership. -/
def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.effectiveOn then
    throw "Capacity effective date must be a real calendar date in YYYY-MM-DD form."
  if draft.quanta <= 0 then
    throw "Capacity movement amount must be a positive integer JPY quantity."
  if draft.source = draft.destination then
    throw "Capacity movement endpoints must differ."

private def loadCapacityMemoryOrEmpty?
    (path : System.FilePath) : IO (Option CapacityMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadCapacityMemory? path
  else
    return CapacityMemory.ofMovements? []

private def effectiveEvidenceComplete
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Bool :=
  memory.movements.all
      (fun movement => (effective.findByMovementId? movement.id).isSome) &&
    effective.entries.all
      (fun entry => (memory.findById? entry.movement).isSome)

private def effectiveMentionsMovement
    (effective : CapacityEffectiveMemory String)
    (id : CapacityMovementId) : Bool :=
  effective.entries.any fun entry => decide (entry.movement = id)

private def freshCapacityIdFrom
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Nat → Nat → Option CapacityMovementId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : CapacityMovementId := ⟨"capacity-" ++ toString index⟩
      match memory.findById? candidate with
      | none =>
          if effectiveMentionsMovement effective candidate then
            freshCapacityIdFrom memory effective (index + 1) fuel
          else
            some candidate
      | some _ => freshCapacityIdFrom memory effective (index + 1) fuel

private def freshCapacityId?
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Option CapacityMovementId :=
  freshCapacityIdFrom memory effective 1
    (memory.movements.length + effective.entries.length + 1)

private def movementForDraft?
    (id : CapacityMovementId) (draft : Draft) : Option CapacityMovement := do
  if draft.quanta <= 0 || draft.source = draft.destination then
    none
  else
    let changes : List (MovementChange CapacityCoordinate) :=
      [ { coordinate := draft.source, quantity := Quantity.ofQuanta (-draft.quanta) }
      , { coordinate := draft.destination, quantity := Quantity.ofQuanta draft.quanta } ]
    let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩ changes
    pure { id := id, movement := movement }

private def publishUnlocked
    (capacityFile : System.FilePath) (draft : Draft) : IO (Except String Receipt) := do
  match validateDraft draft with
  | .error message => return .error message
  | .ok _ => pure ()

  let effectiveFile := Loam.Persistence.capacityEffectivePathForMemory capacityFile
  let some memory ← loadCapacityMemoryOrEmpty? capacityFile
    | return .error "Malformed or unsupported Capacity authority."
  let some effective ← Loam.Persistence.loadCapacityEffectiveMemoryOrEmpty? effectiveFile
    | return .error "Malformed or unsupported Capacity effective evidence."

  if !effectiveEvidenceComplete memory effective then
    return .error
      "Capacity authority and effective evidence are incomplete; explicit recovery is required."

  if !canMoveCapacityFrom memory.movements draft.source ⟨"jpy"⟩ draft.quanta then
    return .error "Capacity source has insufficient current entitlement."

  let some movementId := freshCapacityId? memory effective
    | return .error "Could not generate a fresh Capacity movement identity."
  let some movement := movementForDraft? movementId draft
    | return .error "Capacity movement could not be represented as a balanced JPY movement."
  let some updated := memory.add? movement
    | return .error "Could not append Capacity movement authority."
  let some updatedEffective := CapacityEffectiveMemory.ofEntries?
      (effective.entries ++ [{ movement := movementId, effectiveOn := draft.effectiveOn }])
    | return .error "Could not append Capacity effective evidence."

  if !(← Loam.Persistence.saveCapacityEffectiveMemory? effectiveFile updatedEffective) then
    return .error "Capacity effective evidence could not be published."
  if !(← Loam.Persistence.saveCapacityMemory? capacityFile updated) then
    return .error
      "Capacity authority was not published; already-published effective evidence is inert and requires explicit recovery."

  return .ok {
    movement := movementId
    effectiveOn := draft.effectiveOn
    source := draft.source
    destination := draft.destination
    quanta := draft.quanta
  }

/--
Publish one dated JPY Capacity movement under Capacity writer ownership.

The shared boundary re-reads both retained streams under the lock, rejects
incomplete evidence, checks named-source entitlement, allocates fresh identity,
and publishes effective evidence before the Capacity authority image.
-/
def publish
    (capacityPath : String) (draft : Draft) : IO (Except String Receipt) :=
  let capacityFile := System.FilePath.mk capacityPath
  Loam.WriterOwnership.withOwnership capacityFile (publishUnlocked capacityFile draft)

end Loam.CapacityPublisher

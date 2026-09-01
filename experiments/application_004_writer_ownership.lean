import Loam.Persistence
import Std

namespace Loam.Experiments.Application004

set_option autoImplicit false

open Loam.Core

private def effect (key locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def event? (id key locus : String) (quanta : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩ [effect key locus quanta]

private def emptyMemory : EventMemory := {
  events := []
  idNodup := by simp
}

private def containsEvent (memory : EventMemory) (id : String) : Bool :=
  (EventMemory.findById? memory ⟨id⟩).isSome

private def loadMemory! (path : System.FilePath) : IO EventMemory := do
  match ← Loam.Persistence.loadEventMemory? path with
  | some memory => return memory
  | none => throw <| IO.userError "application-004: malformed event memory"

private def addEvent! (memory : EventMemory) (event : Event) : IO EventMemory := do
  match EventMemory.add? memory event with
  | some updated => return updated
  | none => throw <| IO.userError "application-004: duplicate event identity"

private def saveMemory! (path : System.FilePath) (memory : EventMemory) : IO Unit := do
  if !(← Loam.Persistence.saveEventMemory? path memory) then
    throw <| IO.userError "application-004: unrepresentable memory"

/--
Deterministically expose the current physical lost-update shape.

Both writers prepare from the same observed memory. Writer A publishes first;
writer B then publishes its stale whole-memory replacement. The individual file
replacement is atomic, but writer A's already-completed Event disappears.
-/
private def unsafeWitness (path : System.FilePath) (a b : Event) : IO Bool := do
  saveMemory! path emptyMemory
  let observedA ← loadMemory! path
  let observedB ← loadMemory! path
  let preparedA ← addEvent! observedA a
  let preparedB ← addEvent! observedB b
  saveMemory! path preparedA
  saveMemory! path preparedB
  let final ← loadMemory! path
  return !(containsEvent final a.id.token) && containsEvent final b.id.token

/--
Execute the same two updates with observation, preparation, and publication kept
inside one serial ownership scope.

This executable contrast deliberately does not choose the physical ownership
mechanism. A production scope might later be backed by an OS lock, atomic lock
file/directory creation, or another process-exclusion primitive. The experiment
retains only the requirement that no second writer can observe inside this
region before the first publication completes.
-/
private def ownedPublication (path : System.FilePath) (candidate : Event) : IO Unit := do
  let current ← loadMemory! path
  let updated ← addEvent! current candidate
  saveMemory! path updated

private def ownershipWitness (path : System.FilePath) (a b : Event) : IO Bool := do
  saveMemory! path emptyMemory
  ownedPublication path a
  ownedPublication path b
  let final ← loadMemory! path
  return containsEvent final a.id.token && containsEvent final b.id.token

private def cleanup (path : System.FilePath) : IO Unit := do
  if ← path.pathExists then
    IO.FS.removeFile path
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  if ← stage.pathExists then
    IO.FS.removeFile stage

def run : IO UInt32 := do
  let path := System.FilePath.mk "application-004-writer-ownership.loam"
  cleanup path
  try
    match event? "writer-a" "effect-a" "cash" (-100),
        event? "writer-b" "effect-b" "bank" (-200) with
    | some a, some b =>
        let lost ← unsafeWitness path a b
        IO.println ("unsafe_stale_replace_loses_completed_update=" ++ toString lost)
        let preserved ← ownershipWitness path a b
        IO.println ("serial_ownership_scope_preserves_both_updates=" ++ toString preserved)
        cleanup path
        if lost && preserved then
          return 0
        else
          return 1
    | _, _ =>
        cleanup path
        IO.eprintln "application-004: could not construct synthetic Events"
        return 2
  catch error =>
    cleanup path
    IO.eprintln error.toString
    return 2

end Loam.Experiments.Application004

def main : IO UInt32 :=
  Loam.Experiments.Application004.run

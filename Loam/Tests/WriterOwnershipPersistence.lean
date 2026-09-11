import Loam.Persistence.EventPersistence
import Loam.WriterOwnership
import Std

namespace Loam.Tests.WriterOwnershipPersistence

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
  | none => throw <| IO.userError "writer-ownership persistence regression: malformed event memory"

private def addEvent! (memory : EventMemory) (event : Event) : IO EventMemory := do
  match EventMemory.add? memory event with
  | some updated => return updated
  | none => throw <| IO.userError "writer-ownership persistence regression: duplicate event identity"

private def saveMemory! (path : System.FilePath) (memory : EventMemory) : IO Unit := do
  if !(← Loam.Persistence.saveEventMemory? path memory) then
    throw <| IO.userError "writer-ownership persistence regression: unrepresentable memory"

/--
Deterministically retain the physical stale-replacement counterexample that
originally motivated cross-process writer ownership.

Both logical writers prepare from the same observed EventMemory. A publishes
first and B then publishes its stale whole-memory replacement. Atomic file
replacement alone therefore does not prevent A's completed update from being
lost.
-/
private def staleReplacementWitness
    (path : System.FilePath) (a b : Event) : IO Bool := do
  saveMemory! path emptyMemory
  let observedA ← loadMemory! path
  let observedB ← loadMemory! path
  let preparedA ← addEvent! observedA a
  let preparedB ← addEvent! observedB b
  saveMemory! path preparedA
  saveMemory! path preparedB
  let final ← loadMemory! path
  return !(containsEvent final a.id.token) && containsEvent final b.id.token

private def ownedPublication
    (path : System.FilePath) (candidate : Event) : IO Unit :=
  Loam.WriterOwnership.withOwnership path do
    let current ← loadMemory! path
    let updated ← addEvent! current candidate
    saveMemory! path updated

/--
Run the same updates through the production ownership boundary. Each writer
re-observes persisted state after acquiring ownership, so the second publication
extends the first instead of replacing it with a stale snapshot.
-/
private def ownershipWitness
    (path : System.FilePath) (a b : Event) : IO Bool := do
  saveMemory! path emptyMemory
  ownedPublication path a
  ownedPublication path b
  let final ← loadMemory! path
  return containsEvent final a.id.token && containsEvent final b.id.token

private def cleanup (path : System.FilePath) : IO Unit := do
  for candidate in [
      path,
      System.FilePath.mk (path.toString ++ ".loam-stage"),
      System.FilePath.mk (path.toString ++ ".loam-writer-lock") ] do
    if ← candidate.pathExists then
      IO.FS.removeFile candidate

def run : IO UInt32 := do
  let path := System.FilePath.mk "writer-ownership-persistence-regression.loam"
  cleanup path
  try
    match event? "writer-a" "effect-a" "cash" (-100),
        event? "writer-b" "effect-b" "bank" (-200) with
    | some a, some b =>
        let lost ← staleReplacementWitness path a b
        IO.println ("stale_replace_loses_completed_update=" ++ toString lost)
        let preserved ← ownershipWitness path a b
        IO.println ("production_writer_ownership_preserves_both_updates=" ++ toString preserved)
        cleanup path
        if lost && preserved then
          return 0
        else
          return 1
    | _, _ =>
        cleanup path
        IO.eprintln "writer-ownership persistence regression: could not construct synthetic Events"
        return 2
  catch error =>
    cleanup path
    IO.eprintln error.toString
    return 2

end Loam.Tests.WriterOwnershipPersistence

def main : IO UInt32 :=
  Loam.Tests.WriterOwnershipPersistence.run
import Loam.ActualDate
import Loam.Core.ScheduledMemory
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled persistence

The first practical Scheduled stream retains stable scheduled identity, one ISO
scheduled day, one explicit Measure, and every signed Locus change. Lifecycle
evidence is intentionally absent from version 1 and will be earned by the first
practical complete/cancel/supersede operation.
-/

/-- Version marker for the first raw scheduled-memory format. -/
def scheduledMemoryHeader : String := "LOAM-SCHEDULED-MEMORY\t1"

private def encodeScheduledChangeRow?
    (change : MovementChange LocusId) : Option String :=
  if validToken change.coordinate.token then
    some ("CHANGE\t" ++ change.coordinate.token ++ "\t" ++ toString change.quantity.quanta)
  else
    none

private def decodeScheduledChangeRow?
    (row : String) : Option (MovementChange LocusId) :=
  match row.splitOn "\t" with
  | ["CHANGE", locusToken, quantaText] =>
      if validToken locusToken then
        match quantaText.toInt? with
        | some quanta =>
            some { coordinate := ⟨locusToken⟩, quantity := Quantity.ofQuanta quanta }
        | none => none
      else
        none
  | _ => none

private def encodeScheduledLines?
    (occurrence : ScheduledOccurrence String) : Option (List String) :=
  let idToken := occurrence.id.token
  let day := occurrence.scheduledOn
  let measureToken := occurrence.measure.token
  if validToken idToken && Loam.ActualDate.validIsoDate day && validToken measureToken then
    match occurrence.movement.changes.mapM encodeScheduledChangeRow? with
    | some rows =>
        some (("SCHEDULED\t" ++ idToken ++ "\t" ++ day ++ "\t" ++ measureToken) :: rows)
    | none => none
  else
    none

private def withoutTrailingEmpty (rows : List String) : List String :=
  match rows.reverse with
  | "" :: rest => rest.reverse
  | _ => rows

private def decodeScheduledChunk? (chunk : String) : Option (ScheduledOccurrence String) :=
  match chunk.splitOn "\n" with
  | header :: rawRows =>
      match header.splitOn "\t" with
      | [idToken, day, measureToken] =>
          if validToken idToken && Loam.ActualDate.validIsoDate day && validToken measureToken then
            match (withoutTrailingEmpty rawRows).mapM decodeScheduledChangeRow? with
            | some changes =>
                match BalancedMovement.ofChanges? ⟨measureToken⟩ changes with
                | some movement =>
                    some { id := ⟨idToken⟩, scheduledOn := day, movement := movement }
                | none => none
            | none => none
          else
            none
      | _ => none
  | _ => none

/-- Encode raw Scheduled memory without giving representation order temporal meaning. -/
def encodeScheduledMemory? (memory : ScheduledMemory String) : Option String :=
  match memory.occurrences.mapM encodeScheduledLines? with
  | some blocks =>
      some (String.intercalate "\n" (scheduledMemoryHeader :: blocks.flatten) ++ "\n")
  | none => none

/-- Decode version-1 Scheduled memory, rechecking dates, balance, and identity. -/
def decodeScheduledMemory? (input : String) : Option (ScheduledMemory String) :=
  if input = scheduledMemoryHeader ++ "\n" then
    ScheduledMemory.ofOccurrences? []
  else
    match (input.splitOn "\n").reverse with
    | "" :: _ =>
        match input.splitOn "\nSCHEDULED\t" with
        | header :: chunks =>
            if header = scheduledMemoryHeader then
              match chunks with
              | [] => none
              | _ =>
                  match chunks.mapM decodeScheduledChunk? with
                  | some occurrences => ScheduledMemory.ofOccurrences? occurrences
                  | none => none
            else
              none
        | _ => none
    | _ => none

private def scheduledMemoryStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one Scheduled stream by complete sibling staging plus rename. -/
def saveScheduledMemory?
    (path : System.FilePath)
    (memory : ScheduledMemory String) : IO Bool := do
  match encodeScheduledMemory? memory with
  | some text =>
      let stagePath := scheduledMemoryStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true
  | none => return false

/-- Read and fail-closed decode one Scheduled stream. -/
def loadScheduledMemory?
    (path : System.FilePath) : IO (Option (ScheduledMemory String)) := do
  let input ← IO.FS.readFile path
  return decodeScheduledMemory? input

end Loam.Persistence

import Loam.ActualDate
import Loam.Core.ScheduledRouting
import Loam.Persistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.WriterOwnership

namespace Loam.ScheduledRoutingCli

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

private def usage : String :=
  "LOAM Scheduled routing evidence\n\n" ++
  "Route one Scheduled locus to a managed Purpose from an effective date:\n" ++
  "  loamScheduledRouting ROUTING_FILE SCHEDULED_FILE YYYY-MM-DD SCHEDULED_ID LOCUS managed PURPOSE\n\n" ++
  "Mark one Scheduled locus explicitly unmanaged from an effective date:\n" ++
  "  loamScheduledRouting ROUTING_FILE SCHEDULED_FILE YYYY-MM-DD SCHEDULED_ID LOCUS unmanaged"

private def loadRoutingOrEmpty?
    (path : System.FilePath) : IO (Option ScheduledRoutingHistory) := do
  if ← path.pathExists then
    loadScheduledRoutingHistory? path
  else
    return RoutingHistory.ofEntries? []

private def occurrenceHasLocus
    (occurrence : ScheduledOccurrence String)
    (locus : LocusId) : Bool :=
  occurrence.movement.changes.any fun change => decide (change.coordinate = locus)

private def parsePurpose? (mode : String) (purpose? : Option String) : Option (Option PurposeId) :=
  match mode, purpose? with
  | "managed", some token =>
      if validToken token then some (some ⟨token⟩) else none
  | "unmanaged", none => some none
  | _, _ => none

private def recordUnlocked
    (routingPath scheduledPath effectiveOn scheduledToken locusToken mode : String)
    (purposeToken? : Option String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate effectiveOn then
    IO.eprintln "loam: Scheduled routing effective date must be a real calendar date in YYYY-MM-DD form"
    return 2
  else if !validToken scheduledToken || !validToken locusToken then
    IO.eprintln "loam: Scheduled identity and Locus must be nonempty single-line tokens"
    return 2
  else
    match parsePurpose? mode purposeToken? with
    | none =>
        IO.eprintln "loam: route must be 'managed PURPOSE' or 'unmanaged'"
        return 2
    | some purpose =>
        let scheduledFile := System.FilePath.mk scheduledPath
        if !(← scheduledFile.pathExists) then
          IO.eprintln ("loam: scheduled file not found: " ++ scheduledPath)
          return 2
        else
          match ← loadScheduledMemory? scheduledFile with
          | none =>
              IO.eprintln "loam: malformed or unsupported scheduled file"
              return 2
          | some scheduledMemory =>
              let scheduledId : ScheduledId := ⟨scheduledToken⟩
              let locus : LocusId := ⟨locusToken⟩
              match ScheduledMemory.findById? scheduledMemory scheduledId with
              | none =>
                  IO.eprintln "loam: scheduled identity not found"
                  return 1
              | some occurrence =>
                  if !occurrenceHasLocus occurrence locus then
                    IO.eprintln "loam: Scheduled occurrence does not contain that Locus"
                    return 1
                  else
                    let routingFile := System.FilePath.mk routingPath
                    match ← loadRoutingOrEmpty? routingFile with
                    | none =>
                        IO.eprintln "loam: malformed or unsupported Scheduled routing file"
                        return 2
                    | some history =>
                        let subject : ScheduledRoutingSubject := {
                          scheduled := scheduledId
                          locus := locus
                        }
                        let entry : RoutingEntry ScheduledRoutingSubject String := {
                          subject := subject
                          effectiveOn := effectiveOn
                          purpose := purpose
                        }
                        match RoutingHistory.ofEntries? (history.entries ++ [entry]) with
                        | none =>
                            IO.eprintln
                              "loam: Scheduled routing already has evidence at this subject/effective coordinate"
                            return 2
                        | some updated =>
                            if ← saveScheduledRoutingHistory? routingFile updated then
                              let routeText :=
                                match purpose with
                                | some p => "managed -> " ++ p.token
                                | none => "unmanaged"
                              IO.println
                                ("Recorded Scheduled route: " ++ scheduledToken ++ " / " ++
                                  locusToken ++ " @ " ++ effectiveOn ++ " = " ++ routeText ++ ".")
                              return 0
                            else
                              IO.eprintln "loam: Scheduled routing evidence could not be published"
                              return 2

/--
Record one dated Scheduled routing assertion under routing-file ownership.
The referenced Scheduled occurrence is read-only retained evidence; the route is
admitted only when its exact `ScheduledId × LocusId` subject exists.
-/
def record
    (routingPath scheduledPath effectiveOn scheduledToken locusToken mode : String)
    (purposeToken? : Option String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk routingPath)
    (recordUnlocked
      routingPath scheduledPath effectiveOn scheduledToken locusToken mode purposeToken?)

/-- Command dispatcher for practical Scheduled routing evidence. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [routingPath, scheduledPath, effectiveOn, scheduledToken, locus, "managed", purpose] =>
      record routingPath scheduledPath effectiveOn scheduledToken locus "managed" (some purpose)
  | [routingPath, scheduledPath, effectiveOn, scheduledToken, locus, "unmanaged"] =>
      record routingPath scheduledPath effectiveOn scheduledToken locus "unmanaged" none
  | _ => do
      IO.eprintln usage
      return 2

end Loam.ScheduledRoutingCli

def main (args : List String) : IO UInt32 :=
  Loam.ScheduledRoutingCli.run args

import Loam.ActualDate
import Loam.Core.RoutingEffective
import Loam.Persistence.ActualRoutingPersistence
import Loam.WriterOwnership

namespace Loam.ActualRoutingCli

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

private def usage : String :=
  "LOAM Actual routing evidence\n\n" ++
  "Add initial managed routing:\n" ++
  "  loamActualRouting initial ROUTING_FILE LOCUS managed PURPOSE\n\n" ++
  "Add initial explicitly-unmanaged routing:\n" ++
  "  loamActualRouting initial ROUTING_FILE LOCUS unmanaged\n\n" ++
  "Add dated managed routing:\n" ++
  "  loamActualRouting from ROUTING_FILE YYYY-MM-DD LOCUS managed PURPOSE\n\n" ++
  "Add dated explicitly-unmanaged routing:\n" ++
  "  loamActualRouting from ROUTING_FILE YYYY-MM-DD LOCUS unmanaged"

private def loadHistoryOrEmpty?
    (path : System.FilePath) : IO (Option ActualRoutingHistory) := do
  if ← path.pathExists then
    loadActualRoutingHistory? path
  else
    return RoutingHistory.ofEntries? []

private def validLocus (token : String) : Bool :=
  validToken token

private def parsePurpose? (mode : String) (purpose? : Option String) : Option (Option PurposeId) :=
  match mode, purpose? with
  | "managed", some token =>
      if validToken token then some (some ⟨token⟩) else none
  | "unmanaged", none => some none
  | _, _ => none

private def publishEntryUnlocked
    (routingPath : String)
    (entry : RoutingEntry LocusId (RoutingEffective String)) : IO UInt32 := do
  let file := System.FilePath.mk routingPath
  match ← loadHistoryOrEmpty? file with
  | none =>
      IO.eprintln "loam: malformed or unsupported Actual routing file"
      return 2
  | some history =>
      match RoutingHistory.ofEntries? (history.entries ++ [entry]) with
      | none =>
          IO.eprintln
            "loam: Actual routing already has evidence at this locus/effective coordinate"
          return 2
      | some updated =>
          if ← saveActualRoutingHistory? file updated then
            let routeText :=
              match entry.purpose with
              | some purpose => "managed -> " ++ purpose.token
              | none => "unmanaged"
            let effectiveText :=
              match entry.effectiveOn with
              | .initial => "initial"
              | .dated date => date
            IO.println
              ("Recorded Actual route: " ++ entry.subject.token ++ " @ " ++
                effectiveText ++ " = " ++ routeText ++ ".")
            return 0
          else
            IO.eprintln "loam: Actual routing evidence contains an unrepresentable token"
            return 2

private def publishEntry
    (routingPath : String)
    (entry : RoutingEntry LocusId (RoutingEffective String)) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk routingPath)
    (publishEntryUnlocked routingPath entry)

private def recordInitial
    (routingPath locus mode : String)
    (purpose? : Option String) : IO UInt32 := do
  if !validLocus locus then
    IO.eprintln "loam: routing locus must be a nonempty single-line token"
    return 2
  else
    match parsePurpose? mode purpose? with
    | none =>
        IO.eprintln "loam: route must be 'managed PURPOSE' or 'unmanaged'"
        return 2
    | some purpose =>
        publishEntry routingPath {
          subject := ⟨locus⟩
          effectiveOn := (RoutingEffective.initial : RoutingEffective String)
          purpose := purpose
        }

private def recordDated
    (routingPath date locus mode : String)
    (purpose? : Option String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate date then
    IO.eprintln "loam: routing effective date must be a real calendar date in YYYY-MM-DD form"
    return 2
  else if !validLocus locus then
    IO.eprintln "loam: routing locus must be a nonempty single-line token"
    return 2
  else
    match parsePurpose? mode purpose? with
    | none =>
        IO.eprintln "loam: route must be 'managed PURPOSE' or 'unmanaged'"
        return 2
    | some purpose =>
        publishEntry routingPath {
          subject := ⟨locus⟩
          effectiveOn := RoutingEffective.dated date
          purpose := purpose
        }

/-- Command dispatcher for retaining concrete Actual routing evidence. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | ["initial", routingPath, locus, "managed", purpose] =>
      recordInitial routingPath locus "managed" (some purpose)
  | ["initial", routingPath, locus, "unmanaged"] =>
      recordInitial routingPath locus "unmanaged" none
  | ["from", routingPath, date, locus, "managed", purpose] =>
      recordDated routingPath date locus "managed" (some purpose)
  | ["from", routingPath, date, locus, "unmanaged"] =>
      recordDated routingPath date locus "unmanaged" none
  | _ => do
      IO.eprintln usage
      return 2

end Loam.ActualRoutingCli

def main (args : List String) : IO UInt32 :=
  Loam.ActualRoutingCli.run args

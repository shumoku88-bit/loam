import Loam.ActualRoutingPublisher
import Loam.Core.RoutingEffective

namespace Loam.ActualRoutingCli

open Loam.Core

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

private def parseTarget?
    (mode : String)
    (purpose? : Option String) : Option Loam.ActualRoutingPublisher.Target :=
  match mode, purpose? with
  | "managed", some token =>
      if validToken token then some (.managed ⟨token⟩) else none
  | "unmanaged", none => some .unmanaged
  | _, _ => none

private def effectiveText : RoutingEffective String → String
  | .initial => "initial"
  | .dated date => date

private def targetText : Loam.ActualRoutingPublisher.Target → String
  | .managed purpose => "managed -> " ++ purpose.token
  | .unmanaged => "unmanaged"

private def publishDraft
    (routingPath : String)
    (draft : Loam.ActualRoutingPublisher.Draft) : IO UInt32 := do
  match ← Loam.ActualRoutingPublisher.publish routingPath draft with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok receipt =>
      IO.println
        ("Recorded Actual route: " ++ receipt.locus.token ++ " @ " ++
          effectiveText receipt.effectiveOn ++ " = " ++ targetText receipt.target ++ ".")
      return 0

private def recordInitial
    (routingPath locus mode : String)
    (purpose? : Option String) : IO UInt32 := do
  if !validToken locus then
    IO.eprintln "loam: routing locus must be a nonempty single-line token"
    return 2
  match parseTarget? mode purpose? with
  | none =>
      IO.eprintln "loam: route must be 'managed PURPOSE' or 'unmanaged'"
      return 2
  | some target =>
      publishDraft routingPath {
        locus := ⟨locus⟩
        effectiveOn := (RoutingEffective.initial : RoutingEffective String)
        target := target
      }

private def recordDated
    (routingPath date locus mode : String)
    (purpose? : Option String) : IO UInt32 := do
  if !validToken locus then
    IO.eprintln "loam: routing locus must be a nonempty single-line token"
    return 2
  match parseTarget? mode purpose? with
  | none =>
      IO.eprintln "loam: route must be 'managed PURPOSE' or 'unmanaged'"
      return 2
  | some target =>
      publishDraft routingPath {
        locus := ⟨locus⟩
        effectiveOn := RoutingEffective.dated date
        target := target
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
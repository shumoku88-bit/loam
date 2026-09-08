import Loam.Core.ScheduledRouting
import Loam.ScheduledRoutingPublisher

namespace Loam.ScheduledRoutingCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "LOAM Scheduled routing evidence\n\n" ++
  "Route one Scheduled locus to a managed Purpose from an effective date:\n" ++
  "  loamScheduledRouting ROUTING_FILE SCHEDULED_FILE YYYY-MM-DD SCHEDULED_ID LOCUS managed PURPOSE\n\n" ++
  "Mark one Scheduled locus explicitly unmanaged from an effective date:\n" ++
  "  loamScheduledRouting ROUTING_FILE SCHEDULED_FILE YYYY-MM-DD SCHEDULED_ID LOCUS unmanaged"

private def draftFromArgs?
    (effectiveOn scheduledToken locusToken mode : String)
    (purposeToken? : Option String) : Option Loam.ScheduledRoutingPublisher.Draft :=
  match mode, purposeToken? with
  | "managed", some purpose =>
      some {
        subject := { scheduled := ⟨scheduledToken⟩, locus := ⟨locusToken⟩ }
        effectiveOn := effectiveOn
        target := .managed ⟨purpose⟩
      }
  | "unmanaged", none =>
      some {
        subject := { scheduled := ⟨scheduledToken⟩, locus := ⟨locusToken⟩ }
        effectiveOn := effectiveOn
        target := .unmanaged
      }
  | _, _ => none

/--
Record one dated Scheduled routing assertion under routing-file ownership.
Delegates validation, lifecycle/routing re-reading, duplicate-coordinate refusal,
and publication to `Loam.ScheduledRoutingPublisher`.
-/
def record
    (routingPath scheduledPath effectiveOn scheduledToken locusToken mode : String)
    (purposeToken? : Option String) : IO UInt32 := do
  let some draft := draftFromArgs? effectiveOn scheduledToken locusToken mode purposeToken?
    | do
        IO.eprintln "loam: route must be 'managed PURPOSE' or 'unmanaged'"
        return 2
  match ← Loam.ScheduledRoutingPublisher.publish routingPath scheduledPath draft with
  | .ok receipt =>
      let routeText :=
        match receipt.target with
        | .managed p => "managed -> " ++ p.token
        | .unmanaged => "unmanaged"
      IO.println
        ("Recorded Scheduled route: " ++ receipt.subject.scheduled.token ++ " / " ++
          receipt.subject.locus.token ++ " @ " ++ receipt.effectiveOn ++ " = " ++ routeText ++ ".")
      return 0
  | .error message =>
      IO.eprintln message
      if message == "loam: scheduled identity not found" ||
         message == "loam: Scheduled occurrence does not contain that Locus" then
        return 1
      else
        return 2

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

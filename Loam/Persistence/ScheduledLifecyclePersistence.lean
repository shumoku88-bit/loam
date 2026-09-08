import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledReplacementPersistence
import Loam.Persistence.ScheduledRetirementPersistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Complete Scheduled lifecycle persistence

Observation 226 selected one physical commit image for the four fact families
that jointly determine the Scheduled lifecycle frontier:

- retained Scheduled occurrences;
- Scheduled -> Actual completion relations;
- explicit Scheduled retirements;
- Scheduled -> Scheduled replacement provenance.

The fact families remain semantically distinct and continue to use their existing
typed codecs. This module adds only a thin versioned outer frame so one complete
lifecycle image can be staged and atomically replace the authority path.

ScheduledRouting is deliberately not part of this image. It remains an
independent historical authority because no observed requirement couples routing
publication atomically to lifecycle publication.

There is no missing-as-empty entrance here. A configured lifecycle authority must
exist and decode completely. Empty relation families are represented explicitly
by their valid empty inner images.
-/

structure ScheduledLifecycleImage where
  scheduled : ScheduledMemory String
  completions : ScheduledCompletionMemory
  retirements : ScheduledRetirementMemory
  replacements : ScheduledReplacementMemory

/-- Version marker for the first complete Scheduled lifecycle image. -/
def scheduledLifecycleHeader : String := "LOAM-SCHEDULED-LIFECYCLE\t1"

private def sectionBegin (name : String) : String :=
  "BEGIN\t" ++ name ++ "\n"

private def sectionEnd (name : String) : String :=
  "END\t" ++ name ++ "\n"

private def encodeSection (name body : String) : String :=
  sectionBegin name ++ body ++ sectionEnd name

/--
Encode one complete lifecycle image while delegating each semantic family to its
already-qualified codec.
-/
def encodeScheduledLifecycleImage?
    (image : ScheduledLifecycleImage) : Option String := do
  let scheduled ← encodeScheduledMemory? image.scheduled
  let completions ← encodeScheduledCompletionMemory? image.completions
  let retirements ← encodeScheduledRetirementMemory? image.retirements
  let replacements ← encodeScheduledReplacementMemory? image.replacements
  pure <|
    scheduledLifecycleHeader ++ "\n" ++
    encodeSection "Scheduled" scheduled ++
    encodeSection "Completion" completions ++
    encodeSection "Retirement" retirements ++
    encodeSection "Replacement" replacements

private def takeSection?
    (name input : String) : Option (String × String) :=
  let beginMarker := sectionBegin name
  let endMarker := sectionEnd name
  match input.splitOn beginMarker with
  | [leading, afterBegin] =>
      if leading != "" then
        none
      else
        match afterBegin.splitOn endMarker with
        | [body, rest] => some (body, rest)
        | _ => none
  | _ => none

/--
Decode one complete lifecycle image. Every section is mandatory, including valid
empty relation sections; missing or duplicate sections fail closed.
-/
def decodeScheduledLifecycleImage?
    (input : String) : Option ScheduledLifecycleImage := do
  let headerPrefix := scheduledLifecycleHeader ++ "\n"
  if !input.startsWith headerPrefix then
    none
  else
    let rest0 := (input.drop headerPrefix.length).toString
    let (scheduledText, rest1) ← takeSection? "Scheduled" rest0
    let (completionText, rest2) ← takeSection? "Completion" rest1
    let (retirementText, rest3) ← takeSection? "Retirement" rest2
    let (replacementText, rest4) ← takeSection? "Replacement" rest3
    if rest4 != "" then
      none
    else
      let scheduled ← decodeScheduledMemory? scheduledText
      let completions ← decodeScheduledCompletionMemory? completionText
      let retirements ← decodeScheduledRetirementMemory? retirementText
      let replacements ← decodeScheduledReplacementMemory? replacementText
      some { scheduled, completions, retirements, replacements }

private def scheduledLifecycleStagePath
    (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one complete lifecycle image through sibling staging plus rename. -/
def saveScheduledLifecycleImage?
    (path : System.FilePath)
    (image : ScheduledLifecycleImage) : IO Bool := do
  match encodeScheduledLifecycleImage? image with
  | none => return false
  | some text =>
      let stagePath := scheduledLifecycleStagePath path
      IO.FS.writeFile stagePath text
      let staged ← IO.FS.readFile stagePath
      if staged != text then
        return false
      IO.FS.rename stagePath path
      return true

/--
Load exactly one configured Scheduled lifecycle authority. Missing storage is an
error at the caller's authority boundary, never an implicit empty lifecycle.
-/
def loadScheduledLifecycleImage?
    (path : System.FilePath) : IO (Option ScheduledLifecycleImage) := do
  if !(← path.pathExists) then
    return none
  let input ← IO.FS.readFile path
  return decodeScheduledLifecycleImage? input

end Loam.Persistence

import Loam.Core.ScheduledTerminal
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledReplacementPersistence
import Loam.Persistence.ScheduledRetirementPersistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Complete Scheduled lifecycle persistence

The authoritative runtime image now exposes two semantic components:

- retained Scheduled occurrences;
- one target-preserving Scheduled terminal relation.

The physical `LOAM-SCHEDULED-LIFECYCLE\t1` format is intentionally unchanged in
this cutover. Its historical Completion / Retirement / Replacement sections are
codec adapters only. Decoding joins them into one `ScheduledTerminalMemory`, and
encoding projects that memory back into the same three sections.

This separates semantic recompression from operational-data migration. A future
wire-format revision may replace the three physical sections with one Terminal
section, but that is not required to remove three independently threaded runtime
memories.

ScheduledRouting remains an independent historical authority. Missing lifecycle
authority still fails closed at callers, and complete-image staging plus one
same-filesystem replacement remains the physical publication boundary.
-/

structure ScheduledLifecycleImage where
  scheduled : ScheduledMemory String
  terminals : ScheduledTerminalMemory

/-- Existing v1 physical marker retained during semantic recompression. -/
def scheduledLifecycleHeader : String := "LOAM-SCHEDULED-LIFECYCLE\t1"

private def sectionBegin (name : String) : String :=
  "BEGIN\t" ++ name ++ "\n"

private def sectionEnd (name : String) : String :=
  "END\t" ++ name ++ "\n"

private def encodeSection (name body : String) : String :=
  sectionBegin name ++ body ++ sectionEnd name

private def terminalsFromLegacy?
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (replacements : ScheduledReplacementMemory) : Option ScheduledTerminalMemory :=
  let completionTerminals := completions.completions.map fun completion =>
    ({ source := completion.scheduled,
       target := some (.actual completion.actual) } : ScheduledTerminal)
  let retirementTerminals := retirements.retirements.map fun retirement =>
    ({ source := retirement.scheduled,
       target := none } : ScheduledTerminal)
  let replacementTerminals := replacements.replacements.map fun replacement =>
    ({ source := replacement.source,
       target := some (.scheduled replacement.replacement) } : ScheduledTerminal)
  ScheduledTerminalMemory.ofTerminals?
    (completionTerminals ++ retirementTerminals ++ replacementTerminals)

private def legacyCompletions?
    (terminals : ScheduledTerminalMemory) : Option ScheduledCompletionMemory :=
  let completions := terminals.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.actual actual) =>
        some ({ scheduled := terminal.source, actual := actual } : ScheduledCompletion)
    | _ => none
  ScheduledCompletionMemory.ofCompletions? completions

private def legacyRetirements?
    (terminals : ScheduledTerminalMemory) : Option ScheduledRetirementMemory :=
  let retirements := terminals.terminals.filterMap fun terminal =>
    match terminal.target with
    | none => some ({ scheduled := terminal.source } : ScheduledRetirement)
    | _ => none
  ScheduledRetirementMemory.ofRetirements? retirements

private def legacyReplacements?
    (terminals : ScheduledTerminalMemory) : Option ScheduledReplacementMemory :=
  let replacements := terminals.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.scheduled successor) =>
        some ({ source := terminal.source,
                replacement := successor } : ScheduledReplacement)
    | _ => none
  ScheduledReplacementMemory.ofReplacements? replacements

/--
Encode one semantic lifecycle image into the existing v1 physical envelope.
Terminal meaning is projected only at this codec boundary.
-/
def encodeScheduledLifecycleImage?
    (image : ScheduledLifecycleImage) : Option String := do
  let scheduled ← encodeScheduledMemory? image.scheduled
  let completionMemory ← legacyCompletions? image.terminals
  let retirementMemory ← legacyRetirements? image.terminals
  let replacementMemory ← legacyReplacements? image.terminals
  let completions ← encodeScheduledCompletionMemory? completionMemory
  let retirements ← encodeScheduledRetirementMemory? retirementMemory
  let replacements ← encodeScheduledReplacementMemory? replacementMemory
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
Decode the existing v1 physical sections into one semantic terminal memory.
Every physical section remains mandatory in v1, including valid empty sections.
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
      let terminals ← terminalsFromLegacy? completions retirements replacements
      some { scheduled, terminals }

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

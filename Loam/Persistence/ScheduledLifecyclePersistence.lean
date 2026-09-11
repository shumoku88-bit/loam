import Loam.Core.ScheduledTerminal
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Complete Scheduled lifecycle persistence

The authoritative runtime image exposes two semantic components:

- retained Scheduled occurrences;
- one target-preserving Scheduled terminal relation.

The physical `LOAM-SCHEDULED-LIFECYCLE\t1` format remains unchanged. Its
historical Completion / Retirement / Replacement sections are decoded directly
into `ScheduledTerminal` values and encoded directly from that terminal relation.
No dedicated runtime Completion / Retirement / Replacement memory is retained at
this boundary.

ScheduledRouting remains an independent historical authority. Missing lifecycle
authority still fails closed at callers, and complete-image staging plus one
same-filesystem replacement remains the physical publication boundary.
-/

structure ScheduledLifecycleImage where
  scheduled : ScheduledMemory String
  terminals : ScheduledTerminalMemory

/-- Existing v1 physical marker retained during semantic recompression. -/
def scheduledLifecycleHeader : String := "LOAM-SCHEDULED-LIFECYCLE\t1"

private def scheduledCompletionMemoryHeader : String :=
  "LOAM-SCHEDULED-COMPLETION-MEMORY\t1"

private def scheduledRetirementMemoryHeader : String :=
  "LOAM-SCHEDULED-RETIREMENT-MEMORY\t1"

private def scheduledReplacementMemoryHeader : String :=
  "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1"

private def sectionBegin (name : String) : String :=
  "BEGIN\t" ++ name ++ "\n"

private def sectionEnd (name : String) : String :=
  "END\t" ++ name ++ "\n"

private def encodeSection (name body : String) : String :=
  sectionBegin name ++ body ++ sectionEnd name

private def completionPairs
    (terminals : List ScheduledTerminal) : List (ScheduledId × EventId) :=
  terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.actual actual) => some (terminal.source, actual)
    | _ => none

private def retirementSources
    (terminals : List ScheduledTerminal) : List ScheduledId :=
  terminals.filterMap fun terminal =>
    match terminal.target with
    | none => some terminal.source
    | _ => none

private def replacementPairs
    (terminals : List ScheduledTerminal) : List (ScheduledId × ScheduledId) :=
  terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.scheduled replacement) => some (terminal.source, replacement)
    | _ => none

private def encodeCompletionMemory?
    (memory : ScheduledTerminalMemory) : Option String := do
  let rows ← (completionPairs memory.terminals).mapM fun pair =>
    let (scheduled, actual) := pair
    if validToken scheduled.token && validToken actual.token then
      some ("COMPLETION\t" ++ scheduled.token ++ "\t" ++ actual.token)
    else
      none
  pure (encodeVersionedRows scheduledCompletionMemoryHeader rows)

private def encodeRetirementMemory?
    (memory : ScheduledTerminalMemory) : Option String := do
  let rows ← (retirementSources memory.terminals).mapM fun scheduled =>
    if validToken scheduled.token then
      some ("RETIREMENT\t" ++ scheduled.token)
    else
      none
  pure (encodeVersionedRows scheduledRetirementMemoryHeader rows)

private def encodeReplacementMemory?
    (memory : ScheduledTerminalMemory) : Option String := do
  let rows ← (replacementPairs memory.terminals).mapM fun pair =>
    let (source, replacement) := pair
    if validToken source.token && validToken replacement.token then
      some ("REPLACEMENT\t" ++ source.token ++ "\t" ++ replacement.token)
    else
      none
  pure (encodeVersionedRows scheduledReplacementMemoryHeader rows)

private def decodeCompletionRow? (row : String) : Option ScheduledTerminal :=
  match row.splitOn "\t" with
  | ["COMPLETION", scheduledToken, actualToken] =>
      if validToken scheduledToken && validToken actualToken then
        some {
          source := ⟨scheduledToken⟩
          target := some (.actual ⟨actualToken⟩)
        }
      else
        none
  | _ => none

private def decodeRetirementRow? (row : String) : Option ScheduledTerminal :=
  match row.splitOn "\t" with
  | ["RETIREMENT", scheduledToken] =>
      if validToken scheduledToken then
        some { source := ⟨scheduledToken⟩, target := none }
      else
        none
  | _ => none

private def decodeReplacementRow? (row : String) : Option ScheduledTerminal :=
  match row.splitOn "\t" with
  | ["REPLACEMENT", sourceToken, replacementToken] =>
      if validToken sourceToken && validToken replacementToken then
        some {
          source := ⟨sourceToken⟩
          target := some (.scheduled ⟨replacementToken⟩)
        }
      else
        none
  | _ => none

private def decodeCompletionMemory? (input : String) : Option (List ScheduledTerminal) := do
  let rows ← decodeVersionedRows? scheduledCompletionMemoryHeader input
  rows.mapM decodeCompletionRow?

private def decodeRetirementMemory? (input : String) : Option (List ScheduledTerminal) := do
  let rows ← decodeVersionedRows? scheduledRetirementMemoryHeader input
  rows.mapM decodeRetirementRow?

private def decodeReplacementMemory? (input : String) : Option (List ScheduledTerminal) := do
  let rows ← decodeVersionedRows? scheduledReplacementMemoryHeader input
  rows.mapM decodeReplacementRow?

/--
Encode one semantic lifecycle image into the existing v1 physical envelope.
Terminal meaning is projected only at this codec boundary.
-/
def encodeScheduledLifecycleImage?
    (image : ScheduledLifecycleImage) : Option String := do
  let scheduled ← encodeScheduledMemory? image.scheduled
  let completions ← encodeCompletionMemory? image.terminals
  let retirements ← encodeRetirementMemory? image.terminals
  let replacements ← encodeReplacementMemory? image.terminals
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
The terminal constructor rechecks the same per-kind endpoint uniqueness that the
former dedicated inner memories enforced while preserving cross-kind conflict for
application-level fail-closed review.
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
      let completions ← decodeCompletionMemory? completionText
      let retirements ← decodeRetirementMemory? retirementText
      let replacements ← decodeReplacementMemory? replacementText
      let terminals ← ScheduledTerminalMemory.ofTerminals?
        (completions ++ retirements ++ replacements)
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

import Loam.Examples.PersonalSemanticMemory
import Loam.Persistence.SiblingStage
import Loam.Persistence.TextEscape
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Examples.PersonalSemanticMemoryPersistence

open Loam.Core
open Loam.Persistence
open Loam.Examples.PersonalSemanticMemory

set_option autoImplicit false

/-!
# Persistence experiment for PersonalSemanticMemory

This remains an example-layer experiment. It does not promote personal memory
semantics into Core.

Version 1 stores one complete image:

```text
LOAM-PERSONAL-SEMANTIC-MEMORY<TAB>1
EVENT<TAB><event-id>
DESCRIPTION<TAB><event-id><TAB><escaped-text>
CORRECTION<TAB><target-id><TAB><replacement-id>
```

Row order is representation only.

Only empty-effect Events are admitted by this persistence format. Description
rows must reference retained Events, and correction rows must have both endpoint
Events retained. No current/latest correction frontier is chosen here.
-/

def personalSemanticMemoryHeader : String :=
  "LOAM-PERSONAL-SEMANTIC-MEMORY\t1"

private def encodeEventRow? (event : Event) : Option String :=
  if !validToken event.id.token then
    none
  else
    match event.effects with
    | [] => some ("EVENT\t" ++ event.id.token)
    | _ => none

private def encodeDescriptionRow?
    (events : EventMemory)
    (entry : EventDescription) : Option String := do
  let _ ← EventMemory.findById? events entry.event
  if !validToken entry.event.token || !eventDescriptionTextAdmissible entry.text then
    none
  else
    some
      ("DESCRIPTION\t" ++ entry.event.token ++ "\t" ++ escapeText entry.text)

private def encodeCorrectionRow?
    (events : EventMemory)
    (correction : EventCorrection) : Option String := do
  let _ ← EventCorrection.project? events correction
  if !validToken correction.target.token ||
      !validToken correction.replacement.token then
    none
  else
    some
      ("CORRECTION\t" ++ correction.target.token ++ "\t" ++
        correction.replacement.token)

/--
Encode one complete personal semantic memory image.

The encoder fails closed on non-empty-effect Events, unrepresentable identities,
inadmissible description text, orphan descriptions, or correction endpoints
that are not retained in the same EventMemory.
-/
def encodePersonalSemanticMemory?
    (memory : PersonalSemanticMemory) : Option String := do
  let eventRows ← memory.events.events.mapM encodeEventRow?
  let descriptionRows ←
    memory.descriptions.entries.mapM (encodeDescriptionRow? memory.events)
  let correctionRows ←
    memory.corrections.corrections.mapM (encodeCorrectionRow? memory.events)
  pure
    (encodeVersionedRows personalSemanticMemoryHeader
      (eventRows ++ descriptionRows ++ correctionRows))

private def decodeEventRow? (row : String) : Option Event :=
  match row.splitOn "\t" with
  | ["EVENT", idToken] =>
      if !validToken idToken then
        none
      else
        some (textEvent ⟨idToken⟩)
  | _ => none

private def decodeDescriptionRow? (row : String) : Option EventDescription :=
  match row.splitOn "\t" with
  | ["DESCRIPTION", idToken, escapedText] =>
      if !validToken idToken then
        none
      else do
        let text ← unescapeText? escapedText
        if !eventDescriptionTextAdmissible text then
          none
        else
          some { event := ⟨idToken⟩, text := text }
  | _ => none

private def decodeCorrectionRow? (row : String) : Option EventCorrection :=
  match row.splitOn "\t" with
  | ["CORRECTION", targetToken, replacementToken] =>
      if !validToken targetToken || !validToken replacementToken then
        none
      else
        some
          { target := ⟨targetToken⟩
            replacement := ⟨replacementToken⟩ }
  | _ => none

private def decodeRows :
    List String →
      Option (List Event × List EventDescription × List EventCorrection)
  | [] => some ([], [], [])
  | row :: rest => do
      let (events, descriptions, corrections) ← decodeRows rest
      if row.startsWith "EVENT\t" then
        let event ← decodeEventRow? row
        pure (event :: events, descriptions, corrections)
      else if row.startsWith "DESCRIPTION\t" then
        let description ← decodeDescriptionRow? row
        pure (events, description :: descriptions, corrections)
      else if row.startsWith "CORRECTION\t" then
        let correction ← decodeCorrectionRow? row
        pure (events, descriptions, correction :: corrections)
      else
        none

private def descriptionsClosed?
    (events : EventMemory)
    (descriptions : EventDescriptionMemory) : Option Unit := do
  let _ ← descriptions.entries.mapM fun entry =>
    EventMemory.findById? events entry.event
  pure ()

private def correctionsClosed?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option Unit := do
  let _ ← corrections.corrections.mapM fun correction =>
    EventCorrection.project? events correction
  pure ()

/--
Decode one complete version-1 image and re-admit every retained uniqueness law.

Cross-memory references are checked after independent admission. No missing
Event, description, or correction endpoint is fabricated during recovery.
-/
def decodePersonalSemanticMemory?
    (input : String) : Option PersonalSemanticMemory := do
  let rows ← decodeVersionedRows? personalSemanticMemoryHeader input
  let (rawEvents, rawDescriptions, rawCorrections) ← decodeRows rows
  let events ← EventMemory.ofEvents? rawEvents
  let descriptions ← EventDescriptionMemory.ofEntries? rawDescriptions
  let corrections ← EventCorrectionMemory.ofCorrections? rawCorrections
  let _ ← descriptionsClosed? events descriptions
  let _ ← correctionsClosed? events corrections
  pure
    { events := events
      descriptions := descriptions
      corrections := corrections }

/--
Publish one complete memory image through the shared sibling staging path.

This is one physical replacement rather than three independently published
files, so Events, descriptions, and corrections cannot be split across separate
successful writes by this function.
-/
def savePersonalSemanticMemory?
    (path : System.FilePath)
    (memory : PersonalSemanticMemory) : IO Bool := do
  match encodePersonalSemanticMemory? memory with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read and fail-closed decode one configured personal semantic memory image. -/
def loadPersonalSemanticMemory?
    (path : System.FilePath) : IO (Option PersonalSemanticMemory) := do
  let input ← IO.FS.readFile path
  return decodePersonalSemanticMemory? input

namespace Example

open Loam.Examples.PersonalSemanticMemory.Example

/-- The retained two-note correction example is encodable as one complete image. -/
theorem correctedMemory_encodes :
    (encodePersonalSemanticMemory? correctedMemory).isSome = true := by
  native_decide

/-- A dangling description is refused rather than treated as a remembered fact. -/
def danglingDescriptionMemory : PersonalSemanticMemory :=
  { events := { events := [], idNodup := by simp }
    descriptions :=
      { entries :=
          [{ event := ⟨"memory:missing"⟩, text := "orphan" }]
        eventNodup := by simp }
    corrections := { corrections := [], idNodup := by simp } }

theorem dangling_description_is_rejected :
    encodePersonalSemanticMemory? danglingDescriptionMemory = none := by
  native_decide

/-- A correction whose replacement Event is missing is also refused. -/
def danglingCorrectionMemory : PersonalSemanticMemory :=
  { events :=
      { events := [textEvent note1]
        idNodup := by simp }
    descriptions :=
      { entries :=
          [{ event := note1, text := "editor preference: nvim" }]
        eventNodup := by simp }
    corrections :=
      { corrections := [noteCorrection]
        idNodup := by simp } }

theorem dangling_correction_is_rejected :
    encodePersonalSemanticMemory? danglingCorrectionMemory = none := by
  native_decide

end Example

end Loam.Examples.PersonalSemanticMemoryPersistence

import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Sha256
import Std

namespace Loam.Application030

open Loam.Core

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private structure FamilyRef where
  path : String
  sha256 : String
  deriving Repr, BEq

private inductive FamilyPresence where
  | absent
  | present (ref : FamilyRef)
  deriving Repr, BEq

private structure Manifest where
  events : FamilyPresence
  corrections : FamilyPresence
  validity : FamilyPresence
  descriptions : FamilyPresence
  deriving Repr, BEq

private structure GenerationSnapshot where
  root : System.FilePath
  manifest : Manifest

private structure TypedJournalWorld where
  events : EventMemory
  corrections : EventCorrectionMemory
  validity : ActualValidityHistory String
  descriptions : EventDescriptionMemory

private structure JournalEntry where
  event : Event
  validOn : String
  description : Option String

private def manifestHeader : String := "LOAM-APPLICATION030-MANIFEST\t1"

private def objectRelativePath (family digest : String) : String :=
  "objects/" ++ family ++ "/" ++ digest ++ ".loam"

private def encodePresenceRow (family : String) : FamilyPresence → String
  | .absent => family ++ "\tABSENT"
  | .present ref =>
      family ++ "\tPRESENT\t" ++ ref.path ++ "\t" ++ ref.sha256

private def encodeManifest (manifest : Manifest) : String :=
  String.intercalate "\n" [
    manifestHeader,
    encodePresenceRow "Event" manifest.events,
    encodePresenceRow "EventCorrection" manifest.corrections,
    encodePresenceRow "ActualValidity" manifest.validity,
    encodePresenceRow "EventDescription" manifest.descriptions
  ] ++ "\n"

private def decodePresenceRow? (expected row : String) : Option FamilyPresence :=
  match row.splitOn "\t" with
  | [family, "ABSENT"] =>
      if family == expected then some .absent else none
  | [family, "PRESENT", path, digest] =>
      if family == expected && digest.length == 64 &&
          path == objectRelativePath expected digest then
        some (.present { path := path, sha256 := digest })
      else
        none
  | _ => none

private def decodeManifest? (input : String) : Option Manifest :=
  match input.splitOn "\n" with
  | [header, eventRow, correctionRow, validityRow, descriptionRow, trailing] =>
      if header != manifestHeader || trailing != "" then
        none
      else do
        let events ← decodePresenceRow? "Event" eventRow
        let corrections ← decodePresenceRow? "EventCorrection" correctionRow
        let validity ← decodePresenceRow? "ActualValidity" validityRow
        let descriptions ← decodePresenceRow? "EventDescription" descriptionRow
        some { events, corrections, validity, descriptions }
  | _ => none

private def ensureObject
    (root : System.FilePath) (family text : String) : IO FamilyRef := do
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := objectRelativePath family digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  if ← target.pathExists then
    let existing ← IO.FS.readFile target
    unless existing == text do
      throw <| IO.userError s!"content-addressed object mismatch: {relative}"
  else
    let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
    IO.FS.writeFile stage text
    let staged ← IO.FS.readFile stage
    unless staged == text do
      throw <| IO.userError s!"staged object mismatch: {relative}"
    IO.FS.rename stage target
  pure { path := relative, sha256 := digest }

private def publishManifest (root : System.FilePath) (manifest : Manifest) : IO Unit := do
  IO.FS.createDirAll root
  let target := root / "CURRENT"
  let stage := root / "CURRENT.loam-stage"
  let text := encodeManifest manifest
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  let decoded ← requireSome (decodeManifest? staged)
    "staged CURRENT failed Application 030 manifest decoding"
  expect (decoded == manifest) "staged CURRENT changed family presence or references"
  IO.FS.rename stage target

private def readOptionalFile (path : System.FilePath) : IO (Option String) := do
  if ← path.pathExists then
    return some (← IO.FS.readFile path)
  else
    return none

private def presenceFromOptional
    (root : System.FilePath) (family : String) (text : Option String) : IO FamilyPresence := do
  match text with
  | none => pure .absent
  | some value => pure (.present (← ensureObject root family value))

private def captureCurrent (root : System.FilePath) : IO GenerationSnapshot := do
  let current := root / "CURRENT"
  if !(← current.pathExists) then
    throw <| IO.userError "CURRENT is missing"
  let manifest ← requireSome (decodeManifest? (← IO.FS.readFile current))
    "CURRENT is malformed or unsupported"
  pure { root, manifest }

private def readPresence
    (snapshot : GenerationSnapshot) (family : String) : FamilyPresence → IO (Option String)
  | .absent => pure none
  | .present ref => do
      let expectedPath := objectRelativePath family ref.sha256
      unless ref.path == expectedPath do
        throw <| IO.userError s!"selected {family} path is inconsistent with its digest"
      let target := snapshot.root / ref.path
      if !(← target.pathExists) then
        throw <| IO.userError s!"selected {family} object is missing"
      let text ← IO.FS.readFile target
      unless Loam.Sha256.hash text.toUTF8 == ref.sha256 do
        throw <| IO.userError s!"selected {family} object failed digest verification"
      pure (some text)

private def emptyCorrections : IO EventCorrectionMemory :=
  requireSome (EventCorrectionMemory.ofCorrections? [])
    "empty EventCorrection memory failed construction"

private def emptyValidity : IO (ActualValidityHistory String) :=
  requireSome
    (ActualValidityHistory.ofParts? ([] : List (ActualValidityFact String)) [])
    "empty ActualValidity history failed construction"

private def loadTypedJournalWorld (snapshot : GenerationSnapshot) : IO TypedJournalWorld := do
  let eventText? ← readPresence snapshot "Event" snapshot.manifest.events
  let eventText ← requireSome eventText? "Event is absent from selected generation"
  let events ← requireSome (Loam.Persistence.decodeEventMemory? eventText)
    "selected Event bytes failed production decoding"

  let correctionText? ←
    readPresence snapshot "EventCorrection" snapshot.manifest.corrections
  let corrections ←
    match correctionText? with
    | none => emptyCorrections
    | some text =>
        requireSome (Loam.Persistence.decodeEventCorrectionMemory? text)
          "selected EventCorrection bytes failed production decoding"

  let validityText? ← readPresence snapshot "ActualValidity" snapshot.manifest.validity
  let validity ←
    match validityText? with
    | none => emptyValidity
    | some text =>
        requireSome (Loam.Persistence.decodeActualValidityHistory? text)
          "selected ActualValidity bytes failed production decoding"

  let descriptionText? ←
    readPresence snapshot "EventDescription" snapshot.manifest.descriptions
  let descriptions ←
    match descriptionText? with
    | none => pure EventDescriptionMemory.empty
    | some text =>
        requireSome (Loam.Persistence.decodeEventDescriptionMemory? text)
          "selected EventDescription bytes failed production decoding"

  pure { events, corrections, validity, descriptions }

private def journalEntry?
    (validities : ActualValidityMemory String)
    (descriptions : EventDescriptionMemory)
    (event : Event) : Except String JournalEntry :=
  match ActualValidityMemory.findByEventId? validities event.id with
  | none =>
      Except.error
        ("effective Event is missing current Actual occurrence date: " ++ event.id.token)
  | some validOn =>
      Except.ok {
        event := event
        validOn := validOn
        description := EventDescriptionMemory.findText? descriptions event.id
      }

private def journalEntries?
    (validities : ActualValidityMemory String)
    (descriptions : EventDescriptionMemory) :
    List Event → Except String (List JournalEntry)
  | [] => Except.ok []
  | event :: rest => do
      let entry ← journalEntry? validities descriptions event
      let entries ← journalEntries? validities descriptions rest
      pure (entry :: entries)

private def entryOrdering (left right : JournalEntry) : Ordering :=
  match compare left.validOn right.validOn with
  | .eq => compare left.event.id.token right.event.id.token
  | other => other

private def insertEntry (entry : JournalEntry) : List JournalEntry → List JournalEntry
  | [] => [entry]
  | current :: rest =>
      match entryOrdering entry current with
      | .gt => current :: insertEntry entry rest
      | _ => entry :: current :: rest

private def sortEntries : List JournalEntry → List JournalEntry
  | [] => []
  | entry :: rest => insertEntry entry (sortEntries rest)

private def renderHeadingText (entry : JournalEntry) : String :=
  match entry.description with
  | some text =>
      if text.isEmpty then
        "[" ++ entry.event.id.token ++ "]"
      else
        Loam.Persistence.escapeText text
  | none => "[" ++ entry.event.id.token ++ "]"

private def renderEffect (effect : Effect) : String :=
  "    " ++ effect.locus.token ++ "    " ++
    toString effect.quantity.quanta ++ " " ++ effect.measure.token

private def renderEntry (entry : JournalEntry) : String :=
  let heading := entry.validOn ++ " * " ++ renderHeadingText entry
  String.intercalate "\n" (heading :: entry.event.effects.map renderEffect)

private def journalHeader : String :=
  "; GENERATED FROM LOAM CANONICAL DATA\n" ++
  "; DO NOT EDIT AS AUTHORITY\n" ++
  "; Full regeneration from the current Event correction frontier, ActualValidity, and EventDescription.\n" ++
  "; This file is a human-readable projection, not an import surface.\n"

private def renderJournal (entries : List JournalEntry) : String :=
  match entries with
  | [] => journalHeader ++ "\n; No effective Actual events.\n"
  | _ => journalHeader ++ "\n" ++ String.intercalate "\n\n" (entries.map renderEntry) ++ "\n"

private def deriveJournal? (world : TypedJournalWorld) : Except String String := do
  let frontier ←
    match Loam.Application.correctionFrontierMemory? world.events world.corrections with
    | some result => Except.ok result
    | none => Except.error "corrections do not justify one current Event frontier"
  let validities ←
    match Loam.Application.admittedActualValidityMemory? world.validity with
    | some result => Except.ok result
    | none =>
        Except.error
          "actual-validity corrections do not justify one current date per event"
  let entries ← journalEntries? validities world.descriptions frontier.events
  pure (renderJournal (sortEntries entries))

private def publishJournal (path : System.FilePath) (text : String) : IO Unit := do
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  IO.FS.rename stage path

private def runPublish
    (memoryPath correctionPath rootPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let correctionFile := System.FilePath.mk correctionPath
  let root := System.FilePath.mk rootPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile

  if !(← memoryFile.pathExists) then
    throw <| IO.userError "Event sidecar is missing"

  let eventText ← IO.FS.readFile memoryFile
  let _ ← requireSome (Loam.Persistence.decodeEventMemory? eventText)
    "Event sidecar failed production decoding before manifest publication"

  let correctionText? ← readOptionalFile correctionFile
  match correctionText? with
  | some text =>
      let _ ← requireSome (Loam.Persistence.decodeEventCorrectionMemory? text)
        "EventCorrection sidecar failed production decoding before manifest publication"
      pure ()
  | none => pure ()

  let validityText? ← readOptionalFile validityFile
  match validityText? with
  | some text =>
      let _ ← requireSome (Loam.Persistence.decodeActualValidityHistory? text)
        "ActualValidity sidecar failed production decoding before manifest publication"
      pure ()
  | none => pure ()

  let descriptionText? ← readOptionalFile descriptionFile
  match descriptionText? with
  | some text =>
      let _ ← requireSome (Loam.Persistence.decodeEventDescriptionMemory? text)
        "EventDescription sidecar failed production decoding before manifest publication"
      pure ()
  | none => pure ()

  let events : FamilyPresence := .present (← ensureObject root "Event" eventText)
  let corrections ← presenceFromOptional root "EventCorrection" correctionText?
  let validity ← presenceFromOptional root "ActualValidity" validityText?
  let descriptions ← presenceFromOptional root "EventDescription" descriptionText?
  publishManifest root { events, corrections, validity, descriptions }

  IO.println "Application 030 manifest JournalExport publication PASS"
  IO.println "authority_switches=1"
  IO.println "family_presence_entries=4"
  IO.println s!"event_correction_absent={if correctionText?.isNone then 1 else 0}"
  IO.println s!"event_description_absent={if descriptionText?.isNone then 1 else 0}"
  return 0

private def runExport (rootPath outputPath : String) : IO UInt32 := do
  let root := System.FilePath.mk rootPath
  let output := System.FilePath.mk outputPath
  let snapshot ← captureCurrent root
  let world ← loadTypedJournalWorld snapshot
  match deriveJournal? world with
  | .error message =>
      IO.eprintln ("loam: " ++ message)
      return 2
  | .ok text =>
      publishJournal output text
      IO.println "Application 030 manifest JournalExport PASS"
      IO.println "generation_captures=1"
      IO.println "typed_family_boundaries=4"
      IO.println "derived_output_publications=1"
      return 0

end Loam.Application030

private def usage : String :=
  "Usage: application_030_journal_manifest_parity (publish MEMORY_FILE CORRECTION_FILE MANIFEST_ROOT | export MANIFEST_ROOT OUTPUT_FILE)"

def main (args : List String) : IO UInt32 :=
  match args with
  | ["publish", memoryPath, correctionPath, rootPath] =>
      Loam.Application030.runPublish memoryPath correctionPath rootPath
  | ["export", rootPath, outputPath] =>
      Loam.Application030.runExport rootPath outputPath
  | _ => do
      IO.eprintln usage
      return 2

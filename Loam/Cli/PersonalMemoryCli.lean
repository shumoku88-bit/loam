import Loam.Examples.PersonalSemanticMemoryPersistence
import Std

namespace Loam.PersonalMemoryCli

open Loam.Core
open Loam.Examples.PersonalSemanticMemory
open Loam.Examples.PersonalSemanticMemoryPersistence

set_option autoImplicit false

private def usage : String :=
  "Usage:\n" ++
  "  loamMemory init MEMORY_FILE\n" ++
  "  loamMemory remember MEMORY_FILE EVENT_ID TEXT\n" ++
  "  loamMemory recall MEMORY_FILE EVENT_ID\n" ++
  "  loamMemory correct MEMORY_FILE TARGET_ID REPLACEMENT_ID TEXT\n" ++
  "\n" ++
  "TEXT should be passed as one shell argument when it contains spaces.\n" ++
  "Recall addresses one explicit EventId; correction edges do not imply latest/current authority."

private def loadMemory (path : System.FilePath) :
    IO (Except String PersonalSemanticMemory) := do
  try
    match ← loadPersonalSemanticMemory? path with
    | some memory => return .ok memory
    | none =>
        return .error
          ("loamMemory: refused invalid personal semantic memory image: " ++
            path.toString)
  catch e =>
    return .error
      ("loamMemory: could not read memory file " ++ path.toString ++
        ": " ++ toString e)

private def saveMemory
    (path : System.FilePath)
    (memory : PersonalSemanticMemory) : IO (Except String Unit) := do
  try
    if ← savePersonalSemanticMemory? path memory then
      return .ok ()
    else
      return .error
        ("loamMemory: memory is not persistable under the current v1 boundary: " ++
          path.toString)
  catch e =>
    return .error
      ("loamMemory: could not publish memory file " ++ path.toString ++
        ": " ++ toString e)

private def initMemory (pathText : String) : IO UInt32 := do
  let path := System.FilePath.mk pathText
  if ← path.pathExists then
    IO.eprintln ("loamMemory: init refused because file already exists: " ++ pathText)
    return 2
  match ← saveMemory path Loam.Examples.PersonalSemanticMemory.empty with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok _ =>
      IO.println pathText
      return 0

private def remember
    (pathText idToken text : String) : IO UInt32 := do
  let path := System.FilePath.mk pathText
  let memory ←
    match ← loadMemory path with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok memory => pure memory
  let updated ←
    match Loam.Examples.PersonalSemanticMemory.remember? memory ⟨idToken⟩ text with
    | none =>
        IO.eprintln
          ("loamMemory: remember refused; EventId may already exist or the fact " ++
            "cannot be admitted: " ++ idToken)
        return 2
    | some updated => pure updated
  match ← saveMemory path updated with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok _ =>
      IO.println idToken
      return 0

private def recall (pathText idToken : String) : IO UInt32 := do
  let path := System.FilePath.mk pathText
  let memory ←
    match ← loadMemory path with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok memory => pure memory
  match Loam.Examples.PersonalSemanticMemory.recall? memory ⟨idToken⟩ with
  | none =>
      IO.eprintln ("loamMemory: no retained fact for EventId: " ++ idToken)
      return 2
  | some text =>
      IO.println text
      return 0

private def correct
    (pathText targetToken replacementToken replacementText : String) :
    IO UInt32 := do
  let path := System.FilePath.mk pathText
  let memory ←
    match ← loadMemory path with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok memory => pure memory
  let updated ←
    match PersonalSemanticMemory.correct?
        memory ⟨targetToken⟩ ⟨replacementToken⟩ replacementText with
    | none =>
        IO.eprintln
          ("loamMemory: correction refused; target must exist and replacement " ++
            "EventId must be fresh")
        return 2
    | some updated => pure updated
  match ← saveMemory path updated with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok _ =>
      IO.println replacementToken
      return 0

def run (args : List String) : IO UInt32 := do
  match args with
  | ["init", memoryPath] =>
      initMemory memoryPath
  | ["remember", memoryPath, eventId, text] =>
      remember memoryPath eventId text
  | ["recall", memoryPath, eventId] =>
      recall memoryPath eventId
  | ["correct", memoryPath, targetId, replacementId, text] =>
      correct memoryPath targetId replacementId text
  | ["help"] =>
      IO.println usage
      return 0
  | _ =>
      IO.eprintln usage
      return 2

end Loam.PersonalMemoryCli

def main (args : List String) : IO UInt32 :=
  Loam.PersonalMemoryCli.run args

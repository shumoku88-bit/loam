import Loam.Examples.PersonalSemanticMemoryPersistence
import Std

namespace Loam.PersonalMemoryCli

open Loam.Core
open Loam.Examples.PersonalSemanticMemory
open Loam.Examples.PersonalSemanticMemoryPersistence

set_option autoImplicit false

private def usage : String :=
  "Usage:\n" ++
  "  loamMemory init [MEMORY_FILE]\n" ++
  "  loamMemory remember [MEMORY_FILE] EVENT_ID TEXT\n" ++
  "  loamMemory recall [MEMORY_FILE] EVENT_ID\n" ++
  "  loamMemory correct [MEMORY_FILE] TARGET_ID REPLACEMENT_ID TEXT\n" ++
  "\n" ++
  "When MEMORY_FILE is omitted, LOAM_MEMORY_FILE is used.\n" ++
  "An explicitly supplied MEMORY_FILE always takes precedence.\n" ++
  "TEXT should be passed as one shell argument when it contains spaces.\n" ++
  "Recall addresses one explicit EventId; correction edges do not imply latest/current authority."

private def resolveMemoryPath
    (path? : Option String) : IO (Except String System.FilePath) := do
  match path? with
  | some path =>
      if path.isEmpty then
        return .error "loamMemory: memory file path must not be empty"
      return .ok (System.FilePath.mk path)
  | none =>
      match ← IO.getEnv "LOAM_MEMORY_FILE" with
      | some path =>
          if path.isEmpty then
            return .error "loamMemory: LOAM_MEMORY_FILE must not be empty"
          return .ok (System.FilePath.mk path)
      | none =>
          return .error
            "loamMemory: no memory file supplied and LOAM_MEMORY_FILE is not set"

private def withMemoryPath
    (path? : Option String)
    (action : System.FilePath → IO UInt32) : IO UInt32 := do
  match ← resolveMemoryPath path? with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok path =>
      action path

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

private def initMemory (path : System.FilePath) : IO UInt32 := do
  let pathText := path.toString
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
    (path : System.FilePath)
    (idToken text : String) : IO UInt32 := do
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

private def recall
    (path : System.FilePath)
    (idToken : String) : IO UInt32 := do
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
    (path : System.FilePath)
    (targetToken replacementToken replacementText : String) :
    IO UInt32 := do
  let memory ←
    match ← loadMemory path with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok memory => pure memory
  let updated ←
    match Loam.Examples.PersonalSemanticMemory.correct?
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
  | ["init"] =>
      withMemoryPath none initMemory
  | ["init", memoryPath] =>
      withMemoryPath (some memoryPath) initMemory
  | ["remember", eventId, text] =>
      withMemoryPath none (fun path => remember path eventId text)
  | ["remember", memoryPath, eventId, text] =>
      withMemoryPath (some memoryPath) (fun path => remember path eventId text)
  | ["recall", eventId] =>
      withMemoryPath none (fun path => recall path eventId)
  | ["recall", memoryPath, eventId] =>
      withMemoryPath (some memoryPath) (fun path => recall path eventId)
  | ["correct", targetId, replacementId, text] =>
      withMemoryPath none (fun path => correct path targetId replacementId text)
  | ["correct", memoryPath, targetId, replacementId, text] =>
      withMemoryPath (some memoryPath)
        (fun path => correct path targetId replacementId text)
  | ["help"] =>
      IO.println usage
      return 0
  | _ =>
      IO.eprintln usage
      return 2

end Loam.PersonalMemoryCli

def main (args : List String) : IO UInt32 :=
  Loam.PersonalMemoryCli.run args

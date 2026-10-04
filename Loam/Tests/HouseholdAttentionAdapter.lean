import Loam.Authority.HouseholdAuthority
import Loam.HouseholdCommand
import Loam.Publisher.AttentionPublisher
import Loam.Persistence.AttentionPersistence

namespace Loam.Tests.HouseholdAttentionAdapter

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def cleanupDir (root : System.FilePath) : IO Unit := do
  if ← root.pathExists then
    IO.FS.removeDirAll root

private def attentionBodyFromHousehold
    (root : System.FilePath) : IO (Option String) := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "HouseholdImage did not load"
  pure (body? generation.image "Attention")

private def installFutureOnly (root : System.FilePath) : IO Unit := do
  let initial : Image := {
    sections := [
      { name := "Securities", body := "FUTURE\t1\nopaque\tunknown\n" }
    ]
  }
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? root initial)
    "future-only HouseholdImage installation failed"
  pure ()

def main (args : List String) : IO Unit := do
  let [rootPath] := args
    | throw (IO.userError "supply isolated Household Attention adapter directory")
  let root := System.FilePath.mk rootPath
  let legacyRoot := root / "legacy"
  let imageRoot := root / "image"
  let missingRoot := root / "missing"
  let commandRoot := root / "command"

  cleanupDir root
  IO.FS.createDirAll legacyRoot
  IO.FS.createDirAll imageRoot
  IO.FS.createDirAll missingRoot
  IO.FS.createDirAll commandRoot

  installFutureOnly imageRoot
  installFutureOnly missingRoot
  installFutureOnly commandRoot

  let first : Loam.AttentionPublisher.AddDraft := {
    context := "watch refund"
    due := .dueOn "2026-10-31"
  }
  let second : Loam.AttentionPublisher.AddDraft := {
    context := "future follow-up"
    due := .dueUndetermined
  }

  let legacyPath := legacyRoot / "attention.loam"

  let legacyFirst ← requireOk
    (← Loam.AttentionPublisher.add legacyPath.toString first)
    "legacy first Attention add failed"
  let imageFirst ← requireOk
    (← Loam.AttentionPublisher.addHousehold imageRoot first)
    "Household first Attention add failed"
  expect (legacyFirst == imageFirst)
    "first Attention identity differs across storage topology"
  let legacyFirstWire ← IO.FS.readFile legacyPath
  expect ((← attentionBodyFromHousehold imageRoot) == some legacyFirstWire)
    "first Attention canonical bytes differ across storage topology"

  let legacySecond ← requireOk
    (← Loam.AttentionPublisher.add legacyPath.toString second)
    "legacy second Attention add failed"
  let imageSecond ← requireOk
    (← Loam.AttentionPublisher.addHousehold imageRoot second)
    "Household second Attention add failed"
  expect (legacySecond == imageSecond)
    "second Attention identity differs across storage topology"
  let legacySecondWire ← IO.FS.readFile legacyPath
  expect ((← attentionBodyFromHousehold imageRoot) == some legacySecondWire)
    "second Attention canonical bytes differ across storage topology"

  let closeFirst : Loam.AttentionPublisher.CloseDraft := {
    attention := legacyFirst
    knownOn := "2026-10-04"
    kind := .resolved
  }
  let _ ← requireOk
    (← Loam.AttentionPublisher.close legacyPath.toString closeFirst)
    "legacy Attention close failed"
  let _ ← requireOk
    (← Loam.AttentionPublisher.closeHousehold imageRoot closeFirst)
    "Household Attention close failed"
  let legacyClosedWire ← IO.FS.readFile legacyPath
  expect ((← attentionBodyFromHousehold imageRoot) == some legacyClosedWire)
    "closed Attention canonical bytes differ across storage topology"

  match ← Loam.AttentionPublisher.close legacyPath.toString closeFirst with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "legacy duplicate close unexpectedly succeeded")
  match ← Loam.AttentionPublisher.closeHousehold imageRoot closeFirst with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "Household duplicate close unexpectedly succeeded")
  expect ((← attentionBodyFromHousehold imageRoot) == some legacyClosedWire)
    "failed duplicate close mutated Household Attention"

  let invalid : Loam.AttentionPublisher.AddDraft := {
    context := "invalid date"
    due := .dueOn "2026-02-30"
  }
  match ← Loam.AttentionPublisher.add legacyPath.toString invalid with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "legacy invalid Attention date unexpectedly succeeded")
  match ← Loam.AttentionPublisher.addHousehold imageRoot invalid with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "Household invalid Attention date unexpectedly succeeded")
  expect ((← attentionBodyFromHousehold imageRoot) == some legacyClosedWire)
    "invalid Attention add mutated Household Attention"

  let imageGeneration ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "Household generation disappeared"
  expect
    (body? imageGeneration.image "Securities" ==
      some "FUTURE\t1\nopaque\tunknown\n")
    "Attention adapter changed unknown future evidence"
  expect (!(← (imageRoot / "attention.loam").pathExists))
    "Household Attention adapter wrote the legacy Attention file"

  let missingClose : Loam.AttentionPublisher.CloseDraft := {
    attention := ⟨"attention-1"⟩
    knownOn := "2026-10-04"
    kind := .dropped
  }
  match ← Loam.AttentionPublisher.closeHousehold missingRoot missingClose with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "close against absent Household Attention unexpectedly succeeded")
  expect ((← attentionBodyFromHousehold missingRoot) == none)
    "failed close invented an empty Household Attention section"

  -- High-level authority selection has deliberately not moved yet.
  let commandBefore ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? commandRoot)
    "command isolation HouseholdImage did not load"
  let commandId ← requireOk
    (← Loam.HouseholdCommand.addAttention commandRoot first)
    "HouseholdCommand legacy Attention add failed"
  expect (commandId == ⟨"attention-1"⟩)
    "HouseholdCommand legacy Attention identity changed"
  expect (← (commandRoot / "attention.loam").pathExists)
    "HouseholdCommand no longer wrote legacy attention.loam before cutover"
  let commandAfter ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? commandRoot)
    "command isolation HouseholdImage disappeared"
  expect (commandAfter.wire == commandBefore.wire)
    "HouseholdCommand changed HouseholdImage before authority cutover"
  expect (body? commandAfter.image "Attention" == none)
    "HouseholdCommand silently selected HouseholdImage Attention before cutover"

  cleanupDir root
  IO.println
    "Household Attention adapter: legacy byte equivalence, bootstrap/missing semantics, unknown preservation, and pre-cutover command isolation passed."

end Loam.Tests.HouseholdAttentionAdapter

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdAttentionAdapter.main args

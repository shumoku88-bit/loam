import Loam.Authority.HouseholdAuthority
import Loam.HouseholdCommand
import Loam.Publisher.AttentionPublisher
import Loam.Review.AttentionReview
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


private def availabilitySummaries
    (availability : Loam.AttentionReview.Availability) : Option (List String) :=
  match availability with
  | .unavailable => none
  | .available snapshot =>
      some (snapshot.openItems.map Loam.AttentionReview.summary)

private def expectReviewEquivalent
    (legacyPath : System.FilePath)
    (imageRoot : System.FilePath)
    (message : String) : IO Unit := do
  let legacy ← requireOk
    (← Loam.AttentionReview.loadEvidence legacyPath)
    (message ++ " legacy")
  let household ← requireOk
    (← Loam.AttentionReview.loadHouseholdEvidence imageRoot)
    (message ++ " household")
  expect (availabilitySummaries legacy == availabilitySummaries household)
    message

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
  let emptyLegacyRoot := root / "empty-legacy"
  let emptyImageRoot := root / "empty-image"
  let commandRoot := root / "command"

  cleanupDir root
  IO.FS.createDirAll legacyRoot
  IO.FS.createDirAll imageRoot
  IO.FS.createDirAll missingRoot
  IO.FS.createDirAll emptyLegacyRoot
  IO.FS.createDirAll emptyImageRoot
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

  -- Missing legacy file and missing HouseholdImage section are both unavailable.
  let missingLegacyPath := missingRoot / "attention.loam"
  expectReviewEquivalent missingLegacyPath missingRoot
    "missing Attention availability differs across storage topology"

  -- Explicitly present empty Attention is available-empty, not unavailable.
  let emptyBody := Loam.Persistence.attentionMemoryHeader ++ "\n"
  let emptyLegacyPath := emptyLegacyRoot / "attention.loam"
  IO.FS.writeFile emptyLegacyPath emptyBody
  let emptyImage : Image := {
    sections := [
      { name := "Attention", body := emptyBody },
      { name := "Securities", body := "FUTURE\t1\nopaque\tunknown\n" }
    ]
  }
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? emptyImageRoot emptyImage)
    "explicit-empty HouseholdImage installation failed"
  expectReviewEquivalent emptyLegacyPath emptyImageRoot
    "present-empty Attention availability differs across storage topology"

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

  expectReviewEquivalent legacyPath imageRoot
    "first Attention Review differs across storage topology"

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

  expectReviewEquivalent legacyPath imageRoot
    "second Attention Review differs across storage topology"

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

  expectReviewEquivalent legacyPath imageRoot
    "closed Attention Review differs across storage topology"

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

  -- High-level household commands now select HouseholdImage Attention only.
  let commandBefore ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? commandRoot)
    "command cutover HouseholdImage did not load"
  let commandId ← requireOk
    (← Loam.HouseholdCommand.addAttention commandRoot first)
    "HouseholdCommand HouseholdImage Attention add failed"
  expect (commandId == ⟨"attention-1"⟩)
    "HouseholdCommand HouseholdImage Attention identity changed"
  expect (!(← (commandRoot / "attention.loam").pathExists))
    "HouseholdCommand wrote legacy attention.loam after cutover"
  let commandAfter ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? commandRoot)
    "command cutover HouseholdImage disappeared"
  expect (commandAfter.wire != commandBefore.wire)
    "HouseholdCommand did not publish a new HouseholdImage generation"
  let some commandBody := body? commandAfter.image "Attention"
    | throw (IO.userError "HouseholdCommand did not install HouseholdImage Attention")
  let some (commandItems, commandClosures) :=
      Loam.Persistence.decodeAttentionMemory? commandBody
    | throw (IO.userError "HouseholdCommand installed malformed HouseholdImage Attention")
  let some commandOpen := Loam.Application.openAttentions? commandItems commandClosures
    | throw (IO.userError "HouseholdCommand Attention closure evidence became invalid")
  expect (commandOpen.map Attention.id == [commandId])
    "HouseholdCommand HouseholdImage Attention answer changed after cutover"
  let commandPrevious ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath commandRoot)
  expect (commandPrevious == commandBefore.wire)
    "HouseholdCommand cutover did not retain previous HouseholdImage generation"

  cleanupDir root
  IO.println
    "Household Attention adapter: legacy equivalence, HouseholdCommand/TUI authority cutover, previous-generation retention, missing semantics, and unknown preservation passed."

end Loam.Tests.HouseholdAttentionAdapter

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdAttentionAdapter.main args

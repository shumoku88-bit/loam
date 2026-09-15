import Loam.AttentionReview
import Loam.HouseholdCommand

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def first : Attention String :=
  { id := ⟨"attention-1"⟩
    context := "renew household document"
    due := .dueOn "2026-09-10" }

private def second : Attention String :=
  { id := ⟨"attention-2"⟩
    context := "watch refund\twith note\n二行目"
    due := .noDueDate }

private def third : Attention String :=
  { id := ⟨"attention-3"⟩
    context := "clarify future household matter"
    due := .dueUndetermined }

private def resolvedFirst : AttentionClosure String :=
  { attention := first.id
    knownOn := "2026-09-07"
    kind := .resolved }

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated Attention test directory")
  let root := System.FilePath.mk rootPath
  IO.FS.createDirAll root

  let items ← requireSome
    (AttentionMemory.ofItems? [first, second, third])
    "valid Attention items were rejected"
  let closures ← requireSome
    (AttentionClosureMemory.ofClosures? [resolvedFirst])
    "valid Attention closure was rejected"

  let some encoded := Loam.Persistence.encodeAttentionMemory? items closures
    | throw (IO.userError "valid Attention evidence was not encodable")
  let some (decodedItems, decodedClosures) := Loam.Persistence.decodeAttentionMemory? encoded
    | throw (IO.userError "encoded Attention evidence did not decode")
  expect (decodedItems.items == items.items) "Attention item round-trip changed evidence"
  expect (decodedClosures.closures == closures.closures) "Attention closure round-trip changed evidence"

  let path := root / "attention.loam"
  expect (← Loam.Persistence.saveAttentionMemory? path items closures)
    "Attention stream could not be published"
  match ← Loam.AttentionReview.loadEvidence path with
  | .error message => throw (IO.userError message)
  | .ok .unavailable => throw (IO.userError "configured Attention stream became unavailable")
  | .ok (.available snapshot) =>
      expect (snapshot.openItems.map Attention.id == [second.id, third.id])
        "shared open Attention projection did not exclude explicit closure"
      let some reloadedSecond := snapshot.openItems.find? (fun item => item.id == second.id)
        | throw (IO.userError "open Attention lost second item")
      expect (reloadedSecond.context == second.context)
        "Attention escaped context did not round-trip"

  match ← Loam.AttentionReview.loadEvidence (root / "missing.loam") with
  | .ok .unavailable => pure ()
  | _ => throw (IO.userError "missing Attention source collapsed into configured evidence")

  let emptyItems ← requireSome (AttentionMemory.ofItems? []) "empty Attention memory was rejected"
  let emptyClosures ← requireSome
    (AttentionClosureMemory.ofClosures? []) "empty Attention closure memory was rejected"
  let emptyPath := root / "attention-empty.loam"
  expect (← Loam.Persistence.saveAttentionMemory? emptyPath emptyItems emptyClosures)
    "explicit empty Attention stream could not be published"
  match ← Loam.AttentionReview.loadEvidence emptyPath with
  | .ok (.available snapshot) =>
      expect snapshot.openItems.isEmpty "explicit empty Attention stream was not empty"
  | _ => throw (IO.userError "explicit empty Attention stream became unavailable or malformed")

  let danglingClosure : AttentionClosure String :=
    { attention := ⟨"attention-missing"⟩
      knownOn := "2026-09-07"
      kind := .dropped }
  let danglingClosures ← requireSome
    (AttentionClosureMemory.ofClosures? [danglingClosure])
    "dangling closure specimen was rejected before review"
  let danglingPath := root / "attention-dangling.loam"
  expect (← Loam.Persistence.saveAttentionMemory? danglingPath items danglingClosures)
    "dangling closure specimen could not reach read boundary"
  match ← Loam.AttentionReview.loadEvidence danglingPath with
  | .error _ => pure ()
  | _ => throw (IO.userError "dangling Attention closure was silently accepted")

  expect (Loam.AttentionReview.dueLabel (.dueOn "2026-09-10") == "due 2026-09-10")
    "due-on presentation changed meaning"
  expect (Loam.AttentionReview.dueLabel (.noDueDate : AttentionDue String) == "no due date")
    "NoDueDate presentation collapsed"
  expect (Loam.AttentionReview.dueLabel (.dueUndetermined : AttentionDue String) == "due unknown")
    "DueUndetermined presentation collapsed"

  -- Production writer qualification starts with no Attention file at all.
  let managedRoot := root / "managed"
  IO.FS.createDirAll managedRoot
  let managedPath := managedRoot / "attention.loam"
  expect (!(← managedPath.pathExists)) "managed Attention specimen unexpectedly existed before bootstrap"

  let firstId ←
    match ← Loam.HouseholdCommand.addAttention managedRoot {
      context := "cancel streaming subscription"
      due := .dueOn "2026-10-01"
    } with
    | .ok id => pure id
    | .error message => throw (IO.userError message)
  expect (firstId.token == "attention-1") "first Attention identity was not allocated deterministically"
  expect (← managedPath.pathExists) "first Attention publication did not bootstrap canonical storage"

  let secondId ←
    match ← Loam.HouseholdCommand.addAttention managedRoot {
      context := "watch card refund"
      due := .dueUndetermined
    } with
    | .ok id => pure id
    | .error message => throw (IO.userError message)
  expect (secondId.token == "attention-2") "second Attention identity did not advance"

  match ← Loam.HouseholdCommand.addAttention managedRoot {
      context := "invalid due specimen"
      due := .dueOn "2026-02-30"
    } with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "invalid Attention due date was published")

  match ← Loam.AttentionReview.loadEvidence managedPath with
  | .ok (.available snapshot) =>
      expect (snapshot.openItems.map Attention.id == [firstId, secondId])
        "fresh Attention publications did not appear in canonical open order"
  | .error message => throw (IO.userError message)
  | .ok .unavailable => throw (IO.userError "published Attention authority became unavailable")

  match ← Loam.HouseholdCommand.closeAttention managedRoot {
      attention := firstId
      knownOn := "2026-09-16"
      kind := .resolved
    } with
  | .ok () => pure ()
  | .error message => throw (IO.userError message)

  match ← Loam.HouseholdCommand.closeAttention managedRoot {
      attention := firstId
      knownOn := "2026-09-16"
      kind := .dropped
    } with
  | .error _ => pure ()
  | .ok () => throw (IO.userError "already-closed Attention accepted a second closure")

  match ← Loam.HouseholdCommand.closeAttention managedRoot {
      attention := ⟨"attention-999"⟩
      knownOn := "2026-09-16"
      kind := .resolved
    } with
  | .error _ => pure ()
  | .ok () => throw (IO.userError "unknown Attention accepted closure evidence")

  match ← Loam.AttentionReview.loadEvidence managedPath with
  | .ok (.available snapshot) =>
      expect (snapshot.openItems.map Attention.id == [secondId])
        "resolved Attention remained in the current-open projection"
  | .error message => throw (IO.userError message)
  | .ok .unavailable => throw (IO.userError "managed Attention authority disappeared")

  match ← Loam.HouseholdCommand.closeAttention managedRoot {
      attention := secondId
      knownOn := "2026-09-16"
      kind := .dropped
    } with
  | .ok () => pure ()
  | .error message => throw (IO.userError message)

  match ← Loam.AttentionReview.loadEvidence managedPath with
  | .ok (.available snapshot) =>
      expect snapshot.openItems.isEmpty "dropped Attention remained current-open"
  | .error message => throw (IO.userError message)
  | .ok .unavailable => throw (IO.userError "managed Attention authority disappeared after drop")

  IO.println "Attention persistence/review/publication: bootstrap, due meaning, add, resolve, drop and refusal passed."

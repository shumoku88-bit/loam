import Loam.AttentionReview

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

  let danglingClosures ← requireSome
    (AttentionClosureMemory.ofClosures? [{ attention := ⟨"attention-missing"⟩,
      knownOn := "2026-09-07", kind := .dropped }])
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

  IO.println "Attention persistence/review: unavailable, empty, due meaning and fail-closed lifecycle passed."

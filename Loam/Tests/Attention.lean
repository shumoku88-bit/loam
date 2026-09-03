import Loam.Application.AttentionInspection

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def first : Attention String :=
  { id := ⟨"attention-1"⟩
    context := "renew household document"
    due := .dueOn "2026-09-10" }

private def second : Attention String :=
  { id := ⟨"attention-2"⟩
    context := "watch refund"
    due := .noDueDate }

private def third : Attention String :=
  { id := ⟨"attention-3"⟩
    context := "clarify future household matter"
    due := .dueUndetermined }

private def resolvedFirst : AttentionClosure String :=
  { attention := first.id
    knownOn := "2026-09-04"
    kind := .resolved }

private def droppedSecond : AttentionClosure String :=
  { attention := second.id
    knownOn := "2026-09-05"
    kind := .dropped }

def main : IO Unit := do
  expect (decide (second.due ≠ third.due))
    "NoDueDate collapsed into DueUndetermined"

  let items ← requireSome
    (AttentionMemory.ofItems? [first, second, third])
    "distinct Attention identities were rejected"

  expect
    (AttentionMemory.ofItems? [first, { first with context := "duplicate" }]).isNone
    "duplicate Attention identity was admitted"

  let noClosures ← requireSome
    (AttentionClosureMemory.ofClosures? ([] : List (AttentionClosure String)))
    "empty closure memory was rejected"

  let initiallyOpen ← requireSome
    (openAttentions? items noClosures)
    "valid open Attention view was refused"
  expect (initiallyOpen.length == 3)
    "Attention without closure evidence was not open"

  let closures ← requireSome
    (AttentionClosureMemory.ofClosures? [resolvedFirst, droppedSecond])
    "distinct Attention closures were rejected"

  expect
    (AttentionClosureMemory.ofClosures?
      [resolvedFirst, { resolvedFirst with kind := .dropped }]).isNone
    "two closure dispositions for one Attention were admitted"

  let firstView ← requireSome
    (inspectAttention? items closures first.id)
    "resolved Attention could not be inspected"
  match firstView.lifecycle with
  | .resolved knownOn =>
      expect (knownOn == "2026-09-04")
        "resolved closure lost its learned coordinate"
  | _ => throw <| IO.userError "resolved Attention did not project as resolved"

  let secondView ← requireSome
    (inspectAttention? items closures second.id)
    "dropped Attention could not be inspected"
  match secondView.lifecycle with
  | .dropped knownOn =>
      expect (knownOn == "2026-09-05")
        "dropped closure lost its learned coordinate"
  | _ => throw <| IO.userError "dropped Attention did not project as dropped"

  let thirdView ← requireSome
    (inspectAttention? items closures third.id)
    "open Attention could not be inspected"
  match thirdView.lifecycle with
  | .open => pure ()
  | _ => throw <| IO.userError "Attention without closure projected as closed"

  let stillOpen ← requireSome
    (openAttentions? items closures)
    "current open Attention projection was refused"
  expect (stillOpen.map Attention.id == [third.id])
    "current open Attention projection did not exclude explicit closures"

  let relationToEvent : AttentionRelation String :=
    { source := third.id
      target := .event ⟨"event-1"⟩
      knownOn := "2026-09-06" }
  let continuation : AttentionRelation String :=
    { source := third.id
      target := .attention second.id
      knownOn := "2026-09-07" }
  expect (decide (relationToEvent.source = third.id))
    "Attention-to-Event provenance lost its source identity"
  expect (decide (continuation.source = third.id))
    "Attention continuation provenance lost its source identity"

  let danglingClosure : AttentionClosure String :=
    { attention := ⟨"attention-missing"⟩
      knownOn := "2026-09-08"
      kind := .resolved }
  let dangling ← requireSome
    (AttentionClosureMemory.ofClosures? [danglingClosure])
    "dangling closure specimen was rejected before referential inspection"
  expect (openAttentions? items dangling).isNone
    "dangling Attention closure was silently ignored"

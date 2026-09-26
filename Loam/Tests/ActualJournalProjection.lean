import Loam.ActualJournalProjection
import Loam.Persistence.NormalizedActualAdmission

namespace Loam.Tests.ActualJournalProjection

open Loam.Core

set_option autoImplicit false

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def emptyEvent (id : String) : Event :=
  {
    id := ⟨id⟩
    effects := []
    keyNodup := by simp
  }

private def eventIds (entries : List Loam.ActualJournalProjection.Entry) : List String :=
  entries.map fun entry => entry.event.id.token

private def validities (entries : List Loam.ActualJournalProjection.Entry) : List String :=
  entries.map fun entry => entry.validOn

def main : IO Unit := do
  let eventB := emptyEvent "event-b"
  let eventC := emptyEvent "event-c"
  let eventA := emptyEvent "event-a"

  let events ← requireSome
    (EventMemory.ofEvents? [eventB, eventC, eventA])
    "event memory admission failed"

  let validity ← requireSome
    (ActualValidityHistory.ofParts? [
      .base eventB.id "2026-09-02",
      .base eventC.id "2026-09-01",
      .base eventA.id "2026-09-02"
    ] [])
    "validity history admission failed"

  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := events
      validity := validity
  }

  let image ← requireSome
    (Loam.Persistence.admitActualImage? evidence)
    "Actual image admission failed"

  let entries ←
    match Loam.ActualJournalProjection.fromImage? image with
    | .ok entries => pure entries
    | .error message => throw <| IO.userError message

  unless eventIds entries == ["event-c", "event-a", "event-b"] do
    throw <| IO.userError
      s!"unexpected journal EventId order: {repr (eventIds entries)}"

  unless validities entries == ["2026-09-01", "2026-09-02", "2026-09-02"] do
    throw <| IO.userError
      s!"unexpected journal date order: {repr (validities entries)}"

  IO.println "Actual journal merge-sort ordering regression passed."

end Loam.Tests.ActualJournalProjection

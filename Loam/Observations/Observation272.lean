import Loam.ScheduledGeneration
import Loam.ScheduledReview

namespace Loam.Observation272

open Loam.Core

set_option autoImplicit false

/-!
# Observation 272 — Scheduled generation existing-plan pressure

Scheduled generation generates explicit construction candidates from one
selected Scheduled occurrence and one construction-only cadence. Post-completion
continuation separately reloads current-open Scheduled evidence and surfaces
later plans with the same positive Locus set.

This observation asks whether both facts can hold at once:

1. generation proposes a later explicit due date; and
2. the admitted Scheduled world already contains a later current-open plan with
   the same positive Locus set at that date.

The observation does not call such plans duplicates or assert series identity.
It only fixes the residual awareness pressure mechanically.
-/

private def limit : Loam.ScheduledGeneration.FillLimit := {
  endExclusive := "2026-10-15"
}

private def overlapWitness : Bool :=
  match BalancedMovement.ofChanges? ⟨"jpy"⟩
      [ { coordinate := ⟨"smbc"⟩, quantity := Quantity.ofQuanta (-3000) }
      , { coordinate := ⟨"gpt-plus"⟩, quantity := Quantity.ofQuanta 3000 } ] with
  | none => false
  | some movement =>
      let source : ScheduledOccurrence String := {
        id := ⟨"o272-source"⟩
        scheduledOn := "2026-09-08"
        movement := movement
      }
      let existing : ScheduledOccurrence String := {
        id := ⟨"o272-existing"⟩
        scheduledOn := "2026-10-08"
        movement := movement
      }
      match ScheduledMemory.ofOccurrences? [source, existing],
          ScheduledTerminalMemory.ofTerminals? [],
          EventMemory.ofEvents? [] with
      | some scheduled, some terminals, some events =>
          let snapshot : Loam.ScheduledReview.EvidenceSnapshot := {
            scheduled := scheduled
            terminals := terminals
            events := events
          }
          match
              Loam.ScheduledGeneration.plan limit "2026-09-18" {
                anchor := source.scheduledOn
                cadence := .monthly
              },
              Loam.ScheduledReview.laterSimilarOpenRecords snapshot source with
          | .ok generated, .ok similar =>
              generated.contains existing.scheduledOn &&
                similar.any (fun row => decide (row.id = existing.id))
          | _, _ => false
      | _, _, _ => false

/--
A monthly generation action can propose an explicit date that is already
represented by a later current-open same-positive-Locus Scheduled occurrence.

This proves only an awareness overlap. Same date + same positive Locus does not
establish recurrence, series identity, contract identity, or semantic equality.
-/
theorem generated_slot_can_already_have_similar_open_plan :
    overlapWitness = true := by
  native_decide

end Loam.Observation272

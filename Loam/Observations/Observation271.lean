import Loam.ActualEvidence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Persistence.NormalizedActualPersistence

namespace Loam.Observation271

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 271 — admitted Actual read image

Normalized Actual decoding already admits the correction frontier and current
validity view before canonical evidence is exposed to production readers.

This observation asks whether those two repeatedly reused derived views can be
carried once by one read image without changing their meaning.

The image is deliberately narrow. It does not carry Relation, Discharge,
Merchant, Reversal, description, or persistence proofs. Those invariants are not
currently recomputed broadly by downstream readers.
-/

/-- Observation-local read image carrying the two repeatedly reused Actual views. -/
structure ReadImage where
  evidence : ActualEvidence
  admitted :
    (Loam.Persistence.admitActualEvidence? evidence).isSome = true
  currentEvents : EventMemory
  currentValidities : ActualValidityMemory String
  currentEvents_admitted :
    correctionFrontierMemory? evidence.events evidence.corrections = some currentEvents
  currentValidities_admitted :
    admittedActualValidityMemory? evidence.validity = some currentValidities

namespace ReadImage

/-- Admit the two shared read projections once from one Actual evidence value. -/
def ofEvidence? (evidence : ActualEvidence) : Option ReadImage :=
  match hAdmitted : Loam.Persistence.admitActualEvidence? evidence with
  | none => none
  | some _ =>
      match hFrontier : correctionFrontierMemory? evidence.events evidence.corrections with
      | none => none
      | some currentEvents =>
          match hValidity : admittedActualValidityMemory? evidence.validity with
          | none => none
          | some currentValidities =>
              some {
                evidence := evidence
                admitted := by simp [hAdmitted]
                currentEvents := currentEvents
                currentValidities := currentValidities
                currentEvents_admitted := hFrontier
                currentValidities_admitted := hValidity
              }

/--
Any quantity projected from the carried current Event memory is exactly the
existing correction-frontier quantity answer.
-/
theorem quantity_eq_raw
    (image : ReadImage)
    (locus : LocusId)
    (measure : MeasureId) :
    quantityAtCorrectionFrontier?
        image.evidence.events image.evidence.corrections locus measure =
      some (EventMemory.quantityAtRecorded image.currentEvents locus measure) := by
  unfold quantityAtCorrectionFrontier?
  rw [image.currentEvents_admitted]
  rfl

/-- The carried current validity view is exactly the existing admission result. -/
theorem validity_eq_raw (image : ReadImage) :
    admittedActualValidityMemory? image.evidence.validity =
      some image.currentValidities :=
  image.currentValidities_admitted

end ReadImage

private def yen : MeasureId := ⟨"jpy"⟩
private def wallet : LocusId := ⟨"o271-wallet"⟩
private def counter : LocusId := ⟨"o271-counter"⟩

private def original : Event := {
  id := ⟨"o271-original"⟩
  effects := [
    Effect.ofAnonymousQuantity wallet yen (Quantity.ofQuanta 10),
    Effect.ofAnonymousQuantity counter yen (Quantity.ofQuanta (-10))
  ]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def replacement : Event := {
  id := ⟨"o271-replacement"⟩
  effects := [
    Effect.ofAnonymousQuantity wallet yen (Quantity.ofQuanta 20),
    Effect.ofAnonymousQuantity counter yen (Quantity.ofQuanta (-20))
  ]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def events : EventMemory := {
  events := [original, replacement]
  idNodup := by native_decide
}

private def corrections : EventCorrectionMemory := {
  corrections := [{ target := original.id, replacement := replacement.id }]
  idNodup := by simp
}

private def validity : ActualValidityHistory String := {
  facts := [
    .base original.id "2026-09-01",
    .base replacement.id "2026-09-02"
  ]
  factRefNodup := by native_decide
  corrections := []
  correctionIdNodup := by simp
}

private def evidence : ActualEvidence := {
  events := events
  validity := validity
  descriptions := .empty
  merchants := .empty
  corrections := corrections
  reversals := .empty
  relations := []
  discharges := []
}

/-- A representative correction-bearing Actual world admits one reusable read image. -/
theorem representative_image_is_admitted :
    (ReadImage.ofEvidence? evidence).isSome = true := by
  native_decide

/--
The representative image carries the terminal replacement quantity exactly once;
the superseded original does not need a second frontier calculation per query.
-/
theorem representative_raw_quantity_is_terminal :
    quantityAtCorrectionFrontier? evidence.events evidence.corrections wallet yen =
      some (Quantity.ofQuanta 20) := by
  native_decide

/-- Missing validity for a remembered Event refuses the read image. -/
private def incompleteValidityEvidence : ActualEvidence := {
  evidence with
  validity := {
    facts := [.base original.id "2026-09-01"]
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp
  }
}

theorem incomplete_validity_is_rejected :
    (ReadImage.ofEvidence? incompleteValidityEvidence).isNone = true := by
  native_decide

/-- A cyclic correction shape likewise refuses the read image. -/
private def cyclicCorrectionEvidence : ActualEvidence := {
  evidence with
  corrections := {
    corrections := [{ target := original.id, replacement := original.id }]
    idNodup := by simp
  }
}

theorem cyclic_correction_is_rejected :
    (ReadImage.ofEvidence? cyclicCorrectionEvidence).isNone = true := by
  native_decide

end Loam.Observation271

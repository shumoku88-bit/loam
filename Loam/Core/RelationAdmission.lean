import Loam.Core.EventCorrection

namespace Loam.Core

set_option autoImplicit false

/-!
# Referential relation admission

This module is the pure fail-closed boundary suggested by Observation 055.
Raw correction and resolution facts may eventually arrive from any physical
storage topology. They become eligible for later semantic projection only when
every Event identity they explicitly reference is present in the supplied
`EventMemory`.

This boundary deliberately knows nothing about files, publication protocols,
arrival order, time, authority, or storage layout. It also does not decide
whether a correction is current-tip admissible or whether a resolution covers a
whole conflict frontier. Those are later semantic questions.
-/

/-- Whether one explicit Event identity is present in the supplied memory. -/
private def eventPresent (memory : EventMemory) (id : EventId) : Bool :=
  (EventMemory.findById? memory id).isSome

namespace EventCorrection

/--
Whether every Event explicitly referenced by one correction fact is present.

This is referential admission only. A `true` result does not make the correction
current, authoritative, or temporally later than anything else.
-/
def referencesPresent (memory : EventMemory) (correction : EventCorrection) : Bool :=
  eventPresent memory correction.target &&
    eventPresent memory correction.replacement

/--
Keep only correction facts whose explicit Event references are all present.

Input list order is retained as representation only. No relation acquires
priority from surviving earlier or later in the list.
-/
def admitReferenced
    (memory : EventMemory) (corrections : List EventCorrection) : List EventCorrection :=
  corrections.filter (referencesPresent memory)

/-- Membership in the admitted view is exactly raw membership plus closed references. -/
theorem mem_admitReferenced_iff
    (memory : EventMemory)
    (corrections : List EventCorrection)
    (correction : EventCorrection) :
    correction ∈ admitReferenced memory corrections ↔
      correction ∈ corrections ∧ referencesPresent memory correction = true := by
  simp [admitReferenced]

/-- A correction with a missing explicit Event reference never enters the admitted view. -/
theorem not_mem_admitReferenced_of_missing
    (memory : EventMemory)
    (corrections : List EventCorrection)
    (correction : EventCorrection)
    (hMissing : referencesPresent memory correction = false) :
    correction ∉ admitReferenced memory corrections := by
  simp [admitReferenced, hMissing]

/--
Referential admission agrees with the endpoint-presence portion of ordinary
single-correction projection.
-/
theorem referencesPresent_iff_project?_isSome
    (memory : EventMemory)
    (correction : EventCorrection) :
    referencesPresent memory correction = true ↔
      (project? memory correction).isSome = true := by
  unfold referencesPresent eventPresent project?
  cases hTarget : EventMemory.findById? memory correction.target with
  | none =>
      simp [hTarget]
  | some target =>
      cases hReplacement : EventMemory.findById? memory correction.replacement with
      | none =>
          simp [hTarget, hReplacement]
      | some replacement =>
          simp [hTarget, hReplacement]

end EventCorrection

namespace EventResolution

/--
Whether every Event explicitly referenced by one resolution fact is present.

This checks only the raw relation's `parents` and `replacement`. It does not
claim that the parents equal any current conflict frontier, nor that the offered
replacement is justified.
-/
def referencesPresent (memory : EventMemory) (resolution : EventResolution) : Bool :=
  resolution.parents.all (eventPresent memory) &&
    eventPresent memory resolution.replacement

/--
Keep only resolution facts whose explicit parent and replacement Events are all
present. Whole-frontier settlement remains a later `EventResolution.project?`
question.
-/
def admitReferenced
    (memory : EventMemory) (resolutions : List EventResolution) : List EventResolution :=
  resolutions.filter (referencesPresent memory)

/-- Membership in the admitted view is exactly raw membership plus closed references. -/
theorem mem_admitReferenced_iff
    (memory : EventMemory)
    (resolutions : List EventResolution)
    (resolution : EventResolution) :
    resolution ∈ admitReferenced memory resolutions ↔
      resolution ∈ resolutions ∧ referencesPresent memory resolution = true := by
  simp [admitReferenced]

/-- A resolution with any missing explicit Event reference stays semantically hidden. -/
theorem not_mem_admitReferenced_of_missing
    (memory : EventMemory)
    (resolutions : List EventResolution)
    (resolution : EventResolution)
    (hMissing : referencesPresent memory resolution = false) :
    resolution ∉ admitReferenced memory resolutions := by
  simp [admitReferenced, hMissing]

end EventResolution

end Loam.Core

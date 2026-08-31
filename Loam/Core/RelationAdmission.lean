import Loam.Core.EventCorrectionMemory
import Loam.Core.EventResolutionMemory

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

/--
Filtering a typed relation representation cannot introduce repeated identity.

This is a representation lemma only. It says nothing about what the relation
means or why an item is retained by the filter.
-/
private theorem map_filter_nodup
    {α β : Type}
    (identity : α → β)
    (keep : α → Bool)
    (items : List α)
    (hNodup : (items.map identity).Nodup) :
    ((items.filter keep).map identity).Nodup := by
  induction items with
  | nil =>
      simp
  | cons item rest ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases hKeep : keep item = true
      · simp only [List.filter_cons_of_pos hKeep, List.map_cons, List.nodup_cons]
        constructor
        · intro hMem
          apply hNodup.1
          rcases List.mem_map.mp hMem with ⟨candidate, hCandidate, hIdentity⟩
          exact List.mem_map.mpr ⟨candidate, (List.mem_filter.mp hCandidate).1, hIdentity⟩
        · exact ih hNodup.2
      · have hKeepFalse : keep item = false := Bool.eq_false_of_not_eq_true hKeep
        simp only [List.filter_cons_of_neg hKeepFalse]
        exact ih hNodup.2

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

namespace EventCorrectionMemory

/--
Admit a correction memory against the currently present Events.

The resulting memory contains exactly the referentially closed correction facts
and retains the input memory's per-kind identity uniqueness. Filtering keeps
representation order only; it does not choose a current or authoritative
correction.
-/
def admitReferenced
    (events : EventMemory)
    (memory : EventCorrectionMemory) : EventCorrectionMemory :=
  {
    corrections := EventCorrection.admitReferenced events memory.corrections
    idNodup := by
      exact map_filter_nodup
        EventCorrection.id
        (EventCorrection.referencesPresent events)
        memory.corrections
        memory.idNodup
  }

/-- Typed correction admission has the same membership law as raw list admission. -/
theorem mem_admitReferenced_iff
    (events : EventMemory)
    (memory : EventCorrectionMemory)
    (correction : EventCorrection) :
    correction ∈ (admitReferenced events memory).corrections ↔
      correction ∈ memory.corrections ∧
        EventCorrection.referencesPresent events correction = true := by
  simpa [admitReferenced] using
    EventCorrection.mem_admitReferenced_iff events memory.corrections correction

end EventCorrectionMemory

namespace EventResolutionMemory

/--
Admit a resolution memory against the currently present Events.

The resulting memory contains exactly the referentially closed resolution facts
and retains the input memory's per-kind identity uniqueness. This does not
establish whole-frontier coverage or justify any replacement meaning.
-/
def admitReferenced
    (events : EventMemory)
    (memory : EventResolutionMemory) : EventResolutionMemory :=
  {
    resolutions := EventResolution.admitReferenced events memory.resolutions
    idNodup := by
      exact map_filter_nodup
        EventResolution.id
        (EventResolution.referencesPresent events)
        memory.resolutions
        memory.idNodup
  }

/-- Typed resolution admission has the same membership law as raw list admission. -/
theorem mem_admitReferenced_iff
    (events : EventMemory)
    (memory : EventResolutionMemory)
    (resolution : EventResolution) :
    resolution ∈ (admitReferenced events memory).resolutions ↔
      resolution ∈ memory.resolutions ∧
        EventResolution.referencesPresent events resolution = true := by
  simpa [admitReferenced] using
    EventResolution.mem_admitReferenced_iff events memory.resolutions resolution

end EventResolutionMemory

end Loam.Core

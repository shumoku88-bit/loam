import Loam.MovementAdmission

namespace Loam.Experiments.CSLibSemanticCorrespondence003

set_option autoImplicit false

/-!
CSA-003 asks whether the existing pure `MovementAdmission.admit?` boundary can
be read directly with CSLib's labelled-transition-system vocabulary without
changing production architecture or adding a dependency.

The definitions below intentionally shadow only the small CSLib surface used by
the experiment: `LTS.Tr`, `MTr`, `TrInv`, `MTrInv`, and determinism.
-/

private structure ProbeLTS (State : Type) (Label : Type) where
  Tr : State → Label → State → Prop

namespace ProbeLTS

private inductive MTr {State Label : Type} (lts : ProbeLTS State Label) :
    State → List Label → State → Prop where
  | refl {s : State} : MTr lts s [] s
  | stepL {s1 : State} {label : Label} {s2 : State}
      {labels : List Label} {s3 : State} :
      lts.Tr s1 label s2 → MTr lts s2 labels s3 →
      MTr lts s1 (label :: labels) s3

private def TrInv {State Label : Type}
    (lts : ProbeLTS State Label) (p : State → Prop) : Prop :=
  ∀ s1 label s2, lts.Tr s1 label s2 → p s1 → p s2

private def MTrInv {State Label : Type}
    (lts : ProbeLTS State Label) (p : State → Prop) : Prop :=
  ∀ s1 labels s2, MTr lts s1 labels s2 → p s1 → p s2

/-- Dependency-free shadow of CSLib `LTS.mtrInv_of_trInv`. -/
private theorem mtrInv_of_trInv
    {State Label : Type}
    {lts : ProbeLTS State Label}
    {p : State → Prop}
    (hStep : TrInv lts p) : MTrInv lts p := by
  intro s1 labels s2 hTrace hP
  induction hTrace with
  | refl => exact hP
  | stepL hTr hTail ih =>
      exact ih (hStep _ _ _ hTr hP)

private def Deterministic {State Label : Type}
    (lts : ProbeLTS State Label) : Prop :=
  ∀ s1 label s2 s3, lts.Tr s1 label s2 → lts.Tr s1 label s3 → s2 = s3

/-- Dependency-free shadow of CSLib `LTS.Deterministic.eq_of_mTr`. -/
private theorem eq_of_mTr_of_deterministic
    {State Label : Type}
    {lts : ProbeLTS State Label}
    (hDet : Deterministic lts)
    {s1 s2 s3 : State}
    {labels : List Label}
    (left : MTr lts s1 labels s2)
    (right : MTr lts s1 labels s3) : s2 = s3 := by
  induction left generalizing s3 with
  | refl =>
      cases right
      rfl
  | stepL hLeftStep hLeftTail ih =>
      cases right with
      | stepL hRightStep hRightTail =>
          have hMid := hDet _ _ _ _ hLeftStep hRightStep
          cases hMid
          exact ih hRightTail

end ProbeLTS

abbrev World := Loam.MovementAdmission.World
abbrev Draft := Loam.MovementAdmission.Draft
abbrev Admitted := Loam.MovementAdmission.Admitted

/--
Successful admission is one labelled transition. Refusal has no target state:
there is deliberately no synthetic error state in this relation.
-/
def MovementTr (before : World) (draft : Draft) (after : World) : Prop :=
  ∃ admitted : Admitted,
    Loam.MovementAdmission.admit? before draft = .ok admitted ∧
      admitted.world = after

private def movementLTS : ProbeLTS World Draft where
  Tr := MovementTr

/-- A refused admission does not manufacture a household state. -/
theorem refusal_has_no_transition
    {before after : World} {draft : Draft} {message : String}
    (hRefused : Loam.MovementAdmission.admit? before draft = .error message) :
    ¬ MovementTr before draft after := by
  intro hTr
  rcases hTr with ⟨admitted, hAdmitted, _⟩
  rw [hRefused] at hAdmitted
  contradiction

/--
`MovementAdmission.admit?` is a pure function, so a fixed world and fixed label
cannot produce two different successor worlds.
-/
theorem movement_deterministic : ProbeLTS.Deterministic movementLTS := by
  intro before draft left right hLeft hRight
  rcases hLeft with ⟨leftAdmitted, hLeftAdmitted, rfl⟩
  rcases hRight with ⟨rightAdmitted, hRightAdmitted, rfl⟩
  rw [hLeftAdmitted] at hRightAdmitted
  cases hRightAdmitted
  rfl

/-- Therefore a fixed finite trace also has a unique successor world. -/
theorem movement_trace_deterministic
    {before left right : World} {drafts : List Draft}
    (hLeft : ProbeLTS.MTr movementLTS before drafts left)
    (hRight : ProbeLTS.MTr movementLTS before drafts right) :
    left = right :=
  ProbeLTS.eq_of_mTr_of_deterministic movement_deterministic hLeft hRight

private theorem admit_eq_of_canonicalize_eq
    (world : World) {left right : Draft}
    (hCanonical :
      Loam.MovementAdmission.canonicalizeDraft left =
        Loam.MovementAdmission.canonicalizeDraft right) :
    Loam.MovementAdmission.admit? world left =
      Loam.MovementAdmission.admit? world right := by
  unfold Loam.MovementAdmission.admit?
  rw [hCanonical]

/--
Raw draft labels that canonicalize to the same semantic draft induce exactly the
same transition relation. This records the representational duplication instead
of prematurely introducing a quotient/canonical-label production type.
-/
theorem movementTr_congr_of_canonicalize_eq
    (world : World) {left right : Draft} (after : World)
    (hCanonical :
      Loam.MovementAdmission.canonicalizeDraft left =
        Loam.MovementAdmission.canonicalizeDraft right) :
    MovementTr world left after ↔ MovementTr world right after := by
  unfold MovementTr
  rw [admit_eq_of_canonicalize_eq world hCanonical]

/--
The local one-step proof obligation is enough to obtain the corresponding
finite-trace invariant, exactly as in CSLib. CSLib contributes composition; it
does not replace the domain-specific one-step proof.
-/
theorem movement_multistep_invariant
    (p : World → Prop)
    (hStep : ProbeLTS.TrInv movementLTS p) :
    ProbeLTS.MTrInv movementLTS p :=
  ProbeLTS.mtrInv_of_trInv hStep

/-!
A concrete production invariant worth checking is that Movement admission does
not mutate the current Locus-admission policy. The successful result literally
copies `world.locusAdmission`; the theorem below makes that one-step fact usable
by the generic multistep rule.
-/
private theorem admitted_preserves_locusAdmission
    {before : World} {draft : Draft} {admitted : Admitted}
    (hAdmitted : Loam.MovementAdmission.admit? before draft = .ok admitted) :
    admitted.world.locusAdmission = before.locusAdmission := by
  simp only [Loam.MovementAdmission.admit?] at hAdmitted
  split at hAdmitted <;> simp_all

/-- Fixed Locus policy is a one-step invariant of Movement admission. -/
theorem locus_policy_step_invariant
    (policy : Loam.Core.LocusAdmissionVocabulary) :
    ProbeLTS.TrInv movementLTS (fun world => world.locusAdmission = policy) := by
  intro before draft after hTr hPolicy
  rcases hTr with ⟨admitted, hAdmitted, hWorld⟩
  subst after
  rw [admitted_preserves_locusAdmission hAdmitted]
  exact hPolicy

/-- Hence the same Locus policy survives every finite Movement trace. -/
theorem locus_policy_multistep_invariant
    (policy : Loam.Core.LocusAdmissionVocabulary) :
    ProbeLTS.MTrInv movementLTS (fun world => world.locusAdmission = policy) :=
  ProbeLTS.mtrInv_of_trInv (locus_policy_step_invariant policy)

end Loam.Experiments.CSLibSemanticCorrespondence003

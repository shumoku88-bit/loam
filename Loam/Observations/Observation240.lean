namespace Loam.Observations.Observation240

set_option autoImplicit false

/-!
Observation 240

Qualification: retained in the Selected Lean Observations umbrella.

Question: can the publication pattern now shared by several production writers be
stated as one small law without merging their semantic authorities?

The law is intentionally representation-free. Each publication artifact receives
a natural-number rank. A crash may expose any prefix of that order. An anchor is
semantically safe only when every piece of evidence required by that anchor ranks
strictly before it.

This is a law about visibility, not referential direction. Observation 055 showed
that some relations must follow the Events they reference. Observation 240 asks a
different question: when an artifact is the point that makes already-retained
evidence semantically live, what ordering keeps every crash prefix closed?
-/

/-- One artifact is visible at a crash prefix exactly when its publication rank is before the cut. -/
def visibleAt {α : Type} (rank : α → Nat) (cut : Nat) (artifact : α) : Prop :=
  rank artifact < cut

/--
A prefix is semantically closed for one activation anchor when visibility of the
anchor implies visibility of every piece of evidence required by it.
-/
def semanticallyClosed {α : Type}
    (rank : α → Nat) (required : List α) (anchor : α) (cut : Nat) : Prop :=
  visibleAt rank cut anchor →
    ∀ evidence, evidence ∈ required → visibleAt rank cut evidence

/--
If every required evidence artifact is published before the activation anchor,
then every possible crash prefix is semantically closed.

The theorem is independent of the number and identity of evidence artifacts. It
therefore captures the common ordering law without creating a generic Publisher
or collapsing Correction, Reversal, Scheduled, or Capacity semantics.
-/
theorem activation_last_preserves_every_prefix
    {α : Type}
    (rank : α → Nat)
    (required : List α)
    (anchor : α)
    (evidenceBeforeAnchor :
      ∀ evidence, evidence ∈ required → rank evidence < rank anchor)
    (cut : Nat) :
    semanticallyClosed rank required anchor cut := by
  unfold semanticallyClosed visibleAt
  intro anchorVisible evidence evidenceRequired
  exact Nat.lt_trans (evidenceBeforeAnchor evidence evidenceRequired) anchorVisible

/--
Conversely, if an activation anchor is published before one required evidence
artifact, there is a crash cut that exposes the anchor while hiding that evidence.
Final-state correctness alone therefore cannot justify the wrong publication
order.
-/
theorem anchor_before_evidence_exposes_crash_prefix
    {α : Type}
    (rank : α → Nat)
    (anchor evidence : α)
    (anchorBeforeEvidence : rank anchor < rank evidence) :
    ∃ cut,
      visibleAt rank cut anchor ∧
      ¬ visibleAt rank cut evidence := by
  refine ⟨rank anchor + 1, ?_, ?_⟩
  · exact Nat.lt_succ_self (rank anchor)
  · unfold visibleAt
    exact Nat.not_lt_of_ge (Nat.succ_le_iff.mpr anchorBeforeEvidence)

end Loam.Observations.Observation240

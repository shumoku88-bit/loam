import Init

namespace Loam.Observation231

set_option autoImplicit false

/-!
Observation 231 compares two ways to close an otherwise open-world Scheduled
future query:

* retained completeness evidence;
* an explicit query-local completeness assumption.

The numerical projection may be identical, but the epistemic status must remain
different.  This probe is deliberately experiment-local and adds no production
persistence, completeness authority, or scenario engine.
-/

structure PathInput where
  current : Int
  day1Flow : Int
  day2Flow : Int
deriving Repr, DecidableEq

structure CompletenessEvidence where
  through : Nat
deriving Repr, DecidableEq

structure CompletenessAssumption where
  through : Nat
deriving Repr, DecidableEq

inductive PathAnswer where
  | unknown
  | qualified (evidence : CompletenessEvidence) (path : List Int)
  | conditional (assumption : CompletenessAssumption) (path : List Int)
deriving Repr, DecidableEq

structure Review where
  canonical : PathInput
  answer : PathAnswer
deriving Repr, DecidableEq

/-- Two day-boundary prefix sums.  Observation 229 already qualified this arithmetic shape. -/
def projectedPath (input : PathInput) : List Int :=
  let day1 := input.current + input.day1Flow
  let day2 := day1 + input.day2Flow
  [day1, day2]

private def evidenceCovers (evidence : CompletenessEvidence) (target : Nat) : Bool :=
  decide (target ≤ evidence.through)

private def assumptionCovers (assumption : CompletenessAssumption) (target : Nat) : Bool :=
  decide (target ≤ assumption.through)

private def conditionalOrUnknown
    (input : PathInput)
    (target : Nat)
    (assumption? : Option CompletenessAssumption) : PathAnswer :=
  match assumption? with
  | some assumption =>
      if assumptionCovers assumption target then
        .conditional assumption (projectedPath input)
      else
        .unknown
  | none => .unknown

/--
Evidence has priority because it can qualify the answer.  An assumption is used
only when retained evidence does not cover the query, and then the result remains
explicitly conditional.
-/
def answer
    (input : PathInput)
    (target : Nat)
    (evidence? : Option CompletenessEvidence)
    (assumption? : Option CompletenessAssumption) : PathAnswer :=
  match evidence? with
  | some evidence =>
      if evidenceCovers evidence target then
        .qualified evidence (projectedPath input)
      else
        conditionalOrUnknown input target assumption?
  | none =>
      conditionalOrUnknown input target assumption?

/-- The query never replaces or mutates the retained canonical input. -/
def review
    (input : PathInput)
    (target : Nat)
    (evidence? : Option CompletenessEvidence)
    (assumption? : Option CompletenessAssumption) : Review :=
  {
    canonical := input
    answer := answer input target evidence? assumption?
  }

/-- Forget epistemic status only for the deliberate equal-payload probe below. -/
def payload? : PathAnswer → Option (List Int)
  | .unknown => none
  | .qualified _ path => some path
  | .conditional _ path => some path

def isQualified : PathAnswer → Bool
  | .qualified _ _ => true
  | _ => false

def isConditional : PathAnswer → Bool
  | .conditional _ _ => true
  | _ => false

private def specimen : PathInput :=
  { current := 10, day1Flow := -3, day2Flow := 5 }

private def complete2 : CompletenessEvidence := ⟨2⟩
private def complete1 : CompletenessEvidence := ⟨1⟩
private def assume2 : CompletenessAssumption := ⟨2⟩
private def assume1 : CompletenessAssumption := ⟨1⟩
private def assumeFar : CompletenessAssumption := ⟨99⟩

private def evidenceAnswer : PathAnswer :=
  answer specimen 2 (some complete2) none

private def assumptionAnswer : PathAnswer :=
  answer specimen 2 none (some assume2)

/-- The underlying two-day arithmetic is ordinary prefix accumulation. -/
example : projectedPath specimen = [7, 12] := by
  native_decide

/-- Retained completeness evidence may qualify the path. -/
example : evidenceAnswer = .qualified complete2 [7, 12] := by
  native_decide

/-- The same horizon supplied only as a query assumption yields a conditional path. -/
example : assumptionAnswer = .conditional assume2 [7, 12] := by
  native_decide

/-- Equal numerical payload does not erase the provenance/status distinction. -/
example : payload? evidenceAnswer = payload? assumptionAnswer := by
  native_decide

example : evidenceAnswer ≠ assumptionAnswer := by
  native_decide

/-- A query-local assumption must never masquerade as a qualified answer. -/
example : isQualified assumptionAnswer = false := by
  native_decide

example : isConditional assumptionAnswer = true := by
  native_decide

/-- Without evidence or an explicit assumption, the open-world answer remains unknown. -/
example : (review specimen 2 none none).answer = .unknown := by
  native_decide

/-- An assumption that does not cover the requested horizon also leaves the answer unknown. -/
example : (review specimen 2 none (some assume1)).answer = .unknown := by
  native_decide

/-- If retained evidence is too short but an explicit assumption covers the query, status is conditional. -/
example :
    (review specimen 2 (some complete1) (some assume2)).answer =
      .conditional assume2 [7, 12] := by
  native_decide

/-- Qualified evidence wins over even a broader query-local assumption. -/
example :
    (review specimen 2 (some complete2) (some assumeFar)).answer =
      .qualified complete2 [7, 12] := by
  native_decide

/-- The read-only operation preserves the canonical input mechanically. -/
theorem canonicalPreserved
    (input : PathInput)
    (target : Nat)
    (evidence? : Option CompletenessEvidence)
    (assumption? : Option CompletenessAssumption) :
    (review input target evidence? assumption?).canonical = input := by
  rfl

end Loam.Observation231

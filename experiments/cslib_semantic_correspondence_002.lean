import Loam.Application.ReplacementFrontier
import Lean.Elab.Tactic.Omega

namespace Loam.Experiments.CSLibSemanticCorrespondence002

set_option autoImplicit false

open Loam.Application.ReplacementFrontier

/-!
CSA-002 asks for the mathematical premise actually needed by LOAM's bounded
start-return cycle detector.

Observation 218 needed successor injectivity when comparing two path-local
algorithms from the same arbitrary start.  Relation-level acyclicity is a
different question: if a finite deterministic relation has a cycle, starting on
the cycle itself returns to that start.  This probe therefore separates
finite-domain coverage from right-uniqueness (determinism) and does not assume
injectivity of successors.
-/

private def advance? {Id : Type}
    (next? : Id → Option Id) : Nat → Id → Option Id
  | 0, id => some id
  | steps + 1, id =>
      match next? id with
      | none => none
      | some next => advance? next? steps next

private theorem advance?_add
    {Id : Type}
    (next? : Id → Option Id)
    (first second : Nat)
    (start : Id) :
    advance? next? (first + second) start =
      (advance? next? first start).bind (advance? next? second) := by
  induction first generalizing start with
  | zero =>
      simp [advance?]
  | succ first ih =>
      simp only [Nat.succ_add]
      simp [advance?]
      cases hNext : next? start with
      | none => simp
      | some next => simp [ih]

private def returnsWithin {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (start : Id) : Nat → Id → Bool
  | 0, _ => false
  | fuel + 1, current =>
      match next? current with
      | none => false
      | some next =>
          if next = start then true
          else returnsWithin next? start fuel next

private def nextRel {Id : Type}
    (next? : Id → Option Id) : Id → Id → Prop :=
  fun source successor => next? source = some successor

private abbrev StandardAcyclicNext {Id : Type}
    (next? : Id → Option Id) : Prop :=
  Std.Irrefl (Relation.TransGen (nextRel next?))

/--
Whole finite-domain start-return detector.  `sources` need not itself be Nodup;
it only needs to cover every state where `next?` is defined.
-/
private def wholeAcyclic {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id) (sources : List Id) : Bool :=
  !(sources.any fun source =>
    returnsWithin next? source sources.length source)

private theorem returnsWithin_true_exists_advance
    {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (start current : Id)
    (fuel : Nat)
    (hReturn : returnsWithin next? start fuel current = true) :
    ∃ steps, 0 < steps ∧ steps ≤ fuel ∧
      advance? next? steps current = some start := by
  induction fuel generalizing current with
  | zero =>
      simp [returnsWithin] at hReturn
  | succ fuel ih =>
      cases hNext : next? current with
      | none =>
          simp [returnsWithin, hNext] at hReturn
      | some next =>
          by_cases hImmediate : next = start
          · refine ⟨1, by omega, by omega, ?_⟩
            simp [advance?, hNext, hImmediate]
          · have hTail : returnsWithin next? start fuel next = true := by
              simpa [returnsWithin, hNext, hImmediate] using hReturn
            rcases ih next hTail with ⟨steps, hPositive, hBound, hAdvance⟩
            refine ⟨steps + 1, by omega, by omega, ?_⟩
            simp [advance?, hNext, hAdvance]

private theorem advance_return_implies_returnsWithin
    {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (start current : Id)
    (steps fuel : Nat)
    (hPositive : 0 < steps)
    (hBound : steps ≤ fuel)
    (hAdvance : advance? next? steps current = some start) :
    returnsWithin next? start fuel current = true := by
  induction fuel generalizing steps current with
  | zero =>
      omega
  | succ fuel ih =>
      cases steps with
      | zero => omega
      | succ steps =>
          cases hNext : next? current with
          | none =>
              simp [advance?, hNext] at hAdvance
          | some next =>
              by_cases hImmediate : next = start
              · simp [returnsWithin, hNext, hImmediate]
              · cases steps with
                | zero =>
                    have hEq : next = start := by
                      simpa [advance?, hNext] using hAdvance
                    exact False.elim (hImmediate hEq)
                | succ steps =>
                    have hTailAdvance :
                        advance? next? (steps + 1) next = some start := by
                      simpa [advance?, hNext] using hAdvance
                    have hTailReturn :=
                      ih (steps := steps + 1) (current := next)
                        (by omega) (by omega) hTailAdvance
                    simpa [returnsWithin, hNext, hImmediate] using hTailReturn

private theorem advance?_prefix_some
    {Id : Type}
    (next? : Id → Option Id)
    {total prefix : Nat}
    {start finish : Id}
    (hAdvance : advance? next? total start = some finish)
    (hPrefix : prefix ≤ total) :
    ∃ current, advance? next? prefix start = some current := by
  have hSplit : prefix + (total - prefix) = total := Nat.add_sub_of_le hPrefix
  rw [← hSplit, advance?_add] at hAdvance
  cases hCurrent : advance? next? prefix start with
  | none => simp [hCurrent] at hAdvance
  | some current => exact ⟨current, hCurrent⟩

private theorem advance_positive_to_transGen
    {Id : Type}
    (next? : Id → Option Id)
    {steps : Nat} {start finish : Id}
    (hPositive : 0 < steps)
    (hAdvance : advance? next? steps start = some finish) :
    Relation.TransGen (nextRel next?) start finish := by
  induction steps generalizing start with
  | zero => omega
  | succ steps ih =>
      cases hNext : next? start with
      | none =>
          simp [advance?, hNext] at hAdvance
      | some next =>
          cases steps with
          | zero =>
              have hEq : next = finish := by
                simpa [advance?, hNext] using hAdvance
              apply Relation.TransGen.single
              simpa [nextRel, hEq] using hNext
          | succ steps =>
              have hTail : advance? next? (steps + 1) next = some finish := by
                simpa [advance?, hNext] using hAdvance
              have hRest := ih (start := next) (by omega) hTail
              exact Relation.TransGen.trans
                (Relation.TransGen.single (show nextRel next? start next from hNext))
                hRest

private theorem transGen_to_advance
    {Id : Type}
    (next? : Id → Option Id)
    {start finish : Id}
    (hTr : Relation.TransGen (nextRel next?) start finish) :
    ∃ steps, 0 < steps ∧ advance? next? steps start = some finish := by
  induction hTr with
  | single hStep =>
      refine ⟨1, by omega, ?_⟩
      simpa [nextRel, advance?] using hStep
  | tail hPrefix hStep ih =>
      rcases ih with ⟨steps, hPositive, hAdvance⟩
      refine ⟨steps + 1, by omega, ?_⟩
      rw [advance?_add next? steps 1 start]
      simp [hAdvance, advance?, nextRel] at hStep ⊢
      exact hStep

private def orbitAt {Id : Type}
    (next? : Id → Option Id) (start : Id) (steps : Nat) : Id :=
  (advance? next? steps start).getD start

private theorem orbitAt_ne_of_lt_minimal_return
    {Id : Type}
    (next? : Id → Option Id)
    (start : Id)
    (hExists : ∃ steps, 0 < steps ∧ advance? next? steps start = some start)
    {i j : Nat}
    (hij : i < j)
    (hj : j < Nat.find hExists) :
    orbitAt next? start i ≠ orbitAt next? start j := by
  intro hOrbitEq
  let period := Nat.find hExists
  have hPeriod : advance? next? period start = some start :=
    (Nat.find_spec hExists).2
  have hiLe : i ≤ period := by
    dsimp [period]
    omega
  have hjLe : j ≤ period := by
    dsimp [period]
    omega
  rcases advance?_prefix_some next? hPeriod hiLe with ⟨left, hLeft⟩
  rcases advance?_prefix_some next? hPeriod hjLe with ⟨right, hRight⟩
  have hLeftValue : orbitAt next? start i = left := by
    simp [orbitAt, hLeft]
  have hRightValue : orbitAt next? start j = right := by
    simp [orbitAt, hRight]
  have hStateEq : left = right := by
    rw [← hLeftValue, ← hRightValue]
    exact hOrbitEq
  have hSuffix : advance? next? (period - j) right = some start := by
    have hSplit : j + (period - j) = period := Nat.add_sub_of_le hjLe
    have h := hPeriod
    rw [← hSplit, advance?_add next? j (period - j) start, hRight] at h
    simpa using h
  let shorter := i + (period - j)
  have hShortReturn : advance? next? shorter start = some start := by
    dsimp [shorter]
    rw [advance?_add next? i (period - j) start, hLeft]
    simpa [hStateEq] using hSuffix
  have hShortPositive : 0 < shorter := by
    dsimp [shorter, period]
    omega
  have hShortLt : shorter < period := by
    dsimp [shorter, period]
    omega
  have hMin : period ≤ shorter := by
    dsimp [period]
    exact Nat.find_min' hExists ⟨hShortPositive, hShortReturn⟩
  omega

private theorem minimal_period_le_sources
    {Id : Type}
    (next? : Id → Option Id)
    (sources : List Id)
    (hDomain : ∀ {source successor : Id},
      next? source = some successor → source ∈ sources)
    (start : Id)
    (hExists : ∃ steps, 0 < steps ∧ advance? next? steps start = some start) :
    Nat.find hExists ≤ sources.length := by
  let period := Nat.find hExists
  let orbit := (List.range period).map (orbitAt next? start)
  have hPeriodPositive : 0 < period := by
    exact (Nat.find_spec hExists).1
  have hPeriod : advance? next? period start = some start :=
    (Nat.find_spec hExists).2
  have hOrbitNodup : orbit.Nodup := by
    dsimp [orbit]
    change (List.range period).Pairwise
      (fun i j => orbitAt next? start i ≠ orbitAt next? start j)
    rw [List.pairwise_iff_getElem]
    intro i j hi hj hij
    have hjPeriod : j < period := by
      simpa using hj
    simpa using
      orbitAt_ne_of_lt_minimal_return next? start hExists hij hjPeriod
  have hOrbitSubset : ∀ id, id ∈ orbit → id ∈ sources := by
    intro id hMem
    rcases List.mem_map.mp hMem with ⟨steps, hSteps, rfl⟩
    have hStepsLt : steps < period := List.mem_range.mp hSteps
    have hStepsLe : steps ≤ period := by omega
    have hNextLe : steps + 1 ≤ period := by omega
    rcases advance?_prefix_some next? hPeriod hStepsLe with
      ⟨current, hCurrent⟩
    rcases advance?_prefix_some next? hPeriod hNextLe with
      ⟨successor, hSuccessor⟩
    have hCurrentValue : orbitAt next? start steps = current := by
      simp [orbitAt, hCurrent]
    rw [hCurrentValue]
    apply hDomain
    have h := hSuccessor
    rw [advance?_add next? steps 1 start, hCurrent] at h
    simpa [advance?] using h
  have hLength := List.Nodup.length_le_of_subset hOrbitNodup hOrbitSubset
  simpa [orbit] using hLength

private theorem transGen_cycle_returnsWithin
    {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (sources : List Id)
    (hDomain : ∀ {source successor : Id},
      next? source = some successor → source ∈ sources)
    (start : Id)
    (hCycle : Relation.TransGen (nextRel next?) start start) :
    returnsWithin next? start sources.length start = true := by
  rcases transGen_to_advance next? hCycle with
    ⟨steps, hPositive, hAdvance⟩
  let hExists : ∃ n, 0 < n ∧ advance? next? n start = some start :=
    ⟨steps, hPositive, hAdvance⟩
  have hSpec := Nat.find_spec hExists
  have hBound := minimal_period_le_sources next? sources hDomain start hExists
  exact advance_return_implies_returnsWithin
    next? start start (Nat.find hExists) sources.length
      hSpec.1 hBound hSpec.2

private theorem cycle_start_mem_sources
    {Id : Type}
    (next? : Id → Option Id)
    (sources : List Id)
    (hDomain : ∀ {source successor : Id},
      next? source = some successor → source ∈ sources)
    (start : Id)
    (hCycle : Relation.TransGen (nextRel next?) start start) :
    start ∈ sources := by
  rcases transGen_to_advance next? hCycle with
    ⟨steps, hPositive, hAdvance⟩
  have hOneLe : 1 ≤ steps := by omega
  rcases advance?_prefix_some next? hAdvance hOneLe with ⟨next, hOne⟩
  apply hDomain
  simpa [advance?] using hOne

/--
A bounded whole-domain start-return detector exactly decides the standard
`TransGen` notion of acyclicity for any partial function with a finite list that
covers its domain.  No injectivity of successors is used.
-/
theorem wholeAcyclic_iff_standardAcyclic
    {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (sources : List Id)
    (hDomain : ∀ {source successor : Id},
      next? source = some successor → source ∈ sources) :
    wholeAcyclic next? sources = true ↔ StandardAcyclicNext next? := by
  constructor
  · intro hExecutable
    refine ⟨?_⟩
    intro start hCycle
    have hReturn :=
      transGen_cycle_returnsWithin next? sources hDomain start hCycle
    have hMem := cycle_start_mem_sources next? sources hDomain start hCycle
    have hAny :
        sources.any (fun source =>
          returnsWithin next? source sources.length source) = true :=
      List.any_eq_true.mpr ⟨start, hMem, hReturn⟩
    simp [wholeAcyclic, hAny] at hExecutable
  · intro hStandard
    cases hAny : sources.any (fun source =>
        returnsWithin next? source sources.length source) with
    | false =>
        simp [wholeAcyclic, hAny]
    | true =>
        rcases List.any_eq_true.mp hAny with ⟨start, _, hReturn⟩
        rcases returnsWithin_true_exists_advance
          next? start start sources.length hReturn with
          ⟨steps, hPositive, _, hAdvance⟩
        have hCycle := advance_positive_to_transGen
          next? hPositive hAdvance
        exact False.elim (hStandard.irrefl start hCycle)

/-! ## ReplacementFrontier shadow -/

private def edgeNext? {Id : Type} [DecidableEq Id] :
    List (Edge Id) → Id → Option Id
  | [], _ => none
  | edge :: rest, id =>
      if edge.source = id then some edge.successor else edgeNext? rest id

/-- Ordinary relation represented by all retained edges, independent of list order. -/
def edgeRel {Id : Type} (edges : List (Edge Id)) : Id → Id → Prop :=
  fun source successor =>
    ∃ edge, edge ∈ edges ∧ edge.source = source ∧ edge.successor = successor

/-- Shadow of CSLib/Mathlib `Relator.RightUnique`. -/
def RightUnique {Id : Type} (edges : List (Edge Id)) : Prop :=
  ∀ ⦃source left right⦄,
    edgeRel edges source left → edgeRel edges source right → left = right

/-- Dependency-free shadow of CSLib `Relation.Acyclic`. -/
abbrev StandardAcyclic {Id : Type} (edges : List (Edge Id)) : Prop :=
  Std.Irrefl (Relation.TransGen (edgeRel edges))

/--
The public production `acyclic` has this same bounded-start-return shape.  The
shadow keeps the proof independent of private implementation helper names.
-/
def shadowAcyclic {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  wholeAcyclic (edgeNext? edges) (edges.map Edge.source)

private theorem edgeRel_of_edgeNext?_eq_some
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) {source successor : Id}
    (hNext : edgeNext? edges source = some successor) :
    edgeRel edges source successor := by
  induction edges with
  | nil =>
      simp [edgeNext?] at hNext
  | cons edge rest ih =>
      by_cases hSource : edge.source = source
      · have hSucc : edge.successor = successor := by
          simpa [edgeNext?, hSource] using hNext
        exact ⟨edge, by simp, hSource, hSucc⟩
      · have hTail : edgeNext? rest source = some successor := by
          simpa [edgeNext?, hSource] using hNext
        rcases ih hTail with ⟨candidate, hMem, hS, hT⟩
        exact ⟨candidate, by simp [hMem], hS, hT⟩

private theorem edgeNext?_exists_of_edgeRel
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) {source successor : Id}
    (hRel : edgeRel edges source successor) :
    ∃ actual, edgeNext? edges source = some actual := by
  rcases hRel with ⟨candidate, hMem, hSource, _⟩
  induction edges with
  | nil => simp at hMem
  | cons edge rest ih =>
      simp at hMem
      rcases hMem with rfl | hMem
      · exact ⟨candidate.successor, by simp [edgeNext?, hSource]⟩
      · by_cases hHead : edge.source = source
        · exact ⟨edge.successor, by simp [edgeNext?, hHead]⟩
        · rcases ih hMem with ⟨actual, hActual⟩
          exact ⟨actual, by simp [edgeNext?, hHead, hActual]⟩

private theorem edgeRel_to_edgeNext?_of_rightUnique
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (hUnique : RightUnique edges)
    {source successor : Id}
    (hRel : edgeRel edges source successor) :
    edgeNext? edges source = some successor := by
  rcases edgeNext?_exists_of_edgeRel edges hRel with ⟨actual, hNext⟩
  have hActualRel := edgeRel_of_edgeNext?_eq_some edges hNext
  have hEq : actual = successor := hUnique hActualRel hRel
  simpa [hEq] using hNext

private theorem edgeNext?_domain
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) {source successor : Id}
    (hNext : edgeNext? edges source = some successor) :
    source ∈ edges.map Edge.source := by
  rcases edgeRel_of_edgeNext?_eq_some edges hNext with
    ⟨edge, hMem, hSource, _⟩
  exact List.mem_map.mpr ⟨edge, hMem, hSource⟩

/--
For a right-unique represented edge relation, the bounded LOAM-shaped checker
and CSLib's standard transitive-closure acyclicity notion coincide.  Successor
injectivity is not a premise.
-/
theorem shadowAcyclic_iff_standardAcyclic_of_rightUnique
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (hUnique : RightUnique edges) :
    shadowAcyclic edges = true ↔ StandardAcyclic edges := by
  have hRelEq : edgeRel edges = nextRel (edgeNext? edges) := by
    funext source successor
    apply propext
    constructor
    · exact edgeRel_to_edgeNext?_of_rightUnique edges hUnique
    · exact edgeRel_of_edgeNext?_eq_some edges
  rw [hRelEq]
  exact wholeAcyclic_iff_standardAcyclic
    (edgeNext? edges) (edges.map Edge.source) (edgeNext?_domain edges)

/-- Non-injective successors are admitted by the correspondence theorem. -/
def convergingAcyclic : List (Edge Nat) :=
  [ { source := 0, successor := 2 }
  , { source := 1, successor := 2 }
  ]

example : RightUnique convergingAcyclic := by
  intro source left right hLeft hRight
  simp [edgeRel, convergingAcyclic] at hLeft hRight
  omega

example : shadowAcyclic convergingAcyclic = true := by
  native_decide

/-- A cycle can also coexist with a non-injective successor relation. -/
def convergingCyclic : List (Edge Nat) :=
  [ { source := 0, successor := 1 }
  , { source := 1, successor := 0 }
  , { source := 2, successor := 0 }
  ]

example : RightUnique convergingCyclic := by
  intro source left right hLeft hRight
  simp [edgeRel, convergingCyclic] at hLeft hRight
  omega

example : shadowAcyclic convergingCyclic = false := by
  native_decide

end Loam.Experiments.CSLibSemanticCorrespondence002

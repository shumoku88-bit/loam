import Lean.Elab.Tactic.Omega

namespace Loam.Experiments.Observation218FinitePartialInjection

set_option autoImplicit false

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

private theorem advance?_injective
    {Id : Type}
    (next? : Id → Option Id)
    (hInjective : ∀ {left right endpoint : Id},
      next? left = some endpoint → next? right = some endpoint → left = right)
    (steps : Nat)
    {left right endpoint : Id}
    (hLeft : advance? next? steps left = some endpoint)
    (hRight : advance? next? steps right = some endpoint) :
    left = right := by
  induction steps generalizing left right endpoint with
  | zero =>
      simp [advance?] at hLeft hRight
      exact hLeft.trans hRight.symm
  | succ steps ih =>
      cases hLeftNext : next? left with
      | none => simp [advance?, hLeftNext] at hLeft
      | some leftNext =>
          cases hRightNext : next? right with
          | none => simp [advance?, hRightNext] at hRight
          | some rightNext =>
              have hLeftTail : advance? next? steps leftNext = some endpoint := by
                simpa [advance?, hLeftNext] using hLeft
              have hRightTail : advance? next? steps rightNext = some endpoint := by
                simpa [advance?, hRightNext] using hRight
              have hNextEq : leftNext = rightNext := ih hLeftTail hRightTail
              have hLeftNext' : next? left = some rightNext := by
                simpa [hNextEq] using hLeftNext
              exact hInjective hLeftNext' hRightNext

private theorem repeated_advance_forces_start_return
    {Id : Type}
    (next? : Id → Option Id)
    (hInjective : ∀ {left right endpoint : Id},
      next? left = some endpoint → next? right = some endpoint → left = right)
    (period prefixSteps : Nat)
    {start repeated : Id}
    (hPrefix : advance? next? prefixSteps start = some repeated)
    (hRepeated : advance? next? (period + prefixSteps) start = some repeated) :
    advance? next? period start = some start := by
  rw [advance?_add next? period prefixSteps start] at hRepeated
  cases hPeriod : advance? next? period start with
  | none => simp [hPeriod] at hRepeated
  | some afterPeriod =>
      have hTail : advance? next? prefixSteps afterPeriod = some repeated := by
        simpa [hPeriod] using hRepeated
      have hEq : afterPeriod = start :=
        advance?_injective next? hInjective prefixSteps hTail hPrefix
      simpa [hEq] using hPeriod

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

private def walkAfter {Id : Type}
    (next? : Id → Option Id) : Nat → Id → List Id
  | 0, _ => []
  | fuel + 1, current =>
      match next? current with
      | none => []
      | some next => next :: walkAfter next? fuel next

private theorem returnsWithin_eq_true_iff_mem_walkAfter
    {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (start current : Id)
    (fuel : Nat) :
    returnsWithin next? start fuel current = true ↔
      start ∈ walkAfter next? fuel current := by
  induction fuel generalizing current with
  | zero =>
      simp [returnsWithin, walkAfter]
  | succ fuel ih =>
      cases hNext : next? current with
      | none =>
          simp [returnsWithin, walkAfter, hNext]
      | some next =>
          by_cases hReturn : next = start
          · simp [returnsWithin, walkAfter, hNext, hReturn]
          · have hReverse : start ≠ next := by
              intro h
              exact hReturn h.symm
            simp [returnsWithin, walkAfter, hNext, hReturn, hReverse, ih]

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

private theorem successor_cycle_forces_start_cycle
    {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (hInjective : ∀ {left right endpoint : Id},
      next? left = some endpoint → next? right = some endpoint → left = right)
    (start next : Id)
    (fuel : Nat)
    (hNext : next? start = some next)
    (hCycle : returnsWithin next? next fuel next = true) :
    returnsWithin next? start (fuel + 1) start = true := by
  rcases returnsWithin_true_exists_advance next? next next fuel hCycle with
    ⟨period, hPositive, hBound, hCycleAdvance⟩
  have hPrefix : advance? next? 1 start = some next := by
    simp [advance?, hNext]
  have hRepeated : advance? next? (period + 1) start = some next := by
    have hCombined : advance? next? (1 + period) start = some next := by
      rw [advance?_add next? 1 period start]
      simp [hPrefix, hCycleAdvance]
    simpa [Nat.add_comm] using hCombined
  have hStartAdvance : advance? next? period start = some start :=
    repeated_advance_forces_start_return
      next? hInjective period 1 hPrefix hRepeated
  exact advance_return_implies_returnsWithin
    next? start start period (fuel + 1)
      hPositive (by omega) hStartAdvance

private def traceChecks {Id : Type}
    (next? : Id → Option Id) : Nat → Id → List Id
  | 0, _ => []
  | fuel + 1, current =>
      current ::
        match next? current with
        | none => []
        | some next => traceChecks next? fuel next

private def reachesTerminal {Id : Type}
    (next? : Id → Option Id) : Nat → Id → Bool
  | 0, _ => false
  | fuel + 1, current =>
      match next? current with
      | none => true
      | some next => reachesTerminal next? fuel next

private theorem traceChecks_succ_eq_cons_walkAfter
    {Id : Type}
    (next? : Id → Option Id)
    (fuel : Nat)
    (current : Id) :
    traceChecks next? (fuel + 1) current =
      current :: walkAfter next? fuel current := by
  induction fuel generalizing current with
  | zero =>
      cases hNext : next? current <;>
        simp [traceChecks, walkAfter, hNext]
  | succ fuel ih =>
      cases hNext : next? current with
      | none =>
          simp [traceChecks, walkAfter, hNext]
      | some next =>
          change
            (current :: (match next? current with
              | none => []
              | some next => traceChecks next? (fuel + 1) next)) =
            current :: (match next? current with
              | none => []
              | some next => next :: walkAfter next? fuel next)
          rw [hNext]
          exact congrArg (List.cons current) (ih next)

private def avoids {Id : Type} [DecidableEq Id]
    (nodes seen : List Id) : Prop :=
  ∀ id, id ∈ nodes → id ∉ seen

private def pathAcyclic {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (current : Id)
    (seen : List Id) : Nat → Bool
  | 0 => false
  | fuel + 1 =>
      if current ∈ seen then false
      else
        match next? current with
        | none => true
        | some next => pathAcyclic next? next (current :: seen) fuel

private theorem pathAcyclic_eq_true_iff
    {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (current : Id)
    (seen : List Id)
    (fuel : Nat) :
    pathAcyclic next? current seen fuel = true ↔
      (traceChecks next? fuel current).Nodup ∧
        avoids (traceChecks next? fuel current) seen ∧
        reachesTerminal next? fuel current = true := by
  induction fuel generalizing current seen with
  | zero =>
      simp [pathAcyclic, traceChecks, reachesTerminal, avoids]
  | succ fuel ih =>
      by_cases hSeen : current ∈ seen
      · simp [pathAcyclic, traceChecks, reachesTerminal, avoids, hSeen]
      · cases hNext : next? current with
        | none =>
            simp [pathAcyclic, traceChecks, reachesTerminal, avoids, hSeen, hNext]
        | some next =>
            simp [pathAcyclic, traceChecks, reachesTerminal, avoids,
              hSeen, hNext, ih]
            constructor
            · rintro ⟨hNodup, hAvoid, hTerminal⟩
              have hFresh : ¬current ∈ traceChecks next? fuel next := by
                intro hMem
                exact (hAvoid current hMem).1 rfl
              have hAvoidSeen :
                  ∀ id, id ∈ traceChecks next? fuel next → ¬id ∈ seen := by
                intro id hMem
                exact (hAvoid id hMem).2
              exact ⟨⟨hFresh, hNodup⟩, hAvoidSeen, hTerminal⟩
            · rintro ⟨⟨hFresh, hNodup⟩, hAvoidSeen, hTerminal⟩
              have hAvoid :
                  ∀ id, id ∈ traceChecks next? fuel next →
                    ¬id = current ∧ ¬id ∈ seen := by
                intro id hMem
                constructor
                · intro hEq
                  apply hFresh
                  simpa [hEq] using hMem
                · exact hAvoidSeen id hMem
              exact ⟨hNodup, hAvoid, hTerminal⟩

private theorem traceChecks_subset_sources_of_not_terminal
    {Id : Type} [DecidableEq Id]
    (next? : Id → Option Id)
    (sources : List Id)
    (hDomain : ∀ {source successor : Id},
      next? source = some successor → source ∈ sources)
    (fuel : Nat)
    (current : Id)
    (hNotTerminal : reachesTerminal next? fuel current = false) :
    ∀ id ∈ traceChecks next? fuel current, id ∈ sources := by
  induction fuel generalizing current with
  | zero =>
      simp [traceChecks]
  | succ fuel ih =>
      cases hNext : next? current with
      | none =>
          simp [reachesTerminal, hNext] at hNotTerminal
      | some next =>
          have hTailNotTerminal : reachesTerminal next? fuel next = false := by
            simpa [reachesTerminal, hNext] using hNotTerminal
          intro id hMem
          simp [traceChecks, hNext] at hMem
          rcases hMem with rfl | hMem
          · exact hDomain hNext
          · exact ih next hTailNotTerminal id hMem

private theorem traceChecks_length_of_not_terminal
    {Id : Type}
    (next? : Id → Option Id)
    (fuel : Nat)
    (current : Id)
    (hNotTerminal : reachesTerminal next? fuel current = false) :
    (traceChecks next? fuel current).length = fuel := by
  induction fuel generalizing current with
  | zero =>
      rfl
  | succ fuel ih =>
      cases hNext : next? current with
      | none =>
          simp [reachesTerminal, hNext] at hNotTerminal
      | some next =>
          have hTailNotTerminal : reachesTerminal next? fuel next = false := by
            simpa [reachesTerminal, hNext] using hNotTerminal
          simp [traceChecks, hNext, ih next hTailNotTerminal]

end Loam.Experiments.Observation218FinitePartialInjection

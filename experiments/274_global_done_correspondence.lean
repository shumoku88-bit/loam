import Loam.Application.ReplacementFrontier
import Lean.Elab.Tactic.Omega

namespace Loam.Experiments.Observation274GlobalDoneCorrespondence

set_option autoImplicit false

open Loam.Application.ReplacementFrontier

/-!
# Observation 274 — global-done replacement correspondence

Observation 273 showed that a list-only global-done traversal can avoid repeated
suffix walks while keeping the existing `[DecidableEq Id]` boundary.

This experiment closes the semantic promotion obligation for a slightly simpler
candidate: cycle detection is still bounded by the finite source count, but a
successful walk memoizes its suffix while unwinding. A represented cycle
therefore exhausts the bound; an acyclic path reaches either a terminal or an
already-qualified suffix.

The proof reuses the finite partial-injection argument shape historically
qualified by Observation 218. The theorem-heavy machinery stays here; production
is not changed by this PR.
-/

/-! ## Existing start-return semantics, shadowed exactly -/

private def next? {Id : Type} [DecidableEq Id] :
    List (Edge Id) → Id → Option Id
  | [], _ => none
  | edge :: rest, id =>
      if edge.source = id then some edge.successor else next? rest id

private theorem next?_some_mem_successors
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (source successor : Id)
    (hNext : next? edges source = some successor) :
    successor ∈ edges.map Edge.successor := by
  induction edges with
  | nil =>
      simp [next?] at hNext
  | cons edge rest ih =>
      by_cases hSource : edge.source = source
      · simp [next?, hSource] at hNext
        subst successor
        simp
      · simp [next?, hSource] at hNext
        have hMem : successor ∈ rest.map Edge.successor := ih hNext
        simp [hMem]

private theorem next?_injective_of_successor_nodup
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (hNodup : (edges.map Edge.successor).Nodup)
    {left right successor : Id}
    (hLeft : next? edges left = some successor)
    (hRight : next? edges right = some successor) :
    left = right := by
  induction edges generalizing left right successor with
  | nil =>
      simp [next?] at hLeft
  | cons edge rest ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      rcases hNodup with ⟨hFresh, hRestNodup⟩
      by_cases hLeftHead : edge.source = left
      · have hSuccessor : edge.successor = successor := by
          simpa [next?, hLeftHead] using hLeft
        by_cases hRightHead : edge.source = right
        · exact hLeftHead.symm.trans hRightHead
        · have hRightRest : next? rest right = some successor := by
            simpa [next?, hRightHead] using hRight
          have hMem : successor ∈ rest.map Edge.successor :=
            next?_some_mem_successors rest right successor hRightRest
          rw [← hSuccessor] at hMem
          exact False.elim (hFresh hMem)
      · have hLeftRest : next? rest left = some successor := by
          simpa [next?, hLeftHead] using hLeft
        by_cases hRightHead : edge.source = right
        · have hSuccessor : edge.successor = successor := by
            simpa [next?, hRightHead] using hRight
          have hMem : successor ∈ rest.map Edge.successor :=
            next?_some_mem_successors rest left successor hLeftRest
          rw [← hSuccessor] at hMem
          exact False.elim (hFresh hMem)
        · have hRightRest : next? rest right = some successor := by
            simpa [next?, hRightHead] using hRight
          exact ih hRestNodup hLeftRest hRightRest

private theorem next?_domain
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    {source successor : Id}
    (hNext : next? edges source = some successor) :
    source ∈ edges.map Edge.source := by
  induction edges with
  | nil =>
      simp [next?] at hNext
  | cons edge rest ih =>
      by_cases hSource : edge.source = source
      · simp [hSource]
      · have hTail : next? rest source = some successor := by
          simpa [next?, hSource] using hNext
        simp [ih hTail]

private def advance? {Id : Type}
    (nextFn : Id → Option Id) : Nat → Id → Option Id
  | 0, id => some id
  | steps + 1, id =>
      match nextFn id with
      | none => none
      | some next => advance? nextFn steps next

private theorem advance?_add
    {Id : Type}
    (nextFn : Id → Option Id)
    (first second : Nat)
    (start : Id) :
    advance? nextFn (first + second) start =
      (advance? nextFn first start).bind (advance? nextFn second) := by
  induction first generalizing start with
  | zero =>
      simp [advance?]
  | succ first ih =>
      simp only [Nat.succ_add]
      simp [advance?]
      cases hNext : nextFn start with
      | none => simp
      | some next => simp [ih]

private theorem advance?_injective
    {Id : Type}
    (nextFn : Id → Option Id)
    (hInjective : ∀ {left right endpoint : Id},
      nextFn left = some endpoint → nextFn right = some endpoint → left = right)
    (steps : Nat)
    {left right endpoint : Id}
    (hLeft : advance? nextFn steps left = some endpoint)
    (hRight : advance? nextFn steps right = some endpoint) :
    left = right := by
  induction steps generalizing left right endpoint with
  | zero =>
      simp [advance?] at hLeft hRight
      exact hLeft.trans hRight.symm
  | succ steps ih =>
      cases hLeftNext : nextFn left with
      | none => simp [advance?, hLeftNext] at hLeft
      | some leftNext =>
          cases hRightNext : nextFn right with
          | none => simp [advance?, hRightNext] at hRight
          | some rightNext =>
              have hLeftTail : advance? nextFn steps leftNext = some endpoint := by
                simpa [advance?, hLeftNext] using hLeft
              have hRightTail : advance? nextFn steps rightNext = some endpoint := by
                simpa [advance?, hRightNext] using hRight
              have hNextEq : leftNext = rightNext := ih hLeftTail hRightTail
              have hLeftNext' : nextFn left = some rightNext := by
                simpa [hNextEq] using hLeftNext
              exact hInjective hLeftNext' hRightNext

private theorem repeated_advance_forces_start_return
    {Id : Type}
    (nextFn : Id → Option Id)
    (hInjective : ∀ {left right endpoint : Id},
      nextFn left = some endpoint → nextFn right = some endpoint → left = right)
    (period prefixSteps : Nat)
    {start repeated : Id}
    (hPrefix : advance? nextFn prefixSteps start = some repeated)
    (hRepeated : advance? nextFn (period + prefixSteps) start = some repeated) :
    advance? nextFn period start = some start := by
  rw [advance?_add nextFn period prefixSteps start] at hRepeated
  cases hPeriod : advance? nextFn period start with
  | none => simp [hPeriod] at hRepeated
  | some afterPeriod =>
      have hTail : advance? nextFn prefixSteps afterPeriod = some repeated := by
        simpa [hPeriod] using hRepeated
      have hEq : afterPeriod = start :=
        advance?_injective nextFn hInjective prefixSteps hTail hPrefix
      simpa [hEq] using hPeriod

private def returnsWithin {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (start : Id) : Nat → Id → Bool
  | 0, _ => false
  | fuel + 1, current =>
      match nextFn current with
      | none => false
      | some next =>
          if next = start then true
          else returnsWithin nextFn start fuel next

private def walkAfter {Id : Type}
    (nextFn : Id → Option Id) : Nat → Id → List Id
  | 0, _ => []
  | fuel + 1, current =>
      match nextFn current with
      | none => []
      | some next => next :: walkAfter nextFn fuel next

private theorem returnsWithin_eq_true_iff_mem_walkAfter
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (start current : Id)
    (fuel : Nat) :
    returnsWithin nextFn start fuel current = true ↔
      start ∈ walkAfter nextFn fuel current := by
  induction fuel generalizing current with
  | zero =>
      simp [returnsWithin, walkAfter]
  | succ fuel ih =>
      cases hNext : nextFn current with
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
    (nextFn : Id → Option Id)
    (start current : Id)
    (fuel : Nat)
    (hReturn : returnsWithin nextFn start fuel current = true) :
    ∃ steps, 0 < steps ∧ steps ≤ fuel ∧
      advance? nextFn steps current = some start := by
  induction fuel generalizing current with
  | zero =>
      simp [returnsWithin] at hReturn
  | succ fuel ih =>
      cases hNext : nextFn current with
      | none =>
          simp [returnsWithin, hNext] at hReturn
      | some next =>
          by_cases hImmediate : next = start
          · refine ⟨1, by omega, by omega, ?_⟩
            simp [advance?, hNext, hImmediate]
          · have hTail : returnsWithin nextFn start fuel next = true := by
              simpa [returnsWithin, hNext, hImmediate] using hReturn
            rcases ih next hTail with ⟨steps, hPositive, hBound, hAdvance⟩
            refine ⟨steps + 1, by omega, by omega, ?_⟩
            simp [advance?, hNext, hAdvance]

private theorem advance_return_implies_returnsWithin
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (start current : Id)
    (steps fuel : Nat)
    (hPositive : 0 < steps)
    (hBound : steps ≤ fuel)
    (hAdvance : advance? nextFn steps current = some start) :
    returnsWithin nextFn start fuel current = true := by
  induction fuel generalizing steps current with
  | zero =>
      omega
  | succ fuel ih =>
      cases steps with
      | zero => omega
      | succ steps =>
          cases hNext : nextFn current with
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
                        advance? nextFn (steps + 1) next = some start := by
                      simpa [advance?, hNext] using hAdvance
                    have hTailReturn :=
                      ih (steps := steps + 1) (current := next)
                        (by omega) (by omega) hTailAdvance
                    simpa [returnsWithin, hNext, hImmediate] using hTailReturn

private theorem successor_cycle_forces_start_cycle
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (hInjective : ∀ {left right endpoint : Id},
      nextFn left = some endpoint → nextFn right = some endpoint → left = right)
    (start next : Id)
    (fuel : Nat)
    (hNext : nextFn start = some next)
    (hCycle : returnsWithin nextFn next fuel next = true) :
    returnsWithin nextFn start (fuel + 1) start = true := by
  rcases returnsWithin_true_exists_advance nextFn next next fuel hCycle with
    ⟨period, hPositive, _, hCycleAdvance⟩
  have hPrefix : advance? nextFn 1 start = some next := by
    simp [advance?, hNext]
  have hRepeated : advance? nextFn (period + 1) start = some next := by
    have hCombined : advance? nextFn (1 + period) start = some next := by
      rw [advance?_add nextFn 1 period start]
      simp [hPrefix, hCycleAdvance]
    simpa [Nat.add_comm] using hCombined
  have hStartAdvance : advance? nextFn period start = some start :=
    repeated_advance_forces_start_return
      nextFn hInjective period 1 hPrefix hRepeated
  exact advance_return_implies_returnsWithin
    nextFn start start period (fuel + 1)
      hPositive (by omega) hStartAdvance

private def traceChecks {Id : Type}
    (nextFn : Id → Option Id) : Nat → Id → List Id
  | 0, _ => []
  | fuel + 1, current =>
      current ::
        match nextFn current with
        | none => []
        | some next => traceChecks nextFn fuel next

private def reachesTerminal {Id : Type}
    (nextFn : Id → Option Id) : Nat → Id → Bool
  | 0, _ => false
  | fuel + 1, current =>
      match nextFn current with
      | none => true
      | some next => reachesTerminal nextFn fuel next

private theorem traceChecks_succ_eq_cons_walkAfter
    {Id : Type}
    (nextFn : Id → Option Id)
    (fuel : Nat)
    (current : Id) :
    traceChecks nextFn (fuel + 1) current =
      current :: walkAfter nextFn fuel current := by
  induction fuel generalizing current with
  | zero =>
      cases hNext : nextFn current <;>
        simp [traceChecks, walkAfter, hNext]
  | succ fuel ih =>
      cases hNext : nextFn current with
      | none =>
          simp [traceChecks, walkAfter, hNext]
      | some next =>
          change
            (current :: (match nextFn current with
              | none => []
              | some next => traceChecks nextFn (fuel + 1) next)) =
            current :: (match nextFn current with
              | none => []
              | some next => next :: walkAfter nextFn fuel next)
          rw [hNext]
          exact congrArg (List.cons current) (ih next)

private theorem traceChecks_subset_sources_of_not_terminal
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (sources : List Id)
    (hDomain : ∀ {source successor : Id},
      nextFn source = some successor → source ∈ sources)
    (fuel : Nat)
    (current : Id)
    (hNotTerminal : reachesTerminal nextFn fuel current = false) :
    ∀ id ∈ traceChecks nextFn fuel current, id ∈ sources := by
  induction fuel generalizing current with
  | zero =>
      simp [traceChecks]
  | succ fuel ih =>
      cases hNext : nextFn current with
      | none =>
          simp [reachesTerminal, hNext] at hNotTerminal
      | some next =>
          have hTailNotTerminal : reachesTerminal nextFn fuel next = false := by
            simpa [reachesTerminal, hNext] using hNotTerminal
          intro id hMem
          simp [traceChecks, hNext] at hMem
          rcases hMem with rfl | hMem
          · exact hDomain hNext
          · exact ih next hTailNotTerminal id hMem

private theorem traceChecks_length_of_not_terminal
    {Id : Type}
    (nextFn : Id → Option Id)
    (fuel : Nat)
    (current : Id)
    (hNotTerminal : reachesTerminal nextFn fuel current = false) :
    (traceChecks nextFn fuel current).length = fuel := by
  induction fuel generalizing current with
  | zero =>
      rfl
  | succ fuel ih =>
      cases hNext : nextFn current with
      | none =>
          simp [reachesTerminal, hNext] at hNotTerminal
      | some next =>
          have hTailNotTerminal : reachesTerminal nextFn fuel next = false := by
            simpa [reachesTerminal, hNext] using hNotTerminal
          simp [traceChecks, hNext, ih next hTailNotTerminal]

private theorem traceChecks_nodup_of_no_return
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (hInjective : ∀ {left right endpoint : Id},
      nextFn left = some endpoint → nextFn right = some endpoint → left = right)
    (fuel : Nat)
    (current : Id)
    (hNoReturn : returnsWithin nextFn current fuel current = false) :
    (traceChecks nextFn (fuel + 1) current).Nodup := by
  induction fuel generalizing current with
  | zero =>
      cases hNext : nextFn current <;>
        simp [traceChecks, hNext]
  | succ fuel ih =>
      cases hNext : nextFn current with
      | none =>
          simp [traceChecks, hNext]
      | some next =>
          have hTailNoReturn :
              returnsWithin nextFn next fuel next = false := by
            cases hTail : returnsWithin nextFn next fuel next with
            | false => rfl
            | true =>
                have hStartCycle :=
                  successor_cycle_forces_start_cycle
                    nextFn hInjective current next fuel hNext hTail
                simp [hNoReturn] at hStartCycle
          have hTailNodup := ih next hTailNoReturn
          have hNoMemWalk :
              current ∉ walkAfter nextFn (fuel + 1) current := by
            intro hMem
            have hReturnTrue :=
              (returnsWithin_eq_true_iff_mem_walkAfter
                nextFn current current (fuel + 1)).2 hMem
            simp [hNoReturn] at hReturnTrue
          have hTailEq :
              traceChecks nextFn (fuel + 1) next =
                walkAfter nextFn (fuel + 1) current := by
            calc
              traceChecks nextFn (fuel + 1) next =
                  next :: walkAfter nextFn fuel next :=
                traceChecks_succ_eq_cons_walkAfter nextFn fuel next
              _ = walkAfter nextFn (fuel + 1) current := by
                simp [walkAfter, hNext]
          have hFresh :
              current ∉ traceChecks nextFn (fuel + 1) next := by
            intro hMem
            apply hNoMemWalk
            rw [← hTailEq]
            exact hMem
          change
            (current :: (match nextFn current with
              | none => []
              | some next => traceChecks nextFn (fuel + 1) next)).Nodup
          rw [hNext]
          exact List.nodup_cons.mpr ⟨hFresh, hTailNodup⟩

private theorem reachesTerminal_of_no_return_finite
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (sources : List Id)
    (hDomain : ∀ {source successor : Id},
      nextFn source = some successor → source ∈ sources)
    (hInjective : ∀ {left right endpoint : Id},
      nextFn left = some endpoint → nextFn right = some endpoint → left = right)
    (current : Id)
    (hNoReturn :
      returnsWithin nextFn current sources.length current = false) :
    reachesTerminal nextFn (sources.length + 1) current = true := by
  cases hTerminal : reachesTerminal nextFn (sources.length + 1) current with
  | true => rfl
  | false =>
      have hTraceNodup :=
        traceChecks_nodup_of_no_return
          nextFn hInjective sources.length current hNoReturn
      have hSubset :=
        traceChecks_subset_sources_of_not_terminal
          nextFn sources hDomain (sources.length + 1) current hTerminal
      have hLength :=
        traceChecks_length_of_not_terminal
          nextFn (sources.length + 1) current hTerminal
      have hLe :
          (traceChecks nextFn (sources.length + 1) current).length ≤
            sources.length :=
        List.Nodup.length_le_of_subset hTraceNodup hSubset
      rw [hLength] at hLe
      omega

/-! ## Termination certificate used by the memoized detector -/

private def Terminates {Id : Type}
    (nextFn : Id → Option Id) (start : Id) : Prop :=
  ∃ steps terminal,
    advance? nextFn steps start = some terminal ∧ nextFn terminal = none

private theorem terminates_of_reachesTerminal
    {Id : Type}
    (nextFn : Id → Option Id)
    (fuel : Nat)
    (current : Id)
    (hReach : reachesTerminal nextFn fuel current = true) :
    Terminates nextFn current := by
  induction fuel generalizing current with
  | zero =>
      simp [reachesTerminal] at hReach
  | succ fuel ih =>
      cases hNext : nextFn current with
      | none =>
          exact ⟨0, current, by simp [advance?], hNext⟩
      | some next =>
          have hTail : reachesTerminal nextFn fuel next = true := by
            simpa [reachesTerminal, hNext] using hReach
          rcases ih next hTail with ⟨steps, terminal, hAdvance, hNone⟩
          exact ⟨steps + 1, terminal, by simp [advance?, hNext, hAdvance], hNone⟩

private theorem terminates_of_next
    {Id : Type}
    (nextFn : Id → Option Id)
    {current next : Id}
    (hNext : nextFn current = some next)
    (hTerm : Terminates nextFn next) :
    Terminates nextFn current := by
  rcases hTerm with ⟨steps, terminal, hAdvance, hNone⟩
  exact ⟨steps + 1, terminal, by simp [advance?, hNext, hAdvance], hNone⟩

private theorem no_return_of_terminates
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (current : Id)
    (fuel : Nat)
    (hTerm : Terminates nextFn current) :
    returnsWithin nextFn current fuel current = false := by
  cases hReturn : returnsWithin nextFn current fuel current with
  | false => rfl
  | true =>
      rcases returnsWithin_true_exists_advance
        nextFn current current fuel hReturn with
        ⟨period, hPositive, _, hCycle⟩
      rcases hTerm with ⟨steps, terminal, hAdvance, hNone⟩
      have hLong : advance? nextFn (period + steps) current = some terminal := by
        rw [advance?_add nextFn period steps current, hCycle]
        simpa using hAdvance
      have hLong' : advance? nextFn (steps + period) current = some terminal := by
        simpa [Nat.add_comm] using hLong
      rw [advance?_add nextFn steps period current, hAdvance] at hLong'
      have hTerminalCycle : advance? nextFn period terminal = some terminal := by
        simpa using hLong'
      cases period with
      | zero => omega
      | succ period =>
          simp [advance?, hNone] at hTerminalCycle

/-! ## Fuel-bounded global-done candidate -/

private def memoWalk {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id) :
    Nat → Id → List Id → Option (List Id)
  | 0, _, _ => none
  | fuel + 1, current, done =>
      if current ∈ done then
        some done
      else
        match nextFn current with
        | none => some (current :: done)
        | some next =>
            match memoWalk nextFn fuel next done with
            | none => none
            | some done' => some (current :: done')

private def memoScan {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (fuel : Nat) :
    List Id → List Id → Option (List Id)
  | [], done => some done
  | source :: rest, done =>
      if source ∈ done then
        memoScan nextFn fuel rest done
      else
        match memoWalk nextFn fuel source done with
        | none => none
        | some done' => memoScan nextFn fuel rest done'

private def globalDoneAcyclic {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  (memoScan
    (next? edges)
    (edges.length + 1)
    (edges.map Edge.source)
    []).isSome

private def AllTerminates {Id : Type}
    (nextFn : Id → Option Id)
    (done : List Id) : Prop :=
  ∀ id, id ∈ done → Terminates nextFn id

private theorem memoWalk_success_preserves_termination
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (fuel : Nat)
    (current : Id)
    (done done' : List Id)
    (hDone : AllTerminates nextFn done)
    (hWalk : memoWalk nextFn fuel current done = some done') :
    AllTerminates nextFn done' ∧ Terminates nextFn current := by
  induction fuel generalizing current done done' with
  | zero =>
      simp [memoWalk] at hWalk
  | succ fuel ih =>
      by_cases hMem : current ∈ done
      · simp [memoWalk, hMem] at hWalk
        subst done'
        exact ⟨hDone, hDone current hMem⟩
      · cases hNext : nextFn current with
        | none =>
            have hEq : done' = current :: done := by
              simpa [memoWalk, hMem, hNext] using hWalk.symm
            subst done'
            have hCurrent : Terminates nextFn current :=
              ⟨0, current, by simp [advance?], hNext⟩
            constructor
            · intro id hId
              simp at hId
              rcases hId with rfl | hId
              · exact hCurrent
              · exact hDone id hId
            · exact hCurrent
        | some next =>
            cases hTail : memoWalk nextFn fuel next done with
            | none =>
                simp [memoWalk, hMem, hNext, hTail] at hWalk
            | some tailDone =>
                have hEq : done' = current :: tailDone := by
                  simpa [memoWalk, hMem, hNext, hTail] using hWalk.symm
                subst done'
                rcases ih next done tailDone hDone hTail with
                  ⟨hTailDone, hNextTerminates⟩
                have hCurrent :=
                  terminates_of_next nextFn hNext hNextTerminates
                constructor
                · intro id hId
                  simp at hId
                  rcases hId with rfl | hId
                  · exact hCurrent
                  · exact hTailDone id hId
                · exact hCurrent

private theorem memoWalk_succeeds_of_reachesTerminal
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (fuel : Nat)
    (current : Id)
    (done : List Id)
    (hReach : reachesTerminal nextFn fuel current = true) :
    ∃ done', memoWalk nextFn fuel current done = some done' := by
  induction fuel generalizing current with
  | zero =>
      simp [reachesTerminal] at hReach
  | succ fuel ih =>
      by_cases hMem : current ∈ done
      · exact ⟨done, by simp [memoWalk, hMem]⟩
      · cases hNext : nextFn current with
        | none =>
            exact ⟨current :: done, by simp [memoWalk, hMem, hNext]⟩
        | some next =>
            have hTailReach : reachesTerminal nextFn fuel next = true := by
              simpa [reachesTerminal, hNext] using hReach
            rcases ih next hTailReach with ⟨tailDone, hTail⟩
            exact ⟨current :: tailDone,
              by simp [memoWalk, hMem, hNext, hTail]⟩

private theorem memoScan_succeeds_of_reachesTerminal
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (fuel : Nat)
    (sources : List Id)
    (done : List Id)
    (hReach : ∀ source ∈ sources,
      reachesTerminal nextFn fuel source = true) :
    ∃ done', memoScan nextFn fuel sources done = some done' := by
  induction sources generalizing done with
  | nil =>
      exact ⟨done, by simp [memoScan]⟩
  | cons source rest ih =>
      by_cases hMem : source ∈ done
      · rcases ih done (by
          intro candidate hCandidate
          exact hReach candidate (by simp [hCandidate])) with
          ⟨done', hDone'⟩
        exact ⟨done', by simp [memoScan, hMem, hDone']⟩
      · have hSourceReach := hReach source (by simp)
        rcases memoWalk_succeeds_of_reachesTerminal
          nextFn fuel source done hSourceReach with
          ⟨walkDone, hWalk⟩
        rcases ih walkDone (by
          intro candidate hCandidate
          exact hReach candidate (by simp [hCandidate])) with
          ⟨done', hDone'⟩
        exact ⟨done', by simp [memoScan, hMem, hWalk, hDone']⟩

private theorem memoScan_success_preserves_termination
    {Id : Type} [DecidableEq Id]
    (nextFn : Id → Option Id)
    (fuel : Nat)
    (sources done done' : List Id)
    (hDone : AllTerminates nextFn done)
    (hScan : memoScan nextFn fuel sources done = some done') :
    AllTerminates nextFn done' ∧
      ∀ source ∈ sources, Terminates nextFn source := by
  induction sources generalizing done done' with
  | nil =>
      simp [memoScan] at hScan
      subst done'
      exact ⟨hDone, by simp⟩
  | cons source rest ih =>
      by_cases hMem : source ∈ done
      · have hSourceTerm := hDone source hMem
        have hTail :
            memoScan nextFn fuel rest done = some done' := by
          simpa [memoScan, hMem] using hScan
        rcases ih done done' hDone hTail with ⟨hDone', hRest⟩
        exact ⟨hDone', by
          intro candidate hCandidate
          simp at hCandidate
          rcases hCandidate with rfl | hCandidate
          · exact hSourceTerm
          · exact hRest candidate hCandidate⟩
      · cases hWalk : memoWalk nextFn fuel source done with
        | none =>
            simp [memoScan, hMem, hWalk] at hScan
        | some walkDone =>
            have hTail :
                memoScan nextFn fuel rest walkDone = some done' := by
              simpa [memoScan, hMem, hWalk] using hScan
            rcases memoWalk_success_preserves_termination
              nextFn fuel source done walkDone hDone hWalk with
              ⟨hWalkDone, hSourceTerm⟩
            rcases ih walkDone done' hWalkDone hTail with
              ⟨hDone', hRest⟩
            exact ⟨hDone', by
              intro candidate hCandidate
              simp at hCandidate
              rcases hCandidate with rfl | hCandidate
              · exact hSourceTerm
              · exact hRest candidate hCandidate⟩

/-! ## Correspondence with current production decision -/

private def shadowStartReturnAcyclic {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  !(edges.any fun edge =>
    returnsWithin (next? edges) edge.source edges.length edge.source)

private theorem globalDone_true_of_shadow_true
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (hSuccessorNodup : (edges.map Edge.successor).Nodup)
    (hShadow : shadowStartReturnAcyclic edges = true) :
    globalDoneAcyclic edges = true := by
  have hAny :
      edges.any (fun edge =>
        returnsWithin (next? edges) edge.source edges.length edge.source) = false := by
    simpa [shadowStartReturnAcyclic] using hShadow
  have hNoReturn :
      ∀ edge ∈ edges,
        returnsWithin (next? edges) edge.source edges.length edge.source = false := by
    intro edge hEdge
    have hNotTrue := (List.any_eq_false.mp hAny) edge hEdge
    cases hValue :
        returnsWithin (next? edges) edge.source edges.length edge.source with
    | false => rfl
    | true => exact False.elim (hNotTrue hValue)
  have hInjective :
      ∀ {left right endpoint : Id},
        next? edges left = some endpoint →
        next? edges right = some endpoint →
        left = right :=
    next?_injective_of_successor_nodup edges hSuccessorNodup
  have hReach :
      ∀ source ∈ edges.map Edge.source,
        reachesTerminal (next? edges) (edges.length + 1) source = true := by
    intro source hSource
    rcases List.mem_map.mp hSource with ⟨edge, hEdge, rfl⟩
    have hTerminal := reachesTerminal_of_no_return_finite
      (next? edges)
      (edges.map Edge.source)
      (next?_domain edges)
      hInjective
      edge.source
      (by
        simpa using hNoReturn edge hEdge)
    simpa using hTerminal
  rcases memoScan_succeeds_of_reachesTerminal
    (next? edges)
    (edges.length + 1)
    (edges.map Edge.source)
    []
    hReach with
    ⟨done', hScan⟩
  simp [globalDoneAcyclic, hScan]

private theorem shadow_true_of_globalDone_true
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (hGlobal : globalDoneAcyclic edges = true) :
    shadowStartReturnAcyclic edges = true := by
  cases hScan :
      memoScan
        (next? edges)
        (edges.length + 1)
        (edges.map Edge.source)
        [] with
  | none =>
      simp [globalDoneAcyclic, hScan] at hGlobal
  | some done' =>
      rcases memoScan_success_preserves_termination
        (next? edges)
        (edges.length + 1)
        (edges.map Edge.source)
        []
        done'
        (by simp [AllTerminates])
        hScan with
        ⟨_, hSourcesTerminate⟩
      have hNoReturn :
          ∀ edge ∈ edges,
            returnsWithin
              (next? edges) edge.source edges.length edge.source = false := by
        intro edge hEdge
        apply no_return_of_terminates
        apply hSourcesTerminate edge.source
        exact List.mem_map.mpr ⟨edge, hEdge, rfl⟩
      have hAny :
          edges.any (fun edge =>
            returnsWithin
              (next? edges) edge.source edges.length edge.source) = false := by
        apply List.any_eq_false.mpr
        intro edge hEdge hTrue
        have hFalse := hNoReturn edge hEdge
        rw [hFalse] at hTrue
        simp at hTrue
      simp [shadowStartReturnAcyclic, hAny]

/--
For every finite one-to-one replacement relation, the fuel-bounded global-done
candidate makes exactly the same cycle decision as the bounded start-return
semantics used by production `ReplacementFrontier.acyclic`.

Observation 273 already pins the executable production/shadow shape on concrete
fixtures. This theorem closes the general optimized-vs-bounded-start-return
correspondence without importing theorem-heavy machinery into Application.

Only successor uniqueness is needed by the proof. Production `endpointUnique`
also keeps source uniqueness because replacement semantics independently refuse
branching.
-/
theorem globalDoneAcyclic_eq_startReturn_of_endpointUnique
    {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (hUnique : endpointUnique edges = true) :
    globalDoneAcyclic edges = shadowStartReturnAcyclic edges := by
  have hNodup :
      (edges.map Edge.source).Nodup ∧
        (edges.map Edge.successor).Nodup := by
    simpa [endpointUnique] using hUnique
  cases hShadow : shadowStartReturnAcyclic edges with
  | false =>
      cases hGlobal : globalDoneAcyclic edges with
      | false => rfl
      | true =>
          have hContradiction :=
            shadow_true_of_globalDone_true edges hGlobal
          simp [hShadow] at hContradiction
  | true =>
      have hGlobal :=
        globalDone_true_of_shadow_true edges hNodup.2 hShadow
      simpa [hGlobal]

private def chain : List (Edge Nat) :=
  (List.range 64).map fun i =>
    { source := i, successor := i + 1 }

example : endpointUnique chain = true := by
  native_decide

example : globalDoneAcyclic chain = shadowStartReturnAcyclic chain :=
  globalDoneAcyclic_eq_startReturn_of_endpointUnique chain (by native_decide)

end Loam.Experiments.Observation274GlobalDoneCorrespondence

import Loam.Application.ScheduledInspection

open Loam.Core
open Loam.Application

/-!
# Phase K: currentOpenScheduled scaling benchmark

Three fixture families:
  A. Completion-heavy (N scheduled, N completion terminals, N events)
  B. Retirement-heavy (N scheduled, N retirement terminals)
  C. Replacement-heavy (N scheduled, replacement chain)

Measures both old (reference) and new (indexed) implementations.
-/

namespace Reference

private def scheduledPresent {Time : Type}
    (scheduledMemory : ScheduledMemory Time) (id : ScheduledId) : Bool :=
  (ScheduledMemory.findById? scheduledMemory id).isSome

private def completionSourcesKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  terminalMemory.terminals.all fun terminal =>
    match terminal.target with
    | some (.actual _) => scheduledPresent scheduledMemory terminal.source
    | _ => true

private def retirementSourcesKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  terminalMemory.terminals.all fun terminal =>
    match terminal.target with
    | none => scheduledPresent scheduledMemory terminal.source
    | _ => true

private def replacementEdges
    (terminalMemory : ScheduledTerminalMemory) :
    List (ReplacementFrontier.Edge ScheduledId) :=
  terminalMemory.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.scheduled successor) =>
        some { source := terminal.source, successor := successor }
    | _ => none

private def replacementEndpointsKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  ReplacementFrontier.referencesClosed
    (scheduledPresent scheduledMemory) (replacementEdges terminalMemory)

private def hasEffectiveCompletion
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory) (scheduled : ScheduledId) : Bool :=
  match ScheduledTerminalMemory.completionActualFor? terminalMemory scheduled with
  | none => false
  | some actual => (EventMemory.findById? eventMemory actual).isSome

private def isCurrentOpen {Time : Type}
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory) (occurrence : ScheduledOccurrence Time) : Bool :=
  (ScheduledTerminalMemory.retirementFor? terminalMemory occurrence.id).isNone &&
    (ScheduledTerminalMemory.replacementFor? terminalMemory occurrence.id).isNone &&
    !hasEffectiveCompletion terminalMemory eventMemory occurrence.id

def currentOpenScheduled {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory) : CurrentOpenScheduledResult Time :=
  let edges := replacementEdges terminalMemory
  if !completionSourcesKnown scheduledMemory terminalMemory then .unknownCompletionScheduled
  else if !retirementSourcesKnown scheduledMemory terminalMemory then .unknownRetirementScheduled
  else if !replacementEndpointsKnown scheduledMemory terminalMemory then .unknownReplacementScheduled
  else if !ReplacementFrontier.acyclic edges then .invalidReplacementGraph
  else if terminalMemory.hasCrossKindConflict then .conflictingTerminalEvidence
  else .open <| scheduledMemory.occurrences.filter (isCurrentOpen terminalMemory eventMemory)

end Reference

private def yen : MeasureId := ⟨"jpy"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def mkMovement : BalancedMovement LocusId :=
  match BalancedMovement.ofChanges? yen
      [{ coordinate := paypay, quantity := Quantity.ofQuanta (-100) },
       { coordinate := groceries, quantity := Quantity.ofQuanta 100 }] with
  | some m => m
  | none => { measure := yen, changes := [], balanced := by decide }

private def mkOccurrence (i : Nat) : ScheduledOccurrence String :=
  { id := ⟨s!"s-{i}"⟩, scheduledOn := s!"2026-01-{i}", movement := mkMovement }

private def mkEvent (i : Nat) : Event :=
  { id := ⟨s!"e-{i}"⟩, effects := [], keyNodup := by simp }

private def buildScheduledMemory (n : Nat) : Option (ScheduledMemory String) :=
  ScheduledMemory.ofOccurrences? ((List.range n).map mkOccurrence)

private def buildCompletionTerminals (n : Nat) : Option ScheduledTerminalMemory :=
  ScheduledTerminalMemory.ofTerminals?
    ((List.range n).map fun i =>
      { source := ⟨s!"s-{i}"⟩, target := some (.actual ⟨s!"e-{i}"⟩) })

private def buildCompletionEvents (n : Nat) : Option EventMemory :=
  EventMemory.ofEvents? ((List.range n).map mkEvent)

private def buildRetirementTerminals (n : Nat) : Option ScheduledTerminalMemory :=
  ScheduledTerminalMemory.ofTerminals?
    ((List.range n).map fun i =>
      { source := ⟨s!"s-{i}"⟩, target := none })

private def emptyTerminals : Option ScheduledTerminalMemory :=
  ScheduledTerminalMemory.ofTerminals? []

private def emptyEvents : Option EventMemory :=
  EventMemory.ofEvents? []

-- Replacement: chain s-0 → s-1 → ... → s-(n-1)
private def buildReplacementTerminals (n : Nat) : Option ScheduledTerminalMemory :=
  if n ≤ 1 then ScheduledTerminalMemory.ofTerminals? []
  else
    ScheduledTerminalMemory.ofTerminals?
      ((List.range (n - 1)).map fun i =>
        { source := ⟨s!"s-{i}"⟩, target := some (.scheduled ⟨s!"s-{i+1}"⟩) })

@[noinline] private def openCount : CurrentOpenScheduledResult String → Nat
  | .open occs => occs.length
  | _ => 0

private def timeUsForced
    (action : Unit → CurrentOpenScheduledResult String) : IO (Nat × Nat) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let count := openCount result
  -- Ensure `count` is evaluated before reading t1
  if count > 1000000 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  let us := (t1 - t0) / 1000
  pure (us, count)

private def timeUsAvg (iterations : Nat)
    (action : Unit → CurrentOpenScheduledResult String) : IO (Nat × Nat) := do
  let mut total : Nat := 0
  let mut count : Nat := 0
  for _ in List.range iterations do
    let (us, c) ← timeUsForced action
    total := total + us
    count := c
  pure (total / iterations, count)

private def fmtUs (us : Nat) : String :=
  if us >= 1000 then s!"{us / 1000}.{(us % 1000) / 100} ms"
  else s!"{us} µs"

private def fmtRatio (numerator denominator : Nat) : String :=
  if denominator > 0 then
    let tenths := numerator * 10 / denominator
    s!"{tenths / 10}.{tenths % 10}x"
  else
    "∞"

def main : IO Unit := do
  let sizes := [50, 100, 200, 500, 1000, 2000, 5000]
  let reps := 3

  IO.println "=== Fixture A: Completion-heavy ==="
  IO.println "  N\t| before\t\t| after\t\t\t| speedup\t| growth(a)\t| growth(b)"
  let mut prevBefore : Nat := 0
  let mut prevAfter : Nat := 0
  for n in sizes do
    let sched ← match buildScheduledMemory n with
      | some s => pure s | none => throw <| IO.userError s!"sched {n}"
    let terms ← match buildCompletionTerminals n with
      | some t => pure t | none => throw <| IO.userError s!"terms {n}"
    let events ← match buildCompletionEvents n with
      | some e => pure e | none => throw <| IO.userError s!"events {n}"

    let (before, countRef) ← timeUsAvg reps fun _ => Reference.currentOpenScheduled sched terms events
    let (after, countNew) ← timeUsAvg reps fun _ => currentOpenScheduled sched terms events

    unless countRef == countNew do
      throw <| IO.userError s!"semantic mismatch at N={n}: {countNew} vs {countRef}"

    let speedup := fmtRatio before after
    let growthB := if prevBefore > 0 then s!"{(before * 100 / prevBefore)}%" else "-"
    let growthA := if prevAfter > 0 then s!"{(after * 100 / prevAfter)}%" else "-"
    IO.println s!"  {n}\t| {fmtUs before}\t\t| {fmtUs after}\t\t| {speedup}\t| {growthA}\t| {growthB}"
    prevBefore := before
    prevAfter := after

  IO.println ""
  IO.println "=== Fixture B: Retirement-heavy ==="
  IO.println "  N\t| before\t\t| after\t\t\t| speedup\t| growth(a)\t| growth(b)"
  prevBefore := 0
  prevAfter := 0
  for n in sizes do
    let sched ← match buildScheduledMemory n with
      | some s => pure s | none => throw <| IO.userError s!"sched {n}"
    let terms ← match buildRetirementTerminals n with
      | some t => pure t | none => throw <| IO.userError s!"terms {n}"
    let events ← match emptyEvents with
      | some e => pure e | none => throw <| IO.userError "events"

    let (before, countRef) ← timeUsAvg reps fun _ => Reference.currentOpenScheduled sched terms events
    let (after, countNew) ← timeUsAvg reps fun _ => currentOpenScheduled sched terms events

    unless countRef == countNew do
      throw <| IO.userError s!"semantic mismatch at N={n}: {countNew} vs {countRef}"

    let speedup := fmtRatio before after
    let growthB := if prevBefore > 0 then s!"{(before * 100 / prevBefore)}%" else "-"
    let growthA := if prevAfter > 0 then s!"{(after * 100 / prevAfter)}%" else "-"
    IO.println s!"  {n}\t| {fmtUs before}\t\t| {fmtUs after}\t\t| {speedup}\t| {growthA}\t| {growthB}"
    prevBefore := before
    prevAfter := after

  IO.println ""
  IO.println "=== Fixture C: Replacement-heavy ==="
  IO.println "  N\t| before\t\t| after\t\t\t| speedup\t| growth(a)\t| growth(b)"
  prevBefore := 0
  prevAfter := 0
  for n in sizes do
    let sched ← match buildScheduledMemory n with
      | some s => pure s | none => throw <| IO.userError s!"sched {n}"
    let terms ← match buildReplacementTerminals n with
      | some t => pure t | none => throw <| IO.userError s!"terms {n}"
    let events ← match emptyEvents with
      | some e => pure e | none => throw <| IO.userError "events"

    let (before, countRef) ← timeUsAvg reps fun _ => Reference.currentOpenScheduled sched terms events
    let (after, countNew) ← timeUsAvg reps fun _ => currentOpenScheduled sched terms events

    unless countRef == countNew do
      throw <| IO.userError s!"semantic mismatch at N={n}: {countNew} vs {countRef}"

    let speedup := fmtRatio before after
    let growthB := if prevBefore > 0 then s!"{(before * 100 / prevBefore)}%" else "-"
    let growthA := if prevAfter > 0 then s!"{(after * 100 / prevAfter)}%" else "-"
    IO.println s!"  {n}\t| {fmtUs before}\t\t| {fmtUs after}\t\t| {speedup}\t| {growthA}\t| {growthB}"
    prevBefore := before
    prevAfter := after

  IO.println ""
  IO.println "Benchmark complete. growth(a) = after-impl growth ratio, growth(b) = before-impl growth ratio."
  IO.println "Note: Replacement-heavy (C) reference includes list-based ReplacementFrontier.acyclic (O(N²)), whereas currentOpenScheduled uses acyclicIndexedBy (linear O(N))."


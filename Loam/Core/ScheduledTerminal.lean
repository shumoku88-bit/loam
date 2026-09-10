import Loam.Core.Event
import Loam.Core.Scheduled

namespace Loam.Core

set_option autoImplicit false

/-!
# Scheduled terminal relation

A Scheduled occurrence can cease to be current-open in three retained ways:

- an Actual Event realizes it;
- another Scheduled occurrence replaces it;
- it is explicitly retired.

These are three meanings of one Scheduled-terminal relation, not three unrelated
memory mechanisms. The target preserves which meaning occurred:

```text
some (.actual event)          completion
some (.scheduled successor)   replacement
none                          retirement
```

Raw memory deliberately preserves the possibility of cross-kind conflict. Each
kind keeps the endpoint uniqueness already qualified by the former dedicated
memories, while application review remains responsible for rejecting a source
that carries competing terminal meanings. This keeps malformed retained evidence
observable instead of collapsing it into a generic decode failure.
-/

inductive ScheduledTerminalTarget where
  | actual (event : EventId)
  | scheduled (successor : ScheduledId)
deriving Repr, DecidableEq

structure ScheduledTerminal where
  source : ScheduledId
  target : Option ScheduledTerminalTarget
deriving Repr, DecidableEq

private def completionSource? (terminal : ScheduledTerminal) : Option ScheduledId :=
  match terminal.target with
  | some (.actual _) => some terminal.source
  | _ => none

private def completionActual? (terminal : ScheduledTerminal) : Option EventId :=
  match terminal.target with
  | some (.actual event) => some event
  | _ => none

private def retirementSource? (terminal : ScheduledTerminal) : Option ScheduledId :=
  match terminal.target with
  | none => some terminal.source
  | _ => none

private def replacementSource? (terminal : ScheduledTerminal) : Option ScheduledId :=
  match terminal.target with
  | some (.scheduled _) => some terminal.source
  | _ => none

private def replacementTarget? (terminal : ScheduledTerminal) : Option ScheduledId :=
  match terminal.target with
  | some (.scheduled successor) => some successor
  | _ => none

structure ScheduledTerminalMemory where
  terminals : List ScheduledTerminal
  completionSourceNodup : (terminals.filterMap completionSource?).Nodup
  completionActualNodup : (terminals.filterMap completionActual?).Nodup
  retirementSourceNodup : (terminals.filterMap retirementSource?).Nodup
  replacementSourceNodup : (terminals.filterMap replacementSource?).Nodup
  replacementTargetNodup : (terminals.filterMap replacementTarget?).Nodup

namespace ScheduledTerminalMemory

/--
Admit the existing per-kind uniqueness laws while retaining cross-kind source
conflict for application-level fail-closed review.
-/
def ofTerminals? (terminals : List ScheduledTerminal) : Option ScheduledTerminalMemory :=
  if hCompletionSource : (terminals.filterMap completionSource?).Nodup then
    if hCompletionActual : (terminals.filterMap completionActual?).Nodup then
      if hRetirementSource : (terminals.filterMap retirementSource?).Nodup then
        if hReplacementSource : (terminals.filterMap replacementSource?).Nodup then
          if hReplacementTarget : (terminals.filterMap replacementTarget?).Nodup then
            some {
              terminals := terminals
              completionSourceNodup := hCompletionSource
              completionActualNodup := hCompletionActual
              retirementSourceNodup := hRetirementSource
              replacementSourceNodup := hReplacementSource
              replacementTargetNodup := hReplacementTarget
            }
          else none
        else none
      else none
    else none
  else none

/-- Append one terminal claim while preserving the current per-kind raw shape. -/
def add?
    (memory : ScheduledTerminalMemory)
    (terminal : ScheduledTerminal) : Option ScheduledTerminalMemory :=
  ofTerminals? (memory.terminals ++ [terminal])

private def findCompletionActualIn?
    (terminals : List ScheduledTerminal)
    (id : ScheduledId) : Option EventId :=
  match terminals with
  | [] => none
  | terminal :: rest =>
      if terminal.source = id then
        match terminal.target with
        | some (.actual event) => some event
        | _ => findCompletionActualIn? rest id
      else
        findCompletionActualIn? rest id

private def findCompletionSourceIn?
    (terminals : List ScheduledTerminal)
    (id : EventId) : Option ScheduledId :=
  match terminals with
  | [] => none
  | terminal :: rest =>
      match terminal.target with
      | some (.actual event) =>
          if event = id then some terminal.source
          else findCompletionSourceIn? rest id
      | _ => findCompletionSourceIn? rest id

private def findRetirementIn?
    (terminals : List ScheduledTerminal)
    (id : ScheduledId) : Option ScheduledTerminal :=
  match terminals with
  | [] => none
  | terminal :: rest =>
      if terminal.source = id then
        match terminal.target with
        | none => some terminal
        | _ => findRetirementIn? rest id
      else
        findRetirementIn? rest id

private def findReplacementIn?
    (terminals : List ScheduledTerminal)
    (id : ScheduledId) : Option ScheduledId :=
  match terminals with
  | [] => none
  | terminal :: rest =>
      if terminal.source = id then
        match terminal.target with
        | some (.scheduled successor) => some successor
        | _ => findReplacementIn? rest id
      else
        findReplacementIn? rest id

private def findReplacementSourceIn?
    (terminals : List ScheduledTerminal)
    (id : ScheduledId) : Option ScheduledId :=
  match terminals with
  | [] => none
  | terminal :: rest =>
      match terminal.target with
      | some (.scheduled successor) =>
          if successor = id then some terminal.source
          else findReplacementSourceIn? rest id
      | _ => findReplacementSourceIn? rest id

/-- Actual endpoint retained for one Scheduled completion claim, if any. -/
def completionActualFor?
    (memory : ScheduledTerminalMemory)
    (id : ScheduledId) : Option EventId :=
  findCompletionActualIn? memory.terminals id

/-- Scheduled source that claims one Actual endpoint, if any. -/
def completionSourceForActual?
    (memory : ScheduledTerminalMemory)
    (id : EventId) : Option ScheduledId :=
  findCompletionSourceIn? memory.terminals id

/-- Explicit retirement claim for one Scheduled identity, if any. -/
def retirementFor?
    (memory : ScheduledTerminalMemory)
    (id : ScheduledId) : Option ScheduledTerminal :=
  findRetirementIn? memory.terminals id

/-- Replacement successor retained for one Scheduled source, if any. -/
def replacementFor?
    (memory : ScheduledTerminalMemory)
    (id : ScheduledId) : Option ScheduledId :=
  findReplacementIn? memory.terminals id

/-- Source whose replacement target is one Scheduled identity, if any. -/
def replacementSourceFor?
    (memory : ScheduledTerminalMemory)
    (id : ScheduledId) : Option ScheduledId :=
  findReplacementSourceIn? memory.terminals id

/-- True when one source carries more than one terminal meaning. -/
def hasCrossKindConflict (memory : ScheduledTerminalMemory) : Bool :=
  memory.terminals.any fun left =>
    memory.terminals.any fun right =>
      decide (left.source = right.source) && decide (left.target != right.target)

@[simp] theorem ofTerminals?_nil :
    ofTerminals? [] = some {
      terminals := []
      completionSourceNodup := by simp
      completionActualNodup := by simp
      retirementSourceNodup := by simp
      replacementSourceNodup := by simp
      replacementTargetNodup := by simp
    } := by
  simp [ofTerminals?]

end ScheduledTerminalMemory

end Loam.Core

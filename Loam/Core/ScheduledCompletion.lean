import Loam.Core.Event
import Loam.Core.Scheduled

namespace Loam.Core

set_option autoImplicit false

/-!
# Scheduled completion relation

Observation 063 showed that expected and Actual records do not determine which
Actual Event realizes which Scheduled occurrence. The correspondence therefore
survives explicitly rather than being inferred from matching date, amount,
Locus shape, or description.

This first practical relation intentionally has no independent identity. It
keeps the one-to-one partial-matching boundary already qualified by Observation
063. Split or merged realization remains future pressure rather than being
smuggled into the first writer.
-/

/-- Explicit evidence that one Scheduled occurrence is realized by one Actual Event. -/
structure ScheduledCompletion where
  scheduled : ScheduledId
  actual : EventId
deriving Repr, DecidableEq

/--
Raw append-oriented completion relations.

Uniqueness on both endpoints preserves the current one-to-one boundary. Raw
storage may temporarily contain a completion whose Actual Event is not yet
published; readers must check referenced evidence before treating it as live.
-/
structure ScheduledCompletionMemory where
  completions : List ScheduledCompletion
  scheduledNodup : (completions.map ScheduledCompletion.scheduled).Nodup
  actualNodup : (completions.map ScheduledCompletion.actual).Nodup

namespace ScheduledCompletionMemory

/-- Admit only one-to-one raw completion relations. -/
def ofCompletions? (completions : List ScheduledCompletion) : Option ScheduledCompletionMemory :=
  if hScheduled : (completions.map ScheduledCompletion.scheduled).Nodup then
    if hActual : (completions.map ScheduledCompletion.actual).Nodup then
      some {
        completions := completions
        scheduledNodup := hScheduled
        actualNodup := hActual
      }
    else
      none
  else
    none

/-- Append one completion relation while preserving endpoint uniqueness. -/
def add?
    (memory : ScheduledCompletionMemory)
    (completion : ScheduledCompletion) : Option ScheduledCompletionMemory :=
  ofCompletions? (memory.completions ++ [completion])

private def findByScheduledIn :
    List ScheduledCompletion → ScheduledId → Option ScheduledCompletion
  | [], _ => none
  | completion :: rest, id =>
      if completion.scheduled = id then
        some completion
      else
        findByScheduledIn rest id

/-- Find the retained completion relation for one Scheduled identity. -/
def findByScheduled?
    (memory : ScheduledCompletionMemory)
    (id : ScheduledId) : Option ScheduledCompletion :=
  findByScheduledIn memory.completions id

private def findByActualIn :
    List ScheduledCompletion → EventId → Option ScheduledCompletion
  | [], _ => none
  | completion :: rest, id =>
      if completion.actual = id then
        some completion
      else
        findByActualIn rest id

/-- Find the retained completion relation that uses one Actual Event identity. -/
def findByActual?
    (memory : ScheduledCompletionMemory)
    (id : EventId) : Option ScheduledCompletion :=
  findByActualIn memory.completions id

@[simp] theorem ofCompletions?_nil :
    ofCompletions? [] =
      some {
        completions := []
        scheduledNodup := by simp
        actualNodup := by simp
      } := by
  simp [ofCompletions?]

end ScheduledCompletionMemory

end Loam.Core

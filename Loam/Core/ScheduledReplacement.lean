import Loam.Core.Scheduled

namespace Loam.Core

set_option autoImplicit false

/-!
# Scheduled replacement provenance

Observation 105 showed that a mutable lifecycle status is too small when the
household later asks which Scheduled occurrence replaced which earlier one.
Observation 122 then separated this terminal replacement meaning from ordinary
next-occurrence continuation provenance.

This module therefore keeps only the explicit `Scheduled -> Scheduled` relation
already earned by those observations. It does not add an edit-kind enum,
postpone/advance tags, recurrence, Series, or continuation evidence.
-/

/-- Explicit evidence that one Scheduled occurrence is superseded by another. -/
structure ScheduledReplacement where
  source : ScheduledId
  replacement : ScheduledId
deriving Repr, DecidableEq

/--
Raw append-oriented replacement relations.

The current qualified boundary is one-to-one in both directions. A source cannot
have competing replacement successors, and one replacement cannot silently merge
several prior Scheduled occurrences. Referential closure, acyclicity, and
terminal compatibility remain application-level admission questions because they
depend on the surrounding retained Scheduled and lifecycle evidence.
-/
structure ScheduledReplacementMemory where
  replacements : List ScheduledReplacement
  sourceNodup : (replacements.map ScheduledReplacement.source).Nodup
  replacementNodup : (replacements.map ScheduledReplacement.replacement).Nodup

namespace ScheduledReplacementMemory

/-- Admit only the currently qualified one-to-one raw replacement shape. -/
def ofReplacements?
    (replacements : List ScheduledReplacement) : Option ScheduledReplacementMemory :=
  if hSource : (replacements.map ScheduledReplacement.source).Nodup then
    if hReplacement : (replacements.map ScheduledReplacement.replacement).Nodup then
      some {
        replacements := replacements
        sourceNodup := hSource
        replacementNodup := hReplacement
      }
    else
      none
  else
    none

/-- Append one raw replacement while preserving endpoint uniqueness. -/
def add?
    (memory : ScheduledReplacementMemory)
    (replacement : ScheduledReplacement) : Option ScheduledReplacementMemory :=
  ofReplacements? (memory.replacements ++ [replacement])

private def findBySourceIn :
    List ScheduledReplacement → ScheduledId → Option ScheduledReplacement
  | [], _ => none
  | replacement :: rest, id =>
      if replacement.source = id then
        some replacement
      else
        findBySourceIn rest id

/-- Find the retained replacement relation whose source is one Scheduled identity. -/
def findBySource?
    (memory : ScheduledReplacementMemory)
    (id : ScheduledId) : Option ScheduledReplacement :=
  findBySourceIn memory.replacements id

private def findByReplacementIn :
    List ScheduledReplacement → ScheduledId → Option ScheduledReplacement
  | [], _ => none
  | replacement :: rest, id =>
      if replacement.replacement = id then
        some replacement
      else
        findByReplacementIn rest id

/-- Find the retained relation that names one Scheduled identity as its replacement. -/
def findByReplacement?
    (memory : ScheduledReplacementMemory)
    (id : ScheduledId) : Option ScheduledReplacement :=
  findByReplacementIn memory.replacements id

@[simp] theorem ofReplacements?_nil :
    ofReplacements? [] =
      some {
        replacements := []
        sourceNodup := by simp
        replacementNodup := by simp
      } := by
  simp [ofReplacements?]

end ScheduledReplacementMemory

end Loam.Core

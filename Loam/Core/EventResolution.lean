import Loam.Core.EventCorrection

namespace Loam.Core

set_option autoImplicit false

/-- Stable identity for one explicit whole-frontier resolution relation. -/
structure EventResolutionId where
  token : String
deriving Repr, DecidableEq

/--
One explicit relation offering a new Event interpretation for several prior
candidate interpretations at once.

`parents` is representation only. Its list order carries no chronology,
priority, or authority. This raw relation does not by itself prove that the
parents cover a current conflict frontier or that the replacement is justified;
those are projection/admission questions.
-/
structure EventResolution where
  id : EventResolutionId
  parents : List EventId
  replacement : EventId
deriving Repr, DecidableEq

/--
A read-only result in which an unresolved correction frontier has been covered
by one explicit resolution relation and therefore has one offered effective
Event again.

The unresolved conflict remains attached as provenance. Nothing in this value
asserts why the resolution meaning is correct or who had authority to choose it.
-/
structure ResolvedCorrection where
  resolution : EventResolution
  conflict : UnresolvedCorrection
  effective : Event

namespace EventResolution

/-- Check that every named parent Event is still present in the same memory. -/
private def parentsPresent? (memory : EventMemory) : List EventId → Option Unit
  | [] => some ()
  | parent :: rest =>
      match EventMemory.findById? memory parent with
      | none => none
      | some _ => parentsPresent? memory rest

/--
Project a conflict resolution only when it covers the whole current unresolved
candidate frontier.

Coverage is compared modulo permutation so parent representation order is not
authoritative. The original conflict target, every parent, and the replacement
Event must all remain present in the same EventMemory. The replacement must not
reuse one of the frontier candidates. The result preserves the entire unresolved
conflict as provenance and exposes one effective Event again.

This is only structural admission from Observation 023. It does not establish
who may resolve a conflict, what evidence is required, or why the replacement
meaning should be trusted.
-/
def project?
    (memory : EventMemory)
    (conflict : UnresolvedCorrection)
    (resolution : EventResolution) : Option ResolvedCorrection :=
  if resolution.parents.Perm (UnresolvedCorrection.candidateIds conflict) then
    if resolution.replacement ∉ resolution.parents then
      match EventMemory.findById? memory conflict.target,
          parentsPresent? memory resolution.parents,
          EventMemory.findById? memory resolution.replacement with
      | some _, some _, some effective =>
          some { resolution := resolution, conflict := conflict, effective := effective }
      | _, _, _ => none
    else
      none
  else
    none

/-- A relation that omits any current frontier candidate cannot settle the conflict. -/
@[simp] theorem project?_partial
    (memory : EventMemory)
    (conflict : UnresolvedCorrection)
    (resolution : EventResolution)
    (hCoverage : ¬ resolution.parents.Perm (UnresolvedCorrection.candidateIds conflict)) :
    project? memory conflict resolution = none := by
  simp [project?, hCoverage]

/-- A relation cannot settle a frontier by reusing one of its own parent candidates. -/
@[simp] theorem project?_reusesParent
    (memory : EventMemory)
    (conflict : UnresolvedCorrection)
    (resolution : EventResolution)
    (hParent : resolution.replacement ∈ resolution.parents) :
    project? memory conflict resolution = none := by
  by_cases hCoverage : resolution.parents.Perm (UnresolvedCorrection.candidateIds conflict)
  · simp [project?, hCoverage, hParent]
  · simp [project?, hCoverage]

/-- Successful resolution projection certifies whole-frontier coverage. -/
theorem project?_some_covers
    (memory : EventMemory)
    (conflict : UnresolvedCorrection)
    (resolution : EventResolution)
    (projected : ResolvedCorrection)
    (hProjected : project? memory conflict resolution = some projected) :
    resolution.parents.Perm (UnresolvedCorrection.candidateIds conflict) := by
  unfold project? at hProjected
  split at hProjected
  next hCoverage => exact hCoverage
  next hCoverage => simp at hProjected

/-- Successful resolution projection certifies a replacement distinct from its parents. -/
theorem project?_some_fresh
    (memory : EventMemory)
    (conflict : UnresolvedCorrection)
    (resolution : EventResolution)
    (projected : ResolvedCorrection)
    (hProjected : project? memory conflict resolution = some projected) :
    resolution.replacement ∉ resolution.parents := by
  unfold project? at hProjected
  split at hProjected
  next hCoverage =>
    split at hProjected
    next hFresh => exact hFresh
    next hFresh => simp at hProjected
  next hCoverage => simp at hProjected

end EventResolution

end Loam.Core

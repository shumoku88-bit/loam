import Loam.Observations.Observation299

namespace Loam.Observation303

set_option autoImplicit false

/-!
# Observation 303 — search future distinctions only inside current-summary collisions

Observation 299 originally enumerated every ordered state pair and let the
trusted checker reject pairs whose current summaries differ.

That remains semantically sound, but it does unnecessary explorer work. This
observation adds one deliberately irrelevant state to the reveal model and asks
whether current-summary collision filtering can reduce the bounded candidate
set without changing the trusted checker or losing the known witness.

The optimization belongs entirely outside the trust boundary.
-/

private def hiddenFalse : Loam.Observation192.RevealState :=
  { visible := false, hidden := false }

private def hiddenTrue : Loam.Observation192.RevealState :=
  { visible := false, hidden := true }

/-- A distractor state whose current summary is already visibly different. -/
private def visibleTrue : Loam.Observation192.RevealState :=
  { visible := true, hidden := false }

private def states : List Loam.Observation192.RevealState :=
  [hiddenFalse, hiddenTrue, visibleTrue]

private def operations : List Loam.Observation192.RevealOperation :=
  [.reveal]

private def questions : List Loam.Observation192.RevealQuestion :=
  [.visible]

private def searchSpace :
    Loam.Observation299.SearchSpace
      Loam.Observation192.RevealState
      Loam.Observation192.RevealOperation
      Loam.Observation192.RevealQuestion :=
  { states := states
    operations := operations
    questions := questions
    depth := 1 }

/--
Without filtering, three ordered states produce nine state pairs and two
continuations (empty and reveal): 18 payloads.
-/
theorem unfiltered_candidate_count :
    searchSpace.candidateCount = 18 := by
  native_decide

/--
Current-summary collision filtering keeps the four ordered pairs inside the
visible=false class plus the visible=true self-pair. With two continuations this
leaves 10 payloads.
-/
theorem summary_collision_candidate_count :
    searchSpace.summaryCollisionCandidateCount
      Loam.Observation192.encodeVisible = 10 := by
  native_decide


/--
Removing self-pairs and symmetric duplicates leaves one distinct colliding pair
(the two visible=false worlds). With two continuations, only two payloads remain.
-/
theorem distinct_summary_collision_candidate_count :
    searchSpace.distinctSummaryCollisionCandidateCount
      Loam.Observation192.encodeVisible = 2 := by
  native_decide

/-- The collision-prefiltered explorer still discovers the reveal witness. -/
def collisionSearch :=
  searchSpace.searchSummaryCollisions
    Loam.Observation192.revealAnswer
    Loam.Observation192.revealStep
    Loam.Observation192.VisibleVocabulary
    Loam.Observation298.decideVisibleVocabulary
    Loam.Observation192.encodeVisible

theorem collision_search_finds_counterexample :
    collisionSearch.isSome = true := by
  native_decide


/-- Search the same fixture using distinct unordered summary collisions only. -/
def distinctCollisionSearch :=
  searchSpace.searchDistinctSummaryCollisions
    Loam.Observation192.revealAnswer
    Loam.Observation192.revealStep
    Loam.Observation192.VisibleVocabulary
    Loam.Observation298.decideVisibleVocabulary
    Loam.Observation192.encodeVisible

theorem distinct_collision_search_finds_counterexample :
    distinctCollisionSearch.isSome = true := by
  native_decide

/--
The optimization changes only candidate generation. The same small checker
certifies the discovered payload and therefore refutes future sufficiency.
-/
theorem collision_search_refutes_visible_summary :
    ¬ Loam.Observation192.FutureSufficient
      Loam.Observation192.revealAnswer
      Loam.Observation192.revealStep
      Loam.Observation192.VisibleVocabulary
      Loam.Observation192.encodeVisible := by
  have hSome : collisionSearch.isSome = true :=
    collision_search_finds_counterexample
  cases hSearch : collisionSearch with
  | none =>
      simp [hSearch] at hSome
  | some payload =>
      exact
        searchSpace.searchSummaryCollisions_some_refutes_futureSufficient
          Loam.Observation192.revealAnswer
          Loam.Observation192.revealStep
          Loam.Observation192.VisibleVocabulary
          Loam.Observation298.decideVisibleVocabulary
          Loam.Observation192.encodeVisible
          payload
          (by simpa [collisionSearch] using hSearch)


/--
The narrowest explorer still returns a checker-certified witness.
-/
theorem distinct_collision_search_refutes_visible_summary :
    ¬ Loam.Observation192.FutureSufficient
      Loam.Observation192.revealAnswer
      Loam.Observation192.revealStep
      Loam.Observation192.VisibleVocabulary
      Loam.Observation192.encodeVisible := by
  have hSome : distinctCollisionSearch.isSome = true :=
    distinct_collision_search_finds_counterexample
  cases hSearch : distinctCollisionSearch with
  | none =>
      simp [hSearch] at hSome
  | some payload =>
      exact
        searchSpace.searchDistinctSummaryCollisions_some_refutes_futureSufficient
          Loam.Observation192.revealAnswer
          Loam.Observation192.revealStep
          Loam.Observation192.VisibleVocabulary
          Loam.Observation298.decideVisibleVocabulary
          Loam.Observation192.encodeVisible
          payload
          (by simpa [distinctCollisionSearch] using hSearch)

/-!
## Finding

The bounded exploration pipeline can now be decomposed explicitly:

    finite semantic worlds
            |
            v
      current summaries
            |
            v
    summary-colliding pairs
            |
            v
   bounded future contexts
            |
            v
    Observation-298 checker
            |
            v
      certified witness

In the small reveal fixture, the candidate count falls from 18 to 10 after
current-summary filtering and then to 2 after removing self-pairs and symmetric
duplicates. The known depth-one future distinction remains discoverable.

No new semantic trust is placed in the collision filter. A buggy or incomplete
explorer may miss witnesses, but anything it does return must still pass the
same checker before it can refute `FutureSufficient`.
-/

end Loam.Observation303

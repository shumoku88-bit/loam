---- MODULE ProvenanceWithoutResourceIdentity ----
EXTENDS FiniteSets, Naturals

Purposes == {"p0", "p1"}
Events == {"e0", "e1", "e2", "e3"}

EventPurpose ==
  [e \in Events |-> IF e \in {"e0", "e1"} THEN "p0" ELSE "p1"]

Capacity == [p \in Purposes |-> 2]

VARIABLES active, leftActive, rightActive

vars == <<active, leftActive, rightActive>>

EventsAt(S, p) == {e \in S : EventPurpose[e] = p}
Committed(S, p) == Cardinality(EventsAt(S, p))
Available(S, p) == Capacity[p] - Committed(S, p)
Explanation(S, p) == EventsAt(S, p)

CanCommit(S, e) ==
  /\ e \notin S
  /\ Committed(S, EventPurpose[e]) < Capacity[EventPurpose[e]]

CanUndo(S, e) == e \in S

Init ==
  /\ active = {}
  /\ leftActive = {"e0"}
  /\ rightActive = {"e1"}

Commit(e) ==
  /\ CanCommit(active, e)
  /\ active' = active \cup {e}
  /\ UNCHANGED <<leftActive, rightActive>>

Undo(e) ==
  /\ CanUndo(active, e)
  /\ active' = active \ {e}
  /\ UNCHANGED <<leftActive, rightActive>>

Next == \E e \in Events : Commit(e) \/ Undo(e)

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ active \subseteq Events
  /\ leftActive \subseteq Events
  /\ rightActive \subseteq Events

CapacityOK ==
  \A p \in Purposes : Committed(active, p) <= Capacity[p]

ExplanationMatchesAggregate ==
  \A p \in Purposes : Cardinality(Explanation(active, p)) = Committed(active, p)

CauseVisible ==
  \A e \in active : e \in Explanation(active, EventPurpose[e])

UndoEnabledExactlyActive ==
  \A e \in Events : (ENABLED Undo(e)) = CanUndo(active, e)

TargetedUndoRemovesExactlyOne ==
  \A e \in Events :
    e \in active =>
      /\ Committed(active \ {e}, EventPurpose[e]) + 1
           = Committed(active, EventPurpose[e])
      /\ \A p \in Purposes \ {EventPurpose[e]} :
           Committed(active \ {e}, p) = Committed(active, p)

SameAggregateBoundary ==
  \A p \in Purposes : Committed(leftActive, p) = Committed(rightActive, p)

AggregateDeterminesExplanation ==
  SameAggregateBoundary =>
    \A p \in Purposes : Explanation(leftActive, p) = Explanation(rightActive, p)

AggregateDeterminesNamedUndo ==
  SameAggregateBoundary =>
    (CanUndo(leftActive, "e0") = CanUndo(rightActive, "e0"))

====

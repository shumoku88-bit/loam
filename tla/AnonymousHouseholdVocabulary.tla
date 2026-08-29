---- MODULE AnonymousHouseholdVocabulary ----
EXTENDS FiniteSets

Units == {"u0", "u1", "u2", "u3"}
P0 == "p0"
P1 == "p1"
Purposes == {P0, P1}

VARIABLES leftPlace, rightPlace, leftCommitted, rightCommitted

vars == <<leftPlace, rightPlace, leftCommitted, rightCommitted>>

FixedPlacement ==
  [u \in Units |->
    IF u \in {"u0", "u1"}
    THEN P0
    ELSE P1]

Init ==
  /\ leftPlace = FixedPlacement
  /\ rightPlace = FixedPlacement
  /\ leftCommitted = {"u0", "u2"}
  /\ rightCommitted = {"u1", "u3"}

UnitsAt(place, p) ==
  {u \in Units : place[u] = p}

CommittedAt(place, committed, p) ==
  {u \in Units : place[u] = p /\ u \in committed}

TotalAt(place, p) == Cardinality(UnitsAt(place, p))
CommittedCountAt(place, committed, p) ==
  Cardinality(CommittedAt(place, committed, p))

SameAnonymousProjection ==
  \A p \in Purposes :
    /\ TotalAt(leftPlace, p) = TotalAt(rightPlace, p)
    /\ CommittedCountAt(leftPlace, leftCommitted, p) =
       CommittedCountAt(rightPlace, rightCommitted, p)

MayCommit(place, committed, p) ==
  \E u \in Units :
    /\ place[u] = p
    /\ u \notin committed

MayRelease(place, committed, p) ==
  \E u \in Units :
    /\ place[u] = p
    /\ u \in committed

MayReassign(place, committed, p, q) ==
  /\ p # q
  /\ \E u \in Units :
       /\ place[u] = p
       /\ u \notin committed

AnonymousEnabledAgreement ==
  /\ \A p \in Purposes :
       MayCommit(leftPlace, leftCommitted, p) =
       MayCommit(rightPlace, rightCommitted, p)
  /\ \A p \in Purposes :
       MayRelease(leftPlace, leftCommitted, p) =
       MayRelease(rightPlace, rightCommitted, p)
  /\ \A p \in Purposes :
       \A q \in Purposes :
         MayReassign(leftPlace, leftCommitted, p, q) =
         MayReassign(rightPlace, rightCommitted, p, q)

NamedMayReassign(place, committed, u, q) ==
  /\ u \notin committed
  /\ place[u] # q

NamedPermissionAgreement ==
  \A u \in Units :
    \A q \in Purposes :
      NamedMayReassign(leftPlace, leftCommitted, u, q) =
      NamedMayReassign(rightPlace, rightCommitted, u, q)

CommitBoth(p) ==
  \E lu \in Units :
    \E ru \in Units :
      /\ leftPlace[lu] = p
      /\ lu \notin leftCommitted
      /\ rightPlace[ru] = p
      /\ ru \notin rightCommitted
      /\ leftCommitted' = leftCommitted \cup {lu}
      /\ rightCommitted' = rightCommitted \cup {ru}
      /\ UNCHANGED <<leftPlace, rightPlace>>

ReleaseBoth(p) ==
  \E lu \in Units :
    \E ru \in Units :
      /\ leftPlace[lu] = p
      /\ lu \in leftCommitted
      /\ rightPlace[ru] = p
      /\ ru \in rightCommitted
      /\ leftCommitted' = leftCommitted \ {lu}
      /\ rightCommitted' = rightCommitted \ {ru}
      /\ UNCHANGED <<leftPlace, rightPlace>>

ReassignBoth(p, q) ==
  /\ p # q
  /\ \E lu \in Units :
       \E ru \in Units :
         /\ leftPlace[lu] = p
         /\ lu \notin leftCommitted
         /\ rightPlace[ru] = p
         /\ ru \notin rightCommitted
         /\ leftPlace' = [leftPlace EXCEPT ![lu] = q]
         /\ rightPlace' = [rightPlace EXCEPT ![ru] = q]
         /\ UNCHANGED <<leftCommitted, rightCommitted>>

Next ==
  \/ \E p \in Purposes : CommitBoth(p)
  \/ \E p \in Purposes : ReleaseBoth(p)
  \/ \E p \in Purposes :
       \E q \in Purposes : ReassignBoth(p, q)

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ leftPlace \in [Units -> Purposes]
  /\ rightPlace \in [Units -> Purposes]
  /\ leftCommitted \subseteq Units
  /\ rightCommitted \subseteq Units

====

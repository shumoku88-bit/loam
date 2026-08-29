---- MODULE MinimalSufficientHistory ----
EXTENDS FiniteSets

Units == {"u0", "u1"}
P0 == "p0"
P1 == "p1"
Purposes == {P0, P1}
Target == P0

VARIABLES place, stayed, u0Stayed

vars == <<place, stayed, u0Stayed>>

Init ==
  /\ place \in [Units -> Purposes]
  /\ stayed = {u \in Units : place[u] = Target}
  /\ u0Stayed = (place["u0"] = Target)

Step ==
  \E newPlace \in [Units -> Purposes] :
    /\ place' = newPlace
    /\ stayed' = stayed \cap {u \in Units : newPlace[u] = Target}
    /\ u0Stayed' = (u0Stayed /\ (newPlace["u0"] = Target))

Spec == Init /\ [][Step]_vars

TypeOK ==
  /\ place \in [Units -> Purposes]
  /\ stayed \subseteq Units
  /\ u0Stayed \in BOOLEAN

BitIsProjectionOfFullSummary ==
  u0Stayed = ("u0" \in stayed)

FullContinuityUse ==
  /\ "u0" \in stayed
  /\ UNCHANGED vars

BitContinuityUse ==
  /\ u0Stayed
  /\ UNCHANGED vars

EnabledEquivalent ==
  (ENABLED FullContinuityUse) = (ENABLED BitContinuityUse)

====

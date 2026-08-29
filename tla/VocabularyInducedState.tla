---- MODULE VocabularyInducedState ----
EXTENDS FiniteSets

Units == {"u0", "u1"}
Target == "target"
Other == "other"
Purposes == {Target, Other}

VARIABLES place, stayed, u0Stayed, u1Stayed

vars == <<place, stayed, u0Stayed, u1Stayed>>

AtTarget(p) == {u \in Units : p[u] = Target}

Init ==
  /\ place \in [Units -> Purposes]
  /\ stayed = AtTarget(place)
  /\ u0Stayed = ("u0" \in stayed)
  /\ u1Stayed = ("u1" \in stayed)

Move ==
  \E newPlace \in [Units -> Purposes] :
    /\ place' = newPlace
    /\ stayed' = stayed \cap AtTarget(newPlace)
    /\ u0Stayed' = u0Stayed /\ (newPlace["u0"] = Target)
    /\ u1Stayed' = u1Stayed /\ (newPlace["u1"] = Target)

Next == Move

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ place \in [Units -> Purposes]
  /\ stayed \subseteq Units
  /\ u0Stayed \in BOOLEAN
  /\ u1Stayed \in BOOLEAN

BitsMatchOracle ==
  /\ u0Stayed = ("u0" \in stayed)
  /\ u1Stayed = ("u1" \in stayed)

OracleUse0 ==
  /\ "u0" \in stayed
  /\ UNCHANGED vars

BitUse0 ==
  /\ u0Stayed
  /\ UNCHANGED vars

OracleUse1 ==
  /\ "u1" \in stayed
  /\ UNCHANGED vars

BitUse1 ==
  /\ u1Stayed
  /\ UNCHANGED vars

VocabularyEnablednessPreserved ==
  /\ (ENABLED OracleUse0) = (ENABLED BitUse0)
  /\ (ENABLED OracleUse1) = (ENABLED BitUse1)

====

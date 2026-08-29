---- MODULE CommitmentIdentitySummary ----
EXTENDS FiniteSets

Units == {"u0", "u1"}
P0 == "p0"
P1 == "p1"
Purposes == {P0, P1}
None == "none"
ActiveValues == Purposes \cup {None}

VARIABLES place, used, active, committed

vars == <<place, used, active, committed>>

Init ==
  /\ place \in [Units -> Purposes]
  /\ used = {}
  /\ active = [u \in Units |-> None]
  /\ committed = {}

OracleDeclareEnabled(u, p) ==
  /\ u \notin used
  /\ active[u] = None
  /\ place[u] = p

SummaryDeclareEnabled(u, p) ==
  /\ u \notin used
  /\ u \notin committed
  /\ place[u] = p

OracleReleaseEnabled(u, p) ==
  /\ u \notin used
  /\ active[u] = p

SummaryReleaseEnabled(u, p) ==
  /\ u \notin used
  /\ u \in committed
  /\ place[u] = p

OracleMayReassign(u, q) ==
  /\ u \notin used
  /\ active[u] = None
  /\ place[u] # q

SummaryMayReassign(u, q) ==
  /\ u \notin used
  /\ u \notin committed
  /\ place[u] # q

OracleUseEnabled(u) ==
  /\ u \notin used
  /\ active[u] = None

SummaryUseEnabled(u) ==
  /\ u \notin used
  /\ u \notin committed

Declare(u, p) ==
  /\ OracleDeclareEnabled(u, p)
  /\ active' = [active EXCEPT ![u] = p]
  /\ committed' = committed \cup {u}
  /\ UNCHANGED <<place, used>>

Release(u, p) ==
  /\ OracleReleaseEnabled(u, p)
  /\ active' = [active EXCEPT ![u] = None]
  /\ committed' = committed \ {u}
  /\ UNCHANGED <<place, used>>

Reassign(u, q) ==
  /\ OracleMayReassign(u, q)
  /\ place' = [place EXCEPT ![u] = q]
  /\ UNCHANGED <<used, active, committed>>

Use(u) ==
  /\ OracleUseEnabled(u)
  /\ used' = used \cup {u}
  /\ UNCHANGED <<place, active, committed>>

Next ==
  \/ \E u \in Units, p \in Purposes : Declare(u, p)
  \/ \E u \in Units, p \in Purposes : Release(u, p)
  \/ \E u \in Units, q \in Purposes : Reassign(u, q)
  \/ \E u \in Units : Use(u)

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ place \in [Units -> Purposes]
  /\ used \subseteq Units
  /\ active \in [Units -> ActiveValues]
  /\ committed \subseteq Units

CommitmentPlacementLaw ==
  \A u \in Units :
    active[u] # None => active[u] = place[u]

SummaryMatchesOracle ==
  committed = {u \in Units : active[u] # None}

ReconstructedActive ==
  [u \in Units |-> IF u \in committed THEN place[u] ELSE None]

ReconstructionMatchesOracle ==
  active = ReconstructedActive

VocabularyEnablednessEquivalent ==
  /\ \A u \in Units, p \in Purposes :
       OracleDeclareEnabled(u, p) = SummaryDeclareEnabled(u, p)
  /\ \A u \in Units, p \in Purposes :
       OracleReleaseEnabled(u, p) = SummaryReleaseEnabled(u, p)
  /\ \A u \in Units, q \in Purposes :
       OracleMayReassign(u, q) = SummaryMayReassign(u, q)
  /\ \A u \in Units :
       OracleUseEnabled(u) = SummaryUseEnabled(u)

====

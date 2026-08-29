---- MODULE AppendOnlyProvenance ----
EXTENDS FiniteSets, Naturals, Sequences

Purposes == {"p0", "p1"}
CommitEvents == {"c0", "c1", "c2", "c3"}
ReverseEvents == {"r0", "r1", "r2", "r3"}
AllEvents == CommitEvents \cup ReverseEvents

CommitPurpose ==
  [c \in CommitEvents |-> IF c \in {"c0", "c1"} THEN "p0" ELSE "p1"]

ReverseTarget ==
  [r \in ReverseEvents |->
    IF r = "r0" THEN "c0"
    ELSE IF r = "r1" THEN "c1"
    ELSE IF r = "r2" THEN "c2"
    ELSE "c3"]

Capacity == [p \in Purposes |-> 2]

VARIABLES history, oracleActive, leftHistory, rightHistory

vars == <<history, oracleActive, leftHistory, rightHistory>>

Seen(H) == {H[i] : i \in DOMAIN H}
ReversedCommits(H) == {ReverseTarget[r] : r \in Seen(H) \cap ReverseEvents}
ActiveFromHistory(H) == (Seen(H) \cap CommitEvents) \ ReversedCommits(H)
ActiveAt(H, p) == {c \in ActiveFromHistory(H) : CommitPurpose[c] = p}
Committed(H, p) == Cardinality(ActiveAt(H, p))
Available(H, p) == Capacity[p] - Committed(H, p)
CurrentExplanation(H, p) == ActiveAt(H, p)

OracleAt(S, p) == {c \in S : CommitPurpose[c] = p}
OracleCommitted(S, p) == Cardinality(OracleAt(S, p))

CanCommit(H, c) ==
  /\ c \in CommitEvents
  /\ c \notin Seen(H)
  /\ Committed(H, CommitPurpose[c]) < Capacity[CommitPurpose[c]]

CanReverse(H, r) ==
  /\ r \in ReverseEvents
  /\ r \notin Seen(H)
  /\ ReverseTarget[r] \in ActiveFromHistory(H)

Init ==
  /\ history = <<>>
  /\ oracleActive = {}
  /\ leftHistory = <<>>
  /\ rightHistory = <<"c0", "r0">>

Commit(c) ==
  /\ CanCommit(history, c)
  /\ history' = Append(history, c)
  /\ oracleActive' = oracleActive \cup {c}
  /\ UNCHANGED <<leftHistory, rightHistory>>

Reverse(r) ==
  /\ CanReverse(history, r)
  /\ history' = Append(history, r)
  /\ oracleActive' = oracleActive \ {ReverseTarget[r]}
  /\ UNCHANGED <<leftHistory, rightHistory>>

Next ==
  \/ \E c \in CommitEvents : Commit(c)
  \/ \E r \in ReverseEvents : Reverse(r)

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK ==
  /\ history \in Seq(AllEvents)
  /\ oracleActive \subseteq CommitEvents
  /\ leftHistory \in Seq(AllEvents)
  /\ rightHistory \in Seq(AllEvents)

ProjectionMatchesOracle ==
  ActiveFromHistory(history) = oracleActive

CapacityOK ==
  \A p \in Purposes : Committed(history, p) <= Capacity[p]

CurrentExplanationMatchesAggregate ==
  \A p \in Purposes :
    Cardinality(CurrentExplanation(history, p)) = Committed(history, p)

AvailableMatchesOracle ==
  \A p \in Purposes :
    Available(history, p) = Capacity[p] - OracleCommitted(oracleActive, p)

ReversalKeepsCause ==
  \A r \in Seen(history) \cap ReverseEvents :
    /\ ReverseTarget[r] \in Seen(history)
    /\ ReverseTarget[r] \notin ActiveFromHistory(history)

TargetedReverseIsExact ==
  \A r \in ReverseEvents :
    CanReverse(history, r) =>
      ActiveFromHistory(Append(history, r))
        = ActiveFromHistory(history) \ {ReverseTarget[r]}

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

SameCurrentProjectionBoundary ==
  /\ \A p \in Purposes : Committed(leftHistory, p) = Committed(rightHistory, p)
  /\ \A p \in Purposes : CurrentExplanation(leftHistory, p) = CurrentExplanation(rightHistory, p)

CurrentProjectionDeterminesHistory ==
  SameCurrentProjectionBoundary => leftHistory = rightHistory

====

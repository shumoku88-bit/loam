---- MODULE UnresolvedCorrectionConflict ----
EXTENDS FiniteSets, Naturals, Sequences

Corrections == {"kA", "kB"}
AllEvents == {"c0"} \cup Corrections

VARIABLE history

vars == <<history>>

Seen(H) == {H[i] : i \in DOMAIN H}

Tips(H) ==
  IF Seen(H) \cap Corrections = {}
  THEN {"c0"}
  ELSE Seen(H) \cap Corrections

Conflict(H) == Cardinality(Tips(H)) > 1

SingleMeaningEnabled(H) == Cardinality(Tips(H)) = 1

ConflictView(H) ==
  [kind |-> IF Conflict(H) THEN "conflict" ELSE "settled",
   candidates |-> Tips(H)]

CanAppend(H, k) ==
  /\ k \in Corrections
  /\ k \notin Seen(H)

Init == history = <<"c0">>

AppendCorrection(k) ==
  /\ CanAppend(history, k)
  /\ history' = Append(history, k)

Next == \E k \in Corrections : AppendCorrection(k)

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK == history \in Seq(AllEvents)

NoImplicitWinner ==
  Conflict(history) => ~SingleMeaningEnabled(history)

CompleteConflictIsPreserved ==
  Corrections \subseteq Seen(history) =>
    /\ Conflict(history)
    /\ Tips(history) = Corrections
    /\ ConflictView(history).kind = "conflict"
    /\ ConflictView(history).candidates = Corrections

ArrivalOrderDoesNotChooseAuthority ==
  ConflictView(<<"c0", "kA", "kB">>)
    = ConflictView(<<"c0", "kB", "kA">>)

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

ABReached == history = <<"c0", "kA", "kB">>
BAReached == history = <<"c0", "kB", "kA">>

NoABWitness == ~ABReached
NoBAWitness == ~BAReached

====

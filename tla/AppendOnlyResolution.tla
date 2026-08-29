---- MODULE AppendOnlyResolution ----
EXTENDS FiniteSets, Naturals, Sequences

Corrections == {"kA", "kB"}
Resolution == "r0"
AllEvents == {"c0", Resolution} \cup Corrections

VARIABLE history

vars == <<history>>

Seen(H) == {H[i] : i \in DOMAIN H}

Parents(e) ==
  CASE e = "kA" -> {"c0"}
    [] e = "kB" -> {"c0"}
    [] e = Resolution -> Corrections
    [] OTHER -> {}

ChildrenSeen(H, e) ==
  {x \in Seen(H) : e \in Parents(x)}

Frontier(H) ==
  {e \in Seen(H) : ChildrenSeen(H, e) = {}}

Conflict(H) == Cardinality(Frontier(H)) > 1
SingleMeaningEnabled(H) == Cardinality(Frontier(H)) = 1

CurrentView(H) ==
  [kind |-> IF Conflict(H) THEN "conflict" ELSE "settled",
   candidates |-> Frontier(H)]

CanAppendCorrection(H, k) ==
  /\ k \in Corrections
  /\ k \notin Seen(H)
  /\ Resolution \notin Seen(H)

CanAppendResolution(H) ==
  /\ Resolution \notin Seen(H)
  /\ Corrections \subseteq Seen(H)
  /\ Frontier(H) = Corrections

Init == history = <<"c0">>

AppendCorrection(k) ==
  /\ CanAppendCorrection(history, k)
  /\ history' = Append(history, k)

AppendResolution ==
  /\ CanAppendResolution(history)
  /\ history' = Append(history, Resolution)

Next ==
  \/ \E k \in Corrections : AppendCorrection(k)
  \/ AppendResolution

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK == history \in Seq(AllEvents)

ConflictBeforeResolutionIsPreserved ==
  (Corrections \subseteq Seen(history) /\ Resolution \notin Seen(history)) =>
    /\ Conflict(history)
    /\ Frontier(history) = Corrections
    /\ ~SingleMeaningEnabled(history)

ResolutionRequiresWholeConflict ==
  CanAppendResolution(history) =>
    /\ Conflict(history)
    /\ Frontier(history) = Corrections

ResolutionSettlesFrontier ==
  Resolution \in Seen(history) =>
    /\ Frontier(history) = {Resolution}
    /\ ~Conflict(history)
    /\ SingleMeaningEnabled(history)
    /\ Corrections \subseteq Seen(history)

ArrivalOrderDoesNotChangeResolvedView ==
  CurrentView(<<"c0", "kA", "kB", Resolution>>)
    = CurrentView(<<"c0", "kB", "kA", Resolution>>)

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

ABRReached == history = <<"c0", "kA", "kB", Resolution>>
BARReached == history = <<"c0", "kB", "kA", Resolution>>

NoABRWitness == ~ABRReached
NoBARWitness == ~BARReached

====

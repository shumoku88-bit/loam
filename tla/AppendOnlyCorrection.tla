---- MODULE AppendOnlyCorrection ----
EXTENDS FiniteSets, Naturals, Sequences

Purposes == {"p0", "p1"}
CommitEvents == {"c0", "c1"}
CorrectionEvents == {"k0", "k1"}
ReverseEvents == {"r0", "r1"}
AllEvents == CommitEvents \cup CorrectionEvents \cup ReverseEvents

CommitPurpose ==
  [c \in CommitEvents |-> IF c = "c0" THEN "p0" ELSE "p1"]

CommitQuantity ==
  [c \in CommitEvents |-> 1]

CorrectionTarget ==
  [k \in CorrectionEvents |-> IF k = "k0" THEN "c0" ELSE "c1"]

CorrectionOf ==
  [c \in CommitEvents |-> IF c = "c0" THEN "k0" ELSE "k1"]

CorrectionPurpose ==
  [k \in CorrectionEvents |-> "p1"]

CorrectionQuantity ==
  [k \in CorrectionEvents |-> IF k = "k0" THEN 1 ELSE 2]

ReverseTarget ==
  [r \in ReverseEvents |-> IF r = "r0" THEN "c0" ELSE "c1"]

Capacity == [p \in Purposes |-> 3]

VARIABLES history,
          oracleActive,
          oraclePurpose,
          oracleQuantity,
          leftHistory,
          rightHistory

vars == <<history,
          oracleActive,
          oraclePurpose,
          oracleQuantity,
          leftHistory,
          rightHistory>>

Seen(H) == {H[i] : i \in DOMAIN H}

ReversedCommits(H) ==
  {ReverseTarget[r] : r \in Seen(H) \cap ReverseEvents}

ActiveFromHistory(H) ==
  (Seen(H) \cap CommitEvents) \ ReversedCommits(H)

CorrectionSeen(H, c) ==
  CorrectionOf[c] \in Seen(H)

EffectivePurpose(H, c) ==
  IF CorrectionSeen(H, c)
  THEN CorrectionPurpose[CorrectionOf[c]]
  ELSE CommitPurpose[c]

EffectiveQuantity(H, c) ==
  IF CorrectionSeen(H, c)
  THEN CorrectionQuantity[CorrectionOf[c]]
  ELSE CommitQuantity[c]

CommittedQuantity(H, p) ==
  (IF "c0" \in ActiveFromHistory(H) /\ EffectivePurpose(H, "c0") = p
   THEN EffectiveQuantity(H, "c0")
   ELSE 0)
  +
  (IF "c1" \in ActiveFromHistory(H) /\ EffectivePurpose(H, "c1") = p
   THEN EffectiveQuantity(H, "c1")
   ELSE 0)

Available(H, p) ==
  Capacity[p] - CommittedQuantity(H, p)

OracleCommittedQuantity(S, OP, OQ, p) ==
  (IF "c0" \in S /\ OP["c0"] = p THEN OQ["c0"] ELSE 0)
  +
  (IF "c1" \in S /\ OP["c1"] = p THEN OQ["c1"] ELSE 0)

CurrentExplanation(H, c) ==
  [commit |-> c,
   originalPurpose |-> CommitPurpose[c],
   originalQuantity |-> CommitQuantity[c],
   effectivePurpose |-> EffectivePurpose(H, c),
   effectiveQuantity |-> EffectiveQuantity(H, c),
   correction |-> IF CorrectionSeen(H, c) THEN CorrectionOf[c] ELSE "none"]

CanCommit(H, c) ==
  /\ c \in CommitEvents
  /\ c \notin Seen(H)
  /\ \A p \in Purposes :
       CommittedQuantity(Append(H, c), p) <= Capacity[p]

CanCorrect(H, k) ==
  /\ k \in CorrectionEvents
  /\ k \notin Seen(H)
  /\ CorrectionTarget[k] \in Seen(H) \cap CommitEvents
  /\ \A p \in Purposes :
       CommittedQuantity(Append(H, k), p) <= Capacity[p]

CanReverse(H, r) ==
  /\ r \in ReverseEvents
  /\ r \notin Seen(H)
  /\ ReverseTarget[r] \in ActiveFromHistory(H)

Init ==
  /\ history = <<>>
  /\ oracleActive = {}
  /\ oraclePurpose = CommitPurpose
  /\ oracleQuantity = CommitQuantity
  /\ leftHistory = <<"c1">>
  /\ rightHistory = <<"c0", "k0">>

Commit(c) ==
  /\ CanCommit(history, c)
  /\ history' = Append(history, c)
  /\ oracleActive' = oracleActive \cup {c}
  /\ UNCHANGED <<oraclePurpose,
                  oracleQuantity,
                  leftHistory,
                  rightHistory>>

Correct(k) ==
  /\ CanCorrect(history, k)
  /\ history' = Append(history, k)
  /\ oraclePurpose' =
       [oraclePurpose EXCEPT ![CorrectionTarget[k]] = CorrectionPurpose[k]]
  /\ oracleQuantity' =
       [oracleQuantity EXCEPT ![CorrectionTarget[k]] = CorrectionQuantity[k]]
  /\ UNCHANGED <<oracleActive, leftHistory, rightHistory>>

Reverse(r) ==
  /\ CanReverse(history, r)
  /\ history' = Append(history, r)
  /\ oracleActive' = oracleActive \ {ReverseTarget[r]}
  /\ UNCHANGED <<oraclePurpose,
                  oracleQuantity,
                  leftHistory,
                  rightHistory>>

Next ==
  \/ \E c \in CommitEvents : Commit(c)
  \/ \E k \in CorrectionEvents : Correct(k)
  \/ \E r \in ReverseEvents : Reverse(r)

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

OccursBefore(H, earlier, later) ==
  \E i, j \in DOMAIN H :
    /\ i < j
    /\ H[i] = earlier
    /\ H[j] = later

TypeOK ==
  /\ history \in Seq(AllEvents)
  /\ oracleActive \subseteq CommitEvents
  /\ oraclePurpose \in [CommitEvents -> Purposes]
  /\ oracleQuantity \in [CommitEvents -> {1, 2}]
  /\ leftHistory \in Seq(AllEvents)
  /\ rightHistory \in Seq(AllEvents)

ProjectionMatchesOracle ==
  ActiveFromHistory(history) = oracleActive

EffectiveMeaningMatchesOracle ==
  \A c \in Seen(history) \cap CommitEvents :
    /\ EffectivePurpose(history, c) = oraclePurpose[c]
    /\ EffectiveQuantity(history, c) = oracleQuantity[c]

CurrentAggregateMatchesOracle ==
  \A p \in Purposes :
    CommittedQuantity(history, p)
      = OracleCommittedQuantity(oracleActive,
                                oraclePurpose,
                                oracleQuantity,
                                p)

CapacityOK ==
  \A p \in Purposes : CommittedQuantity(history, p) <= Capacity[p]

AvailableMatchesOracle ==
  \A p \in Purposes :
    Available(history, p)
      = Capacity[p]
        - OracleCommittedQuantity(oracleActive,
                                  oraclePurpose,
                                  oracleQuantity,
                                  p)

CorrectionFollowsOriginal ==
  \A k \in Seen(history) \cap CorrectionEvents :
    OccursBefore(history, CorrectionTarget[k], k)

CorrectionKeepsOriginal ==
  \A k \in Seen(history) \cap CorrectionEvents :
    /\ CorrectionTarget[k] \in Seen(history) \cap CommitEvents
    /\ CommitPurpose[CorrectionTarget[k]] \in Purposes
    /\ CommitQuantity[CorrectionTarget[k]] = 1

TargetedCorrectionIsExact ==
  \A k \in CorrectionEvents :
    CanCorrect(history, k) =>
      /\ ActiveFromHistory(Append(history, k)) = ActiveFromHistory(history)
      /\ EffectivePurpose(Append(history, k), CorrectionTarget[k])
           = CorrectionPurpose[k]
      /\ EffectiveQuantity(Append(history, k), CorrectionTarget[k])
           = CorrectionQuantity[k]
      /\ \A c \in CommitEvents \ {CorrectionTarget[k]} :
           /\ EffectivePurpose(Append(history, k), c)
                = EffectivePurpose(history, c)
           /\ EffectiveQuantity(Append(history, k), c)
                = EffectiveQuantity(history, c)

CurrentExplanationTruthful ==
  \A c \in ActiveFromHistory(history) :
    /\ CurrentExplanation(history, c).originalPurpose = CommitPurpose[c]
    /\ CurrentExplanation(history, c).originalQuantity = CommitQuantity[c]
    /\ CurrentExplanation(history, c).effectivePurpose = oraclePurpose[c]
    /\ CurrentExplanation(history, c).effectiveQuantity = oracleQuantity[c]
    /\ CurrentExplanation(history, c).correction
         = IF CorrectionSeen(history, c) THEN CorrectionOf[c] ELSE "none"

ReversalKeepsCorrectedCause ==
  \A r \in Seen(history) \cap ReverseEvents :
    /\ ReverseTarget[r] \in Seen(history) \cap CommitEvents
    /\ ReverseTarget[r] \notin ActiveFromHistory(history)

TargetedReverseIsExact ==
  \A r \in ReverseEvents :
    CanReverse(history, r) =>
      ActiveFromHistory(Append(history, r))
        = ActiveFromHistory(history) \ {ReverseTarget[r]}

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

PurposeCorrectionReached ==
  "k0" \in Seen(history)

QuantityCorrectionReached ==
  "k1" \in Seen(history)

NoPurposeCorrectionWitness ==
  ~PurposeCorrectionReached

NoQuantityCorrectionWitness ==
  ~QuantityCorrectionReached

FlattenedCurrent(H) ==
  [p \in Purposes |-> CommittedQuantity(H, p)]

FlattenedExplanation(H) ==
  {<<EffectivePurpose(H, c), EffectiveQuantity(H, c)>>
    : c \in ActiveFromHistory(H)}

CorrectionHistory(H) ==
  Seen(H) \cap CorrectionEvents

SameFlattenedBoundary ==
  /\ FlattenedCurrent(leftHistory) = FlattenedCurrent(rightHistory)
  /\ FlattenedExplanation(leftHistory) = FlattenedExplanation(rightHistory)

FlattenedCurrentDeterminesCorrectionHistory ==
  SameFlattenedBoundary =>
    CorrectionHistory(leftHistory) = CorrectionHistory(rightHistory)

====

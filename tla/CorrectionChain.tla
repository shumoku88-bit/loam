---- MODULE CorrectionChain ----
EXTENDS FiniteSets, Naturals, Sequences

Purposes == {"p0", "p1", "p2"}
Quantities == {1, 2}

CommitEvents == {"c0"}
CorrectionEvents == {"k0", "k1", "k2"}
InterpretationEvents == CommitEvents \cup CorrectionEvents

CorrectionTarget ==
  [k \in CorrectionEvents |->
    IF k = "k0" THEN "c0"
    ELSE IF k = "k1" THEN "k0"
    ELSE "k1"]

NodePurpose ==
  [n \in InterpretationEvents |->
    IF n = "c0" THEN "p0"
    ELSE IF n = "k0" THEN "p1"
    ELSE IF n = "k1" THEN "p2"
    ELSE "p1"]

NodeQuantity ==
  [n \in InterpretationEvents |->
    IF n = "k1" THEN 2 ELSE 1]

VARIABLES history, oracleTip, oraclePurpose, oracleQuantity

vars == <<history, oracleTip, oraclePurpose, oracleQuantity>>

Seen(H) == {H[i] : i \in DOMAIN H}

Children(H, n) ==
  {k \in Seen(H) \cap CorrectionEvents : CorrectionTarget[k] = n}

Tips(H) ==
  {n \in Seen(H) \cap InterpretationEvents : Children(H, n) = {}}

CurrentTip(H) ==
  CHOOSE n \in Tips(H) : TRUE

EffectivePurpose(H) == NodePurpose[CurrentTip(H)]
EffectiveQuantity(H) == NodeQuantity[CurrentTip(H)]

CanCorrect(H, k) ==
  /\ k \in CorrectionEvents
  /\ k \notin Seen(H)
  /\ CorrectionTarget[k] \in Tips(H)

Init ==
  /\ history = <<"c0">>
  /\ oracleTip = "c0"
  /\ oraclePurpose = "p0"
  /\ oracleQuantity = 1

Correct(k) ==
  /\ CanCorrect(history, k)
  /\ history' = Append(history, k)
  /\ oracleTip' = k
  /\ oraclePurpose' = NodePurpose[k]
  /\ oracleQuantity' = NodeQuantity[k]

Next ==
  \E k \in CorrectionEvents : Correct(k)

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK ==
  /\ history \in Seq(InterpretationEvents)
  /\ oracleTip \in InterpretationEvents
  /\ oraclePurpose \in Purposes
  /\ oracleQuantity \in Quantities

TipIsUnique ==
  Cardinality(Tips(history)) = 1

TipMatchesOracle ==
  CurrentTip(history) = oracleTip

EffectiveMeaningMatchesOracle ==
  /\ EffectivePurpose(history) = oraclePurpose
  /\ EffectiveQuantity(history) = oracleQuantity

LatestRecordedInterpretationIsTip ==
  history[Len(history)] = CurrentTip(history)

EveryCorrectionTargetsEarlierInterpretation ==
  \A k \in Seen(history) \cap CorrectionEvents :
    \E i, j \in DOMAIN history :
      /\ i < j
      /\ history[i] = CorrectionTarget[k]
      /\ history[j] = k

TargetedCorrectionExtendsTip ==
  \A k \in CorrectionEvents :
    CanCorrect(history, k) =>
      /\ Tips(Append(history, k)) = {k}
      /\ EffectivePurpose(Append(history, k)) = NodePurpose[k]
      /\ EffectiveQuantity(Append(history, k)) = NodeQuantity[k]

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

ThreeCorrectionsReached ==
  "k2" \in Seen(history)

NoThreeCorrectionWitness ==
  ~ThreeCorrectionsReached

====

---- MODULE CorrectableExplanationEdge ----
EXTENDS Naturals, Sequences

Times == 0..2
Claims == {"e0", "e1"}
Targets == {"A", "B"}
Unknown == "unknown"

ClaimTarget(c) == IF c = "e0" THEN "A" ELSE "B"
Supersedes(c) == IF c = "e1" THEN "e0" ELSE "none"

VARIABLES now, history, oracleParent

vars == <<now, history, oracleParent>>

ClaimIds(H) ==
  {c \in Claims : \E i \in DOMAIN H : H[i].claim = c}

KnownClaimsAt(H, knowledgeTime) ==
  {c \in Claims :
    \E i \in DOMAIN H :
      H[i].claim = c /\ H[i].learned <= knowledgeTime}

ActiveClaimsAt(H, knowledgeTime) ==
  {c \in KnownClaimsAt(H, knowledgeTime) :
    ~\E d \in KnownClaimsAt(H, knowledgeTime) : Supersedes(d) = c}

EffectiveParentAt(H, knowledgeTime) ==
  LET active == ActiveClaimsAt(H, knowledgeTime)
  IN IF active = {}
     THEN Unknown
     ELSE ClaimTarget(CHOOSE c \in active : TRUE)

LearnedAt(H, claim) ==
  CHOOSE t \in Times :
    \E i \in DOMAIN H : H[i].claim = claim /\ H[i].learned = t

Init ==
  /\ now = 0
  /\ history = <<>>
  /\ oracleParent = Unknown

ObserveInitialEdge ==
  /\ now = 0
  /\ "e0" \notin ClaimIds(history)
  /\ history' = Append(history, [claim |-> "e0", learned |-> now])
  /\ oracleParent' = "A"
  /\ UNCHANGED now

CorrectEdge ==
  /\ now > 0
  /\ "e0" \in ClaimIds(history)
  /\ "e1" \notin ClaimIds(history)
  /\ history' = Append(history, [claim |-> "e1", learned |-> now])
  /\ oracleParent' = "B"
  /\ UNCHANGED now

Advance ==
  /\ now < 2
  /\ now' = now + 1
  /\ UNCHANGED <<history, oracleParent>>

Next == ObserveInitialEdge \/ CorrectEdge \/ Advance

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK ==
  /\ now \in Times
  /\ history \in Seq([claim : Claims, learned : Times])
  /\ oracleParent \in Targets \cup {Unknown}

UniqueClaims ==
  \A i, j \in DOMAIN history :
    history[i].claim = history[j].claim => i = j

CorrectionFollowsOriginal ==
  "e1" \in ClaimIds(history) =>
    /\ "e0" \in ClaimIds(history)
    /\ LearnedAt(history, "e0") < LearnedAt(history, "e1")

CurrentProjectionMatchesOracle ==
  EffectiveParentAt(history, now) = oracleParent

PastExplanationSurvivesCorrection ==
  "e1" \in ClaimIds(history) =>
    /\ EffectiveParentAt(history, LearnedAt(history, "e0")) = "A"
    /\ EffectiveParentAt(history, LearnedAt(history, "e1")) = "B"
    /\ EffectiveParentAt(history, now) = "B"

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

MutableCurrentGraphAnswersEveryAsOf ==
  \A knowledgeTime \in Times :
    knowledgeTime <= now /\
    EffectiveParentAt(history, knowledgeTime) # Unknown
      => EffectiveParentAt(history, knowledgeTime) = oracleParent

EarlyCorrectionHistory ==
  <<[claim |-> "e0", learned |-> 0],
    [claim |-> "e1", learned |-> 1]>>

LateCorrectionHistory ==
  <<[claim |-> "e0", learned |-> 0],
    [claim |-> "e1", learned |-> 2]>>

SameTimelessClaimGraph(H, K) ==
  /\ Len(H) = Len(K)
  /\ \A i \in DOMAIN H : H[i].claim = K[i].claim

ClaimGraphWithoutLearnedTimeDeterminesAsOf ==
  SameTimelessClaimGraph(EarlyCorrectionHistory, LateCorrectionHistory) =>
    \A knowledgeTime \in Times :
      EffectiveParentAt(EarlyCorrectionHistory, knowledgeTime)
        = EffectiveParentAt(LateCorrectionHistory, knowledgeTime)

====

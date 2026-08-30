---- MODULE ValidTimeVsLearnedTime ----
EXTENDS Naturals, Sequences

Times == 0..2
Values == {"r0", "r1"}
Unknown == "unknown"

VARIABLES now, history

vars == <<now, history>>

Candidates(H, validTime, knowledgeTime) ==
  {i \in DOMAIN H :
    /\ H[i].valid = validTime
    /\ H[i].learned <= knowledgeTime}

Answer(H, validTime, knowledgeTime) ==
  IF Candidates(H, validTime, knowledgeTime) = {}
  THEN Unknown
  ELSE H[CHOOSE i \in Candidates(H, validTime, knowledgeTime) : TRUE].value

Init ==
  /\ now = 0
  /\ history = <<>>

CanObserve(validTime, value) ==
  /\ validTime \in Times
  /\ validTime <= now
  /\ value \in Values
  /\ \A i \in DOMAIN history : history[i].valid # validTime

Observe(validTime, value) ==
  /\ CanObserve(validTime, value)
  /\ history' = Append(
       history,
       [valid |-> validTime, learned |-> now, value |-> value])
  /\ UNCHANGED now

Advance ==
  /\ now < 2
  /\ now' = now + 1
  /\ UNCHANGED history

Next ==
  \/ \E validTime \in Times, value \in Values : Observe(validTime, value)
  \/ Advance

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK ==
  /\ now \in Times
  /\ history \in Seq([valid : Times, learned : Times, value : Values])

AtMostOneObservationPerValidTime ==
  \A i, j \in DOMAIN history :
    history[i].valid = history[j].valid => i = j

ValidityNeverComesFromTheFuture ==
  \A i \in DOMAIN history : history[i].valid <= history[i].learned

NoKnowledgeBeforeLearning ==
  \A i \in DOMAIN history :
    \A k \in Times :
      k < history[i].learned =>
        Answer(history, history[i].valid, k) = Unknown

KnownAfterLearning ==
  \A i \in DOMAIN history :
    \A k \in Times :
      history[i].learned <= k =>
        Answer(history, history[i].valid, k) = history[i].value

NoKnowledgeBeforeValidTime ==
  \A validTime \in Times :
    \A k \in Times :
      k < validTime => Answer(history, validTime, k) = Unknown

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

ObservationTimeEqualsValidity ==
  \A i \in DOMAIN history : history[i].learned = history[i].valid

RetrospectiveViewEqualsContemporaneousView ==
  \A validTime \in Times :
    validTime <= now =>
      Answer(history, validTime, now) = Answer(history, validTime, validTime)

====

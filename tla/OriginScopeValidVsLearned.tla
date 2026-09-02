---- MODULE OriginScopeValidVsLearned ----
EXTENDS Naturals, Sequences

Times == 0..3
EventIds == {"e0", "e1"}

OriginValid == 1
OriginLearned == 1

VARIABLES now, history

vars == <<now, history>>

KnownAt(observation, knowledgeTime) ==
  observation.learned <= knowledgeTime

InValidScope(observation) ==
  observation.valid >= OriginValid

InLearnedScope(observation) ==
  observation.learned >= OriginLearned

KnownValidMembers(H, knowledgeTime) ==
  {i \in DOMAIN H :
    /\ KnownAt(H[i], knowledgeTime)
    /\ InValidScope(H[i])}

KnownLearnedMembers(H, knowledgeTime) ==
  {i \in DOMAIN H :
    /\ KnownAt(H[i], knowledgeTime)
    /\ InLearnedScope(H[i])}

Init ==
  /\ now = 0
  /\ history = <<>>

CanObserve(id, validTime) ==
  /\ id \in EventIds
  /\ validTime \in Times
  /\ validTime <= now
  /\ now >= OriginLearned
  /\ \A i \in DOMAIN history : history[i].id # id

Observe(id, validTime) ==
  /\ CanObserve(id, validTime)
  /\ history' = Append(
       history,
       [id |-> id, valid |-> validTime, learned |-> now])
  /\ UNCHANGED now

Advance ==
  /\ now < 3
  /\ now' = now + 1
  /\ UNCHANGED history

Next ==
  \/ \E id \in EventIds, validTime \in Times : Observe(id, validTime)
  \/ Advance

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK ==
  /\ now \in Times
  /\ history \in Seq([id : EventIds, valid : Times, learned : Times])

UniqueEventIdentity ==
  \A i, j \in DOMAIN history :
    history[i].id = history[j].id => i = j

ValidityNeverComesFromTheFuture ==
  \A i \in DOMAIN history :
    history[i].valid <= history[i].learned

ObservationNeverPrecedesOriginKnowledge ==
  \A i \in DOMAIN history :
    history[i].learned >= OriginLearned

NoKnowledgeBeforeLearning ==
  \A i \in DOMAIN history :
    \A k \in Times :
      k < history[i].learned =>
        /\ i \notin KnownValidMembers(history, k)
        /\ i \notin KnownLearnedMembers(history, k)

PreOriginNeverEntersValidScope ==
  \A i \in DOMAIN history :
    history[i].valid < OriginValid =>
      i \notin KnownValidMembers(history, now)

PostOriginEntersValidScopeWhenKnown ==
  \A i \in DOMAIN history :
    /\ history[i].valid >= OriginValid
    /\ history[i].learned <= now
    => i \in KnownValidMembers(history, now)

LateRetrospectiveNeverEntersValidScope ==
  \A i \in DOMAIN history :
    /\ history[i].valid < OriginValid
    /\ history[i].learned > OriginLearned
    => i \notin KnownValidMembers(history, now)

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

LearnedScopeMatchesValidScopeForLateEvents ==
  \A i \in DOMAIN history :
    history[i].learned > OriginLearned =>
      InLearnedScope(history[i]) = InValidScope(history[i])

====

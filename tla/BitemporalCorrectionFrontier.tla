---- MODULE BitemporalCorrectionFrontier ----
EXTENDS Naturals, Sequences

Times == 0..3
Events == {"c0", "kA", "kB", "r0"}
Corrections == {"kA", "kB"}
Meanings == {"v0", "vA", "vB", "vR"}

Parents(e) ==
  CASE e = "c0" -> {}
    [] e = "kA" -> {"c0"}
    [] e = "kB" -> {"c0"}
    [] e = "r0" -> {"kA", "kB"}

Meaning(e) ==
  CASE e = "c0" -> "v0"
    [] e = "kA" -> "vA"
    [] e = "kB" -> "vB"
    [] e = "r0" -> "vR"

VARIABLES now, history

vars == <<now, history>>

SeenIds(H, knowledgeTime) ==
  {H[i].id : i \in {j \in DOMAIN H : H[j].learned <= knowledgeTime}}

ChildrenAt(H, knowledgeTime, e) ==
  {child \in SeenIds(H, knowledgeTime) : e \in Parents(child)}

FrontierAt(H, knowledgeTime) ==
  {e \in SeenIds(H, knowledgeTime) : ChildrenAt(H, knowledgeTime, e) = {}}

RecordIndex(H, e) ==
  CHOOSE i \in DOMAIN H : H[i].id = e

LearnedOf(H, e) ==
  H[RecordIndex(H, e)].learned

LaterCorrection(H) ==
  IF LearnedOf(H, "kA") > LearnedOf(H, "kB")
  THEN "kA"
  ELSE "kB"

Init ==
  /\ now = 0
  /\ history = <<[id |-> "c0", valid |-> 0, learned |-> 0, meaning |-> Meaning("c0")]>>

NoObservationAtCurrentTime ==
  \A i \in DOMAIN history : history[i].learned # now

LearnCorrection(e) ==
  /\ e \in Corrections
  /\ now \in 1..2
  /\ e \notin SeenIds(history, now)
  /\ "c0" \in SeenIds(history, now)
  /\ NoObservationAtCurrentTime
  /\ history' = Append(
       history,
       [id |-> e, valid |-> 0, learned |-> now, meaning |-> Meaning(e)])
  /\ UNCHANGED now

Resolve ==
  /\ now = 3
  /\ "r0" \notin SeenIds(history, now)
  /\ FrontierAt(history, now) = {"kA", "kB"}
  /\ NoObservationAtCurrentTime
  /\ history' = Append(
       history,
       [id |-> "r0", valid |-> 0, learned |-> now, meaning |-> Meaning("r0")])
  /\ UNCHANGED now

Advance ==
  /\ now < 3
  /\ now' = now + 1
  /\ UNCHANGED history

Next ==
  \/ \E e \in Corrections : LearnCorrection(e)
  \/ Resolve
  \/ Advance

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK ==
  /\ now \in Times
  /\ history \in Seq([id : Events, valid : 0..0, learned : Times, meaning : Meanings])

NoDuplicateEventIds ==
  \A i, j \in DOMAIN history :
    history[i].id = history[j].id => i = j

AtMostOneObservationPerLearnedTime ==
  \A i, j \in DOMAIN history :
    history[i].learned = history[j].learned => i = j

MeaningMatchesEvent ==
  \A i \in DOMAIN history : history[i].meaning = Meaning(history[i].id)

ParentsWereAlreadyKnown ==
  \A i \in DOMAIN history :
    \A p \in Parents(history[i].id) :
      \E j \in DOMAIN history :
        /\ history[j].id = p
        /\ history[j].learned <= history[i].learned

ConflictUsesWholeFrontier ==
  /\ "kA" \in SeenIds(history, now)
  /\ "kB" \in SeenIds(history, now)
  /\ "r0" \notin SeenIds(history, now)
  => FrontierAt(history, now) = {"kA", "kB"}

ResolutionSettlesCurrentFrontier ==
  "r0" \in SeenIds(history, now)
  => FrontierAt(history, now) = {"r0"}

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

PastViewsStableAction ==
  \A k \in Times :
    k < now => FrontierAt(history', k) = FrontierAt(history, k)

PastKnowledgeViewsDoNotRewrite ==
  [][PastViewsStableAction]_vars

LaterLearnedCorrectionWins ==
  /\ "kA" \in SeenIds(history, now)
  /\ "kB" \in SeenIds(history, now)
  /\ "r0" \notin SeenIds(history, now)
  => FrontierAt(history, now) = {LaterCorrection(history)}

ResolutionRewritesPastConflict ==
  "r0" \in SeenIds(history, now)
  => FrontierAt(history, 2) = {"r0"}

====

---- MODULE TemporalCorrectionConflict ----
EXTENDS Naturals, FiniteSets

Times == 0..3
EventIds == {"e0"}
FactIds == {"t0", "t1", "t2"}
CorrectionIds == {"c1", "c2"}
Days == {"d0", "d1", "d2"}

FactEvent(f) == "e0"

FactDay(f) ==
  CASE f = "t0" -> "d0"
    [] f = "t1" -> "d1"
    [] OTHER -> "d2"

FactLearned(f) ==
  CASE f = "t0" -> 1
    [] f = "t1" -> 2
    [] OTHER -> 3

CorrectionTarget(c) == "t0"

CorrectionReplacement(c) ==
  IF c = "c1" THEN "t1" ELSE "t2"

CorrectionLearned(c) ==
  IF c = "c1" THEN 2 ELSE 3

VARIABLES now, retainedFacts, retainedCorrections

vars == <<now, retainedFacts, retainedCorrections>>

KnownFactsAt(k) ==
  {f \in retainedFacts : FactLearned(f) <= k}

KnownCorrectionsAt(k) ==
  {c \in retainedCorrections : CorrectionLearned(c) <= k}

CorrectionTargetsAt(k) ==
  {CorrectionTarget(c) : c \in KnownCorrectionsAt(k)}

FrontierAt(k) ==
  KnownFactsAt(k) \ CorrectionTargetsAt(k)

EventFrontierAt(k, e) ==
  {f \in FrontierAt(k) : FactEvent(f) = e}

LatestLearnedFrontierAt(k, e) ==
  {f \in EventFrontierAt(k, e) :
    \A g \in EventFrontierAt(k, e) : FactLearned(g) <= FactLearned(f)}

Init ==
  /\ now = 0
  /\ retainedFacts = {}
  /\ retainedCorrections = {}

LearnInitialTemporalFact ==
  /\ now = 1
  /\ "t0" \notin retainedFacts
  /\ retainedFacts' = retainedFacts \cup {"t0"}
  /\ UNCHANGED <<now, retainedCorrections>>

LearnFirstCorrection ==
  /\ now = 2
  /\ "t0" \in retainedFacts
  /\ "c1" \notin retainedCorrections
  /\ retainedFacts' = retainedFacts \cup {"t1"}
  /\ retainedCorrections' = retainedCorrections \cup {"c1"}
  /\ UNCHANGED now

LearnLaterSiblingCorrection ==
  /\ now = 3
  /\ "c1" \in retainedCorrections
  /\ "c2" \notin retainedCorrections
  /\ retainedFacts' = retainedFacts \cup {"t2"}
  /\ retainedCorrections' = retainedCorrections \cup {"c2"}
  /\ UNCHANGED now

Advance ==
  /\ now < 3
  /\ now' = now + 1
  /\ UNCHANGED <<retainedFacts, retainedCorrections>>

Next ==
  \/ LearnInitialTemporalFact
  \/ LearnFirstCorrection
  \/ LearnLaterSiblingCorrection
  \/ Advance

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ now \in Times
  /\ retainedFacts \subseteq FactIds
  /\ retainedCorrections \subseteq CorrectionIds

NoKnowledgeBeforeLearnedTime ==
  /\ \A f \in retainedFacts : FactLearned(f) <= now
  /\ \A c \in retainedCorrections : CorrectionLearned(c) <= now

ClosedCorrectionReferences ==
  \A c \in retainedCorrections :
    /\ CorrectionTarget(c) \in retainedFacts
    /\ CorrectionReplacement(c) \in retainedFacts

CorrectionsStayOnSameEvent ==
  \A c \in retainedCorrections :
    FactEvent(CorrectionTarget(c)) = FactEvent(CorrectionReplacement(c))

ReplacementArrivesWithCorrection ==
  \A c \in retainedCorrections :
    /\ FactLearned(CorrectionReplacement(c)) = CorrectionLearned(c)
    /\ FactLearned(CorrectionTarget(c)) < CorrectionLearned(c)

FirstCorrectionIsSettledBeforeSibling ==
  ("c1" \in retainedCorrections /\ "c2" \notin retainedCorrections) =>
    EventFrontierAt(now, "e0") = {"t1"}

LaterSiblingCreatesConflict ==
  ("c1" \in retainedCorrections /\ "c2" \in retainedCorrections) =>
    /\ EventFrontierAt(now, "e0") = {"t1", "t2"}
    /\ Cardinality(EventFrontierAt(now, "e0")) = 2

LearnedOrderDoesNotEraseEarlierSibling ==
  ("c1" \in retainedCorrections /\ "c2" \in retainedCorrections) =>
    /\ "t1" \in EventFrontierAt(now, "e0")
    /\ "t2" \in EventFrontierAt(now, "e0")

LatestLearnedIdentifiesLaterCandidate ==
  ("c1" \in retainedCorrections /\ "c2" \in retainedCorrections) =>
    LatestLearnedFrontierAt(now, "e0") = {"t2"}

LearnedLatestEqualsStructuralCurrent ==
  LatestLearnedFrontierAt(now, "e0") = EventFrontierAt(now, "e0")

====

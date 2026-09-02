---- MODULE TemporalEvidenceCorrection ----
EXTENDS Naturals, FiniteSets

Times == 0..3
EventIds == {"e0"}
FactIds == {"t0", "t1"}
CorrectionIds == {"c0"}
Days == {"d1", "d2"}

FactEvent(f) == "e0"
FactDay(f) == IF f = "t0" THEN "d2" ELSE "d1"
FactLearned(f) == IF f = "t0" THEN 1 ELSE 3

CorrectionTarget(c) == "t0"
CorrectionReplacement(c) == "t1"
CorrectionLearned(c) == 3

VARIABLES now, retainedFacts, retainedCorrections

vars == <<now, retainedFacts, retainedCorrections>>

KnownFactsAt(k) ==
  {f \in retainedFacts : FactLearned(f) <= k}

KnownCorrectionsAt(k) ==
  {c \in retainedCorrections : CorrectionLearned(c) <= k}

TargetsAt(k) ==
  {CorrectionTarget(c) : c \in KnownCorrectionsAt(k)}

FrontierAt(k) ==
  KnownFactsAt(k) \ TargetsAt(k)

FactsForEventAt(k, e) ==
  {f \in FrontierAt(k) : FactEvent(f) = e}

DaysAt(k, e) ==
  {FactDay(f) : f \in FactsForEventAt(k, e)}

CurrentFrontier ==
  retainedFacts \ {CorrectionTarget(c) : c \in retainedCorrections}

CurrentFrontierKnownAt(k) ==
  {f \in CurrentFrontier : FactLearned(f) <= k}

CurrentFrontierDaysAt(k, e) ==
  {FactDay(f) :
    f \in {g \in CurrentFrontierKnownAt(k) : FactEvent(g) = e}}

Init ==
  /\ now = 0
  /\ retainedFacts = {}
  /\ retainedCorrections = {}

LearnInitialTemporalFact ==
  /\ now = 1
  /\ "t0" \notin retainedFacts
  /\ retainedFacts' = retainedFacts \cup {"t0"}
  /\ UNCHANGED <<now, retainedCorrections>>

LearnTemporalCorrection ==
  /\ now = 3
  /\ "t0" \in retainedFacts
  /\ "t1" \notin retainedFacts
  /\ "c0" \notin retainedCorrections
  /\ retainedFacts' = retainedFacts \cup {"t1"}
  /\ retainedCorrections' = retainedCorrections \cup {"c0"}
  /\ UNCHANGED now

Advance ==
  /\ now < 3
  /\ now' = now + 1
  /\ UNCHANGED <<retainedFacts, retainedCorrections>>

Next ==
  \/ LearnInitialTemporalFact
  \/ LearnTemporalCorrection
  \/ Advance

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ now \in Times
  /\ retainedFacts \subseteq FactIds
  /\ retainedCorrections \subseteq CorrectionIds

NoFutureRetainedKnowledge ==
  /\ \A f \in retainedFacts : FactLearned(f) <= now
  /\ \A c \in retainedCorrections : CorrectionLearned(c) <= now

ClosedCorrectionReferences ==
  \A c \in retainedCorrections :
    /\ CorrectionTarget(c) \in retainedFacts
    /\ CorrectionReplacement(c) \in retainedFacts

CorrectionPreservesEvent ==
  \A c \in retainedCorrections :
    FactEvent(CorrectionTarget(c)) = FactEvent(CorrectionReplacement(c))

CorrectionLearnedAfterTarget ==
  \A c \in retainedCorrections :
    FactLearned(CorrectionTarget(c)) < CorrectionLearned(c)

ReplacementLearnedWithCorrection ==
  \A c \in retainedCorrections :
    FactLearned(CorrectionReplacement(c)) = CorrectionLearned(c)

FrontierUniquePerEvent ==
  \A k \in Times, e \in EventIds :
    Cardinality(FactsForEventAt(k, e)) <= 1

HistoricalKnowledgePreserved ==
  "c0" \in retainedCorrections =>
    /\ DaysAt(1, "e0") = {"d2"}
    /\ DaysAt(2, "e0") = {"d2"}
    /\ DaysAt(3, "e0") = {"d1"}

CurrentKnowledgeUsesReplacement ==
  "c0" \in retainedCorrections =>
    /\ "t0" \notin FrontierAt(now)
    /\ "t1" \in FrontierAt(now)
    /\ DaysAt(now, "e0") = {"d1"}

FactsOnlyGrow ==
  [][retainedFacts \subseteq retainedFacts']_vars

CorrectionsOnlyGrow ==
  [][retainedCorrections \subseteq retainedCorrections']_vars

\* Deliberately too strong. After correction, retaining only the current
\* frontier loses the earlier answer that was legitimately known at time 1.
CurrentFrontierCanReconstructPastKnowledge ==
  "c0" \notin retainedCorrections \/
    CurrentFrontierDaysAt(1, "e0") = DaysAt(1, "e0")

====

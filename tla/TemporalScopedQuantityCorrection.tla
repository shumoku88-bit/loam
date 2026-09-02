---- MODULE TemporalScopedQuantityCorrection ----
EXTENDS Naturals, FiniteSets

Times == 0..3
EventIds == {"e0"}
FactIds == {"t0", "t1"}
CorrectionIds == {"c0"}
Sides == {"Before", "After"}

OriginQuantity == 0
EventAmount(e) == 100
EventLearned(e) == 1

FactEvent(f) == "e0"
FactSide(f) == IF f = "t0" THEN "After" ELSE "Before"
FactLearned(f) == IF f = "t0" THEN 1 ELSE 3

CorrectionTarget(c) == "t0"
CorrectionReplacement(c) == "t1"
CorrectionLearned(c) == 3

VARIABLES now, retainedEvents, retainedFacts, retainedCorrections

vars == <<now, retainedEvents, retainedFacts, retainedCorrections>>

KnownEventsAt(k) ==
  {e \in retainedEvents : EventLearned(e) <= k}

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

ScopedContribution(f, e) ==
  IF FactSide(f) = "After" THEN EventAmount(e) ELSE 0

ScopedActivityAnswersAt(k, e) ==
  {ScopedContribution(f, e) : f \in FactsForEventAt(k, e)}

CurrentQuantityAnswersAt(k, e) ==
  IF e \in KnownEventsAt(k)
  THEN {OriginQuantity + a : a \in ScopedActivityAnswersAt(k, e)}
  ELSE {}

CurrentTemporalFrontier ==
  retainedFacts \ {CorrectionTarget(c) : c \in retainedCorrections}

CurrentTemporalFrontierKnownAt(k) ==
  {f \in CurrentTemporalFrontier : FactLearned(f) <= k}

CurrentFrontierFactsForEventAt(k, e) ==
  {f \in CurrentTemporalFrontierKnownAt(k) : FactEvent(f) = e}

CurrentFrontierQuantityAnswersAt(k, e) ==
  IF e \in KnownEventsAt(k)
  THEN {OriginQuantity + ScopedContribution(f, e) :
        f \in CurrentFrontierFactsForEventAt(k, e)}
  ELSE {}

Init ==
  /\ now = 0
  /\ retainedEvents = {}
  /\ retainedFacts = {}
  /\ retainedCorrections = {}

LearnEventAndInitialTemporalFact ==
  /\ now = 1
  /\ "e0" \notin retainedEvents
  /\ "t0" \notin retainedFacts
  /\ retainedEvents' = retainedEvents \cup {"e0"}
  /\ retainedFacts' = retainedFacts \cup {"t0"}
  /\ UNCHANGED <<now, retainedCorrections>>

LearnTemporalCorrection ==
  /\ now = 3
  /\ "e0" \in retainedEvents
  /\ "t0" \in retainedFacts
  /\ "t1" \notin retainedFacts
  /\ "c0" \notin retainedCorrections
  /\ retainedFacts' = retainedFacts \cup {"t1"}
  /\ retainedCorrections' = retainedCorrections \cup {"c0"}
  /\ UNCHANGED <<now, retainedEvents>>

Advance ==
  /\ now < 3
  /\ now' = now + 1
  /\ UNCHANGED <<retainedEvents, retainedFacts, retainedCorrections>>

Next ==
  \/ LearnEventAndInitialTemporalFact
  \/ LearnTemporalCorrection
  \/ Advance

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ now \in Times
  /\ retainedEvents \subseteq EventIds
  /\ retainedFacts \subseteq FactIds
  /\ retainedCorrections \subseteq CorrectionIds

NoFutureRetainedKnowledge ==
  /\ \A e \in retainedEvents : EventLearned(e) <= now
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

MissingTemporalEvidenceInventsNoQuantity ==
  \A k \in Times, e \in EventIds :
    FactsForEventAt(k, e) = {} => CurrentQuantityAnswersAt(k, e) = {}

HistoricalScopedQuantityPreserved ==
  "c0" \in retainedCorrections =>
    /\ CurrentQuantityAnswersAt(1, "e0") = {100}
    /\ CurrentQuantityAnswersAt(2, "e0") = {100}
    /\ CurrentQuantityAnswersAt(3, "e0") = {0}

CorrectionChangesScopeNotEventAmount ==
  "c0" \in retainedCorrections =>
    /\ EventAmount("e0") = 100
    /\ FactSide("t0") = "After"
    /\ FactSide("t1") = "Before"
    /\ FactEvent("t0") = FactEvent("t1")

CurrentUsesReplacementScope ==
  "c0" \in retainedCorrections =>
    /\ "t0" \notin FrontierAt(now)
    /\ "t1" \in FrontierAt(now)
    /\ CurrentQuantityAnswersAt(now, "e0") = {0}

EventsOnlyGrow ==
  [][retainedEvents \subseteq retainedEvents']_vars

FactsOnlyGrow ==
  [][retainedFacts \subseteq retainedFacts']_vars

CorrectionsOnlyGrow ==
  [][retainedCorrections \subseteq retainedCorrections']_vars

\* Deliberately too strong. Once the final temporal frontier keeps only t1,
\* filtering that frontier back to knowledge time 1 loses the earlier scoped
\* quantity answer 100, even though the full append-only history retains it.
FinalTemporalFrontierCanReconstructPastQuantity ==
  "c0" \notin retainedCorrections \/
    CurrentFrontierQuantityAnswersAt(1, "e0") = CurrentQuantityAnswersAt(1, "e0")

====

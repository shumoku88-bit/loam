---- MODULE QueryRelativeTemporalAmbiguity ----
EXTENDS Naturals, FiniteSets

Times == 0..3
Events == {"e0", "e1"}
Facts == {"t0", "t1", "t2", "u0", "u1", "u2", "r0"}
Corrections == {"c1", "c2", "d1", "d2"}
Resolutions == {"h0"}
Positions == {"Before", "After"}
QuantityValues == {0, 100}

OriginQuantity == 0

EventAmount(e) == 100

FactEvent(f) ==
  IF f \in {"t0", "t1", "t2", "r0"}
  THEN "e0"
  ELSE "e1"

FactPosition(f) ==
  IF f = "t1"
  THEN "Before"
  ELSE "After"

FactLearned(f) ==
  IF f \in {"t0", "u0"}
  THEN 1
  ELSE IF f \in {"t1", "t2", "u1", "u2"}
       THEN 2
       ELSE 3

CorrectionTarget(c) ==
  IF c \in {"c1", "c2"}
  THEN "t0"
  ELSE "u0"

CorrectionReplacement(c) ==
  CASE c = "c1" -> "t1"
    [] c = "c2" -> "t2"
    [] c = "d1" -> "u1"
    [] c = "d2" -> "u2"

CorrectionLearned(c) == 2

ResolutionParents(r) == {"t1", "t2"}
ResolutionReplacement(r) == "r0"
ResolutionLearned(r) == 3

CurrentFromFact(f, e) ==
  OriginQuantity +
    (IF FactPosition(f) = "After"
     THEN EventAmount(e)
     ELSE 0)

VARIABLES now,
          retainedEvents,
          retainedFacts,
          retainedCorrections,
          retainedResolutions

vars == <<now,
          retainedEvents,
          retainedFacts,
          retainedCorrections,
          retainedResolutions>>

KnownFactsAt(k) ==
  {f \in retainedFacts : FactLearned(f) <= k}

KnownCorrectionsAt(k) ==
  {c \in retainedCorrections : CorrectionLearned(c) <= k}

KnownResolutionsAt(k) ==
  {r \in retainedResolutions : ResolutionLearned(r) <= k}

CorrectionConsumedAt(k) ==
  {CorrectionTarget(c) : c \in KnownCorrectionsAt(k)}

ResolutionConsumedAt(k) ==
  UNION {ResolutionParents(r) : r \in KnownResolutionsAt(k)}

ConsumedAt(k) ==
  CorrectionConsumedAt(k) \union ResolutionConsumedAt(k)

FrontierAt(k) ==
  KnownFactsAt(k) \ ConsumedAt(k)

FrontierForEventAt(k, e) ==
  {f \in FrontierAt(k) : FactEvent(f) = e}

CandidateQuantityValuesAt(k, e) ==
  {q \in QuantityValues :
    \E f \in FrontierForEventAt(k, e) :
      q = CurrentFromFact(f, e)}

QuantityAnswerAt(k, e) ==
  IF Cardinality(CandidateQuantityValuesAt(k, e)) = 1
  THEN CandidateQuantityValuesAt(k, e)
  ELSE {}

TemporalConflictAt(k, e) ==
  Cardinality(FrontierForEventAt(k, e)) > 1

Init ==
  /\ now = 0
  /\ retainedEvents = {}
  /\ retainedFacts = {}
  /\ retainedCorrections = {}
  /\ retainedResolutions = {}

LearnInitialFacts ==
  /\ now = 1
  /\ "t0" \notin retainedFacts
  /\ "u0" \notin retainedFacts
  /\ retainedEvents' = retainedEvents \union Events
  /\ retainedFacts' = retainedFacts \union {"t0", "u0"}
  /\ UNCHANGED <<now, retainedCorrections, retainedResolutions>>

LearnSiblingConflicts ==
  /\ now = 2
  /\ {"t0", "u0"} \subseteq retainedFacts
  /\ retainedCorrections = {}
  /\ retainedFacts' = retainedFacts \union {"t1", "t2", "u1", "u2"}
  /\ retainedCorrections' = retainedCorrections \union Corrections
  /\ UNCHANGED <<now, retainedEvents, retainedResolutions>>

ResolveDivergentConflict ==
  /\ now = 3
  /\ Corrections \subseteq retainedCorrections
  /\ "h0" \notin retainedResolutions
  /\ FrontierForEventAt(now, "e0") = {"t1", "t2"}
  /\ retainedFacts' = retainedFacts \union {"r0"}
  /\ retainedResolutions' = retainedResolutions \union {"h0"}
  /\ UNCHANGED <<now, retainedEvents, retainedCorrections>>

Advance ==
  /\ now < 3
  /\ now' = now + 1
  /\ UNCHANGED <<retainedEvents,
                  retainedFacts,
                  retainedCorrections,
                  retainedResolutions>>

Next ==
  \/ LearnInitialFacts
  \/ LearnSiblingConflicts
  \/ ResolveDivergentConflict
  \/ Advance

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ now \in Times
  /\ retainedEvents \subseteq Events
  /\ retainedFacts \subseteq Facts
  /\ retainedCorrections \subseteq Corrections
  /\ retainedResolutions \subseteq Resolutions

NoKnowledgeBeforeLearned ==
  /\ \A f \in retainedFacts : FactLearned(f) <= now
  /\ \A c \in retainedCorrections : CorrectionLearned(c) <= now
  /\ \A r \in retainedResolutions : ResolutionLearned(r) <= now

ClosedCorrections ==
  \A c \in retainedCorrections :
    /\ CorrectionTarget(c) \in retainedFacts
    /\ CorrectionReplacement(c) \in retainedFacts
    /\ FactEvent(CorrectionTarget(c)) = FactEvent(CorrectionReplacement(c))
    /\ FactLearned(CorrectionTarget(c)) < CorrectionLearned(c)
    /\ FactLearned(CorrectionReplacement(c)) = CorrectionLearned(c)

ClosedResolution ==
  \A r \in retainedResolutions :
    /\ \A p \in ResolutionParents(r) : p \in retainedFacts
    /\ ResolutionReplacement(r) \in retainedFacts
    /\ \A p \in ResolutionParents(r) :
         FactEvent(p) = FactEvent(ResolutionReplacement(r))
    /\ \A p \in ResolutionParents(r) :
         FactLearned(p) < ResolutionLearned(r)
    /\ FactLearned(ResolutionReplacement(r)) = ResolutionLearned(r)

EventQuantityStaysFixed ==
  \A e \in retainedEvents : EventAmount(e) = 100

InitialQuantityIsAvailable ==
  {"t0", "u0"} \subseteq retainedFacts =>
    /\ QuantityAnswerAt(1, "e0") = {100}
    /\ QuantityAnswerAt(1, "e1") = {100}

DivergentConflictBlocksOnlyItsQuantity ==
  (Corrections \subseteq retainedCorrections /\
   "h0" \notin retainedResolutions) =>
    /\ FrontierForEventAt(now, "e0") = {"t1", "t2"}
    /\ CandidateQuantityValuesAt(now, "e0") = {0, 100}
    /\ QuantityAnswerAt(now, "e0") = {}

ConvergentConflictStillDeterminesQuantity ==
  Corrections \subseteq retainedCorrections =>
    /\ FrontierForEventAt(now, "e1") = {"u1", "u2"}
    /\ CandidateQuantityValuesAt(now, "e1") = {100}
    /\ QuantityAnswerAt(now, "e1") = {100}

ResolutionRestoresDivergentQuantity ==
  "h0" \in retainedResolutions =>
    /\ FrontierForEventAt(now, "e0") = {"r0"}
    /\ QuantityAnswerAt(now, "e0") = {100}
    /\ TemporalConflictAt(now, "e1")
    /\ QuantityAnswerAt(now, "e1") = {100}

HistoricalQueryViewsArePreserved ==
  "h0" \in retainedResolutions =>
    /\ QuantityAnswerAt(1, "e0") = {100}
    /\ QuantityAnswerAt(1, "e1") = {100}
    /\ QuantityAnswerAt(2, "e0") = {}
    /\ QuantityAnswerAt(2, "e1") = {100}
    /\ QuantityAnswerAt(3, "e0") = {100}
    /\ QuantityAnswerAt(3, "e1") = {100}

EventsOnlyGrow ==
  [][retainedEvents \subseteq retainedEvents']_vars

FactsOnlyGrow ==
  [][retainedFacts \subseteq retainedFacts']_vars

CorrectionsOnlyGrow ==
  [][retainedCorrections \subseteq retainedCorrections']_vars

ResolutionsOnlyGrow ==
  [][retainedResolutions \subseteq retainedResolutions']_vars

\* Deliberately too strong. e1 has two unresolved temporal frontier facts,
\* but both map to the same quantity candidate 100 for this projection.
AnyTemporalConflictBlocksQuantity ==
  \A k \in Times, e \in Events :
    TemporalConflictAt(k, e) => QuantityAnswerAt(k, e) = {}

\* Deliberately too strong in the other direction. e0 has unresolved
\* Before/After candidates that map to distinct quantity values 0 and 100.
AnyTemporalConflictStillYieldsQuantity ==
  \A k \in Times, e \in Events :
    TemporalConflictAt(k, e) => QuantityAnswerAt(k, e) /= {}

=============================================================================

---- MODULE TemporalConflictResolutionHistory ----
EXTENDS Naturals, FiniteSets

Facts == {"t0", "t1", "t2", "r0"}
Corrections == {"c1", "c2"}
Resolutions == {"h0"}
Events == {"e0"}
Days == {"d0", "d1", "d2"}

FactEvent(f) == "e0"

FactDay(f) ==
  CASE f = "t0" -> "d0"
    [] f = "t1" -> "d1"
    [] f = "t2" -> "d2"
    [] f = "r0" -> "d1"

FactLearned(f) ==
  CASE f = "t0" -> 1
    [] f = "t1" -> 2
    [] f = "t2" -> 3
    [] f = "r0" -> 4

CorrectionTarget(c) == "t0"

CorrectionReplacement(c) ==
  CASE c = "c1" -> "t1"
    [] c = "c2" -> "t2"

CorrectionLearned(c) ==
  CASE c = "c1" -> 2
    [] c = "c2" -> 3

ResolutionParents(r) == {"t1", "t2"}
ResolutionReplacement(r) == "r0"
ResolutionLearned(r) == 4

VARIABLES now, retainedFacts, retainedCorrections, retainedResolutions
vars == <<now, retainedFacts, retainedCorrections, retainedResolutions>>

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

FinalFrontierBackTo(k) ==
  {f \in FrontierAt(now) : FactLearned(f) <= k}

Init ==
  /\ now = 0
  /\ retainedFacts = {}
  /\ retainedCorrections = {}
  /\ retainedResolutions = {}

LearnInitialTemporalFact ==
  /\ now = 1
  /\ "t0" \notin retainedFacts
  /\ retainedFacts' = retainedFacts \union {"t0"}
  /\ UNCHANGED <<now, retainedCorrections, retainedResolutions>>

LearnFirstCorrection ==
  /\ now = 2
  /\ "t0" \in retainedFacts
  /\ "c1" \notin retainedCorrections
  /\ retainedFacts' = retainedFacts \union {"t1"}
  /\ retainedCorrections' = retainedCorrections \union {"c1"}
  /\ UNCHANGED <<now, retainedResolutions>>

LearnSiblingCorrection ==
  /\ now = 3
  /\ "c1" \in retainedCorrections
  /\ "c2" \notin retainedCorrections
  /\ retainedFacts' = retainedFacts \union {"t2"}
  /\ retainedCorrections' = retainedCorrections \union {"c2"}
  /\ UNCHANGED <<now, retainedResolutions>>

ResolveWholeConflict ==
  /\ now = 4
  /\ "c1" \in retainedCorrections
  /\ "c2" \in retainedCorrections
  /\ "h0" \notin retainedResolutions
  /\ FrontierAt(now) = {"t1", "t2"}
  /\ retainedFacts' = retainedFacts \union {"r0"}
  /\ retainedResolutions' = retainedResolutions \union {"h0"}
  /\ UNCHANGED <<now, retainedCorrections>>

Advance ==
  /\ now < 4
  /\ now' = now + 1
  /\ UNCHANGED <<retainedFacts, retainedCorrections, retainedResolutions>>

Next ==
  \/ LearnInitialTemporalFact
  \/ LearnFirstCorrection
  \/ LearnSiblingCorrection
  \/ ResolveWholeConflict
  \/ Advance

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ now \in 0..4
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

FirstCorrectionSettlesAlone ==
  ("c1" \in retainedCorrections /\ "c2" \notin retainedCorrections) =>
    FrontierAt(now) = {"t1"}

SiblingCorrectionsAreConflict ==
  ("c1" \in retainedCorrections /\
   "c2" \in retainedCorrections /\
   "h0" \notin retainedResolutions) =>
    FrontierAt(now) = {"t1", "t2"}

WholeConflictResolutionSettles ==
  "h0" \in retainedResolutions =>
    FrontierAt(now) = {"r0"}

HistoricalConflictPreserved ==
  "h0" \in retainedResolutions =>
    /\ FrontierAt(3) = {"t1", "t2"}
    /\ FrontierAt(4) = {"r0"}

ResolutionRetainsProvenance ==
  "h0" \in retainedResolutions =>
    /\ "t0" \in retainedFacts
    /\ "t1" \in retainedFacts
    /\ "t2" \in retainedFacts
    /\ "r0" \in retainedFacts
    /\ "c1" \in retainedCorrections
    /\ "c2" \in retainedCorrections

FinalFrontierCanReconstructHistoricalConflict ==
  "h0" \in retainedResolutions =>
    FinalFrontierBackTo(3) = FrontierAt(3)

=============================================================================

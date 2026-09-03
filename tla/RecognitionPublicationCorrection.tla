---- MODULE RecognitionPublicationCorrection ----
EXTENDS Naturals, FiniteSets

KnowledgeTimes == 0..3
RecognitionFactIds == {"r0", "r1"}
CorrectionIds == {"c0"}
PublicationIds == {"p0"}

\* r0 mirrors the immediate recognition shape from Observation 140.
\* r1 is a later replacement that mirrors the spread shape.
FactLearned(f) == IF f = "r0" THEN 1 ELSE 3
FactQueryAmount(f) == IF f = "r0" THEN 12 ELSE 6
FactWholeAmount(f) == 12

CorrectionTarget(c) == "r0"
CorrectionReplacement(c) == "r1"
CorrectionLearned(c) == 3

PublicationLearned(p) == 2
PublicationKnownThrough(p) == 2

VARIABLES now, retainedFacts, retainedCorrections, retainedPublications

vars == <<now, retainedFacts, retainedCorrections, retainedPublications>>

KnownFactsAt(k) ==
  {f \in retainedFacts : FactLearned(f) <= k}

KnownCorrectionsAt(k) ==
  {c \in retainedCorrections : CorrectionLearned(c) <= k}

TargetsAt(k) ==
  {CorrectionTarget(c) : c \in KnownCorrectionsAt(k)}

FrontierAt(k) ==
  KnownFactsAt(k) \ TargetsAt(k)

QueryAmountsAt(k) ==
  {FactQueryAmount(f) : f \in FrontierAt(k)}

WholeAmountsAt(k) ==
  {FactWholeAmount(f) : f \in FrontierAt(k)}

PublishedQueryAmounts(p) ==
  QueryAmountsAt(PublicationKnownThrough(p))

CurrentFrontier ==
  retainedFacts \ {CorrectionTarget(c) : c \in retainedCorrections}

CurrentFrontierKnownAt(k) ==
  {f \in CurrentFrontier : FactLearned(f) <= k}

CurrentFrontierQueryAmountsAt(k) ==
  {FactQueryAmount(f) : f \in CurrentFrontierKnownAt(k)}

Init ==
  /\ now = 0
  /\ retainedFacts = {}
  /\ retainedCorrections = {}
  /\ retainedPublications = {}

LearnInitialRecognition ==
  /\ now = 1
  /\ "r0" \notin retainedFacts
  /\ retainedFacts' = retainedFacts \cup {"r0"}
  /\ UNCHANGED <<now, retainedCorrections, retainedPublications>>

PublishHistoricalView ==
  /\ now = 2
  /\ "r0" \in retainedFacts
  /\ "p0" \notin retainedPublications
  /\ retainedPublications' = retainedPublications \cup {"p0"}
  /\ UNCHANGED <<now, retainedFacts, retainedCorrections>>

LearnRecognitionCorrection ==
  /\ now = 3
  /\ "r0" \in retainedFacts
  /\ "p0" \in retainedPublications
  /\ "r1" \notin retainedFacts
  /\ "c0" \notin retainedCorrections
  /\ retainedFacts' = retainedFacts \cup {"r1"}
  /\ retainedCorrections' = retainedCorrections \cup {"c0"}
  /\ UNCHANGED <<now, retainedPublications>>

Advance ==
  /\ now < 3
  /\ now' = now + 1
  /\ UNCHANGED <<retainedFacts, retainedCorrections, retainedPublications>>

Next ==
  \/ LearnInitialRecognition
  \/ PublishHistoricalView
  \/ LearnRecognitionCorrection
  \/ Advance

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ now \in KnowledgeTimes
  /\ retainedFacts \subseteq RecognitionFactIds
  /\ retainedCorrections \subseteq CorrectionIds
  /\ retainedPublications \subseteq PublicationIds

NoFutureRetainedKnowledge ==
  /\ \A f \in retainedFacts : FactLearned(f) <= now
  /\ \A c \in retainedCorrections : CorrectionLearned(c) <= now
  /\ \A p \in retainedPublications : PublicationLearned(p) <= now

ClosedCorrectionReferences ==
  \A c \in retainedCorrections :
    /\ CorrectionTarget(c) \in retainedFacts
    /\ CorrectionReplacement(c) \in retainedFacts

CorrectionLearnedAfterTarget ==
  \A c \in retainedCorrections :
    FactLearned(CorrectionTarget(c)) < CorrectionLearned(c)

ReplacementLearnedWithCorrection ==
  \A c \in retainedCorrections :
    FactLearned(CorrectionReplacement(c)) = CorrectionLearned(c)

PublicationUsesPastOrPresentKnowledge ==
  \A p \in retainedPublications :
    /\ PublicationKnownThrough(p) <= PublicationLearned(p)
    /\ PublicationLearned(p) <= now

FrontierUnique ==
  \A k \in KnowledgeTimes : Cardinality(FrontierAt(k)) <= 1

PublishedViewPreserved ==
  "p0" \in retainedPublications =>
    PublishedQueryAmounts("p0") = {12}

CurrentRestatementUsesCorrection ==
  "c0" \in retainedCorrections =>
    QueryAmountsAt(now) = {6}

PublishedAndRestatedCanCoexist ==
  ("p0" \in retainedPublications /\ "c0" \in retainedCorrections) =>
    /\ PublishedQueryAmounts("p0") = {12}
    /\ QueryAmountsAt(now) = {6}

WholeRecognitionConserved ==
  \A k \in KnowledgeTimes :
    Cardinality(FrontierAt(k)) = 1 => WholeAmountsAt(k) = {12}

FactsOnlyGrow ==
  [][retainedFacts \subseteq retainedFacts']_vars

CorrectionsOnlyGrow ==
  [][retainedCorrections \subseteq retainedCorrections']_vars

PublicationsOnlyGrow ==
  [][retainedPublications \subseteq retainedPublications']_vars

\* Deliberately too strong. Once later recognition evidence is admitted,
\* the historically published answer and the current restated answer diverge.
PublishedProjectionAlwaysEqualsCurrent ==
  "p0" \notin retainedPublications \/
  "c0" \notin retainedCorrections \/
    PublishedQueryAmounts("p0") = QueryAmountsAt(now)

\* Deliberately too strong. If only the final current frontier survives,
\* filtering it back to the publication horizon cannot recover r0.
CurrentFrontierCanReconstructPublished ==
  "p0" \notin retainedPublications \/
  "c0" \notin retainedCorrections \/
    CurrentFrontierQueryAmountsAt(PublicationKnownThrough("p0")) =
      PublishedQueryAmounts("p0")

====

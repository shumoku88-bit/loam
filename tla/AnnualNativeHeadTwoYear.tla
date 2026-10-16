---- MODULE AnnualNativeHeadTwoYear ----
EXTENDS Naturals, FiniteSets

\* Bounded behavioral model of merged #2042:
\*   baseline ordinal 0 in 2026, publication 1 in 2027, 2 in 2028.
\* Native full-section validation is abstracted to ValidateFullSource.
\* ASSUME process-visible atomic object/HEAD rename, NOT fsync/power durability.
\* calendarYear is TEST INJECTED, NOT an actual trusted admission clock.
\* committed is an INDEPENDENT GHOST freshness oracle, NOT stored in #2042.
\* The occupied orphan path prevents safe retry in current sandbox.
Ordinals == 0..2
Years == 2026..2028
Required(h) == {i \in Ordinals : i <= h}
Phases == {"idle", "partial", "checked", "installed", "head-staged"}
RefusalKinds == {"stale", "noop", "duplicate"}
ReadOutcomes == {"g0", "g1", "g2", "none", "unavailable"}
Answer(h) == IF h = 0 THEN "g0" ELSE IF h = 1 THEN "g1" ELSE "g2"

VARIABLES head, objects, phase, observedHead, committed, crashed,
          calendarYear, readPin, readAnswer, refused

vars == <<head, objects, phase, observedHead, committed, crashed,
          calendarYear, readPin, readAnswer, refused>>

Init ==
  /\ head = 0
  /\ objects = {0}
  /\ phase = "idle"
  /\ observedHead = 0
  /\ committed = 0
  /\ crashed = FALSE
  /\ calendarYear = 2026
  /\ readPin = 0
  /\ readAnswer = "none"
  /\ refused = {}

\* A calendar tick alone does not create a year journal.
AdvanceCalendar ==
  /\ calendarYear < 2028
  /\ calendarYear' = calendarYear + 1
  /\ UNCHANGED <<head, objects, phase, observedHead, committed,
                 crashed, readPin, readAnswer, refused>>

CaptureObservedHead ==
  /\ ~crashed
  /\ phase = "idle"
  /\ observedHead # head
  /\ observedHead' = head
  /\ UNCHANGED <<head, objects, phase, committed, crashed,
                 calendarYear, readPin, readAnswer, refused>>

\* The exact observed HEAD and next ordinal path must both be admissible.
BeginPublication ==
  /\ ~crashed
  /\ phase = "idle"
  /\ head < 2
  /\ observedHead = head
  /\ calendarYear >= 2026 + head + 1
  /\ (head + 1) \notin objects
  /\ phase' = "partial"
  /\ UNCHANGED <<head, objects, observedHead, committed, crashed,
                 calendarYear, readPin, readAnswer, refused>>

ValidateFullSource ==
  /\ ~crashed
  /\ phase = "partial"
  /\ phase' = "checked"
  /\ UNCHANGED <<head, objects, observedHead, committed, crashed,
                 calendarYear, readPin, readAnswer, refused>>

\* One full native object is installed BEFORE the HEAD changes.
InstallSourceObject ==
  /\ ~crashed
  /\ phase = "checked"
  /\ head < 2
  /\ objects' = objects \cup {head + 1}
  /\ phase' = "installed"
  /\ UNCHANGED <<head, observedHead, committed, crashed,
                 calendarYear, readPin, readAnswer, refused>>

ValidateCandidateHead ==
  /\ ~crashed
  /\ phase = "installed"
  /\ Required(head + 1) \subseteq objects
  /\ phase' = "head-staged"
  /\ UNCHANGED <<head, objects, observedHead, committed, crashed,
                 calendarYear, readPin, readAnswer, refused>>

CommitOneHead ==
  /\ ~crashed
  /\ phase = "head-staged"
  /\ head < 2
  /\ Required(head + 1) \subseteq objects
  /\ head' = head + 1
  /\ committed' = committed + 1
  /\ phase' = "idle"
  /\ UNCHANGED <<objects, observedHead, crashed,
                 calendarYear, readPin, readAnswer, refused>>

\* SIGKILL discards incomplete staging. An already installed source survives.
Crash ==
  /\ ~crashed
  /\ phase # "idle"
  /\ crashed' = TRUE
  /\ phase' = "idle"
  /\ UNCHANGED <<head, objects, observedHead, committed,
                 calendarYear, readPin, readAnswer, refused>>

Restart ==
  /\ crashed
  /\ crashed' = FALSE
  /\ UNCHANGED <<head, objects, phase, observedHead, committed,
                 calendarYear, readPin, readAnswer, refused>>

RefuseStale ==
  /\ ~crashed
  /\ phase = "idle"
  /\ observedHead # head
  /\ "stale" \notin refused
  /\ refused' = refused \cup {"stale"}
  /\ UNCHANGED <<head, objects, phase, observedHead, committed,
                 crashed, calendarYear, readPin, readAnswer>>

RefuseNoop ==
  /\ ~crashed
  /\ phase = "idle"
  /\ "noop" \notin refused
  /\ refused' = refused \cup {"noop"}
  /\ UNCHANGED <<head, objects, phase, observedHead, committed,
                 crashed, calendarYear, readPin, readAnswer>>

RefuseDuplicate ==
  /\ ~crashed
  /\ phase = "idle"
  /\ head > 0
  /\ "duplicate" \notin refused
  /\ refused' = refused \cup {"duplicate"}
  /\ UNCHANGED <<head, objects, phase, observedHead, committed,
                 crashed, calendarYear, readPin, readAnswer>>

\* Reader pins one selected HEAD and admits its FULL closure or unavailable.
ReadSelected ==
  /\ ~crashed
  /\ LET result == IF Required(head) \subseteq objects
                    THEN Answer(head) ELSE "unavailable"
     IN (readPin # head \/ readAnswer # result)
  /\ readPin' = head
  /\ readAnswer' = IF Required(head) \subseteq objects
                    THEN Answer(head) ELSE "unavailable"
  /\ UNCHANGED <<head, objects, phase, observedHead, committed,
                 crashed, calendarYear, refused>>

Next ==
  \/ AdvanceCalendar
  \/ CaptureObservedHead
  \/ BeginPublication
  \/ ValidateFullSource
  \/ InstallSourceObject
  \/ ValidateCandidateHead
  \/ CommitOneHead
  \/ Crash
  \/ Restart
  \/ RefuseStale
  \/ RefuseNoop
  \/ RefuseDuplicate
  \/ ReadSelected

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ head \in Ordinals
  /\ committed \in Ordinals
  /\ objects \subseteq Ordinals
  /\ phase \in Phases
  /\ observedHead \in Ordinals
  /\ crashed \in BOOLEAN
  /\ calendarYear \in Years
  /\ readPin \in Ordinals
  /\ readAnswer \in ReadOutcomes
  /\ refused \subseteq RefusalKinds

HeadReferencesCompleteSource == Required(head) \subseteq objects
HeadMatchesGhostChronology == head = committed
BaselineNeverDisappears == 0 \in objects
ReaderNeverInventsPartial ==
  readAnswer = "none" \/ readAnswer = "unavailable" \/ readAnswer = Answer(readPin)

IdleCalendarChangePreservesSource ==
  [][(calendarYear' # calendarYear) =>
    (head' = head /\ objects' = objects /\ committed' = committed)]_vars

\* Expected negative reachability: SIGKILL after object rename, before HEAD.
OrphanAfterCrashImpossible ==
  ~(crashed /\ head < 2 /\ (head + 1) \in objects)
NeverReachSecondYear == head # 2

\* UNSAFE: HEAD is promoted before source object exists.
UnsafeHeadFirst ==
  /\ ~crashed
  /\ phase = "checked"
  /\ head < 2
  /\ head' = head + 1
  /\ committed' = committed + 1
  /\ phase' = "idle"
  /\ UNCHANGED <<objects, observedHead, crashed, calendarYear,
                 readPin, readAnswer, refused>>
UnsafeHeadFirstSpec == Init /\ [][Next \/ UnsafeHeadFirst]_vars

\* UNSAFE: valid old HEAD restored. Only a trusted GHOST freshness witness
\* detects rollback. The native reader currently admits the old chain.
UnsafeValidOldHead ==
  /\ ~crashed
  /\ phase = "idle"
  /\ head = 2
  /\ head' = 1
  /\ UNCHANGED <<objects, phase, observedHead, committed, crashed,
                 calendarYear, readPin, readAnswer, refused>>
UnsafeRollbackSpec == Init /\ [][Next \/ UnsafeValidOldHead]_vars

\* UNSAFE partial restore: required selected source disappears.
UnsafeRemoveSelectedObject ==
  /\ ~crashed
  /\ phase = "idle"
  /\ head > 0
  /\ objects' = objects \ {head}
  /\ UNCHANGED <<head, phase, observedHead, committed, crashed,
                 calendarYear, readPin, readAnswer, refused>>
UnsafePartialRestoreSpec == Init /\ [][Next \/ UnsafeRemoveSelectedObject]_vars

====
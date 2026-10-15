---- MODULE AnnualSegmentCommitRecovery ----
EXTENDS Naturals

\* Finite abstract model of ONE annual rollover, not a POSIX durability proof.
\* An immutable old shard exists. A newly accepted source change is staged
\* in a new shard. An atomic head swap is the single logical commit point.
Old == "old"
New == "new"
DiskNames == {Old, New}
None == "none"
Partial == "partial"
Complete == "complete"
Checked == "checked"
Persisted == "persisted"
Stages == {None, Partial, Complete, Checked, Persisted}
Observations == {"old", "new", "unavailable"}

Required(h) == IF h = 0 THEN {Old} ELSE {Old, New}

VARIABLES year, durable, stage, head, commits, crashed, everCrashed,
          retryCount, observed, oldIntact, refusedRestore

vars == <<year, durable, stage, head, commits, crashed, everCrashed,
          retryCount, observed, oldIntact, refusedRestore>>

Init ==
  /\ year = 0
  /\ durable = {Old}
  /\ stage = None
  /\ head = 0
  /\ commits = 0
  /\ crashed = FALSE
  /\ everCrashed = FALSE
  /\ retryCount = 0
  /\ observed = {}
  /\ oldIntact = TRUE
  /\ refusedRestore = FALSE

\* Calendar year can change without opening an app or writing any data.
AdvanceYear ==
  /\ year < 2
  /\ year' = year + 1
  /\ UNCHANGED <<durable, stage, head, commits, crashed,
                 everCrashed, retryCount, observed, oldIntact, refusedRestore>>

\* Only an ordinary semantic write begins annual rollover, not a yearly close.
BeginOrdinaryPublication ==
  /\ ~crashed
  /\ year >= 1
  /\ head = 0
  /\ stage = None
  /\ stage' = Partial
  /\ UNCHANGED <<year, durable, head, commits, crashed,
                 everCrashed, retryCount, observed, oldIntact, refusedRestore>>

FinishNewSegment ==
  /\ ~crashed
  /\ stage = Partial
  /\ stage' = Complete
  /\ UNCHANGED <<year, durable, head, commits, crashed,
                 everCrashed, retryCount, observed, oldIntact, refusedRestore>>

ValidateNewSegment ==
  /\ ~crashed
  /\ stage = Complete
  /\ stage' = Checked
  /\ UNCHANGED <<year, durable, head, commits, crashed,
                 everCrashed, retryCount, observed, oldIntact, refusedRestore>>

\* Durability and checksum qualification are ASSUMED by this transition.
PersistNewSegment ==
  /\ ~crashed
  /\ stage = Checked
  /\ durable' = durable \cup {New}
  /\ stage' = Persisted
  /\ UNCHANGED <<year, head, commits, crashed,
                 everCrashed, retryCount, observed, oldIntact, refusedRestore>>

\* The only authority switch. Readers never inspect staging paths.
CommitNewHead ==
  /\ ~crashed
  /\ head = 0
  /\ stage = Persisted
  /\ Required(1) \subseteq durable
  /\ oldIntact
  /\ head' = 1
  /\ commits' = 1
  /\ stage' = None
  /\ UNCHANGED <<year, durable, crashed, everCrashed,
                 retryCount, observed, oldIntact, refusedRestore>>

\* Crash removes incomplete staging only. Precommit orphan shard is harmless.
Crash ==
  /\ ~crashed
  /\ crashed' = TRUE
  /\ everCrashed' = TRUE
  /\ stage' = None
  /\ UNCHANGED <<year, durable, head, commits,
                 retryCount, observed, oldIntact, refusedRestore>>

Restart ==
  /\ crashed
  /\ crashed' = FALSE
  /\ UNCHANGED <<year, durable, stage, head, commits,
                 everCrashed, retryCount, observed, oldIntact, refusedRestore>>

\* A committed logical retry never creates a second generation.
RetryCommitted ==
  /\ ~crashed
  /\ head = 1
  /\ retryCount = 0
  /\ retryCount' = 1
  /\ UNCHANGED <<year, durable, stage, head, commits, crashed,
                 everCrashed, observed, oldIntact, refusedRestore>>

\* An unqualified partial restore must refuse without changing authority.
RefuseUnqualifiedRestore ==
  /\ ~crashed
  /\ ~refusedRestore
  /\ refusedRestore' = TRUE
  /\ UNCHANGED <<year, durable, stage, head, commits, crashed,
                 everCrashed, retryCount, observed, oldIntact>>

\* Observed only through authoritative head; no source-side cache fallback.
Observe ==
  /\ (IF Required(head) \subseteq durable /\ oldIntact
      THEN observed' = observed \cup {IF head = 0 THEN "old" ELSE "new"}
      ELSE observed' = observed \cup {"unavailable"})
  /\ UNCHANGED <<year, durable, stage, head, commits, crashed,
                 everCrashed, retryCount, oldIntact, refusedRestore>>

Next ==
  \/ AdvanceYear
  \/ BeginOrdinaryPublication
  \/ FinishNewSegment
  \/ ValidateNewSegment
  \/ PersistNewSegment
  \/ CommitNewHead
  \/ Crash
  \/ Restart
  \/ RetryCommitted
  \/ RefuseUnqualifiedRestore
  \/ Observe

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ year \in 0..2
  /\ durable \subseteq DiskNames
  /\ stage \in Stages
  /\ head \in 0..1
  /\ commits \in 0..1
  /\ crashed \in BOOLEAN
  /\ everCrashed \in BOOLEAN
  /\ retryCount \in 0..1
  /\ observed \subseteq Observations
  /\ oldIntact \in BOOLEAN
  /\ refusedRestore \in BOOLEAN

HeadReferencesDurable == Required(head) \subseteq durable
SealedPastNeverMutated == oldIntact
HeadMatchesCommittedChronology == head = commits
NoPartialRead == observed \subseteq {"old", "new", "unavailable"}
SingleCommit == commits <= 1

\* A calendar transition alone never changes canonical artifacts.
IdleYearNeverPublishes ==
  [][(year' = year \/ (durable' = durable /\ head' = head /\
                     commits' = commits /\ oldIntact' = oldIntact))]_vars

HeadNeverRewinds == [][head' >= head]_vars

\* Negative reachability probes: each should get a witness.
YearNeverAdvances == year = 0
NoCommitAfterCrash == ~(everCrashed /\ head = 1)

\* UNSAFE 1: change head before new shard persisted.
UnsafeHeadFirst ==
  /\ ~crashed
  /\ head = 0
  /\ stage = Complete
  /\ head' = 1
  /\ commits' = 1
  /\ UNCHANGED <<year, durable, stage, crashed, everCrashed,
                 retryCount, observed, oldIntact, refusedRestore>>
HeadFirstSpec == Init /\ [][Next \/ UnsafeHeadFirst]_vars

\* UNSAFE 2: mutate a sealed previous year on a later correction.
UnsafeOverwriteOld ==
  /\ head = 1
  /\ oldIntact
  /\ oldIntact' = FALSE
  /\ UNCHANGED <<year, durable, stage, head, commits, crashed,
                 everCrashed, retryCount, observed, refusedRestore>>
OverwriteSpec == Init /\ [][Next \/ UnsafeOverwriteOld]_vars

\* UNSAFE 3: restore head but omit required segment.
UnsafePartialRestore ==
  /\ head = 1
  /\ New \in durable
  /\ durable' = durable \ {New}
  /\ UNCHANGED <<year, stage, head, commits, crashed, everCrashed,
                 retryCount, observed, oldIntact, refusedRestore>>
PartialRestoreSpec == Init /\ [][Next \/ UnsafePartialRestore]_vars

\* UNSAFE 4: silently roll back the published head after a commit.
UnsafeHeadRollback ==
  /\ head = 1
  /\ head' = 0
  /\ UNCHANGED <<year, durable, stage, commits, crashed, everCrashed,
                 retryCount, observed, oldIntact, refusedRestore>>
RollbackSpec == Init /\ [][Next \/ UnsafeHeadRollback]_vars

====

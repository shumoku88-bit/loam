---- MODULE AnnualNativeOrphanRecovery ----
EXTENDS Naturals

\* Bounded correspondence with #2044. 0 is the 2026 baseline.
\* Publication ordinals 1 and 2 are 2027 and 2028, respectively.
\* An "exact" object matches the ENTIRE native expected publication,
\* including predecessor, date, identity, changed families and image bytes.
\* A "foreign" object is a mismatched or corrupt orphan. The real codec's
\* semantic correctness and atomic process-visible rename are ASSUMED.
\* No file fsync, directory fsync, power-loss or trusted clock is modeled.
\* committed is a ghost for logic, NOT a trusted rollback anchor.
Ordinals == 0..2
SourceStates == {"absent", "exact", "foreign"}
Phases == {"idle", "staging", "installed", "head-staged"}
Responses == {"none", "g0", "g1", "g2"}
Result(h) == IF h = 0 THEN "g0" ELSE IF h = 1 THEN "g1" ELSE "g2"

VARIABLES head, committed, source, phase, killed, wasKilled,
          requested, currentYear, retryCount, mismatchRefused,
          readResult, badAdoption

vars == <<head, committed, source, phase, killed, wasKilled,
          requested, currentYear, retryCount, mismatchRefused,
          readResult, badAdoption>>

Init ==
  /\ head = 0
  /\ committed = 0
  /\ source = [i \in {1,2} |-> "absent"]
  /\ phase = "idle"
  /\ killed = FALSE
  /\ wasKilled = FALSE
  /\ requested = "same"
  /\ currentYear = 2026
  /\ retryCount = 0
  /\ mismatchRefused = FALSE
  /\ readResult = "none"
  /\ badAdoption = FALSE

AdvanceYear ==
  /\ currentYear < 2028
  /\ currentYear' = currentYear + 1
  /\ UNCHANGED <<head, committed, source, phase, killed, wasKilled,
                 requested, retryCount, mismatchRefused, readResult, badAdoption>>

StartNew ==
  /\ ~killed
  /\ head < 2
  /\ phase = "idle"
  /\ requested = "same"
  /\ source[head + 1] = "absent"
  /\ currentYear >= 2027 + head
  /\ phase' = "staging"
  /\ UNCHANGED <<head, committed, source, killed, wasKilled,
                 requested, currentYear, retryCount, mismatchRefused,
                 readResult, badAdoption>>

InstallExactSource ==
  /\ ~killed
  /\ phase = "staging"
  /\ head < 2
  /\ source' = [source EXCEPT ![head + 1] = "exact"]
  /\ phase' = "installed"
  /\ UNCHANGED <<head, committed, killed, wasKilled,
                 requested, currentYear, retryCount, mismatchRefused,
                 readResult, badAdoption>>

RequalifyStagedHead ==
  /\ ~killed
  /\ phase = "installed"
  /\ head < 2
  /\ source[head + 1] = "exact"
  /\ phase' = "head-staged"
  /\ UNCHANGED <<head, committed, source, killed, wasKilled,
                 requested, currentYear, retryCount, mismatchRefused,
                 readResult, badAdoption>>

CommitHead ==
  /\ ~killed
  /\ phase = "head-staged"
  /\ head < 2
  /\ source[head + 1] = "exact"
  /\ head' = head + 1
  /\ committed' = committed + 1
  /\ phase' = "idle"
  /\ UNCHANGED <<source, killed, wasKilled,
                 requested, currentYear, retryCount, mismatchRefused,
                 readResult, badAdoption>>

KillWriter ==
  /\ ~killed
  /\ phase # "idle"
  /\ killed' = TRUE
  /\ wasKilled' = TRUE
  /\ phase' = "idle"
  /\ UNCHANGED <<head, committed, source, requested, currentYear,
                 retryCount, mismatchRefused, readResult, badAdoption>>

Restart ==
  /\ killed
  /\ killed' = FALSE
  /\ UNCHANGED <<head, committed, source, phase, wasKilled, requested,
                 currentYear, retryCount, mismatchRefused, readResult,
                 badAdoption>>

SelectDifferentRequest ==
  /\ ~killed
  /\ phase = "idle"
  /\ requested = "same"
  /\ requested' = "different"
  /\ UNCHANGED <<head, committed, source, phase, killed, wasKilled,
                 currentYear, retryCount, mismatchRefused, readResult,
                 badAdoption>>

SelectOriginalRequest ==
  /\ ~killed
  /\ phase = "idle"
  /\ requested = "different"
  /\ requested' = "same"
  /\ UNCHANGED <<head, committed, source, phase, killed, wasKilled,
                 currentYear, retryCount, mismatchRefused, readResult,
                 badAdoption>>

InstallForeignOrphan ==
  /\ ~killed
  /\ phase = "idle"
  /\ head < 2
  /\ source[head + 1] = "absent"
  /\ source' = [source EXCEPT ![head + 1] = "foreign"]
  /\ UNCHANGED <<head, committed, phase, killed, wasKilled,
                 requested, currentYear, retryCount, mismatchRefused,
                 readResult, badAdoption>>

RefuseMismatch ==
  /\ ~killed
  /\ phase = "idle"
  /\ head < 2
  /\ source[head + 1] # "absent"
  /\ (requested = "different" \/ source[head + 1] = "foreign")
  /\ ~mismatchRefused
  /\ mismatchRefused' = TRUE
  /\ UNCHANGED <<head, committed, source, phase, killed, wasKilled,
                 requested, currentYear, retryCount, readResult, badAdoption>>

\* A byte-exact fully requalified orphan is never rewritten or deleted.
\* The writer completes only ONE selected HEAD commit after full replay.
ResumeExactOrphan ==
  /\ ~killed
  /\ phase = "idle"
  /\ head < 2
  /\ requested = "same"
  /\ source[head + 1] = "exact"
  /\ currentYear >= 2027 + head
  /\ retryCount < 2
  /\ phase' = "head-staged"
  /\ retryCount' = retryCount + 1
  /\ UNCHANGED <<head, committed, source, killed, wasKilled,
                 requested, currentYear, mismatchRefused, readResult,
                 badAdoption>>

ReadSelected ==
  /\ ~killed
  /\ readResult # Result(head)
  /\ readResult' = Result(head)
  /\ UNCHANGED <<head, committed, source, phase, killed, wasKilled,
                 requested, currentYear, retryCount, mismatchRefused,
                 badAdoption>>

Next ==
  \/ AdvanceYear
  \/ StartNew
  \/ InstallExactSource
  \/ RequalifyStagedHead
  \/ CommitHead
  \/ KillWriter
  \/ Restart
  \/ SelectDifferentRequest
  \/ SelectOriginalRequest
  \/ InstallForeignOrphan
  \/ RefuseMismatch
  \/ ResumeExactOrphan
  \/ ReadSelected

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ head \in Ordinals
  /\ committed \in Ordinals
  /\ source \in [{1,2} -> SourceStates]
  /\ phase \in Phases
  /\ killed \in BOOLEAN
  /\ wasKilled \in BOOLEAN
  /\ requested \in {"same", "different"}
  /\ currentYear \in 2026..2028
  /\ retryCount \in Ordinals
  /\ mismatchRefused \in BOOLEAN
  /\ readResult \in Responses
  /\ badAdoption \in BOOLEAN

SelectedClosureIsExact ==
  \A ordinal \in {1,2} : ordinal <= head => source[ordinal] = "exact"
SingleHeadMatchesGhostCommit == head = committed
NoMismatchedOrphanAdoption == badAdoption = FALSE
NoPartialSelectedRead == readResult \in Responses

\* Expected counterexample witnesses prove reachability, not safe protocol bugs.
NeverResumeAfterProcessKill == ~(wasKilled /\ retryCount > 0)
NeverRefuseDifferentOrphan == ~mismatchRefused
NeverCommitSecondYear == head # 2

\* Deliberately unsafe mutation, disallowed by native #2044 writer.
UnsafeAdoptForeign ==
  /\ ~killed
  /\ phase = "idle"
  /\ head < 2
  /\ source[head + 1] = "foreign"
  /\ badAdoption' = TRUE
  /\ head' = head + 1
  /\ committed' = committed + 1
  /\ UNCHANGED <<source, phase, killed, wasKilled, requested,
                 currentYear, retryCount, mismatchRefused, readResult>>

UnsafeAdoptionSpec == Init /\ [][Next \/ UnsafeAdoptForeign]_vars

====
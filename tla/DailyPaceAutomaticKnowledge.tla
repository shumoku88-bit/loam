---- MODULE DailyPaceAutomaticKnowledge ----
EXTENDS Naturals, Sequences

\* Research-only, finite model of one qualified HouseholdImage publication.
\* "knowledge" stores committed operation/source references and learned days,
\* not Daily Pace snapshots, duplicate amounts or a calendar-day closing row.
\* This is a publication protocol model, not a production codec specification.

Days == 0..3
Ops == {"move", "complete", "policy"}
Sources == {"event-m", "terminal-c", "actual-c", "policy-v1"}
NoStage == "no-stage"

SourceOf(op) ==
  CASE op = "move" -> {"event-m"}
    [] op = "complete" -> {"terminal-c", "actual-c"}
    [] op = "policy" -> {"policy-v1"}

VARIABLES day, image, knowledge, generation, stage,
          crashed, hadCrash, retryCount, externalPending

vars == <<day, image, knowledge, generation, stage,
          crashed, hadCrash, retryCount, externalPending>>

Committed(H) == {H[i].op : i \in DOMAIN H}

ExpectedImage(H) ==
  UNION {SourceOf(op) : op \in Committed(H)}

KnownBy(H, cut) ==
  {H[i].op : i \in DOMAIN H /\ H[i].learned <= cut}

\* A toy exact free-money projection for testing calendar-only progression.
\* Completion releases a protected obligation while spending the matched
\* cash: the numerator does not change. Policy is an identified version,
\* not an asserted source of extra money.
FreeMoneyAt(cut) ==
  120 - (IF "move" \in KnownBy(knowledge, cut) THEN 30 ELSE 0)

PaceAt(cut) == FreeMoneyAt(cut) \div (10 - cut)

Init ==
  /\ day = 0
  /\ image = {}
  /\ knowledge = <<>>
  /\ generation = 0
  /\ stage = NoStage
  /\ crashed = FALSE
  /\ hadCrash = FALSE
  /\ retryCount = 0
  /\ externalPending = FALSE

\* Staging a proposed change does not update the authoritative generation.
Prepare(op) ==
  /\ ~crashed
  /\ stage = NoStage
  /\ op \in Ops \ Committed(knowledge)
  /\ stage' = [op |-> op, base |-> generation]
  /\ UNCHANGED <<day, image, knowledge, generation,
                 crashed, hadCrash, retryCount, externalPending>>

\* Single-generation commit: fact identities and their learned-day
\* membership become visible in the same atomic authority-path transition.
CommitPrepared ==
  /\ ~crashed
  /\ stage # NoStage
  /\ stage.base = generation
  /\ stage.op \notin Committed(knowledge)
  /\ image' = image \cup SourceOf(stage.op)
  /\ knowledge' = Append(knowledge, [op |-> stage.op, learned |-> day])
  /\ generation' = generation + 1
  /\ stage' = NoStage
  /\ UNCHANGED <<day, crashed, hadCrash, retryCount, externalPending>>

\* Another admitted writer can publish after a draft observed an old
\* generation. This must invalidate the draft's CAS base.
CommitConcurrent(op) ==
  /\ ~crashed
  /\ op \in Ops \ Committed(knowledge)
  /\ image' = image \cup SourceOf(op)
  /\ knowledge' = Append(knowledge, [op |-> op, learned |-> day])
  /\ generation' = generation + 1
  /\ UNCHANGED <<day, stage, crashed, hadCrash, retryCount, externalPending>>

RejectStale ==
  /\ ~crashed
  /\ stage # NoStage
  /\ stage.base # generation
  /\ stage' = NoStage
  /\ UNCHANGED <<day, image, knowledge, generation,
                 crashed, hadCrash, retryCount, externalPending>>

\* Crash loses the proposal only. The last committed authority stays intact.
Crash ==
  /\ ~crashed
  /\ stage # NoStage
  /\ crashed' = TRUE
  /\ hadCrash' = TRUE
  /\ stage' = NoStage
  /\ UNCHANGED <<day, image, knowledge, generation,
                 retryCount, externalPending>>

Restart ==
  /\ crashed
  /\ crashed' = FALSE
  /\ UNCHANGED <<day, image, knowledge, generation,
                 stage, hadCrash, retryCount, externalPending>>

\* A logical retry of an already committed request cannot create a second
\* learned-time row or a second household generation.
RetryCommitted(op) ==
  /\ ~crashed
  /\ op \in Committed(knowledge)
  /\ retryCount < 1
  /\ retryCount' = retryCount + 1
  /\ UNCHANGED <<day, image, knowledge, generation,
                 stage, crashed, hadCrash, externalPending>>

\* Calendar time advances without any write and without an active process.
AdvanceDay ==
  /\ day < 3
  /\ day' = day + 1
  /\ UNCHANGED <<image, knowledge, generation, stage,
                 crashed, hadCrash, retryCount, externalPending>>

\* External editing is NOT a qualified Household publication.
ExternalEdit ==
  /\ ~externalPending
  /\ "policy" \notin Committed(knowledge)
  /\ externalPending' = TRUE
  /\ UNCHANGED <<day, image, knowledge, generation, stage,
                 crashed, hadCrash, retryCount>>

\* First qualified policy adoption records the observation/acceptance day,
\* not the unknowable physical edit day. Stale prepared drafts are rejected.
AdoptExternal ==
  /\ ~crashed
  /\ externalPending
  /\ "policy" \notin Committed(knowledge)
  /\ image' = image \cup SourceOf("policy")
  /\ knowledge' = Append(knowledge, [op |-> "policy", learned |-> day])
  /\ generation' = generation + 1
  /\ externalPending' = FALSE
  /\ UNCHANGED <<day, stage, crashed, hadCrash, retryCount>>

Next ==
  \/ \E op \in Ops : Prepare(op)
  \/ CommitPrepared
  \/ \E op \in Ops : CommitConcurrent(op)
  \/ RejectStale
  \/ Crash
  \/ Restart
  \/ \E op \in Ops : RetryCommitted(op)
  \/ AdvanceDay
  \/ ExternalEdit
  \/ AdoptExternal

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ day \in Days
  /\ image \subseteq Sources
  /\ knowledge \in Seq([op : Ops, learned : Days])
  /\ generation \in 0..3
  /\ (stage = NoStage \/ stage \in [op : Ops, base : 0..3])
  /\ crashed \in BOOLEAN
  /\ hadCrash \in BOOLEAN
  /\ retryCount \in 0..1
  /\ externalPending \in BOOLEAN

BodyMatchesKnowledge == image = ExpectedImage(knowledge)

CompletionAtomic ==
  ("terminal-c" \in image) <=> ("actual-c" \in image)

NoDuplicateOperations ==
  \A i, j \in DOMAIN knowledge :
    knowledge[i].op = knowledge[j].op => i = j

PublicationCount ==
  generation = Len(knowledge)

KnowledgeNotFromFuture ==
  \A i \in DOMAIN knowledge : knowledge[i].learned <= day

KnowledgeDaysNondecreasing ==
  \A i, j \in DOMAIN knowledge :
    i < j => knowledge[i].learned <= knowledge[j].learned

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

AppendOnlyKnowledge == [][IsPrefix(knowledge, knowledge')]_vars

\* Reading another calendar day needs no recorded "day closed" transition.
UnattendedDayDoesNotWrite ==
  [][(day' = day \/
      (image' = image /\ knowledge' = knowledge /\ generation' = generation))]_vars

\* These are intentionally false reachability probes, not safety obligations:
\* a day can change the pace even though no knowledge row was recorded.
IdleNeverChangesPace ==
  Len(knowledge) # 0 \/ PaceAt(day) = PaceAt(0)

\* A crashed draft can later be retried and committed after restarting.
NoCommitAfterAnyCrash ==
  ~(hadCrash /\ "move" \in Committed(knowledge))

\* Sensitivity model: split publication of Actual without learned metadata.
UnsafeSplitActual ==
  /\ ~crashed
  /\ stage # NoStage
  /\ stage.op = "complete"
  /\ stage.base = generation
  /\ image' = image \cup {"actual-c"}
  /\ UNCHANGED <<day, knowledge, generation, stage,
                 crashed, hadCrash, retryCount, externalPending>>

SplitNext == Next \/ UnsafeSplitActual
SplitSpec == Init /\ [][SplitNext]_vars

\* Sensitivity model: blindly restore an old physical image but not the
\* durable knowledge timeline. Real restore must be explicitly versioned,
\* reconciled or refused; reusing .prev is not historical time travel.
UnsafeRestore ==
  /\ ~crashed
  /\ knowledge # <<>>
  /\ image' = {}
  /\ UNCHANGED <<day, knowledge, generation, stage,
                 crashed, hadCrash, retryCount, externalPending>>

RestoreNext == Next \/ UnsafeRestore
RestoreSpec == Init /\ [][RestoreNext]_vars

====

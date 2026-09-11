---------------- MODULE Observation245CapacityPublicationTopology ----------------

\* Capacity-specific comparison after production PR #698 hid the backing
\* topology behind CapacityAuthority.
\*
\* `effectiveNew` and `movementNew` represent whether one fresh Capacity
\* operation's two retained meanings are durably present. The semantic meanings
\* stay fixed in both protocols; only physical publication topology changes.
\*
\* SplitNext mirrors the current production ordering:
\*   admit complete image -> publish effective evidence -> publish movement.
\* A restart re-enters ordinary admission. Because production admission rejects
\* incomplete evidence, a crash after the first write can become blocked.
\*
\* AtomicNext represents one typed Capacity image replaced atomically. It does
\* not claim that this topology is operationally superior; it only removes the
\* cross-file incomplete state from this bounded model.

VARIABLES
  \* @type: Bool;
  effectiveNew,
  \* @type: Bool;
  movementNew,
  \* @type: Bool;
  writerUp,
  \* @type: Str;
  pc,
  \* @type: Bool;
  writerCrashed,
  \* @type: Bool;
  crashedAfterEffective,
  \* @type: Bool;
  blocked

vars == <<
  effectiveNew,
  movementNew,
  writerUp,
  pc,
  writerCrashed,
  crashedAfterEffective,
  blocked
>>

TypeOK ==
  /\ effectiveNew \in BOOLEAN
  /\ movementNew \in BOOLEAN
  /\ writerUp \in BOOLEAN
  /\ pc \in {"admit", "effective", "movement", "atomic", "done", "blocked"}
  /\ writerCrashed \in BOOLEAN
  /\ crashedAfterEffective \in BOOLEAN
  /\ blocked \in BOOLEAN

Init ==
  /\ effectiveNew = FALSE
  /\ movementNew = FALSE
  /\ writerUp = TRUE
  /\ pc = "admit"
  /\ writerCrashed = FALSE
  /\ crashedAfterEffective = FALSE
  /\ blocked = FALSE

\* --------------------------------------------------------------------------
\* Current split-file protocol.
\* --------------------------------------------------------------------------

SplitAdmit ==
  /\ writerUp
  /\ pc = "admit"
  /\ effectiveNew = movementNew
  /\ pc' = "effective"
  /\ UNCHANGED <<
       effectiveNew,
       movementNew,
       writerUp,
       writerCrashed,
       crashedAfterEffective,
       blocked
     >>

SplitPublishEffective ==
  /\ writerUp
  /\ pc = "effective"
  /\ effectiveNew' = TRUE
  /\ pc' = "movement"
  /\ UNCHANGED <<
       movementNew,
       writerUp,
       writerCrashed,
       crashedAfterEffective,
       blocked
     >>

SplitPublishMovement ==
  /\ writerUp
  /\ pc = "movement"
  /\ movementNew' = TRUE
  /\ pc' = "done"
  /\ UNCHANGED <<
       effectiveNew,
       writerUp,
       writerCrashed,
       crashedAfterEffective,
       blocked
     >>

SplitCrash ==
  /\ writerUp
  /\ pc # "done"
  /\ pc # "blocked"
  /\ writerUp' = FALSE
  /\ writerCrashed' = TRUE
  /\ crashedAfterEffective' =
       (crashedAfterEffective \/ (effectiveNew /\ ~movementNew))
  /\ UNCHANGED <<
       effectiveNew,
       movementNew,
       pc,
       blocked
     >>

SplitRestart ==
  /\ ~writerUp
  /\ writerUp' = TRUE
  /\ pc' = "admit"
  /\ UNCHANGED <<
       effectiveNew,
       movementNew,
       writerCrashed,
       crashedAfterEffective,
       blocked
     >>

\* This is the important Capacity-specific difference from Observation 060.
\* Ordinary publication does not treat an already-published dependent row as
\* an idempotent first step. It first rechecks global completeness and refuses.
SplitRejectIncomplete ==
  /\ writerUp
  /\ pc = "admit"
  /\ effectiveNew # movementNew
  /\ pc' = "blocked"
  /\ blocked' = TRUE
  /\ UNCHANGED <<
       effectiveNew,
       movementNew,
       writerUp,
       writerCrashed,
       crashedAfterEffective
     >>

Stutter == UNCHANGED vars

SplitNext ==
  \/ SplitAdmit
  \/ SplitPublishEffective
  \/ SplitPublishMovement
  \/ SplitCrash
  \/ SplitRestart
  \/ SplitRejectIncomplete
  \/ Stutter

SplitActivationSafe == movementNew => effectiveNew
SplitCoverageAvailable == (effectiveNew = movementNew)

SplitShape ==
  /\ (pc = "effective" => ~effectiveNew /\ ~movementNew)
  /\ (pc = "movement" => effectiveNew /\ ~movementNew)
  /\ (pc = "done" => effectiveNew /\ movementNew)
  /\ (pc = "blocked" => blocked /\ effectiveNew # movementNew)
  /\ (blocked => pc = "blocked" /\ effectiveNew # movementNew)
  /\ (crashedAfterEffective => effectiveNew /\ ~movementNew)

SplitIndInv ==
  /\ TypeOK
  /\ SplitActivationSafe
  /\ pc # "atomic"
  /\ SplitShape

SplitSafety == TypeOK /\ SplitActivationSafe

\* False-on-a-real-path probes used to require concrete witnesses.
NoSplitCrashUnavailable ==
  ~(crashedAfterEffective /\ ~SplitCoverageAvailable)

NoSplitBlockedRestart == ~blocked

\* --------------------------------------------------------------------------
\* One atomically replaced typed Capacity image, with the same two meanings.
\* --------------------------------------------------------------------------

AtomicAdmit ==
  /\ writerUp
  /\ pc = "admit"
  /\ effectiveNew = movementNew
  /\ pc' = "atomic"
  /\ UNCHANGED <<
       effectiveNew,
       movementNew,
       writerUp,
       writerCrashed,
       crashedAfterEffective,
       blocked
     >>

AtomicCommit ==
  /\ writerUp
  /\ pc = "atomic"
  /\ effectiveNew' = TRUE
  /\ movementNew' = TRUE
  /\ pc' = "done"
  /\ UNCHANGED <<
       writerUp,
       writerCrashed,
       crashedAfterEffective,
       blocked
     >>

AtomicCrash ==
  /\ writerUp
  /\ pc # "done"
  /\ writerUp' = FALSE
  /\ writerCrashed' = TRUE
  /\ UNCHANGED <<
       effectiveNew,
       movementNew,
       pc,
       crashedAfterEffective,
       blocked
     >>

AtomicRestart ==
  /\ ~writerUp
  /\ writerUp' = TRUE
  /\ pc' = "admit"
  /\ UNCHANGED <<
       effectiveNew,
       movementNew,
       writerCrashed,
       crashedAfterEffective,
       blocked
     >>

AtomicNext ==
  \/ AtomicAdmit
  \/ AtomicCommit
  \/ AtomicCrash
  \/ AtomicRestart
  \/ Stutter

AtomicShape ==
  /\ effectiveNew = movementNew
  /\ pc \in {"admit", "atomic", "done"}
  /\ ~blocked
  /\ ~crashedAfterEffective
  /\ (pc = "atomic" => ~effectiveNew /\ ~movementNew)
  /\ (pc = "done" => effectiveNew /\ movementNew)

AtomicIndInv == TypeOK /\ AtomicShape
AtomicCoverageAvailable == (effectiveNew = movementNew)
AtomicSafety == TypeOK /\ AtomicCoverageAvailable /\ SplitActivationSafe

\* A crash before the atomic replacement can be followed by ordinary restart,
\* re-admission, and completion because persistent evidence stayed complete.
NoAtomicRecoveredCompletion ==
  ~(writerCrashed /\ effectiveNew /\ movementNew)

=============================================================================

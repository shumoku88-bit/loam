---------------- MODULE Observation060SplitPublicationRecovery ----------------

\* Observation 060 extends the bounded split-publication protocol from
\* Observation 059 with crash/restart and explicit retry.
\*
\* One original Event is already part of the old snapshot. These booleans only
\* represent whether the newly offered Correction and replacement Event have
\* reached their respective physical streams.

VARIABLES
  \* @type: Bool;
  diskEventNew,
  \* @type: Bool;
  diskCorrectionNew,
  \* @type: Bool;
  writerUp,
  \* @type: Str;
  writerPc,
  \* @type: Bool;
  writerCrashed,
  \* @type: Bool;
  crashedAfterRelation,
  \* @type: Bool;
  readerUp,
  \* @type: Str;
  readerPc,
  \* @type: Bool;
  seenEventNew,
  \* @type: Bool;
  seenCorrectionNew,
  \* @type: Bool;
  readerDone

vars == <<
  diskEventNew,
  diskCorrectionNew,
  writerUp,
  writerPc,
  writerCrashed,
  crashedAfterRelation,
  readerUp,
  readerPc,
  seenEventNew,
  seenCorrectionNew,
  readerDone
>>

TypeOK ==
  /\ diskEventNew \in BOOLEAN
  /\ diskCorrectionNew \in BOOLEAN
  /\ writerUp \in BOOLEAN
  /\ writerPc \in {"relation", "event", "done"}
  /\ writerCrashed \in BOOLEAN
  /\ crashedAfterRelation \in BOOLEAN
  /\ readerUp \in BOOLEAN
  /\ readerPc \in {"event", "correction", "done"}
  /\ seenEventNew \in BOOLEAN
  /\ seenCorrectionNew \in BOOLEAN
  /\ readerDone \in BOOLEAN

Init ==
  /\ diskEventNew = FALSE
  /\ diskCorrectionNew = FALSE
  /\ writerUp = TRUE
  /\ writerPc = "relation"
  /\ writerCrashed = FALSE
  /\ crashedAfterRelation = FALSE
  /\ readerUp = TRUE
  /\ readerPc = "event"
  /\ seenEventNew = FALSE
  /\ seenCorrectionNew = FALSE
  /\ readerDone = FALSE

\* The candidate writer protocol from Observation 059 publishes the raw
\* Correction before the replacement Event. The relation may therefore exist
\* physically while fail-closed admission still keeps it semantically inert.
WriterPublishCorrection ==
  /\ writerUp
  /\ writerPc = "relation"
  /\ diskCorrectionNew' = TRUE
  /\ writerPc' = "event"
  /\ UNCHANGED <<
       diskEventNew,
       writerUp,
       writerCrashed,
       crashedAfterRelation,
       readerUp,
       readerPc,
       seenEventNew,
       seenCorrectionNew,
       readerDone
     >>

WriterPublishEvent ==
  /\ writerUp
  /\ writerPc = "event"
  /\ diskEventNew' = TRUE
  /\ writerPc' = "done"
  /\ UNCHANGED <<
       diskCorrectionNew,
       writerUp,
       writerCrashed,
       crashedAfterRelation,
       readerUp,
       readerPc,
       seenEventNew,
       seenCorrectionNew,
       readerDone
     >>

\* A crash loses volatile writer progress but does not roll back either
\* atomically replaced physical stream. `crashedAfterRelation` records the
\* specific midpoint where the Correction is durable but the Event is not.
WriterCrash ==
  /\ writerUp
  /\ writerPc # "done"
  /\ writerUp' = FALSE
  /\ writerCrashed' = TRUE
  /\ crashedAfterRelation' =
       (crashedAfterRelation \/ (diskCorrectionNew /\ ~diskEventNew))
  /\ UNCHANGED <<
       diskEventNew,
       diskCorrectionNew,
       writerPc,
       readerUp,
       readerPc,
       seenEventNew,
       seenCorrectionNew,
       readerDone
     >>

\* Restart means the same publication request is explicitly retried from its
\* first idempotent step. The retry intent is supplied externally; this model
\* does not claim it can be reconstructed from canonical facts on disk.
WriterRestart ==
  /\ ~writerUp
  /\ writerUp' = TRUE
  /\ writerPc' = "relation"
  /\ UNCHANGED <<
       diskEventNew,
       diskCorrectionNew,
       writerCrashed,
       crashedAfterRelation,
       readerUp,
       readerPc,
       seenEventNew,
       seenCorrectionNew,
       readerDone
     >>

\* The reader acquires in the opposite order: Event stream, then Correction
\* stream. This is the paired protocol discovered by Observation 059.
ReaderReadEvent ==
  /\ readerUp
  /\ readerPc = "event"
  /\ seenEventNew' = diskEventNew
  /\ readerPc' = "correction"
  /\ UNCHANGED <<
       diskEventNew,
       diskCorrectionNew,
       writerUp,
       writerPc,
       writerCrashed,
       crashedAfterRelation,
       readerUp,
       seenCorrectionNew,
       readerDone
     >>

ReaderReadCorrection ==
  /\ readerUp
  /\ readerPc = "correction"
  /\ seenCorrectionNew' = diskCorrectionNew
  /\ readerPc' = "done"
  /\ readerDone' = TRUE
  /\ UNCHANGED <<
       diskEventNew,
       diskCorrectionNew,
       writerUp,
       writerPc,
       writerCrashed,
       crashedAfterRelation,
       readerUp,
       seenEventNew
     >>

ReaderCrash ==
  /\ readerUp
  /\ readerPc # "done"
  /\ readerUp' = FALSE
  /\ UNCHANGED <<
       diskEventNew,
       diskCorrectionNew,
       writerUp,
       writerPc,
       writerCrashed,
       crashedAfterRelation,
       readerPc,
       seenEventNew,
       seenCorrectionNew,
       readerDone
     >>

\* A restarted reader discards a partial acquisition and samples both physical
\* streams again from the first read step.
ReaderRestart ==
  /\ ~readerUp
  /\ readerUp' = TRUE
  /\ readerPc' = "event"
  /\ seenEventNew' = FALSE
  /\ seenCorrectionNew' = FALSE
  /\ readerDone' = FALSE
  /\ UNCHANGED <<
       diskEventNew,
       diskCorrectionNew,
       writerUp,
       writerPc,
       writerCrashed,
       crashedAfterRelation
     >>

\* Permit another complete acquisition after a successful read so Apalache can
\* mix multiple reader snapshots with crash/retry writer behavior.
ReaderBeginAgain ==
  /\ readerUp
  /\ readerPc = "done"
  /\ readerPc' = "event"
  /\ seenEventNew' = FALSE
  /\ seenCorrectionNew' = FALSE
  /\ readerDone' = FALSE
  /\ UNCHANGED <<
       diskEventNew,
       diskCorrectionNew,
       writerUp,
       writerPc,
       writerCrashed,
       crashedAfterRelation,
       readerUp
     >>

Stutter == UNCHANGED vars

Next ==
  \/ WriterPublishCorrection
  \/ WriterPublishEvent
  \/ WriterCrash
  \/ WriterRestart
  \/ ReaderReadEvent
  \/ ReaderReadCorrection
  \/ ReaderCrash
  \/ ReaderRestart
  \/ ReaderBeginAgain
  \/ Stutter

\* Physical writer invariant: once the replacement Event is visible, the raw
\* Correction must already be visible. A crash may leave the opposite mixed
\* state (Correction new, Event old), which remains semantically inert.
DiskOrder == diskEventNew => diskCorrectionNew

\* A completed reader snapshot must never expose the new replacement Event
\* while still carrying the old Correction stream.
ReaderSnapshotSafe ==
  readerDone => ~(seenEventNew /\ ~seenCorrectionNew)

Safety == TypeOK /\ DiskOrder /\ ReaderSnapshotSafe

\* Stronger reachable-state shape used for Apalache's inductive-invariant
\* check. These clauses describe protocol facts, not new domain semantics.
WriterShape ==
  /\ (writerPc = "event" => diskCorrectionNew)
  /\ (writerPc = "done" => diskEventNew /\ diskCorrectionNew)
  /\ (~writerUp => writerCrashed)
  /\ (crashedAfterRelation => writerCrashed /\ diskCorrectionNew)

ReaderShape ==
  /\ (readerPc = "event" =>
        ~seenEventNew /\ ~seenCorrectionNew /\ ~readerDone)
  /\ (readerPc = "correction" => ~seenCorrectionNew /\ ~readerDone)
  /\ (readerPc = "done" => readerDone)
  /\ (readerDone => readerPc = "done")
  /\ (seenEventNew => diskCorrectionNew)
  /\ (seenCorrectionNew => diskCorrectionNew)

IndInv ==
  /\ TypeOK
  /\ DiskOrder
  /\ ReaderSnapshotSafe
  /\ WriterShape
  /\ ReaderShape

\* This intentionally false-on-some-path invariant is a reachability probe.
\* Apalache must find the concrete midpoint: publish Correction, crash while the
\* Event is still old, restart/retry, then eventually publish the Event.
NoRecoveredCompletion == ~(crashedAfterRelation /\ diskEventNew)

\* Sensitivity model: keep the same crash/restart behavior but publish the
\* replacement Event before its Correction. DiskOrder should fail quickly.
UnsafeWriterPublishEvent ==
  /\ writerUp
  /\ writerPc = "relation"
  /\ diskEventNew' = TRUE
  /\ writerPc' = "event"
  /\ UNCHANGED <<
       diskCorrectionNew,
       writerUp,
       writerCrashed,
       crashedAfterRelation,
       readerUp,
       readerPc,
       seenEventNew,
       seenCorrectionNew,
       readerDone
     >>

UnsafeWriterPublishCorrection ==
  /\ writerUp
  /\ writerPc = "event"
  /\ diskCorrectionNew' = TRUE
  /\ writerPc' = "done"
  /\ UNCHANGED <<
       diskEventNew,
       writerUp,
       writerCrashed,
       crashedAfterRelation,
       readerUp,
       readerPc,
       seenEventNew,
       seenCorrectionNew,
       readerDone
     >>

UnsafeNext ==
  \/ UnsafeWriterPublishEvent
  \/ UnsafeWriterPublishCorrection
  \/ WriterCrash
  \/ WriterRestart
  \/ ReaderReadEvent
  \/ ReaderReadCorrection
  \/ ReaderCrash
  \/ ReaderRestart
  \/ ReaderBeginAgain
  \/ Stutter

=============================================================================

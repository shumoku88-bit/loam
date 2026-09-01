---------------- MODULE application_003_writer_interleaving ----------------
EXTENDS Naturals, FiniteSets

CONSTANT Writers

VARIABLES document, revision, phase, seenRevision, prepared, lockOwner

vars == <<document, revision, phase, seenRevision, prepared, lockOwner>>

Phases == {"idle", "locked", "prepared", "authorized", "done"}

Init ==
  /\ document = {}
  /\ revision = 0
  /\ phase = [w \in Writers |-> "idle"]
  /\ seenRevision = [w \in Writers |-> 0]
  /\ prepared = [w \in Writers |-> {}]
  /\ lockOwner = {}

TypeOK ==
  /\ document \subseteq Writers
  /\ revision \in Nat
  /\ phase \in [Writers -> Phases]
  /\ seenRevision \in [Writers -> Nat]
  /\ prepared \in [Writers -> SUBSET Writers]
  /\ lockOwner \subseteq Writers
  /\ Cardinality(lockOwner) <= 1

NoCompletedUpdateLost ==
  \A w \in Writers : phase[w] = "done" => w \in document

Prepare(w) ==
  /\ phase[w] = "idle"
  /\ phase' = [phase EXCEPT ![w] = "prepared"]
  /\ seenRevision' = [seenRevision EXCEPT ![w] = revision]
  /\ prepared' = [prepared EXCEPT ![w] = document \cup {w}]
  /\ UNCHANGED <<document, revision, lockOwner>>

Authorize(w) ==
  /\ phase[w] = "prepared"
  /\ seenRevision[w] = revision
  /\ phase' = [phase EXCEPT ![w] = "authorized"]
  /\ UNCHANGED <<document, revision, seenRevision, prepared, lockOwner>>

PublishNaive(w) ==
  /\ phase[w] = "authorized"
  /\ document' = prepared[w]
  /\ revision' = revision + 1
  /\ phase' = [phase EXCEPT ![w] = "done"]
  /\ UNCHANGED <<seenRevision, prepared, lockOwner>>

PublishCAS(w) ==
  /\ phase[w] = "authorized"
  /\ seenRevision[w] = revision
  /\ document' = prepared[w]
  /\ revision' = revision + 1
  /\ phase' = [phase EXCEPT ![w] = "done"]
  /\ UNCHANGED <<seenRevision, prepared, lockOwner>>

RetryCAS(w) ==
  /\ phase[w] = "authorized"
  /\ seenRevision[w] # revision
  /\ phase' = [phase EXCEPT ![w] = "idle"]
  /\ UNCHANGED <<document, revision, seenRevision, prepared, lockOwner>>

Acquire(w) ==
  /\ phase[w] = "idle"
  /\ lockOwner = {}
  /\ lockOwner' = {w}
  /\ phase' = [phase EXCEPT ![w] = "locked"]
  /\ UNCHANGED <<document, revision, seenRevision, prepared>>

PrepareLocked(w) ==
  /\ phase[w] = "locked"
  /\ lockOwner = {w}
  /\ phase' = [phase EXCEPT ![w] = "prepared"]
  /\ seenRevision' = [seenRevision EXCEPT ![w] = revision]
  /\ prepared' = [prepared EXCEPT ![w] = document \cup {w}]
  /\ UNCHANGED <<document, revision, lockOwner>>

AuthorizeLocked(w) ==
  /\ phase[w] = "prepared"
  /\ lockOwner = {w}
  /\ phase' = [phase EXCEPT ![w] = "authorized"]
  /\ UNCHANGED <<document, revision, seenRevision, prepared, lockOwner>>

PublishLocked(w) ==
  /\ phase[w] = "authorized"
  /\ lockOwner = {w}
  /\ document' = prepared[w]
  /\ revision' = revision + 1
  /\ phase' = [phase EXCEPT ![w] = "done"]
  /\ lockOwner' = {}
  /\ UNCHANGED <<seenRevision, prepared>>

NextNaive ==
  \E w \in Writers : Prepare(w) \/ Authorize(w) \/ PublishNaive(w)

NextCAS ==
  \E w \in Writers : Prepare(w) \/ Authorize(w) \/ PublishCAS(w) \/ RetryCAS(w)

NextLock ==
  \E w \in Writers : Acquire(w) \/ PrepareLocked(w) \/ AuthorizeLocked(w) \/ PublishLocked(w)

NaiveSpec == Init /\ [][NextNaive]_vars
CASSpec == Init /\ [][NextCAS]_vars
LockSpec == Init /\ [][NextLock]_vars

=============================================================================

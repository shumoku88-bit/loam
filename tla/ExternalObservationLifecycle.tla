---- MODULE ExternalObservationLifecycle ----
EXTENDS Integers

\* Observation 123 models source-evidence lifecycle only.
\* The household Actual remains stable while a source may report pending and
\* later posted evidence about that same occurrence.

PendingQuantity == 9
PostedQuantity == 10
ActualQuantity == 10

VARIABLES
  currentKind,
  pendingSeen,
  postedSeen,
  supersessionRecorded,
  pendingSupportsActual,
  postedSupportsActual,
  actualQuantity

vars == <<
  currentKind,
  pendingSeen,
  postedSeen,
  supersessionRecorded,
  pendingSupportsActual,
  postedSupportsActual,
  actualQuantity
>>

CurrentSourceQuantity ==
  CASE currentKind = "pending" -> PendingQuantity
    [] currentKind = "posted" -> PostedQuantity
    [] OTHER -> 0

Init ==
  /\ currentKind = "none"
  /\ pendingSeen = FALSE
  /\ postedSeen = FALSE
  /\ supersessionRecorded = FALSE
  /\ pendingSupportsActual = FALSE
  /\ postedSupportsActual = FALSE
  /\ actualQuantity = ActualQuantity

\* A source may first expose a provisional observation.
ObservePending ==
  /\ currentKind = "none"
  /\ currentKind' = "pending"
  /\ pendingSeen' = TRUE
  /\ UNCHANGED <<
       postedSeen,
       supersessionRecorded,
       pendingSupportsActual,
       postedSupportsActual,
       actualQuantity
     >>

\* Some sources expose only the final posted observation.  This path is
\* intentionally reachable so a current posted row does not imply that a
\* pending observation existed earlier.
ObservePostedDirect ==
  /\ currentKind = "none"
  /\ currentKind' = "posted"
  /\ postedSeen' = TRUE
  /\ UNCHANGED <<
       pendingSeen,
       supersessionRecorded,
       pendingSupportsActual,
       postedSupportsActual,
       actualQuantity
     >>

\* When posted evidence follows pending evidence, the current source view may
\* advance while the pending observation remains historical evidence.
ObservePostedAfterPending ==
  /\ currentKind = "pending"
  /\ pendingSeen
  /\ currentKind' = "posted"
  /\ postedSeen' = TRUE
  /\ supersessionRecorded' = TRUE
  /\ UNCHANGED <<
       pendingSeen,
       pendingSupportsActual,
       postedSupportsActual,
       actualQuantity
     >>

\* Reconciliation remains correspondence evidence.  It does not mutate the
\* household Actual quantity.
ReconcilePending ==
  /\ pendingSeen
  /\ ~pendingSupportsActual
  /\ pendingSupportsActual' = TRUE
  /\ UNCHANGED <<
       currentKind,
       pendingSeen,
       postedSeen,
       supersessionRecorded,
       postedSupportsActual,
       actualQuantity
     >>

ReconcilePosted ==
  /\ postedSeen
  /\ ~postedSupportsActual
  /\ postedSupportsActual' = TRUE
  /\ UNCHANGED <<
       currentKind,
       pendingSeen,
       postedSeen,
       supersessionRecorded,
       pendingSupportsActual,
       actualQuantity
     >>

Next ==
  \/ ObservePending
  \/ ObservePostedDirect
  \/ ObservePostedAfterPending
  \/ ReconcilePending
  \/ ReconcilePosted

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ currentKind \in {"none", "pending", "posted"}
  /\ pendingSeen \in {TRUE, FALSE}
  /\ postedSeen \in {TRUE, FALSE}
  /\ supersessionRecorded \in {TRUE, FALSE}
  /\ pendingSupportsActual \in {TRUE, FALSE}
  /\ postedSupportsActual \in {TRUE, FALSE}
  /\ actualQuantity \in {ActualQuantity}

ActualStable ==
  actualQuantity = ActualQuantity

SupersessionRequiresObservedEndpoints ==
  ~supersessionRecorded \/ (pendingSeen /\ postedSeen)

SupportRequiresObservedSource ==
  /\ (~pendingSupportsActual \/ pendingSeen)
  /\ (~postedSupportsActual \/ postedSeen)

CurrentProjectionBackedByEvidence ==
  /\ (currentKind = "pending" => pendingSeen)
  /\ (currentKind = "posted" => postedSeen)

\* Deliberately-too-strong reachability boundaries.  Dedicated TLC configs
\* should violate each invariant.
NoPendingThenPostedHistory ==
  ~(currentKind = "posted" /\ pendingSeen /\ supersessionRecorded)

NoDirectPostedHistory ==
  ~(currentKind = "posted" /\ ~pendingSeen)

NoDualSourceSupport ==
  ~(pendingSupportsActual /\ postedSupportsActual)

NoQuantityDriftSupport ==
  ~(pendingSupportsActual
    /\ postedSupportsActual
    /\ PendingQuantity # PostedQuantity
    /\ PostedQuantity = actualQuantity)

====

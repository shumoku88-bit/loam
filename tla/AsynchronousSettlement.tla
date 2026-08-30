---- MODULE AsynchronousSettlement ----
EXTENDS Integers

Horizon == 2
Times == 0..Horizon
NoTime == -1

InitialSource == 1
InitialDestination == 0
TotalQuantity == InitialSource + InitialDestination

VARIABLES now, initiatedAt, settledAt, sourceHeld, destinationHeld

vars == <<now, initiatedAt, settledAt, sourceHeld, destinationHeld>>

Initiated == initiatedAt # NoTime
Settled == settledAt # NoTime
Pending == Initiated /\ ~Settled

Init ==
  /\ now = 0
  /\ initiatedAt = NoTime
  /\ settledAt = NoTime
  /\ sourceHeld = InitialSource
  /\ destinationHeld = InitialDestination

\* Initiation records intent/history but does not claim physical settlement.
Initiate ==
  /\ ~Initiated
  /\ now = 0
  /\ initiatedAt' = now
  /\ UNCHANGED <<now, settledAt, sourceHeld, destinationHeld>>

\* Time may pass while the movement is pending.
Advance ==
  /\ Initiated
  /\ now < Horizon
  /\ now' = now + 1
  /\ UNCHANGED <<initiatedAt, settledAt, sourceHeld, destinationHeld>>

\* Settlement is a distinct later transition and is the only action that
\* changes the physical holding coordinates in this observation.
Settle ==
  /\ Pending
  /\ now > initiatedAt
  /\ settledAt' = now
  /\ sourceHeld' = 0
  /\ destinationHeld' = TotalQuantity
  /\ UNCHANGED <<now, initiatedAt>>

Next ==
  \/ Initiate
  \/ Advance
  \/ Settle

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ now \in Times
  /\ initiatedAt \in Times \cup {NoTime}
  /\ settledAt \in Times \cup {NoTime}
  /\ sourceHeld \in 0..TotalQuantity
  /\ destinationHeld \in 0..TotalQuantity

KnownTimesAreNotFuture ==
  /\ (initiatedAt = NoTime \/ initiatedAt <= now)
  /\ (settledAt = NoTime \/ settledAt <= now)

SettlementRequiresInitiation ==
  ~Settled \/ Initiated

SettlementIsLater ==
  ~Settled \/ initiatedAt < settledAt

QuantityConserved ==
  sourceHeld + destinationHeld = TotalQuantity

PhysicalStateFollowsSettlement ==
  /\ (~Settled =>
        /\ sourceHeld = InitialSource
        /\ destinationHeld = InitialDestination)
  /\ (Settled =>
        /\ sourceHeld = 0
        /\ destinationHeld = TotalQuantity)

PendingLeavesPhysicalHoldingsUnchanged ==
  ~Pending \/
    /\ sourceHeld = InitialSource
    /\ destinationHeld = InitialDestination

\* Reachability boundaries. Each is deliberately too strong and should fail
\* under its dedicated TLC configuration.
NoPendingState ==
  ~Pending

NoSettledState ==
  ~Settled

UnmovedPhysicalStateMeansNotInitiated ==
  (sourceHeld = InitialSource /\ destinationHeld = InitialDestination)
    => ~Initiated

====

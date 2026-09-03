---- MODULE ExternalObservationDeliveryIdentity ----
EXTENDS Naturals

\* Observation 124 separates delivery attempts from source-record identity.
\* Two delivery payloads are deliberately identical. The second delivery may
\* either replay source record A or introduce distinct source record B.

ContentA == "same-payload"
ContentB == "same-payload"

VARIABLES
  deliveryCount,
  aDeliveries,
  bDeliveries,
  aKnown,
  bKnown,
  storedObservationCount

vars == <<
  deliveryCount,
  aDeliveries,
  bDeliveries,
  aKnown,
  bKnown,
  storedObservationCount
>>

Init ==
  /\ deliveryCount = 0
  /\ aDeliveries = 0
  /\ bDeliveries = 0
  /\ aKnown = FALSE
  /\ bKnown = FALSE
  /\ storedObservationCount = 0

ReceiveFirstA ==
  /\ deliveryCount = 0
  /\ deliveryCount' = 1
  /\ aDeliveries' = 1
  /\ bDeliveries' = 0
  /\ aKnown' = TRUE
  /\ bKnown' = FALSE
  /\ storedObservationCount' = 1

\* The same source identity is delivered again. Delivery provenance grows,
\* but the retained external observation does not multiply.
SecondAsRetryA ==
  /\ deliveryCount = 1
  /\ aKnown
  /\ ~bKnown
  /\ aDeliveries = 1
  /\ bDeliveries = 0
  /\ deliveryCount' = 2
  /\ aDeliveries' = 2
  /\ bDeliveries' = 0
  /\ UNCHANGED <<aKnown, bKnown, storedObservationCount>>

\* A distinct source identity with exactly the same payload arrives. Identity
\* evidence requires retaining a second observation despite content equality.
SecondAsDistinctB ==
  /\ deliveryCount = 1
  /\ aKnown
  /\ ~bKnown
  /\ aDeliveries = 1
  /\ bDeliveries = 0
  /\ deliveryCount' = 2
  /\ aDeliveries' = 1
  /\ bDeliveries' = 1
  /\ bKnown' = TRUE
  /\ storedObservationCount' = 2
  /\ UNCHANGED aKnown

Idle == UNCHANGED vars

Next ==
  \/ ReceiveFirstA
  \/ SecondAsRetryA
  \/ SecondAsDistinctB
  \/ Idle

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ deliveryCount \in 0..2
  /\ aDeliveries \in 0..2
  /\ bDeliveries \in 0..1
  /\ aKnown \in {TRUE, FALSE}
  /\ bKnown \in {TRUE, FALSE}
  /\ storedObservationCount \in 0..2

StoredCountMatchesSourceIdentity ==
  storedObservationCount =
    (IF aKnown THEN 1 ELSE 0) + (IF bKnown THEN 1 ELSE 0)

DeliveryCountMatchesAttempts ==
  deliveryCount = aDeliveries + bDeliveries

KnownIdentityRequiresDelivery ==
  /\ (~aKnown \/ aDeliveries >= 1)
  /\ (~bKnown \/ bDeliveries >= 1)

RetryPreservesSingleObservation ==
  (aDeliveries = 2 /\ ~bKnown) => storedObservationCount = 1

DistinctKeysRemainDistinct ==
  (aKnown /\ bKnown) => storedObservationCount = 2

\* Deliberately-too-strong reachability boundaries.
NoRetryHistory ==
  ~(deliveryCount = 2
    /\ aDeliveries = 2
    /\ bDeliveries = 0
    /\ storedObservationCount = 1)

NoDistinctSameContentHistory ==
  ~(deliveryCount = 2
    /\ aDeliveries = 1
    /\ bDeliveries = 1
    /\ storedObservationCount = 2
    /\ ContentA = ContentB)

IdenticalPayloadDeliveriesAlwaysOneObservation ==
  ~(deliveryCount = 2
    /\ storedObservationCount = 2
    /\ ContentA = ContentB)

IdenticalPayloadDeliveriesAlwaysTwoObservations ==
  ~(deliveryCount = 2
    /\ storedObservationCount = 1
    /\ ContentA = ContentB)

====

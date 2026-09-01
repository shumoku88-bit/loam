---- MODULE ZeroOriginAdmissionEvidence ----
EXTENDS Naturals

Coordinates == {"a", "b"}

NoOp == "none"
TransferOp == "transfer"
IncomeOp == "income"
SpendUseOp == "spendUse"
Ops == {TransferOp, IncomeOp, SpendUseOp}

NoOrigin == "none"
FirstEventOrigin == "firstEvent"
OriginKinds == {NoOrigin, FirstEventOrigin}

PriorUnset == "unset"
PriorZero == "zero"
PriorNonzero == "nonzero"
PriorKinds == {PriorUnset, PriorZero, PriorNonzero}

VARIABLES seen,
          reality,
          activity,
          enrolled,
          zeroEvidence,
          originKind,
          firstOp,
          firstPrior

vars == <<seen, reality, activity, enrolled, zeroEvidence,
          originKind, firstOp, firstPrior>>

ZeroActivity == [c \in Coordinates |-> 0]
NoOrigins == [c \in Coordinates |-> NoOrigin]
NoOps == [c \in Coordinates |-> NoOp]
NoPriors == [c \in Coordinates |-> PriorUnset]

PriorKind(q) == IF q = 0 THEN PriorZero ELSE PriorNonzero

\* Before LOAM first sees a coordinate, reality may already be zero or nonzero.
\* "Unseen" is therefore epistemic, not a claim that the coordinate is empty.
Init ==
  /\ seen = {}
  /\ reality \in [Coordinates -> 0..1]
  /\ activity = ZeroActivity
  /\ enrolled = {}
  /\ zeroEvidence = {}
  /\ originKind = NoOrigins
  /\ firstOp = NoOps
  /\ firstPrior = NoPriors

\* An ordinary human-facing verb can cause the first recorded Event activity.
\* The verb alone does not claim that the coordinate was zero immediately before
\* the Event, so it does not enroll the coordinate in anchored-current.
ObserveFirst(c, op) ==
  /\ c \in Coordinates
  /\ op \in Ops
  /\ c \notin seen
  /\ seen' = seen \cup {c}
  /\ reality' = [reality EXCEPT ![c] = @ + 1]
  /\ activity' = [activity EXCEPT ![c] = 1]
  /\ firstOp' = [firstOp EXCEPT ![c] = op]
  /\ firstPrior' = [firstPrior EXCEPT ![c] = PriorKind(reality[c])]
  /\ UNCHANGED <<enrolled, zeroEvidence, originKind>>

\* A distinct application-level operation may explicitly admit the coordinate
\* with evidence that the origin immediately before its first Event is exactly
\* zero. The physical Event activity can otherwise be identical to ObserveFirst.
AdmitZeroAtFirstEvent(c, op) ==
  /\ c \in Coordinates
  /\ op \in Ops
  /\ c \notin seen
  /\ reality[c] = 0
  /\ seen' = seen \cup {c}
  /\ reality' = [reality EXCEPT ![c] = @ + 1]
  /\ activity' = [activity EXCEPT ![c] = 1]
  /\ enrolled' = enrolled \cup {c}
  /\ zeroEvidence' = zeroEvidence \cup {c}
  /\ originKind' = [originKind EXCEPT ![c] = FirstEventOrigin]
  /\ firstOp' = [firstOp EXCEPT ![c] = op]
  /\ firstPrior' = [firstPrior EXCEPT ![c] = PriorZero]

Next ==
  \/ \E c \in Coordinates, op \in Ops : ObserveFirst(c, op)
  \/ \E c \in Coordinates, op \in Ops : AdmitZeroAtFirstEvent(c, op)

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ seen \subseteq Coordinates
  /\ reality \in [Coordinates -> 0..2]
  /\ activity \in [Coordinates -> 0..1]
  /\ enrolled \subseteq Coordinates
  /\ zeroEvidence \subseteq Coordinates
  /\ originKind \in [Coordinates -> OriginKinds]
  /\ firstOp \in [Coordinates -> (Ops \cup {NoOp})]
  /\ firstPrior \in [Coordinates -> PriorKinds]

UnseenRemainsUninterpreted ==
  \A c \in Coordinates :
    c \notin seen =>
      /\ activity[c] = 0
      /\ c \notin enrolled
      /\ c \notin zeroEvidence
      /\ originKind[c] = NoOrigin
      /\ firstOp[c] = NoOp
      /\ firstPrior[c] = PriorUnset

EnrollmentHasExplicitZeroEvidence ==
  /\ enrolled = zeroEvidence
  /\ \A c \in Coordinates :
       (c \in enrolled) <=> (originKind[c] = FirstEventOrigin)

EnrolledPriorWasZero ==
  \A c \in Coordinates :
    c \in enrolled => firstPrior[c] = PriorZero

\* With an exact-zero first-event origin, the anchored current coordinate equals
\* the activity accumulated since that origin. Here the bounded model has one
\* first Event only, so both quantities are one.
EnrolledCurrentMatchesReality ==
  \A c \in Coordinates :
    c \in enrolled => activity[c] = reality[c]

\* Deliberately false if an ordinary first transfer can discover a coordinate
\* whose real quantity was already nonzero before LOAM first saw it.
TransferFirstAppearanceProvesZero ==
  \A c \in Coordinates :
    firstOp[c] = TransferOp => firstPrior[c] = PriorZero

\* Same boundary for income: receiving into a newly observed coordinate does not
\* prove that the coordinate was empty immediately before receipt.
IncomeFirstAppearanceProvesZero ==
  \A c \in Coordinates :
    firstOp[c] = IncomeOp => firstPrior[c] = PriorZero

\* Even fixing the human-facing verb to Transfer and fixing the complete first
\* physical signature does not determine enrollment. One transition may carry
\* explicit zero-origin admission evidence and another may merely observe.
SameTransferFirstAppearanceDeterminesEnrollment ==
  (/\ firstOp["a"] = TransferOp
   /\ firstOp["b"] = TransferOp
   /\ firstPrior["a"] = firstPrior["b"]
   /\ activity["a"] = activity["b"]
   /\ reality["a"] = reality["b"])
  => (("a" \in enrolled) <=> ("b" \in enrolled))

====

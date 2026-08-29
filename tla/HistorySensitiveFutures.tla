---- MODULE HistorySensitiveFutures ----
EXTENDS FiniteSets

Units == {"u0", "u1"}
P0 == "p0"
P1 == "p1"
Purposes == {P0, P1}
Target == P0

VARIABLES leftPlace, rightPlace, leftStayed, rightStayed, phase

vars == <<leftPlace, rightPlace, leftStayed, rightStayed, phase>>

ConvergedPlacement ==
  [u \in Units |-> IF u = "u0" THEN P0 ELSE P1]

Init ==
  /\ phase = 0
  /\ leftPlace = [u \in Units |-> IF u = "u0" THEN P0 ELSE P1]
  /\ rightPlace = [u \in Units |-> IF u = "u0" THEN P1 ELSE P0]
  /\ leftStayed = {u \in Units : leftPlace[u] = Target}
  /\ rightStayed = {u \in Units : rightPlace[u] = Target}

Converge ==
  /\ phase = 0
  /\ leftPlace' = ConvergedPlacement
  /\ rightPlace' = ConvergedPlacement
  /\ leftStayed' = leftStayed \cap {u \in Units : ConvergedPlacement[u] = Target}
  /\ rightStayed' = rightStayed \cap {u \in Units : ConvergedPlacement[u] = Target}
  /\ phase' = 1

Stop ==
  /\ phase = 1
  /\ UNCHANGED vars

Next == Converge \/ Stop

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ leftPlace \in [Units -> Purposes]
  /\ rightPlace \in [Units -> Purposes]
  /\ leftStayed \subseteq Units
  /\ rightStayed \subseteq Units
  /\ phase \in {0, 1}

CountAt(place, purpose) ==
  Cardinality({u \in Units : place[u] = purpose})

SameCountProjection ==
  \A p \in Purposes : CountAt(leftPlace, p) = CountAt(rightPlace, p)

LeftContinuityUse ==
  /\ phase = 1
  /\ "u0" \in leftStayed
  /\ UNCHANGED vars

RightContinuityUse ==
  /\ phase = 1
  /\ "u0" \in rightStayed
  /\ UNCHANGED vars

LeftContinuityEnabled == ENABLED LeftContinuityUse
RightContinuityEnabled == ENABLED RightContinuityUse

SameCurrentImpliesSameEnabled ==
  (leftPlace = rightPlace) =>
    (LeftContinuityEnabled = RightContinuityEnabled)

ConvergedStatesAgreeOnCounts ==
  (phase = 1) => SameCountProjection

====

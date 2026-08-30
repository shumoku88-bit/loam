---- MODULE TimeIndexedRelation ----
EXTENDS Integers, FiniteSets, Sequences

Horizon == 2
Times == 0..Horizon
RelationValues == {"r0", "r1"}
Unknown == "unknown"
NoPlan == -1
RelationDomain == RelationValues \cup {Unknown}
Observation == [time : Times, value : RelationValues]

VARIABLES now, history, current, planTarget, planAssumption

vars == <<now, history, current, planTarget, planAssumption>>

ObservedTimes(H) == {H[i].time : i \in DOMAIN H}

HasObservation(H, t) == t \in ObservedTimes(H)

ObservationValue(H, t) ==
  CHOOSE v \in RelationValues :
    \E i \in DOMAIN H :
      /\ H[i].time = t
      /\ H[i].value = v

TimesAtOrBefore(H, t) ==
  {u \in ObservedTimes(H) : u <= t}

LatestTime(S) ==
  CHOOSE u \in S : \A v \in S : v <= u

RelationAsOf(H, t) ==
  LET S == TimesAtOrBefore(H, t)
  IN IF S = {}
     THEN Unknown
     ELSE ObservationValue(H, LatestTime(S))

VisibleRelationAt(t) ==
  IF t <= now THEN RelationAsOf(history, t) ELSE Unknown

Init ==
  /\ now = 0
  /\ history = <<>>
  /\ current = Unknown
  /\ planTarget = NoPlan
  /\ planAssumption = Unknown

Observe(v) ==
  /\ v \in RelationValues
  /\ ~HasObservation(history, now)
  /\ history' = Append(history, [time |-> now, value |-> v])
  /\ current' = v
  /\ UNCHANGED <<now, planTarget, planAssumption>>

Advance ==
  /\ now < Horizon
  /\ now' = now + 1
  /\ UNCHANGED <<history, current, planTarget, planAssumption>>

MakePlan ==
  /\ planTarget = NoPlan
  /\ now < Horizon
  /\ HasObservation(history, now)
  /\ current # Unknown
  /\ planTarget' = now + 1
  /\ planAssumption' = current
  /\ UNCHANGED <<now, history, current>>

Next ==
  \/ \E v \in RelationValues : Observe(v)
  \/ Advance
  \/ MakePlan

Spec == Init /\ [][Next]_vars

IsPrefix(H, K) ==
  /\ Len(H) <= Len(K)
  /\ \A i \in DOMAIN H : H[i] = K[i]

TypeOK ==
  /\ now \in Times
  /\ history \in Seq(Observation)
  /\ current \in RelationDomain
  /\ planTarget \in Times \cup {NoPlan}
  /\ planAssumption \in RelationDomain

UniqueObservationTime ==
  Cardinality(ObservedTimes(history)) = Len(history)

NoFutureObservations ==
  \A i \in DOMAIN history : history[i].time <= now

CurrentMatchesHistory ==
  current = RelationAsOf(history, now)

PlanShapeOK ==
  (planTarget = NoPlan) <=> (planAssumption = Unknown)

PlanAssumptionIsSnapshot ==
  planTarget = NoPlan \/
    planAssumption = RelationAsOf(history, planTarget - 1)

FutureQuestionsDoNotInventFacts ==
  \A t \in Times : t > now => VisibleRelationAt(t) = Unknown

HistoryOnlyExtends ==
  [][IsPrefix(history, history')]_vars

PastViewsUnchanged ==
  \A t \in Times :
    t < now => RelationAsOf(history, t) = RelationAsOf(history', t)

PastViewsNeverRewrite ==
  [][PastViewsUnchanged]_vars

\* Boundary hypothesis 1:
\* If only the latest relation were enough, every known past view would equal current.
LatestRelationAnswersPast ==
  \A t \in Times :
    t < now /\ RelationAsOf(history, t) # Unknown
      => RelationAsOf(history, t) = current

\* Boundary hypothesis 2:
\* A current relation captured for a future plan would have to equal the
\* relation later observed at that target time.
PlanAssumptionDeterminesTarget ==
  \/ planTarget = NoPlan
  \/ now < planTarget
  \/ ~HasObservation(history, planTarget)
  \/ ObservationValue(history, planTarget) = planAssumption

====

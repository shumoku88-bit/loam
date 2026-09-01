---- MODULE FirstEventAnchoredOrigin ----
EXTENDS Naturals

Coordinates == {"base", "a", "b"}
NewCoordinates == {"a", "b"}

NoOrigin == "none"
ApplicationOrigin == "application"
FirstEventOrigin == "firstEvent"
OriginKinds == {NoOrigin, ApplicationOrigin, FirstEventOrigin}

VARIABLES seen, activity, enrolled, originKind

vars == <<seen, activity, enrolled, originKind>>

ZeroActivity == [c \in Coordinates |-> 0]
InitialOrigin ==
  [c \in Coordinates |->
    IF c = "base" THEN ApplicationOrigin ELSE NoOrigin]

Init ==
  /\ seen = {"base"}
  /\ activity = ZeroActivity
  /\ enrolled = {"base"}
  /\ originKind = InitialOrigin

\* First appearance can remain activity-only for the selected question.
ObserveOnly(c) ==
  /\ c \in NewCoordinates
  /\ c \notin seen
  /\ seen' = seen \cup {c}
  /\ activity' = [activity EXCEPT ![c] = 1]
  /\ UNCHANGED <<enrolled, originKind>>

\* A concrete operation may instead admit a previously unseen coordinate to
\* anchored-current at the same transition as its first Event activity.
\* The origin is therefore immediately before that first activity and has
\* exact quantity zero without pretending there was an application-start basis.
AdmitAnchoredAtFirstEvent(c) ==
  /\ c \in NewCoordinates
  /\ c \notin seen
  /\ seen' = seen \cup {c}
  /\ activity' = [activity EXCEPT ![c] = 1]
  /\ enrolled' = enrolled \cup {c}
  /\ originKind' = [originKind EXCEPT ![c] = FirstEventOrigin]

AddExistingActivity(c) ==
  /\ c \in seen
  /\ activity[c] < 2
  /\ activity' = [activity EXCEPT ![c] = @ + 1]
  /\ UNCHANGED <<seen, enrolled, originKind>>

Next ==
  \/ \E c \in NewCoordinates : ObserveOnly(c)
  \/ \E c \in NewCoordinates : AdmitAnchoredAtFirstEvent(c)
  \/ \E c \in Coordinates : AddExistingActivity(c)

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ seen \subseteq Coordinates
  /\ enrolled \subseteq Coordinates
  /\ activity \in [Coordinates -> 0..2]
  /\ originKind \in [Coordinates -> OriginKinds]

OriginMatchesEnrollment ==
  \A c \in Coordinates :
    (c \in enrolled) <=> (originKind[c] # NoOrigin)

UnseenHasNoActivity ==
  \A c \in Coordinates :
    c \notin seen =>
      /\ activity[c] = 0
      /\ c \notin enrolled
      /\ originKind[c] = NoOrigin

Anchor(c) ==
  IF originKind[c] = ApplicationOrigin THEN 10 ELSE 0

Current(c) == Anchor(c) + activity[c]

FirstEventOriginStartsFromZero ==
  \A c \in Coordinates :
    originKind[c] = FirstEventOrigin => Current(c) = activity[c]

\* Temporal claim: a first-event origin can only be introduced on a transition
\* where that coordinate was still unseen and had zero prior activity.
FirstEventOriginIntroducedAtFirstAppearance ==
  [](\A c \in NewCoordinates :
       (originKind[c] = NoOrigin /\ originKind'[c] = FirstEventOrigin) =>
         /\ c \notin seen
         /\ activity[c] = 0
         /\ c \in seen'
         /\ activity'[c] = 1)

\* Witness boundary: false if a new anchored coordinate can really be born at
\* its first Event rather than requiring an application-origin basis.
NoFirstEventOriginEverAppears ==
  \A c \in NewCoordinates : originKind[c] # FirstEventOrigin

\* Universal auto-enrollment is too broad if an observed coordinate can remain
\* outside the selected anchored-current question.
AutoEnrollAllFirstAppearancesMatchesSelection ==
  seen = enrolled

\* Central boundary from Observation 086 moved through time: after two
\* coordinates both first appear with exactly one unit of activity and no
\* application-origin basis, their physical first-appearance signature still
\* does not force the same anchored-current enrollment decision.
PhysicalFirstAppearanceDeterminesEnrollment ==
  (/\ "a" \in seen
   /\ "b" \in seen
   /\ activity["a"] = 1
   /\ activity["b"] = 1)
  => (("a" \in enrolled) <=> ("b" \in enrolled))

====

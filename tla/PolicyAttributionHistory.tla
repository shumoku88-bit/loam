---- MODULE PolicyAttributionHistory ----
EXTENDS Naturals

Policies == {"preferEarlier", "preferLater"}
Attributions == {"earlier3_later1", "earlier1_later3"}
NoAttribution == "none"
AttributionDomain == Attributions \cup {NoAttribution}

PolicyAttribution(p) ==
  IF p = "preferEarlier"
  THEN "earlier3_later1"
  ELSE "earlier1_later3"

VARIABLES currentPolicy, recordedAttribution

vars == <<currentPolicy, recordedAttribution>>

Init ==
  /\ currentPolicy = "preferEarlier"
  /\ recordedAttribution = NoAttribution

RecordDisposal ==
  /\ recordedAttribution = NoAttribution
  /\ recordedAttribution' = PolicyAttribution(currentPolicy)
  /\ UNCHANGED currentPolicy

ChangePolicy(p) ==
  /\ p \in Policies
  /\ p # currentPolicy
  /\ currentPolicy' = p
  /\ UNCHANGED recordedAttribution

Next ==
  \/ RecordDisposal
  \/ \E p \in Policies : ChangePolicy(p)

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ currentPolicy \in Policies
  /\ recordedAttribution \in AttributionDomain

CurrentPolicyView == PolicyAttribution(currentPolicy)

RecordedShapeOK ==
  recordedAttribution = NoAttribution \/ recordedAttribution \in Attributions

\* Once a disposal attribution has been retained, changing the current policy
\* must not rewrite that retained statement.
RecordedAttributionNeverRewrites ==
  [][recordedAttribution # NoAttribution =>
       recordedAttribution' = recordedAttribution]_vars

\* Boundary hypothesis:
\* if today's policy were enough to answer yesterday's retained attribution,
\* the retained statement would always equal the current-policy view.
CurrentPolicyReconstructsRecordedAttribution ==
  recordedAttribution = NoAttribution \/
    recordedAttribution = CurrentPolicyView

====

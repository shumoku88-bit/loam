---- MODULE PolicyDefinitionHistory ----
EXTENDS Naturals

PolicyIdentity == "disposalPolicy"
Definitions == {"definitionA", "definitionB"}
Cases == {"historicalCase", "distinguishingCase"}
Attributions == {"earlier3_later1", "earlier1_later3"}
NoAttribution == "none"
NoDefinition == "none"

AttributionFor(definition, disposalCase) ==
  IF disposalCase = "historicalCase"
  THEN "earlier3_later1"
  ELSE IF definition = "definitionA"
       THEN "earlier3_later1"
       ELSE "earlier1_later3"

VARIABLES currentDefinition, recordedAttribution, recordedDefinition

vars == <<currentDefinition, recordedAttribution, recordedDefinition>>

Init ==
  /\ currentDefinition \in Definitions
  /\ recordedAttribution = NoAttribution
  /\ recordedDefinition = NoDefinition

RecordDisposal ==
  /\ recordedAttribution = NoAttribution
  /\ recordedDefinition = NoDefinition
  /\ recordedAttribution' = AttributionFor(currentDefinition, "historicalCase")
  /\ recordedDefinition' = currentDefinition
  /\ UNCHANGED currentDefinition

ChangeDefinition(definition) ==
  /\ definition \in Definitions
  /\ definition # currentDefinition
  /\ currentDefinition' = definition
  /\ UNCHANGED <<recordedAttribution, recordedDefinition>>

Next ==
  \/ RecordDisposal
  \/ \E definition \in Definitions : ChangeDefinition(definition)

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ currentDefinition \in Definitions
  /\ recordedAttribution \in Attributions \cup {NoAttribution}
  /\ recordedDefinition \in Definitions \cup {NoDefinition}

HistoricalCaseCollides ==
  AttributionFor("definitionA", "historicalCase") =
    AttributionFor("definitionB", "historicalCase")

DefinitionsAreBehaviorallyDistinct ==
  AttributionFor("definitionA", "distinguishingCase") #
    AttributionFor("definitionB", "distinguishingCase")

RecordedPairConforms ==
  recordedDefinition = NoDefinition \/
    recordedAttribution = AttributionFor(recordedDefinition, "historicalCase")

RecordedAttributionNeverRewrites ==
  [][recordedAttribution # NoAttribution =>
       recordedAttribution' = recordedAttribution]_vars

RecordedDefinitionNeverRewrites ==
  [][recordedDefinition # NoDefinition =>
       recordedDefinition' = recordedDefinition]_vars

\* Boundary hypothesis A:
\* the visible projection consisting of the stable Policy identity, current
\* definitionB, and the retained historical attribution would force the
\* historical definition to have been definitionB.
ProjectionForcesRecordedDefinitionB ==
  currentDefinition # "definitionB" \/
  recordedAttribution # "earlier3_later1" \/
  recordedDefinition = NoDefinition \/
  recordedDefinition = "definitionB"

\* Boundary hypothesis B:
\* the same visible projection would instead force the historical definition
\* to have been definitionA. The opposite counterexample shows that neither
\* historical definition is reconstructable from that projection.
ProjectionForcesRecordedDefinitionA ==
  currentDefinition # "definitionB" \/
  recordedAttribution # "earlier3_later1" \/
  recordedDefinition = NoDefinition \/
  recordedDefinition = "definitionA"

====

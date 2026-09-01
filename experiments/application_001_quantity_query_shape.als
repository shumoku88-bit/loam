module experiments/application_001_quantity_query_shape

sig Event {}
sig Context {}
sig PlanEvidence {}

sig Correction {
  target: one Event,
  replacement: one Event
}

abstract sig InspectionMode {}
one sig RecordedQuantity,
        SingleCorrectionEffectiveQuantity,
        MissingCorrectionEndpoint,
        FrontierRequired extends InspectionMode {}

sig World {
  events: set Event,
  corrections: set Correction,
  eventContext: Event -> lone Context,
  planEvidence: set PlanEvidence,
  mode: one InspectionMode
}

fact ContextOnlyAttachesToRememberedEvents {
  all w: World | w.eventContext.Context in w.events
}

pred correctionClosed[w: World, c: Correction] {
  c.target in w.events
  c.replacement in w.events
}

pred allCorrectionsClosed[w: World] {
  all c: w.corrections | correctionClosed[w, c]
}

pred someCorrectionOpen[w: World] {
  some c: w.corrections | not correctionClosed[w, c]
}

-- Application 001 asks only whether the already-earned quantity projection can
-- answer safely. The four modes form a complete partition of the retained
-- Correction evidence. Descriptive context and Plan evidence are not consulted.
fact QuantityInspectionContract {
  all w: World |
    (w.mode = RecordedQuantity iff
      no w.corrections)
    and
    (w.mode = SingleCorrectionEffectiveQuantity iff
      #w.corrections = 1 and allCorrectionsClosed[w])
    and
    (w.mode = MissingCorrectionEndpoint iff
      #w.corrections = 1 and someCorrectionOpen[w])
    and
    (w.mode = FrontierRequired iff
      #w.corrections > 1)
}

pred sameQuantityEvidence[left, right: World] {
  left.events = right.events
  left.corrections = right.corrections
}

pred zeroCorrectionReadable {
  some w: World |
    some w.events
    and no w.corrections
    and w.mode = RecordedQuantity
}

pred oneClosedCorrectionReadable {
  some w: World |
    #w.corrections = 1
    and allCorrectionsClosed[w]
    and w.mode = SingleCorrectionEffectiveQuantity
}

pred oneOpenCorrectionRefuses {
  some w: World |
    #w.corrections = 1
    and someCorrectionOpen[w]
    and w.mode = MissingCorrectionEndpoint
}

pred multipleCorrectionsRequireFrontier {
  some w: World |
    #w.corrections > 1
    and w.mode = FrontierRequired
}

pred invisibleEvidenceCanVaryWithoutChangingMode {
  some disj left, right: World |
    sameQuantityEvidence[left, right]
    and left.eventContext != right.eventContext
    and left.planEvidence != right.planEvidence
    and left.mode = right.mode
}

assert ZeroCorrectionsAlwaysUseRecordedQuantity {
  all w: World |
    no w.corrections implies w.mode = RecordedQuantity
}

assert OneClosedCorrectionAlwaysUsesSingleCorrectionProjection {
  all w: World |
    (#w.corrections = 1 and allCorrectionsClosed[w])
      implies w.mode = SingleCorrectionEffectiveQuantity
}

assert OneOpenCorrectionNeverPretendsToBeEffective {
  all w: World |
    (#w.corrections = 1 and someCorrectionOpen[w])
      implies w.mode = MissingCorrectionEndpoint
}

assert MultipleCorrectionsNeverPretendToHaveAFrontier {
  all w: World |
    #w.corrections > 1 implies w.mode = FrontierRequired
}

assert UnobservedEvidenceCannotChangeInspectionMode {
  all left, right: World |
    sameQuantityEvidence[left, right] implies left.mode = right.mode
}

run zeroCorrectionReadable for 4 but exactly 1 World, 2 Event, 2 Correction, 2 Context, 2 PlanEvidence
run oneClosedCorrectionReadable for 4 but exactly 1 World, 2 Event, 2 Correction, 2 Context, 2 PlanEvidence
run oneOpenCorrectionRefuses for 4 but exactly 1 World, 2 Event, 2 Correction, 2 Context, 2 PlanEvidence
run multipleCorrectionsRequireFrontier for 4 but exactly 1 World, 3 Event, exactly 2 Correction, 2 Context, 2 PlanEvidence
run invisibleEvidenceCanVaryWithoutChangingMode for 5 but exactly 2 World, 2 Event, 2 Correction, 2 Context, 2 PlanEvidence

check ZeroCorrectionsAlwaysUseRecordedQuantity for 5
check OneClosedCorrectionAlwaysUsesSingleCorrectionProjection for 5
check OneOpenCorrectionNeverPretendsToBeEffective for 5
check MultipleCorrectionsNeverPretendToHaveAFrontier for 5
check UnobservedEvidenceCannotChangeInspectionMode for 5

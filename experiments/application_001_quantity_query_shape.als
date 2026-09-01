module experiments/application_001_quantity_query_shape

abstract sig Event {}
abstract sig Context {}
abstract sig PlanEvidence {}

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

-- Application 001 asks only whether the already-earned quantity projection can
-- answer safely. It does not inspect descriptive context or Plan evidence.
fact QuantityInspectionContract {
  all w: World |
    (no w.corrections implies
      w.mode = RecordedQuantity)
    and
    (#w.corrections = 1 and
      all c: w.corrections |
        c.target in w.events and c.replacement in w.events
      implies
        w.mode = SingleCorrectionEffectiveQuantity)
    and
    (#w.corrections = 1 and
      some c: w.corrections |
        c.target not in w.events or c.replacement not in w.events
      implies
        w.mode = MissingCorrectionEndpoint)
    and
    (#w.corrections > 1 implies
      w.mode = FrontierRequired)
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
    and all c: w.corrections |
      c.target in w.events and c.replacement in w.events
    and w.mode = SingleCorrectionEffectiveQuantity
}

pred oneOpenCorrectionRefuses {
  some w: World |
    #w.corrections = 1
    and some c: w.corrections |
      c.target not in w.events or c.replacement not in w.events
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
    (#w.corrections = 1 and
      all c: w.corrections |
        c.target in w.events and c.replacement in w.events)
      implies w.mode = SingleCorrectionEffectiveQuantity
}

assert OneOpenCorrectionNeverPretendsToBeEffective {
  all w: World |
    (#w.corrections = 1 and
      some c: w.corrections |
        c.target not in w.events or c.replacement not in w.events)
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

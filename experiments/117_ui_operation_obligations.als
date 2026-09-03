module experiments/observation_117_ui_operation_obligations

abstract sig Evidence {}
one sig CompletionRelation, ActualDateEvidence, ActualEvent, RetirementEvidence extends Evidence {}

abstract sig Action {}
one sig CompleteAction, CancelAction extends Action {}

abstract sig InputObligation {}
one sig ActualDateInput, ActualMovementInput extends InputObligation {}

abstract sig Label {}
one sig CompleteLabel, ResumeLabel, CancelLabel extends Label {}

sig World {
  evidence: set Evidence
}

one sig FreshOpen,
        InterruptedBeforeDate,
        InterruptedAfterDate,
        Completed,
        Retired extends World {}

fact RepresentativeWorlds {
  no FreshOpen.evidence
  InterruptedBeforeDate.evidence = CompletionRelation
  InterruptedAfterDate.evidence = CompletionRelation + ActualDateEvidence
  Completed.evidence = CompletionRelation + ActualDateEvidence + ActualEvent
  Retired.evidence = RetirementEvidence
}

pred effectiveCompletion[w: World] {
  CompletionRelation in w.evidence
  ActualEvent in w.evidence
}

pred openScheduled[w: World] {
  RetirementEvidence not in w.evidence
  not effectiveCompletion[w]
}

pred admitted[w: World, a: Action] {
  (a = CompleteAction and
    RetirementEvidence not in w.evidence and
    not effectiveCompletion[w])
  or
  (a = CancelAction and
    RetirementEvidence not in w.evidence and
    CompletionRelation not in w.evidence)
}

fun admittedActions[w: World]: set Action {
  { a: Action | admitted[w, a] }
}

fun labelFor[w: World, a: Action]: lone Label {
  { l: Label |
    (a = CompleteAction and CompletionRelation not in w.evidence and l = CompleteLabel)
    or
    (a = CompleteAction and CompletionRelation in w.evidence and l = ResumeLabel)
    or
    (a = CancelAction and l = CancelLabel)
  }
}

fun labeledSurface[w: World]: Action -> Label {
  { a: Action, l: Label |
    a in admittedActions[w] and
    l in labelFor[w, a]
  }
}

fun requiredInputs[w: World, a: Action]: set InputObligation {
  { i: InputObligation |
    a = CompleteAction and
    admitted[w, a] and
    (i = ActualMovementInput or
      (i = ActualDateInput and ActualDateEvidence not in w.evidence))
  }
}

fun obligationSurface[w: World]: Action -> InputObligation {
  { a: Action, i: InputObligation |
    a in admittedActions[w] and
    i in requiredInputs[w, a]
  }
}

pred interruptedStagesShareActionsButNeedDifferentInputs {
  openScheduled[InterruptedBeforeDate]
  openScheduled[InterruptedAfterDate]
  admittedActions[InterruptedBeforeDate] = admittedActions[InterruptedAfterDate]
  requiredInputs[InterruptedBeforeDate, CompleteAction] !=
    requiredInputs[InterruptedAfterDate, CompleteAction]
}

pred resumeLabelStillCollapsesPromptStage {
  labeledSurface[InterruptedBeforeDate] = labeledSurface[InterruptedAfterDate]
  requiredInputs[InterruptedBeforeDate, CompleteAction] !=
    requiredInputs[InterruptedAfterDate, CompleteAction]
}

assert ActionSetDeterminesRequiredInputs {
  all a, b: World |
    admittedActions[a] = admittedActions[b] implies
      all act: Action |
        requiredInputs[a, act] = requiredInputs[b, act]
}

assert LabelsDetermineRequiredInputs {
  all a, b: World |
    labeledSurface[a] = labeledSurface[b] implies
      all act: Action |
        requiredInputs[a, act] = requiredInputs[b, act]
}

assert ObligationSurfaceDeterminesRequiredInputs {
  all a, b: World |
    admittedActions[a] = admittedActions[b] and
    obligationSurface[a] = obligationSurface[b] implies
      all act: Action |
        requiredInputs[a, act] = requiredInputs[b, act]
}

assert FreshOpenNeedsDateAndMovement {
  requiredInputs[FreshOpen, CompleteAction] =
    ActualDateInput + ActualMovementInput
}

assert RetainedDateNeedsOnlyMovement {
  requiredInputs[InterruptedAfterDate, CompleteAction] = ActualMovementInput
}

assert ClosedHasNoInputObligations {
  all w: World |
    not openScheduled[w] implies no obligationSurface[w]
}

run interruptedStagesShareActionsButNeedDifferentInputs
  for exactly 4 Evidence, exactly 2 Action, exactly 2 InputObligation,
      exactly 3 Label, exactly 5 World

run resumeLabelStillCollapsesPromptStage
  for exactly 4 Evidence, exactly 2 Action, exactly 2 InputObligation,
      exactly 3 Label, exactly 5 World

check ActionSetDeterminesRequiredInputs
  for exactly 4 Evidence, exactly 2 Action, exactly 2 InputObligation,
      exactly 3 Label, exactly 5 World

check LabelsDetermineRequiredInputs
  for exactly 4 Evidence, exactly 2 Action, exactly 2 InputObligation,
      exactly 3 Label, exactly 5 World

check ObligationSurfaceDeterminesRequiredInputs
  for exactly 4 Evidence, exactly 2 Action, exactly 2 InputObligation,
      exactly 3 Label, exactly 5 World

check FreshOpenNeedsDateAndMovement
  for exactly 4 Evidence, exactly 2 Action, exactly 2 InputObligation,
      exactly 3 Label, exactly 5 World

check RetainedDateNeedsOnlyMovement
  for exactly 4 Evidence, exactly 2 Action, exactly 2 InputObligation,
      exactly 3 Label, exactly 5 World

check ClosedHasNoInputObligations
  for exactly 4 Evidence, exactly 2 Action, exactly 2 InputObligation,
      exactly 3 Label, exactly 5 World

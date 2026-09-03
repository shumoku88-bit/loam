module experiments/observation_116_ui_action_admission

abstract sig Evidence {}
one sig CompletionRelation, ActualEvent, RetirementEvidence extends Evidence {}

abstract sig Action {}
one sig CompleteAction, CancelAction extends Action {}

sig World {
  evidence: set Evidence
}

one sig FreshOpen, InterruptedCompletion, Completed, Retired extends World {}

fact RepresentativeWorlds {
  no FreshOpen.evidence
  InterruptedCompletion.evidence = CompletionRelation
  Completed.evidence = CompletionRelation + ActualEvent
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

fun naiveOpenActions[w: World]: set Action {
  { a: Action | openScheduled[w] }
}

fun admissionAwareActions[w: World]: set Action {
  { a: Action | admitted[w, a] }
}

pred interruptedOpenButCancelBlocked {
  openScheduled[InterruptedCompletion]
  CompleteAction in admissionAwareActions[InterruptedCompletion]
  CancelAction not in admissionAwareActions[InterruptedCompletion]
  CancelAction in naiveOpenActions[InterruptedCompletion]
}

pred naiveOffersBlockedAction {
  some w: World, a: Action |
    a in naiveOpenActions[w] and
    not admitted[w, a]
}

assert AdmissionAwareOnlyOffersAdmitted {
  all w: World, a: Action |
    a in admissionAwareActions[w] implies admitted[w, a]
}

assert FreshOpenOffersBoth {
  admissionAwareActions[FreshOpen] = CompleteAction + CancelAction
}

assert ClosedOffersNoTerminalActions {
  all w: World |
    not openScheduled[w] implies no admissionAwareActions[w]
}

assert OpenImpliesCancelAdmitted {
  all w: World |
    openScheduled[w] implies admitted[w, CancelAction]
}

run interruptedOpenButCancelBlocked for exactly 3 Evidence, exactly 2 Action, exactly 4 World
run naiveOffersBlockedAction for exactly 3 Evidence, exactly 2 Action, exactly 4 World
check AdmissionAwareOnlyOffersAdmitted for exactly 3 Evidence, exactly 2 Action, exactly 4 World
check FreshOpenOffersBoth for exactly 3 Evidence, exactly 2 Action, exactly 4 World
check ClosedOffersNoTerminalActions for exactly 3 Evidence, exactly 2 Action, exactly 4 World
check OpenImpliesCancelAdmitted for exactly 3 Evidence, exactly 2 Action, exactly 4 World

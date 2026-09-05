module experiments/observation_196_known_obligation_unknown_amount

-- F051 asks whether a known future obligation with no exact amount can be
-- represented by the currently quantity-bearing Scheduled boundary alone.
--
-- This model deliberately does not propose a production storage type. The
-- `knownWithoutAmount` set is observation-local evidence for one distinction:
-- the household knows an obligation exists, but no exact scalar is yet known.

sig Obligation {}
sig Amount {}

sig World {
  -- Information-equivalent abstraction of an exact quantity-bearing Scheduled
  -- claim for this narrow question. Absence means there is no exact Scheduled
  -- amount for that obligation in the selected evidence.
  exactScheduledAmount: Obligation -> lone Amount,

  -- Experiment-local existence evidence with no exact amount attached.
  knownWithoutAmount: set Obligation
}

one sig Left, Right extends World {}

fact KnowledgeStatesAreDisjoint {
  -- In this bounded snapshot, one obligation is either represented by an exact
  -- Scheduled amount or by the candidate amount-unknown existence evidence.
  -- Transition from unknown to known amount is deliberately outside scope.
  all w: World |
    no w.knownWithoutAmount & w.exactScheduledAmount.Amount
}

fun exactScheduledSubjects[w: World]: set Obligation {
  w.exactScheduledAmount.Amount
}

fun knownObligations[w: World]: set Obligation {
  exactScheduledSubjects[w] + w.knownWithoutAmount
}

fun unknownAmountObligations[w: World]: set Obligation {
  w.knownWithoutAmount
}

fun knownAmountObligations[w: World]: set Obligation {
  exactScheduledSubjects[w]
}

fun noKnownObligation[w: World]: set Obligation {
  Obligation - knownObligations[w]
}

pred representativeUnknownAmount {
  some o: Obligation | o in unknownAmountObligations[Left]
}

pred sameExactScheduledDifferentKnownExistence {
  Left.exactScheduledAmount = Right.exactScheduledAmount

  some o: Obligation | {
    o in unknownAmountObligations[Left]
    o in noKnownObligation[Right]
  }
}

pred sameKnownExistenceDifferentAmountKnowledge {
  knownObligations[Left] = knownObligations[Right]

  some o: Obligation | {
    o in unknownAmountObligations[Left]
    o in knownAmountObligations[Right]
  }
}

-- Deliberately too strong: if this held, exact quantity-bearing Scheduled
-- evidence would be enough to answer whether an obligation is known at all.
assert ExactScheduledDeterminesKnownObligation {
  Left.exactScheduledAmount = Right.exactScheduledAmount implies
    knownObligations[Left] = knownObligations[Right]
}

-- Also deliberately too strong: knowing only that an obligation exists should
-- not determine whether its exact amount is known.
assert KnownExistenceDeterminesAmountKnowledge {
  knownObligations[Left] = knownObligations[Right] implies {
    unknownAmountObligations[Left] = unknownAmountObligations[Right]
    knownAmountObligations[Left] = knownAmountObligations[Right]
  }
}

-- Positive sufficiency check for the selected vocabulary. Once both exact
-- Scheduled evidence and the candidate existence-only evidence are fixed, the
-- three selected knowledge views are fixed.
assert ExplicitKnowledgeDeterminesSelectedViews {
  Left.exactScheduledAmount = Right.exactScheduledAmount and
  Left.knownWithoutAmount = Right.knownWithoutAmount implies {
    knownObligations[Left] = knownObligations[Right]
    unknownAmountObligations[Left] = unknownAmountObligations[Right]
    knownAmountObligations[Left] = knownAmountObligations[Right]
    noKnownObligation[Left] = noKnownObligation[Right]
  }
}

-- Exact Scheduled evidence is, by construction, always enough to say that its
-- own represented obligation is known. The pressure is only the converse gap.
assert ExactScheduledSubjectsAreKnown {
  all w: World | exactScheduledSubjects[w] in knownObligations[w]
}

run representativeUnknownAmount for exactly 2 Obligation, exactly 2 Amount, exactly 2 World
run sameExactScheduledDifferentKnownExistence for exactly 2 Obligation, exactly 2 Amount, exactly 2 World
run sameKnownExistenceDifferentAmountKnowledge for exactly 2 Obligation, exactly 2 Amount, exactly 2 World
check ExactScheduledDeterminesKnownObligation for exactly 2 Obligation, exactly 2 Amount, exactly 2 World
check KnownExistenceDeterminesAmountKnowledge for exactly 2 Obligation, exactly 2 Amount, exactly 2 World
check ExplicitKnowledgeDeterminesSelectedViews for exactly 2 Obligation, exactly 2 Amount, exactly 2 World
check ExactScheduledSubjectsAreKnown for exactly 2 Obligation, exactly 2 Amount, exactly 2 World

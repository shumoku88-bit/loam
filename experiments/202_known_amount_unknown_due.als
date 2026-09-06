module experiments/observation_202_known_amount_unknown_due

sig Obligation {}
sig Amount {}
sig Due {}

one sig O extends Obligation {}
one sig Q extends Amount {}
one sig D extends Due {}

abstract sig World {
  exactScheduledAmount: Obligation -> lone Amount,
  exactScheduledDue: Obligation -> lone Due,
  amountKnownDueUndetermined: Obligation -> lone Amount
}

one sig Left, Right extends World {}

fact ExactScheduledPairsAmountAndDue {
  all w: World, o: Obligation |
    (some w.exactScheduledAmount[o]) iff (some w.exactScheduledDue[o])
}

fact DueUndeterminedEvidenceIsNotExactScheduled {
  all w: World, o: Obligation |
    some w.amountKnownDueUndetermined[o] implies
      (no w.exactScheduledAmount[o] and no w.exactScheduledDue[o])
}

fun selectedKnownAmount[w: World]: Obligation -> Amount {
  w.exactScheduledAmount + w.amountKnownDueUndetermined
}

fun dueKnownSubjects[w: World]: set Obligation {
  { o: Obligation | some w.exactScheduledDue[o] }
}

fun dueUndeterminedSubjects[w: World]: set Obligation {
  { o: Obligation | some w.amountKnownDueUndetermined[o] }
}

pred representativeAmountKnownDueUndetermined {
  Left.amountKnownDueUndetermined[O] = Q
  no Left.exactScheduledAmount[O]
  no Left.exactScheduledDue[O]
  O in dueUndeterminedSubjects[Left]
  O not in dueKnownSubjects[Left]
}

pred sameExactScheduledDifferentKnownAmount {
  Left.exactScheduledAmount = Right.exactScheduledAmount
  Left.exactScheduledDue = Right.exactScheduledDue
  Left.amountKnownDueUndetermined[O] = Q
  no Right.amountKnownDueUndetermined[O]
}

pred sameKnownAmountDifferentTemporalPlacement {
  Left.amountKnownDueUndetermined[O] = Q
  no Left.exactScheduledAmount[O]
  no Left.exactScheduledDue[O]

  Right.exactScheduledAmount[O] = Q
  Right.exactScheduledDue[O] = D
  no Right.amountKnownDueUndetermined[O]

  selectedKnownAmount[Left] = selectedKnownAmount[Right]
  dueUndeterminedSubjects[Left] != dueUndeterminedSubjects[Right]
  dueKnownSubjects[Left] != dueKnownSubjects[Right]
}

assert ExactScheduledDeterminesAllKnownAmount {
  Left.exactScheduledAmount = Right.exactScheduledAmount and
  Left.exactScheduledDue = Right.exactScheduledDue implies
    selectedKnownAmount[Left] = selectedKnownAmount[Right]
}

assert KnownAmountDeterminesTemporalPlacement {
  selectedKnownAmount[Left] = selectedKnownAmount[Right] implies
    (dueKnownSubjects[Left] = dueKnownSubjects[Right] and
     dueUndeterminedSubjects[Left] = dueUndeterminedSubjects[Right])
}

assert ExplicitEvidenceDeterminesSelectedViews {
  Left.exactScheduledAmount = Right.exactScheduledAmount and
  Left.exactScheduledDue = Right.exactScheduledDue and
  Left.amountKnownDueUndetermined = Right.amountKnownDueUndetermined implies
    (selectedKnownAmount[Left] = selectedKnownAmount[Right] and
     dueKnownSubjects[Left] = dueKnownSubjects[Right] and
     dueUndeterminedSubjects[Left] = dueUndeterminedSubjects[Right])
}

assert AmountKnownDueUndeterminedHasNoExactDue {
  all w: World, o: Obligation |
    some w.amountKnownDueUndetermined[o] implies
      (o in dueUndeterminedSubjects[w] and o not in dueKnownSubjects[w])
}

run representativeAmountKnownDueUndetermined for exactly 1 Obligation, exactly 1 Amount, exactly 1 Due, exactly 2 World
run sameExactScheduledDifferentKnownAmount for exactly 1 Obligation, exactly 1 Amount, exactly 1 Due, exactly 2 World
run sameKnownAmountDifferentTemporalPlacement for exactly 1 Obligation, exactly 1 Amount, exactly 1 Due, exactly 2 World
check ExactScheduledDeterminesAllKnownAmount for exactly 1 Obligation, exactly 1 Amount, exactly 1 Due, exactly 2 World
check KnownAmountDeterminesTemporalPlacement for exactly 1 Obligation, exactly 1 Amount, exactly 1 Due, exactly 2 World
check ExplicitEvidenceDeterminesSelectedViews for exactly 1 Obligation, exactly 1 Amount, exactly 1 Due, exactly 2 World
check AmountKnownDueUndeterminedHasNoExactDue for exactly 1 Obligation, exactly 1 Amount, exactly 1 Due, exactly 2 World

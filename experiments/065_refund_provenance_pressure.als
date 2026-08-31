module refund_provenance_pressure

sig Time {}
sig Shape {}
one sig ExpenseShape, ReturnShape extends Shape {}

abstract sig Event {
  at: one Time,
  delta: one Int,
  shape: one Shape
}

sig Expense extends Event {}
sig Return extends Event {}

abstract sig World {
  events: set Event,
  refundOf: Return -> lone Expense
}

one sig Left, Right extends World {}

fact SharedEventRecords {
  all w: World | w.events = Event
}

fact SelectedShapes {
  all e: Expense | e.shape = ExpenseShape
  all r: Return | r.shape = ReturnShape
}

fact SignedDirections {
  all e: Expense | e.delta < 0
  all r: Return | r.delta > 0
}

fun refundedExpenses[w: World]: set Expense {
  Return.(w.refundOf)
}

fun refundReturns[w: World]: set Return {
  (w.refundOf).Expense
}

fun netQuantity[w: World]: one Int {
  sum e: w.events | e.delta
}

fun occurredExpenses[w: World]: set Expense {
  Expense & w.events
}

-- This deliberately imitates the effect of treating refund linkage like
-- a Correction relation whose target disappears from an effective frontier.
fun correctionStyleVisibleExpenses[w: World]: set Expense {
  occurredExpenses[w] - refundedExpenses[w]
}

pred representativeRefundPressure {
  some disj e0, e1: Expense, r: Return |
    e0.delta = e1.delta and
    e0.at = e1.at and
    r->e0 in Left.refundOf and
    r->e1 in Right.refundOf
}

pred sameRecordsDifferentRefundProvenance {
  Left.events = Right.events
  Left.refundOf != Right.refundOf
}

pred sameNetDifferentRefundProvenance {
  netQuantity[Left] = netQuantity[Right]
  Left.refundOf != Right.refundOf
}

pred exactSourceCandidatesAmbiguous {
  some disj e0, e1: Expense, r: Return |
    e0.delta = e1.delta and
    e0.at = e1.at and
    e0.shape = e1.shape and
    r->e0 in Left.refundOf and
    r->e1 in Right.refundOf
}

pred sameReturnCanBeRefundOrUnlinked {
  some r: Return, e: Expense |
    r->e in Left.refundOf and
    no r.(Right.refundOf)
}

assert EventRecordsDetermineRefundProvenance {
  Left.events = Right.events implies Left.refundOf = Right.refundOf
}

assert NetQuantityDeterminesRefundProvenance {
  netQuantity[Left] = netQuantity[Right] implies Left.refundOf = Right.refundOf
}

assert ExplicitRefundRelationDeterminesSelectedAnswers {
  Left.refundOf = Right.refundOf implies {
    refundedExpenses[Left] = refundedExpenses[Right]
    refundReturns[Left] = refundReturns[Right]
  }
}

assert RefundCanUseCorrectionProjectionWithoutLosingOccurrence {
  all w: World |
    correctionStyleVisibleExpenses[w] = occurredExpenses[w]
}

run representativeRefundPressure for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int
run sameRecordsDifferentRefundProvenance for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int
run sameNetDifferentRefundProvenance for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int
run exactSourceCandidatesAmbiguous for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int
run sameReturnCanBeRefundOrUnlinked for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int
check EventRecordsDetermineRefundProvenance for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int
check NetQuantityDeterminesRefundProvenance for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int
check ExplicitRefundRelationDeterminesSelectedAnswers for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int
check RefundCanUseCorrectionProjectionWithoutLosingOccurrence for exactly 2 Expense, exactly 2 Return, exactly 2 Time, exactly 2 Shape, exactly 2 World, 6 Int

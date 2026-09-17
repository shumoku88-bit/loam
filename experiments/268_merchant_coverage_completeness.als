module experiments/observation_268_merchant_coverage_completeness

sig Event {}
sig Party {}

abstract sig World {
  expense: Event -> one Int,
  retainedMerchant: Event -> lone Party,
  explicitlyNonMerchant: set Event,
  merchantInterpretation: Event -> lone Party
}

one sig Left, Right extends World {}

fact WellFormed {
  all w: World | {
    all e: Event |
      let n = expenseOf[w, e] |
        n >= 0 and n <= 6

    w.retainedMerchant in w.merchantInterpretation
    no w.explicitlyNonMerchant & w.retainedMerchant.Party
    no w.explicitlyNonMerchant.(w.merchantInterpretation)
  }
}

fun expenseOf[w: World, e: Event]: one Int {
  sum { i: Int | e->i in w.expense }
}

fun relevantExpenseEvents[w: World]: set Event {
  { e: Event | expenseOf[w, e] > 0 }
}

fun classifiedMerchantEvents[w: World]: set Event {
  w.retainedMerchant.Party
}

pred merchantCoverageComplete[w: World] {
  relevantExpenseEvents[w] in
    (classifiedMerchantEvents[w] + w.explicitlyNonMerchant)
}

fun retainedMerchantContribution[w: World, e: Event, p: Party]: one Int {
  (p in e.(w.retainedMerchant)) => expenseOf[w, e] else 0
}

fun retainedMerchantTotal[w: World, p: Party]: one Int {
  sum e: Event | retainedMerchantContribution[w, e, p]
}

fun interpretedMerchantContribution[w: World, e: Event, p: Party]: one Int {
  (p in e.(w.merchantInterpretation)) => expenseOf[w, e] else 0
}

fun interpretedMerchantTotal[w: World, p: Party]: one Int {
  sum e: Event | interpretedMerchantContribution[w, e, p]
}

pred samePhysicalExpense[a, b: World] {
  a.expense = b.expense
}

pred sameRetainedMerchantEvidence[a, b: World] {
  a.retainedMerchant = b.retainedMerchant
  a.explicitlyNonMerchant = b.explicitlyNonMerchant
}

pred positiveOnlyEvidenceCanHideAnotherMerchantEvent {
  some p: Party, disj known, hidden: Event | {
    expenseOf[Left, known] > 0
    expenseOf[Left, hidden] > 0
    p in known.(Left.retainedMerchant)
    no hidden.(Left.retainedMerchant)
    hidden not in Left.explicitlyNonMerchant
    p in hidden.(Left.merchantInterpretation)
    interpretedMerchantTotal[Left, p] > retainedMerchantTotal[Left, p]
  }
}

pred samePositiveEvidenceAllowsDifferentMerchantTotals {
  samePhysicalExpense[Left, Right]
  sameRetainedMerchantEvidence[Left, Right]
  no Left.explicitlyNonMerchant
  no Right.explicitlyNonMerchant
  some p: Party, e: Event | {
    expenseOf[Left, e] > 0
    no e.(Left.retainedMerchant)
    p in e.(Left.merchantInterpretation)
    no e.(Right.merchantInterpretation)
    interpretedMerchantTotal[Left, p] != interpretedMerchantTotal[Right, p]
  }
}

pred explicitNonMerchantCanCloseOneOtherwiseUnknownEvent {
  some p: Party, disj known, excluded: Event | {
    expenseOf[Left, known] > 0
    expenseOf[Left, excluded] > 0
    p in known.(Left.retainedMerchant)
    excluded in Left.explicitlyNonMerchant
    merchantCoverageComplete[Left]
    retainedMerchantTotal[Left, p] = interpretedMerchantTotal[Left, p]
  }
}

assert MerchantAbsenceMeansExplicitNonMerchant {
  all w: World, e: relevantExpenseEvents[w] |
    no e.(w.retainedMerchant) implies e in w.explicitlyNonMerchant
}

assert PositiveMerchantEvidenceDeterminesExactTotal {
  (samePhysicalExpense[Left, Right] and
   Left.retainedMerchant = Right.retainedMerchant) implies
    all p: Party |
      interpretedMerchantTotal[Left, p] = interpretedMerchantTotal[Right, p]
}

assert CompleteMerchantDispositionClosesExactTotal {
  all w: World |
    merchantCoverageComplete[w] implies
      all p: Party |
        retainedMerchantTotal[w, p] = interpretedMerchantTotal[w, p]
}

assert SameCompleteMerchantEvidenceDeterminesExactTotal {
  (samePhysicalExpense[Left, Right] and
   sameRetainedMerchantEvidence[Left, Right] and
   merchantCoverageComplete[Left] and
   merchantCoverageComplete[Right]) implies
    all p: Party |
      interpretedMerchantTotal[Left, p] = interpretedMerchantTotal[Right, p]
}

run positiveOnlyEvidenceCanHideAnotherMerchantEvent for exactly 2 Event, exactly 1 Party, exactly 2 World, 5 Int
run samePositiveEvidenceAllowsDifferentMerchantTotals for exactly 2 Event, exactly 1 Party, exactly 2 World, 5 Int
run explicitNonMerchantCanCloseOneOtherwiseUnknownEvent for exactly 2 Event, exactly 1 Party, exactly 2 World, 5 Int

check MerchantAbsenceMeansExplicitNonMerchant for exactly 2 Event, exactly 1 Party, exactly 2 World, 5 Int
check PositiveMerchantEvidenceDeterminesExactTotal for exactly 2 Event, exactly 1 Party, exactly 2 World, 5 Int
check CompleteMerchantDispositionClosesExactTotal for exactly 2 Event, exactly 1 Party, exactly 2 World, 5 Int
check SameCompleteMerchantEvidenceDeterminesExactTotal for exactly 2 Event, exactly 1 Party, exactly 2 World, 5 Int

module experiments/observation_121_external_observation_reconciliation

abstract sig Source {}
one sig BankFeed, CardFeed extends Source {}

abstract sig Shape {}
one sig CoffeeShape, CashShape, TransferShape extends Shape {}

abstract sig Moment {}
one sig Morning, Evening extends Moment {}

abstract sig Actual {
  amount: one Int,
  at: one Moment,
  shape: one Shape
}
one sig ManualCash, CoffeeA, CoffeeB, CardPayment extends Actual {}

abstract sig ExternalObservation {
  source: one Source,
  observedAmount: one Int,
  observedAt: one Moment,
  observedShape: one Shape
}
one sig BankCoffee, BankPayment, CardPaymentObservation extends ExternalObservation {}

abstract sig World {
  reconciles: ExternalObservation -> lone Actual
}
one sig Left, Right extends World {}

pred contentMatches[o: ExternalObservation, a: Actual] {
  o.observedAmount = a.amount
  o.observedAt = a.at
  o.observedShape = a.shape
}

fun observationsFor[w: World, a: Actual]: set ExternalObservation {
  { o: ExternalObservation | o->a in w.reconciles }
}

pred supported[w: World, a: Actual] {
  some observationsFor[w, a]
}

pred reconciled[w: World, o: ExternalObservation] {
  some a: Actual | o->a in w.reconciles
}

fun supportedActuals[w: World]: set Actual {
  { a: Actual | supported[w, a] }
}

fun unreconciledObservations[w: World]: set ExternalObservation {
  { o: ExternalObservation | not reconciled[w, o] }
}

fact SpecimenFacts {
  ManualCash.amount = 7
  ManualCash.at = Evening
  ManualCash.shape = CashShape

  CoffeeA.amount = 5
  CoffeeA.at = Morning
  CoffeeA.shape = CoffeeShape

  CoffeeB.amount = 5
  CoffeeB.at = Morning
  CoffeeB.shape = CoffeeShape

  CardPayment.amount = 20
  CardPayment.at = Evening
  CardPayment.shape = TransferShape

  BankCoffee.source = BankFeed
  BankCoffee.observedAmount = 5
  BankCoffee.observedAt = Morning
  BankCoffee.observedShape = CoffeeShape

  BankPayment.source = BankFeed
  BankPayment.observedAmount = 20
  BankPayment.observedAt = Morning
  BankPayment.observedShape = TransferShape

  CardPaymentObservation.source = CardFeed
  CardPaymentObservation.observedAmount = 20
  CardPaymentObservation.observedAt = Evening
  CardPaymentObservation.observedShape = TransferShape
}

pred reconciliationCanLinkTimingDrift {
  Left.reconciles = BankPayment->CardPayment
  BankPayment.observedAmount = CardPayment.amount
  BankPayment.observedShape = CardPayment.shape
  BankPayment.observedAt != CardPayment.at
}

pred manualActualCanExistWithoutExternalObservation {
  Left.reconciles =
    BankCoffee->CoffeeA +
    BankPayment->CardPayment +
    CardPaymentObservation->CardPayment

  no observationsFor[Left, ManualCash]
}

pred externalObservationCanRemainUnreconciled {
  Left.reconciles =
    BankPayment->CardPayment +
    CardPaymentObservation->CardPayment

  BankCoffee in unreconciledObservations[Left]
}

pred twoSourcesCanObserveOneActual {
  Left.reconciles =
    BankPayment->CardPayment +
    CardPaymentObservation->CardPayment

  #observationsFor[Left, CardPayment] = 2
  BankPayment.source != CardPaymentObservation.source
}

pred exactContentCanBeAmbiguous {
  contentMatches[BankCoffee, CoffeeA]
  contentMatches[BankCoffee, CoffeeB]

  Left.reconciles = BankCoffee->CoffeeA
  Right.reconciles = BankCoffee->CoffeeB
}

pred sameRecordsDifferentReconciliationWitness {
  Left.reconciles = BankCoffee->CoffeeA
  Right.reconciles = BankCoffee->CoffeeB

  supported[Left, CoffeeA]
  not supported[Left, CoffeeB]
  not supported[Right, CoffeeA]
  supported[Right, CoffeeB]
}

pred separateObservationAvoidsPromotionDoubleCount {
  Left.reconciles =
    BankPayment->CardPayment +
    CardPaymentObservation->CardPayment

  #{ a: Actual | a.shape = TransferShape } = 1
  #{ o: ExternalObservation | o.observedShape = TransferShape } = 2
  #observationsFor[Left, CardPayment] = 2
}

assert ExactContentIdentifiesAtMostOneActual {
  all o: ExternalObservation |
    lone { a: Actual | contentMatches[o, a] }
}

assert RecordsAloneDetermineSupportedActuals {
  supportedActuals[Left] = supportedActuals[Right]
}

assert ReconciliationRelationDeterminesSelectedAnswers {
  Left.reconciles = Right.reconciles implies {
    supportedActuals[Left] = supportedActuals[Right]
    unreconciledObservations[Left] = unreconciledObservations[Right]
  }
}

run reconciliationCanLinkTimingDrift for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int
run manualActualCanExistWithoutExternalObservation for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int
run externalObservationCanRemainUnreconciled for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int
run twoSourcesCanObserveOneActual for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int
run exactContentCanBeAmbiguous for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int
run sameRecordsDifferentReconciliationWitness for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int
run separateObservationAvoidsPromotionDoubleCount for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int

check ExactContentIdentifiesAtMostOneActual for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int
check RecordsAloneDetermineSupportedActuals for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int
check ReconciliationRelationDeterminesSelectedAnswers for exactly 2 Source, exactly 3 Shape, exactly 2 Moment, exactly 4 Actual, exactly 3 ExternalObservation, exactly 2 World, 6 Int

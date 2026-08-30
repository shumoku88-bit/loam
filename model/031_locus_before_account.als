module model/observation_031_locus_before_account

sig Purpose {}
sig Locus {}
sig AccountName {}
sig Event {}

abstract sig World {
  present: set Event,
  effect: Event -> Locus -> lone Int,
  purpose: Event -> lone Purpose,
  parent: Event -> set Event,
  accountName: Locus -> lone AccountName
}

one sig Left, Right extends World {}

fact WellFormed {
  all w: World | {
    w.effect.Int in w.present -> Locus
    w.purpose.Purpose in w.present
    w.parent in w.present -> w.present
    w.accountName.AccountName in Locus

    all l: Locus | one l.(w.accountName)
    all e: w.present | {
      some e.(w.effect) or some e.(w.purpose) or some e.(w.parent)
      all l: Locus | {
        let n = amount[w, e, l] |
          n >= -2 and n <= 2
      }
    }

    no iden & ^(w.parent)
  }
}

fun amount[w: World, e: Event, l: Locus]: one Int {
  sum { i: Int | e->l->i in w.effect }
}

fun affectedLoci[w: World, e: Event]: set Locus {
  { l: Locus | amount[w, e, l] != 0 }
}

fun eventTotal[w: World, e: Event]: one Int {
  sum l: Locus | amount[w, e, l]
}

fun superseded[w: World]: set Event {
  w.present.(w.parent)
}

fun tips[w: World]: set Event {
  w.present - superseded[w]
}

fun balanceAt[w: World, l: Locus]: one Int {
  sum e: tips[w] | amount[w, e, l]
}

fun locusBalances[w: World]: Locus -> Int {
  { l: Locus, i: Int | i = balanceAt[w, l] }
}

fun totalBalance[w: World]: one Int {
  sum l: Locus | balanceAt[w, l]
}

fun commitments[w: World]: set Purpose {
  tips[w].(w.purpose)
}

fun explanation[w: World]: Event -> Event {
  tips[w] <: *(w.parent)
}

fun transferEvents[w: World]: set Event {
  { e: tips[w] |
      #affectedLoci[w, e] = 2 and
      eventTotal[w, e] = 0 and
      (some l: Locus | amount[w, e, l] < 0) and
      (some l: Locus | amount[w, e, l] > 0) }
}

pred sameCoordinateCore[a, b: World] {
  a.present = b.present
  a.effect = b.effect
  a.purpose = b.purpose
  a.parent = b.parent
}

pred sameAnonymousEventTotals[a, b: World] {
  a.present = b.present
  all e: a.present | eventTotal[a, e] = eventTotal[b, e]
}

pred sameSelectedAnswers[a, b: World] {
  totalBalance[a] = totalBalance[b]
  locusBalances[a] = locusBalances[b]
  commitments[a] = commitments[b]
  explanation[a] = explanation[b]
  transferEvents[a] = transferEvents[b]
}

pred locusCoreExpressesHouseholdPlacement {
  #Left.present = 4
  #Locus = 2

  some transferEvents[Left]
  some l1, l2: Locus |
    l1 != l2 and balanceAt[Left, l1] != balanceAt[Left, l2]

  some e: tips[Left] |
    some e.(Left.purpose) and some affectedLoci[Left, e]

  some e: tips[Left] | some e.(Left.parent)
}

pred differentAccountNamesSameCoreSameAnswers {
  sameCoordinateCore[Left, Right]
  Left.accountName != Right.accountName
  sameSelectedAnswers[Left, Right]
}

pred forgettingLocusCanLoseDistribution {
  sameAnonymousEventTotals[Left, Right]
  Left.purpose = Right.purpose
  Left.parent = Right.parent
  Left.accountName = Right.accountName

  totalBalance[Left] = totalBalance[Right]
  locusBalances[Left] != locusBalances[Right]
}

pred forgettingLocusCanLoseTransferShape {
  sameAnonymousEventTotals[Left, Right]
  Left.purpose = Right.purpose
  Left.parent = Right.parent
  Left.accountName = Right.accountName

  totalBalance[Left] = totalBalance[Right]
  transferEvents[Left] != transferEvents[Right]
}

assert CoordinateCoreDeterminesSelectedVocabulary {
  sameCoordinateCore[Left, Right] implies
    sameSelectedAnswers[Left, Right]
}

run locusCoreExpressesHouseholdPlacement for exactly 4 Event, exactly 2 Locus, exactly 2 Purpose, exactly 2 AccountName, exactly 2 World, 5 Int
run differentAccountNamesSameCoreSameAnswers for exactly 4 Event, exactly 2 Locus, exactly 2 Purpose, exactly 2 AccountName, exactly 2 World, 5 Int
run forgettingLocusCanLoseDistribution for exactly 4 Event, exactly 2 Locus, exactly 2 Purpose, exactly 2 AccountName, exactly 2 World, 5 Int
run forgettingLocusCanLoseTransferShape for exactly 4 Event, exactly 2 Locus, exactly 2 Purpose, exactly 2 AccountName, exactly 2 World, 5 Int
check CoordinateCoreDeterminesSelectedVocabulary for exactly 4 Event, exactly 2 Locus, exactly 2 Purpose, exactly 2 AccountName, exactly 2 World, 5 Int

module experiments/observation_119_scheduled_balance_view_projection

abstract sig Locus {}
one sig Bank, Wallet, Rent, Pension extends Locus {}

abstract sig Scheduled {
  change: Locus -> one Int
}
one sig Payment, Funding, Transfer extends Scheduled {}

abstract sig World {
  open: set Scheduled,
  selected: set Locus,
  eligible: set Locus
}
one sig Left, Right extends World {}

fun delta[s: Scheduled, l: Locus]: one Int {
  l.(s.change)
}

fun impactOn[s: Scheduled, loci: set Locus]: one Int {
  sum l: loci | delta[s, l]
}

fun selectedImpact[w: World, s: Scheduled]: one Int {
  impactOn[s, w.selected]
}

fun selectedOpenImpact[w: World]: one Int {
  sum s: w.open | selectedImpact[w, s]
}

fun eligibleOpenImpact[w: World]: one Int {
  sum s: w.open | impactOn[s, w.eligible]
}

pred sameOpen[a, b: World] {
  a.open = b.open
}

fact SpecimenMovements {
  delta[Payment, Bank] = -3
  delta[Payment, Rent] = 3
  delta[Payment, Wallet] = 0
  delta[Payment, Pension] = 0

  delta[Funding, Pension] = -7
  delta[Funding, Bank] = 7
  delta[Funding, Wallet] = 0
  delta[Funding, Rent] = 0

  delta[Transfer, Bank] = -2
  delta[Transfer, Wallet] = 2
  delta[Transfer, Rent] = 0
  delta[Transfer, Pension] = 0

  all s: Scheduled |
    (sum l: Locus | delta[s, l]) = 0
}

fact EligibilityIsASeparateSelection {
  all w: World | w.eligible in w.selected
}

pred balanceViewReadsRelativeDirectionWithoutAccountTypes {
  Left.open = Payment + Funding + Transfer
  Left.selected = Bank + Wallet

  selectedImpact[Left, Payment] < 0
  selectedImpact[Left, Funding] > 0
  selectedImpact[Left, Transfer] = 0

  delta[Transfer, Bank] != 0
  delta[Transfer, Wallet] != 0
}

pred sameScheduledCanReadDifferentlyThroughDifferentViews {
  Left.open = Payment
  Right.open = Payment

  Left.selected = Bank
  Right.selected = Rent

  selectedImpact[Left, Payment] < 0
  selectedImpact[Right, Payment] > 0
}

pred sameViewCanStillDifferInEligibilitySensitiveImpact {
  sameOpen[Left, Right]
  Left.open = Payment + Funding
  Left.selected = Bank + Rent
  Right.selected = Left.selected

  Left.eligible = Bank
  Right.eligible = Rent

  eligibleOpenImpact[Left] != eligibleOpenImpact[Right]
}

assert ScheduledAloneDeterminesSelectedOpenImpact {
  sameOpen[Left, Right] implies
    selectedOpenImpact[Left] = selectedOpenImpact[Right]
}

assert ScheduledPlusBalanceViewDeterminesSelectedOpenImpact {
  (sameOpen[Left, Right] and Left.selected = Right.selected) implies
    selectedOpenImpact[Left] = selectedOpenImpact[Right]
}

assert BalanceViewPlusScheduledDeterminesEligibilitySensitiveImpact {
  (sameOpen[Left, Right] and Left.selected = Right.selected) implies
    eligibleOpenImpact[Left] = eligibleOpenImpact[Right]
}

assert BalanceViewPlusScheduledPlusEligibilityDeterminesEligibilitySensitiveImpact {
  (sameOpen[Left, Right] and
   Left.selected = Right.selected and
   Left.eligible = Right.eligible) implies
    eligibleOpenImpact[Left] = eligibleOpenImpact[Right]
}

run balanceViewReadsRelativeDirectionWithoutAccountTypes for exactly 4 Locus, exactly 3 Scheduled, exactly 2 World, 5 Int
run sameScheduledCanReadDifferentlyThroughDifferentViews for exactly 4 Locus, exactly 3 Scheduled, exactly 2 World, 5 Int
run sameViewCanStillDifferInEligibilitySensitiveImpact for exactly 4 Locus, exactly 3 Scheduled, exactly 2 World, 5 Int

check ScheduledAloneDeterminesSelectedOpenImpact for exactly 4 Locus, exactly 3 Scheduled, exactly 2 World, 5 Int
check ScheduledPlusBalanceViewDeterminesSelectedOpenImpact for exactly 4 Locus, exactly 3 Scheduled, exactly 2 World, 5 Int
check BalanceViewPlusScheduledDeterminesEligibilitySensitiveImpact for exactly 4 Locus, exactly 3 Scheduled, exactly 2 World, 5 Int
check BalanceViewPlusScheduledPlusEligibilityDeterminesEligibilitySensitiveImpact for exactly 4 Locus, exactly 3 Scheduled, exactly 2 World, 5 Int

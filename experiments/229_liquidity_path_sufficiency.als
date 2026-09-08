module experiments/observation_229_liquidity_path_sufficiency

abstract sig Coordinate {}
one sig Bank, Wallet, Investment extends Coordinate {}

abstract sig Day {}
one sig Past, Today, D1, D2, D3 extends Day {}

sig Leg {
  coordinate: one Coordinate,
  quantity: one Int
}

sig ScheduledMove {
  scheduledOn: one Day,
  legs: some Leg
}

one sig Rent, Funding, Transfer, InvestmentMove, Overdue extends ScheduledMove {}
one sig RentBank, FundingBank, TransferBank, TransferWallet,
        InvestBank, InvestAsset, OverdueBank extends Leg {}

one sig Evidence {
  current: Coordinate -> one Int,
  explicit: set ScheduledMove,
  completeThrough: one Day
}

sig World {
  selection: set Coordinate,
  d1First: one ScheduledMove,
  overdueFutureDay: one Day
}

one sig Left, Right extends World {}

fact FixedHouseholdEvidence {
  Evidence.current = Bank->5 + Wallet->2 + Investment->6
  Evidence.explicit = Rent + Funding + Transfer + InvestmentMove + Overdue
  Evidence.completeThrough = D3

  Rent.scheduledOn = D1
  Rent.legs = RentBank
  RentBank.coordinate = Bank
  RentBank.quantity = -3

  Funding.scheduledOn = D1
  Funding.legs = FundingBank
  FundingBank.coordinate = Bank
  FundingBank.quantity = 4

  Transfer.scheduledOn = D2
  Transfer.legs = TransferBank + TransferWallet
  TransferBank.coordinate = Bank
  TransferBank.quantity = -2
  TransferWallet.coordinate = Wallet
  TransferWallet.quantity = 2

  InvestmentMove.scheduledOn = D3
  InvestmentMove.legs = InvestBank + InvestAsset
  InvestBank.coordinate = Bank
  InvestBank.quantity = -2
  InvestAsset.coordinate = Investment
  InvestAsset.quantity = 2

  Overdue.scheduledOn = Past
  Overdue.legs = OverdueBank
  OverdueBank.coordinate = Bank
  OverdueBank.quantity = -2

  all w: World | {
    w.d1First in Rent + Funding
    w.overdueFutureDay in D1 + D2
  }
}

fun selectedCurrent[w: World]: one Int {
  sum c: w.selection | sum c.(Evidence.current)
}

fun selectedMoveDelta[w: World, m: ScheduledMove]: one Int {
  sum l: m.legs | (l.coordinate in w.selection) => l.quantity else 0
}

fun scheduledDayFlow[w: World, d: Day]: one Int {
  sum m: Evidence.explicit |
    (m.scheduledOn = d) => selectedMoveDelta[w, m] else 0
}

fun day1Balance[w: World]: one Int {
  add[selectedCurrent[w], scheduledDayFlow[w, D1]]
}

fun day2Balance[w: World]: one Int {
  add[day1Balance[w], scheduledDayFlow[w, D2]]
}

fun day3Balance[w: World]: one Int {
  add[day2Balance[w], scheduledDayFlow[w, D3]]
}

// One deliberately order-sensitive intraday observation.
fun afterFirstD1[w: World]: one Int {
  add[selectedCurrent[w], selectedMoveDelta[w, w.d1First]]
}

// A hidden future placement for an already-overdue open Scheduled movement.
// This is observation-local ground truth, not proposed production state.
fun overdueDeltaOn[w: World, d: Day]: one Int {
  (w.overdueFutureDay = d) => selectedMoveDelta[w, Overdue] else 0
}

fun pressureDay1Balance[w: World]: one Int {
  add[day1Balance[w], overdueDeltaOn[w, D1]]
}

fun pressureDay2Balance[w: World]: one Int {
  add[add[day1Balance[w], overdueDeltaOn[w, D1]],
      add[scheduledDayFlow[w, D2], overdueDeltaOn[w, D2]]]
}

pred representativeSelectedPath {
  Left.selection = Bank + Wallet
  Left.d1First = Rent
  Left.overdueFutureDay = D1

  selectedCurrent[Left] = 7
  scheduledDayFlow[Left, D1] = 1
  day1Balance[Left] = 8
  day2Balance[Left] = 8
  day3Balance[Left] = 6
}

pred sameEvidenceDifferentSelectionChangesPath {
  Left.selection = Bank + Wallet
  Right.selection = Bank + Wallet + Investment
  day3Balance[Left] != day3Balance[Right]
}

pred sameDayNetDifferentIntradayOrder {
  Left.selection = Right.selection
  Left.selection = Bank + Wallet
  Left.d1First = Rent
  Right.d1First = Funding
  day1Balance[Left] = day1Balance[Right]
  afterFirstD1[Left] != afterFirstD1[Right]
}

pred sameCompleteEvidenceDifferentOverdueTiming {
  Left.selection = Right.selection
  Left.selection = Bank + Wallet
  Left.overdueFutureDay = D1
  Right.overdueFutureDay = D2
  pressureDay1Balance[Left] != pressureDay1Balance[Right]
}

assert FixedSelectionDeterminesDayBoundaryScheduledPath {
  all a, b: World |
    a.selection = b.selection implies
      (day1Balance[a] = day1Balance[b] and
       day2Balance[a] = day2Balance[b] and
       day3Balance[a] = day3Balance[b])
}

assert CompletenessChoosesLiquiditySelection {
  all a, b: World | a.selection = b.selection
}

assert DayBoundaryPathDeterminesIntradayFirstBalance {
  all a, b: World |
    a.selection = b.selection implies afterFirstD1[a] = afterFirstD1[b]
}

assert CompletenessDeterminesOverdueFutureTiming {
  all a, b: World |
    a.selection = b.selection implies
      pressureDay1Balance[a] = pressureDay1Balance[b]
}

run representativeSelectedPath for exactly 3 Coordinate, exactly 5 Day,
  exactly 7 Leg, exactly 5 ScheduledMove, exactly 2 World, 5 Int
run sameEvidenceDifferentSelectionChangesPath for exactly 3 Coordinate, exactly 5 Day,
  exactly 7 Leg, exactly 5 ScheduledMove, exactly 2 World, 5 Int
run sameDayNetDifferentIntradayOrder for exactly 3 Coordinate, exactly 5 Day,
  exactly 7 Leg, exactly 5 ScheduledMove, exactly 2 World, 5 Int
run sameCompleteEvidenceDifferentOverdueTiming for exactly 3 Coordinate, exactly 5 Day,
  exactly 7 Leg, exactly 5 ScheduledMove, exactly 2 World, 5 Int

check FixedSelectionDeterminesDayBoundaryScheduledPath for exactly 3 Coordinate, exactly 5 Day,
  exactly 7 Leg, exactly 5 ScheduledMove, exactly 2 World, 5 Int
check CompletenessChoosesLiquiditySelection for exactly 3 Coordinate, exactly 5 Day,
  exactly 7 Leg, exactly 5 ScheduledMove, exactly 2 World, 5 Int
check DayBoundaryPathDeterminesIntradayFirstBalance for exactly 3 Coordinate, exactly 5 Day,
  exactly 7 Leg, exactly 5 ScheduledMove, exactly 2 World, 5 Int
check CompletenessDeterminesOverdueFutureTiming for exactly 3 Coordinate, exactly 5 Day,
  exactly 7 Leg, exactly 5 ScheduledMove, exactly 2 World, 5 Int

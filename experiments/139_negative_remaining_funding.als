module negative_remaining_funding

open util/integer

abstract sig Purpose {}
one sig Food extends Purpose {}

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, ExpenseRole extends AccountingRole {}

abstract sig Locus {
  role : one AccountingRole
}
one sig CashLocus, LiabilityLocus, FoodExpenseLocus extends Locus {}

abstract sig Range {
  start : one Int,
  end : one Int
}
one sig PreviousRange, NextRange extends Range {}

abstract sig CapacityAuthority {
  range : one Range,
  amount : Purpose -> one Int
}
one sig PreviousAuthority, NextAuthority extends CapacityAuthority {}

one sig InitialPhysicalState {
  quantity : Locus -> one Int
}

abstract sig World {}
one sig CashFundedWorld, LiabilityFundedWorld, CashFundedWorldCopy extends World {}

abstract sig Actual {
  world : one World,
  purpose : one Purpose,
  quantity : one Int,
  effect : Locus -> one Int
}
one sig CashSpend, LiabilitySpend, CashSpendCopy extends Actual {}

fact Specimen {
  CashLocus.role = AssetRole
  LiabilityLocus.role = LiabilityRole
  FoodExpenseLocus.role = ExpenseRole

  PreviousRange.start = 0
  PreviousRange.end = 1
  NextRange.start = 1
  NextRange.end = 2

  PreviousAuthority.range = PreviousRange
  NextAuthority.range = NextRange
  PreviousAuthority.amount[Food] = 10
  NextAuthority.amount[Food] = 10

  InitialPhysicalState.quantity[CashLocus] = 20
  InitialPhysicalState.quantity[LiabilityLocus] = 0
  InitialPhysicalState.quantity[FoodExpenseLocus] = 0

  CashSpend.world = CashFundedWorld
  CashSpend.purpose = Food
  CashSpend.quantity = 12
  CashSpend.effect[CashLocus] = -12
  CashSpend.effect[LiabilityLocus] = 0
  CashSpend.effect[FoodExpenseLocus] = 12

  LiabilitySpend.world = LiabilityFundedWorld
  LiabilitySpend.purpose = Food
  LiabilitySpend.quantity = 12
  LiabilitySpend.effect[CashLocus] = 0
  LiabilitySpend.effect[LiabilityLocus] = 12
  LiabilitySpend.effect[FoodExpenseLocus] = 12

  CashSpendCopy.world = CashFundedWorldCopy
  CashSpendCopy.purpose = Food
  CashSpendCopy.quantity = 12
  CashSpendCopy.effect[CashLocus] = -12
  CashSpendCopy.effect[LiabilityLocus] = 0
  CashSpendCopy.effect[FoodExpenseLocus] = 12

  all w : World | one a : Actual | a.world = w
  all a : Actual | gt[a.quantity, 0]
  all a : Actual | a.quantity = a.effect[FoodExpenseLocus]
}

fun actualFor[w : World] : one Actual {
  { a : Actual | a.world = w }
}

fun consumption[w : World, p : Purpose] : one Int {
  sum a : Actual |
    (a.world = w and a.purpose = p)
      => a.quantity
      else 0
}

fun remaining[w : World, p : Purpose] : one Int {
  sub[PreviousAuthority.amount[p], consumption[w, p]]
}

fun physicalAfter[w : World, l : Locus] : one Int {
  add[InitialPhysicalState.quantity[l], actualFor[w].effect[l]]
}

fun roleQuantityAfter[w : World, r : AccountingRole] : one Int {
  sum l : Locus |
    (l.role = r)
      => physicalAfter[w, l]
      else 0
}

fun assetQuantityAfter[w : World] : one Int {
  roleQuantityAfter[w, AssetRole]
}

fun liabilityQuantityAfter[w : World] : one Int {
  roleQuantityAfter[w, LiabilityRole]
}

fun netFundingPositionAfter[w : World] : one Int {
  sub[assetQuantityAfter[w], liabilityQuantityAfter[w]]
}

pred sameBudgetEvidence[w1, w2 : World] {
  consumption[w1, Food] = consumption[w2, Food]
  remaining[w1, Food] = remaining[w2, Food]
  PreviousAuthority.amount[Food] = 10
  NextAuthority.amount[Food] = 10
}

pred sameActualPhysicalDefinition[w1, w2 : World] {
  actualFor[w1].purpose = actualFor[w2].purpose
  actualFor[w1].quantity = actualFor[w2].quantity
  all l : Locus | actualFor[w1].effect[l] = actualFor[w2].effect[l]
}

pred sameNegativeRemainingDifferentFundingComposition {
  sameBudgetEvidence[CashFundedWorld, LiabilityFundedWorld]
  remaining[CashFundedWorld, Food] = -2
  remaining[LiabilityFundedWorld, Food] = -2

  assetQuantityAfter[CashFundedWorld] = 8
  liabilityQuantityAfter[CashFundedWorld] = 0

  assetQuantityAfter[LiabilityFundedWorld] = 20
  liabilityQuantityAfter[LiabilityFundedWorld] = 12

  netFundingPositionAfter[CashFundedWorld] = 8
  netFundingPositionAfter[LiabilityFundedWorld] = 8
}

pred cashFundedNegativeRemainingIsReachable {
  remaining[CashFundedWorld, Food] = -2
  assetQuantityAfter[CashFundedWorld] = 8
  liabilityQuantityAfter[CashFundedWorld] = 0
}

pred liabilityFundedNegativeRemainingIsReachable {
  remaining[LiabilityFundedWorld, Food] = -2
  assetQuantityAfter[LiabilityFundedWorld] = 20
  liabilityQuantityAfter[LiabilityFundedWorld] = 12
}

pred sameBoundaryCapacityDifferentFundingPressure {
  NextAuthority.amount[Food] = 10
  sameBudgetEvidence[CashFundedWorld, LiabilityFundedWorld]
  assetQuantityAfter[CashFundedWorld] != assetQuantityAfter[LiabilityFundedWorld]
  liabilityQuantityAfter[CashFundedWorld] != liabilityQuantityAfter[LiabilityFundedWorld]
}

pred equalPhysicalDefinitionDifferentIdentitySameAnswer {
  CashFundedWorld != CashFundedWorldCopy
  sameActualPhysicalDefinition[CashFundedWorld, CashFundedWorldCopy]
  remaining[CashFundedWorld, Food] = remaining[CashFundedWorldCopy, Food]
  assetQuantityAfter[CashFundedWorld] = assetQuantityAfter[CashFundedWorldCopy]
  liabilityQuantityAfter[CashFundedWorld] = liabilityQuantityAfter[CashFundedWorldCopy]
  netFundingPositionAfter[CashFundedWorld] = netFundingPositionAfter[CashFundedWorldCopy]
}

assert NegativeRemainingDeterminesFundingComposition {
  all w1, w2 : World |
    sameBudgetEvidence[w1, w2]
    implies
    (assetQuantityAfter[w1] = assetQuantityAfter[w2] and
     liabilityQuantityAfter[w1] = liabilityQuantityAfter[w2])
}

assert NegativeRemainingAndNetPositionDetermineFundingComposition {
  all w1, w2 : World |
    (sameBudgetEvidence[w1, w2] and
     netFundingPositionAfter[w1] = netFundingPositionAfter[w2])
    implies
    (assetQuantityAfter[w1] = assetQuantityAfter[w2] and
     liabilityQuantityAfter[w1] = liabilityQuantityAfter[w2])
}

assert DifferentFundingCompositionRequiresDifferentNextCapacity {
  all w1, w2 : World |
    (sameBudgetEvidence[w1, w2] and
     (assetQuantityAfter[w1] != assetQuantityAfter[w2] or
      liabilityQuantityAfter[w1] != liabilityQuantityAfter[w2]))
    implies
    NextAuthority.amount[Food] != NextAuthority.amount[Food]
}

assert ActualPhysicalDefinitionDeterminesFundingProjection {
  all w1, w2 : World |
    sameActualPhysicalDefinition[w1, w2]
    implies
    (remaining[w1, Food] = remaining[w2, Food] and
     assetQuantityAfter[w1] = assetQuantityAfter[w2] and
     liabilityQuantityAfter[w1] = liabilityQuantityAfter[w2] and
     netFundingPositionAfter[w1] = netFundingPositionAfter[w2])
}

run sameNegativeRemainingDifferentFundingComposition for 6 Int
run cashFundedNegativeRemainingIsReachable for 6 Int
run liabilityFundedNegativeRemainingIsReachable for 6 Int
run sameBoundaryCapacityDifferentFundingPressure for 6 Int
run equalPhysicalDefinitionDifferentIdentitySameAnswer for 6 Int

check NegativeRemainingDeterminesFundingComposition for 6 Int
check NegativeRemainingAndNetPositionDetermineFundingComposition for 6 Int
check DifferentFundingCompositionRequiresDifferentNextCapacity for 6 Int
check ActualPhysicalDefinitionDeterminesFundingProjection for 6 Int

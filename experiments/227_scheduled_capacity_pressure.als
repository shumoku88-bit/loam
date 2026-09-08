module experiments/observation_227_scheduled_capacity_pressure

abstract sig Role {}
one sig Asset, Liability, Equity, Income, Expense extends Role {}

abstract sig Polarity {}
one sig Positive, Negative extends Polarity {}

abstract sig RouteKind {}
one sig Managed, Unmanaged, NoRoute extends RouteKind {}

sig Coordinate {
  role: one Role,
  polarity: one Polarity,
  route: one RouteKind
}

fun positiveCoordinates : set Coordinate {
  { c: Coordinate | c.polarity = Positive }
}

fun explicitRouted : set Coordinate {
  { c: Coordinate | c.route != NoRoute }
}

fun defaultPressureRole : set Role {
  Expense + Liability
}

fun selectedPressure : set Coordinate {
  { c: Coordinate |
      c.polarity = Positive and
      (c.role in defaultPressureRole or c.route != NoRoute) }
}

fun managedPressure : set Coordinate {
  { c: selectedPressure | c.route = Managed }
}

fun unmanagedPressure : set Coordinate {
  { c: selectedPressure | c.route = Unmanaged }
}

fun unroutedPressure : set Coordinate {
  { c: selectedPressure | c.route = NoRoute }
}

pred representativeHousehold {
  some disj wifi, pensionReceipt, debtRepayment, savingsTransfer, fundingSource: Coordinate |
    wifi.role = Expense and
    wifi.polarity = Positive and
    wifi.route = Managed and

    pensionReceipt.role = Asset and
    pensionReceipt.polarity = Positive and
    pensionReceipt.route = NoRoute and

    debtRepayment.role = Liability and
    debtRepayment.polarity = Positive and
    debtRepayment.route = NoRoute and

    savingsTransfer.role = Asset and
    savingsTransfer.polarity = Positive and
    savingsTransfer.route = Managed and

    fundingSource.role = Asset and
    fundingSource.polarity = Negative and
    fundingSource.route = NoRoute and

    wifi in managedPressure and
    pensionReceipt not in selectedPressure and
    debtRepayment in unroutedPressure and
    savingsTransfer in managedPressure and
    fundingSource not in selectedPressure
}

pred sameRoleDifferentPressure {
  some disj a, b: Coordinate |
    a.role = b.role and
    a.polarity = b.polarity and
    a.route != b.route and
    a in selectedPressure and
    b not in selectedPressure
}

pred liabilityWithoutRouteStillPressures {
  some c: Coordinate |
    c.role = Liability and
    c.polarity = Positive and
    c.route = NoRoute and
    c in unroutedPressure
}

assert AllPositiveCoordinatesArePressure {
  positiveCoordinates = selectedPressure
}

assert RoleAndPolarityAloneDetermineSelectedPressure {
  all disj a, b: Coordinate |
    (a.role = b.role and a.polarity = b.polarity) implies
      (a in selectedPressure iff b in selectedPressure)
}

assert RolePolarityAndRoutingDetermineSelectedPressure {
  all disj a, b: Coordinate |
    (a.role = b.role and a.polarity = b.polarity and a.route = b.route) implies
      (a in selectedPressure iff b in selectedPressure)
}

assert PositiveExpenseOrLiabilityAlwaysPressures {
  all c: Coordinate |
    (c.polarity = Positive and c.role in Expense + Liability) implies
      c in selectedPressure
}

assert UnroutedPositiveAssetDoesNotPressure {
  all c: Coordinate |
    (c.polarity = Positive and c.role = Asset and c.route = NoRoute) implies
      c not in selectedPressure
}

assert ExplicitlyRoutedPositiveAssetPressures {
  all c: Coordinate |
    (c.polarity = Positive and c.role = Asset and c.route != NoRoute) implies
      c in selectedPressure
}

assert NegativeCoordinatesNeverPressure {
  all c: Coordinate |
    c.polarity = Negative implies c not in selectedPressure
}

assert PressurePartitionsSelectedCoordinates {
  selectedPressure = managedPressure + unmanagedPressure + unroutedPressure
  no managedPressure & unmanagedPressure
  no managedPressure & unroutedPressure
  no unmanagedPressure & unroutedPressure
}

run representativeHousehold for exactly 5 Coordinate
run sameRoleDifferentPressure for exactly 2 Coordinate
run liabilityWithoutRouteStillPressures for exactly 1 Coordinate
check AllPositiveCoordinatesArePressure for exactly 2 Coordinate
check RoleAndPolarityAloneDetermineSelectedPressure for exactly 2 Coordinate
check RolePolarityAndRoutingDetermineSelectedPressure for exactly 2 Coordinate
check PositiveExpenseOrLiabilityAlwaysPressures for exactly 2 Coordinate
check UnroutedPositiveAssetDoesNotPressure for exactly 2 Coordinate
check ExplicitlyRoutedPositiveAssetPressures for exactly 2 Coordinate
check NegativeCoordinatesNeverPressure for exactly 2 Coordinate
check PressurePartitionsSelectedCoordinates for exactly 3 Coordinate

module stable_purpose_coordinate

open util/integer

abstract sig Purpose {}
one sig FoodPurpose, TravelPurpose, ReservePurpose extends Purpose {}

abstract sig Label {}
one sig FoodLabel, GroceriesLabel, TravelLabel, ReserveLabel, RainyDayLabel extends Label {}

abstract sig Range {
  start : one Int,
  end : one Int
}

one sig EarlierRange, LaterRange extends Range {}

abstract sig CapacityAuthority {
  range : one Range,
  purpose : one Purpose,
  quantity : one Int
}

one sig FoodEarlierCapacity,
        FoodLaterCapacity,
        TravelEarlierCapacity,
        TravelLaterCapacity,
        ReserveEarlierCapacity,
        ReserveLaterCapacity extends CapacityAuthority {}

// Experiment-local descriptive evidence only.
// This is deliberately not a proposed Practical Core PurposeDescription type.
abstract sig PurposeDescription {
  range : one Range,
  purpose : one Purpose,
  label : one Label
}

one sig FoodEarlierDescription,
        FoodLaterDescription,
        TravelEarlierDescription,
        TravelLaterDescription,
        ReserveEarlierDescription,
        ReserveLaterDescription extends PurposeDescription {}

pred active[r : Range, day : Int] {
  gte[day, r.start]
  lt[day, r.end]
}

fun capacityAt[p : Purpose, day : Int] : one Int {
  sum c : CapacityAuthority |
    (c.purpose = p and active[c.range, day]) => c.quantity else 0
}

fun labelsAt[p : Purpose, day : Int] : set Label {
  { d : PurposeDescription |
      d.purpose = p and active[d.range, day]
  }.label
}

fact Specimen {
  EarlierRange.start = 0
  EarlierRange.end = 2
  LaterRange.start = 2
  LaterRange.end = 4

  EarlierRange.end = LaterRange.start

  FoodEarlierCapacity.range = EarlierRange
  FoodEarlierCapacity.purpose = FoodPurpose
  FoodEarlierCapacity.quantity = 10

  FoodLaterCapacity.range = LaterRange
  FoodLaterCapacity.purpose = FoodPurpose
  FoodLaterCapacity.quantity = 7

  TravelEarlierCapacity.range = EarlierRange
  TravelEarlierCapacity.purpose = TravelPurpose
  TravelEarlierCapacity.quantity = 4

  TravelLaterCapacity.range = LaterRange
  TravelLaterCapacity.purpose = TravelPurpose
  TravelLaterCapacity.quantity = 6

  ReserveEarlierCapacity.range = EarlierRange
  ReserveEarlierCapacity.purpose = ReservePurpose
  ReserveEarlierCapacity.quantity = 3

  ReserveLaterCapacity.range = LaterRange
  ReserveLaterCapacity.purpose = ReservePurpose
  ReserveLaterCapacity.quantity = 3

  FoodEarlierDescription.range = EarlierRange
  FoodEarlierDescription.purpose = FoodPurpose
  FoodEarlierDescription.label = FoodLabel

  FoodLaterDescription.range = LaterRange
  FoodLaterDescription.purpose = FoodPurpose
  FoodLaterDescription.label = GroceriesLabel

  TravelEarlierDescription.range = EarlierRange
  TravelEarlierDescription.purpose = TravelPurpose
  TravelEarlierDescription.label = TravelLabel

  TravelLaterDescription.range = LaterRange
  TravelLaterDescription.purpose = TravelPurpose
  TravelLaterDescription.label = TravelLabel

  ReserveEarlierDescription.range = EarlierRange
  ReserveEarlierDescription.purpose = ReservePurpose
  ReserveEarlierDescription.label = ReserveLabel

  ReserveLaterDescription.range = LaterRange
  ReserveLaterDescription.purpose = ReservePurpose
  ReserveLaterDescription.label = RainyDayLabel

  all c : CapacityAuthority | gte[c.quantity, 0]
}

pred stablePurposeCrossesBoundary {
  FoodEarlierCapacity.purpose = FoodLaterCapacity.purpose
  FoodEarlierDescription.purpose = FoodLaterDescription.purpose
  FoodEarlierCapacity.purpose = FoodEarlierDescription.purpose
  FoodLaterCapacity.purpose = FoodLaterDescription.purpose

  capacityAt[FoodPurpose, 1] = 10
  labelsAt[FoodPurpose, 1] = FoodLabel

  capacityAt[FoodPurpose, 2] = 7
  labelsAt[FoodPurpose, 2] = GroceriesLabel
}

pred nameAndCapacityCanChangeTogether {
  FoodEarlierCapacity.purpose = FoodLaterCapacity.purpose
  FoodEarlierCapacity.quantity != FoodLaterCapacity.quantity
  FoodEarlierDescription.label != FoodLaterDescription.label
}

pred capacityCanChangeWithoutNameChange {
  TravelEarlierCapacity.purpose = TravelLaterCapacity.purpose
  TravelEarlierCapacity.quantity != TravelLaterCapacity.quantity
  TravelEarlierDescription.label = TravelLaterDescription.label
}

pred nameCanChangeWithoutCapacityChange {
  ReserveEarlierCapacity.purpose = ReserveLaterCapacity.purpose
  ReserveEarlierCapacity.quantity = ReserveLaterCapacity.quantity
  ReserveEarlierDescription.label != ReserveLaterDescription.label
}

pred historicalNameIsNotOverwritten {
  labelsAt[FoodPurpose, 0] = FoodLabel
  labelsAt[FoodPurpose, 1] = FoodLabel
  labelsAt[FoodPurpose, 2] = GroceriesLabel
  labelsAt[FoodPurpose, 3] = GroceriesLabel
}

pred exactBoundarySelectsLaterEvidence {
  not active[EarlierRange, 2]
  active[LaterRange, 2]
  capacityAt[FoodPurpose, 2] = FoodLaterCapacity.quantity
  labelsAt[FoodPurpose, 2] = FoodLaterDescription.label
}

pred noPurposeLifecycleStateNeededInSpecimen {
  some labelsAt[FoodPurpose, 0]
  some labelsAt[FoodPurpose, 3]
  capacityAt[FoodPurpose, 0] = 10
  capacityAt[FoodPurpose, 3] = 7
}

assert PurposeIdentityDeterminesOneTimelessLabel {
  all p : Purpose, d1, d2 : Int |
    (gte[d1, 0] and lt[d1, 4] and gte[d2, 0] and lt[d2, 4])
    implies labelsAt[p, d1] = labelsAt[p, d2]
}

assert PurposeIdentityDeterminesOneTimelessCapacity {
  all p : Purpose, d1, d2 : Int |
    (gte[d1, 0] and lt[d1, 4] and gte[d2, 0] and lt[d2, 4])
    implies capacityAt[p, d1] = capacityAt[p, d2]
}

assert NameChangeRequiresPurposeReplacement {
  all d1, d2 : PurposeDescription |
    d1.label != d2.label implies d1.purpose != d2.purpose
}

assert CapacityChangeRequiresPurposeReplacement {
  all c1, c2 : CapacityAuthority |
    c1.quantity != c2.quantity implies c1.purpose != c2.purpose
}

assert TimedDescriptionIsUnambiguousWithinCoveredHorizon {
  all p : Purpose, day : Int |
    (gte[day, 0] and lt[day, 4]) implies one labelsAt[p, day]
}

assert TimedCapacityIsUnambiguousWithinCoveredHorizon {
  all p : Purpose, day : Int |
    (gte[day, 0] and lt[day, 4]) implies
      one { c : CapacityAuthority | c.purpose = p and active[c.range, day] }
}

run stablePurposeCrossesBoundary for 5 Int
run nameAndCapacityCanChangeTogether for 5 Int
run capacityCanChangeWithoutNameChange for 5 Int
run nameCanChangeWithoutCapacityChange for 5 Int
run historicalNameIsNotOverwritten for 5 Int
run exactBoundarySelectsLaterEvidence for 5 Int
run noPurposeLifecycleStateNeededInSpecimen for 5 Int

check PurposeIdentityDeterminesOneTimelessLabel for 5 Int
check PurposeIdentityDeterminesOneTimelessCapacity for 5 Int
check NameChangeRequiresPurposeReplacement for 5 Int
check CapacityChangeRequiresPurposeReplacement for 5 Int
check TimedDescriptionIsUnambiguousWithinCoveredHorizon for 5 Int
check TimedCapacityIsUnambiguousWithinCoveredHorizon for 5 Int

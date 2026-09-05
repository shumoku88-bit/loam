module model/observation_190_sparse_human_annotation_boundary

sig Outlay {}
sig Part {
  owner: one Outlay
}

sig Description {}
sig Intent {}

abstract sig ChoiceTag {}
one sig Need, Want extends ChoiceTag {}

abstract sig ScheduleState {}
one sig Scheduled, Unscheduled extends ScheduleState {}

abstract sig FundingState {}
one sig Backed, Unbacked extends FundingState {}

abstract sig World {
  description: Part -> set Description,
  intent: Part -> set Intent,
  choice: Part -> set ChoiceTag,
  schedule: Outlay -> one ScheduleState,
  funding: Outlay -> one FundingState
}

one sig Left, Right extends World {}

fact EveryOutlayHasARepresentedPart {
  all o: Outlay |
    some p: Part |
      p.owner = o
}

pred annotationLaws[w: World] {
  all p: Part |
    lone p.(w.description)

  all p: Part |
    lone p.(w.intent)
}

pred modelLaws {
  all w: World |
    annotationLaws[w]
}

fun outlayChoices[w: World, o: Outlay]: set ChoiceTag {
  { tag: ChoiceTag |
    some p: Part |
      p.owner = o and
      tag in p.(w.choice)
  }
}

fun financialProjection[w: World]: Outlay -> ScheduleState -> FundingState {
  { o: Outlay, s: ScheduleState, f: FundingState |
    s in o.(w.schedule) and
    f in o.(w.funding)
  }
}

pred sameFinancialSkeleton[a, b: World] {
  a.schedule = b.schedule
  a.funding = b.funding
}

pred mixedBundle[w: World] {
  some o: Outlay, disj neededPart, wantedPart: Part |
    neededPart.owner = o and
    wantedPart.owner = o and
    Need in neededPart.(w.choice) and
    Want in wantedPart.(w.choice)
}

pred samePartNeedAndWant[w: World] {
  some p: Part |
    Need + Want in p.(w.choice)
}

pred singleChoicePerOutlay[w: World] {
  all o: Outlay |
    lone outlayChoices[w, o]
}

pred exclusiveChoicePerPart[w: World] {
  all p: Part |
    lone p.(w.choice)
}

pred mixedBundlePressure {
  modelLaws
  mixedBundle[Left]
}

pred samePartNeedAndWantPressure {
  modelLaws
  samePartNeedAndWant[Left]
}

pred mixedBundleWithSingleOutlayChoice {
  modelLaws
  mixedBundle[Left]
  singleChoicePerOutlay[Left]
}

pred samePartNeedAndWantWithExclusiveChoice {
  modelLaws
  samePartNeedAndWant[Left]
  exclusiveChoicePerPart[Left]
}

pred sameFinanceDifferentHumanMeaning {
  modelLaws
  sameFinancialSkeleton[Left, Right]

  some p: Part |
    p.(Left.description) != p.(Right.description) or
    p.(Left.choice) != p.(Right.choice) or
    p.(Left.intent) != p.(Right.intent)
}

pred sameCurrentMeaningDifferentIntent {
  modelLaws
  sameFinancialSkeleton[Left, Right]
  Left.description = Right.description
  Left.choice = Right.choice

  some p: Part |
    p.(Left.intent) != p.(Right.intent)
}

assert HumanAnnotationsCannotChangeFinancialProjection {
  (modelLaws and sameFinancialSkeleton[Left, Right])
  implies
  financialProjection[Left] = financialProjection[Right]
}

run mixedBundlePressure
  for exactly 1 Outlay, exactly 2 Part, exactly 1 Description, exactly 1 Intent

run samePartNeedAndWantPressure
  for exactly 1 Outlay, exactly 1 Part, exactly 1 Description, exactly 1 Intent

run mixedBundleWithSingleOutlayChoice
  for exactly 1 Outlay, exactly 2 Part, exactly 1 Description, exactly 1 Intent

run samePartNeedAndWantWithExclusiveChoice
  for exactly 1 Outlay, exactly 1 Part, exactly 1 Description, exactly 1 Intent

run sameFinanceDifferentHumanMeaning
  for exactly 1 Outlay, exactly 1 Part, exactly 2 Description, exactly 2 Intent

run sameCurrentMeaningDifferentIntent
  for exactly 1 Outlay, exactly 1 Part, exactly 1 Description, exactly 2 Intent

check HumanAnnotationsCannotChangeFinancialProjection
  for exactly 2 Outlay, exactly 3 Part, exactly 2 Description, exactly 2 Intent

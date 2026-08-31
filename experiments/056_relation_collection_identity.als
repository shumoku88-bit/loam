module experiments/observation_056_relation_collection_identity

open util/ordering[Slot]

sig Event {}

sig CorrectionId {}
sig ResolutionId {}

sig Correction {
  id: one CorrectionId,
  target: one Event,
  replacement: one Event
}

sig Resolution {
  id: one ResolutionId,
  parents: some Event,
  replacement: one Event
}

sig Snapshot {
  events: set Event,
  corrections: set Correction,
  resolutions: set Resolution
}

sig Slot {}

abstract sig CorrectionLayout {
  members: set Correction,
  placed: Slot -> lone Correction
}

one sig LeftLayout, RightLayout extends CorrectionLayout {}

fact CorrectionPlacementCoversMembers {
  all layout: CorrectionLayout | {
    layout.members = Slot.(layout.placed)
    all correction: layout.members | one correction.~(layout.placed)
  }
}

pred correctionReferencesPresent[s: Snapshot, correction: Correction] {
  correction.target in s.events
  correction.replacement in s.events
}

pred resolutionReferencesPresent[s: Snapshot, resolution: Resolution] {
  resolution.parents in s.events
  resolution.replacement in s.events
}

fun admittedCorrections[s: Snapshot]: set Correction {
  { correction: s.corrections | correctionReferencesPresent[s, correction] }
}

fun admittedResolutions[s: Snapshot]: set Resolution {
  { resolution: s.resolutions | resolutionReferencesPresent[s, resolution] }
}

pred uniqueCorrectionIds[s: Snapshot] {
  all disj left, right: admittedCorrections[s] | left.id != right.id
}

pred uniqueResolutionIds[s: Snapshot] {
  all disj left, right: admittedResolutions[s] | left.id != right.id
}

fun correctionById[s: Snapshot, id: CorrectionId]: set Correction {
  { correction: admittedCorrections[s] | correction.id = id }
}

fun resolutionById[s: Snapshot, id: ResolutionId]: set Resolution {
  { resolution: admittedResolutions[s] | resolution.id = id }
}

pred admittedDuplicateCorrectionCanDisagree {
  some s: Snapshot, disj left, right: admittedCorrections[s] | {
    left.id = right.id
    left.target != right.target or left.replacement != right.replacement
  }
}

pred admittedDuplicateResolutionCanDisagree {
  some s: Snapshot, disj left, right: admittedResolutions[s] | {
    left.id = right.id
    left.parents != right.parents or left.replacement != right.replacement
  }
}

pred sameCorrectionFactsCanSwapFirstDuplicate {
  LeftLayout.members = RightLayout.members
  #LeftLayout.members = 2
  one LeftLayout.members.id
  some disj left, right: LeftLayout.members | {
    left.target != right.target or left.replacement != right.replacement
  }
  first.(LeftLayout.placed) != first.(RightLayout.placed)
}

pred sameUniqueCorrectionFactsCanReorder {
  LeftLayout.members = RightLayout.members
  #LeftLayout.members = 2
  all disj left, right: LeftLayout.members | left.id != right.id
  first.(LeftLayout.placed) != first.(RightLayout.placed)
}

assert ReferentialAdmissionImpliesUniqueCorrectionIds {
  all s: Snapshot | uniqueCorrectionIds[s]
}

assert ReferentialAdmissionImpliesUniqueResolutionIds {
  all s: Snapshot | uniqueResolutionIds[s]
}

assert UniqueCorrectionIdsMakeLookupSingle {
  all s: Snapshot, id: CorrectionId |
    uniqueCorrectionIds[s] implies lone correctionById[s, id]
}

assert UniqueResolutionIdsMakeLookupSingle {
  all s: Snapshot, id: ResolutionId |
    uniqueResolutionIds[s] implies lone resolutionById[s, id]
}

assert CorrectionIdentityLookupIgnoresLayoutOrder {
  (LeftLayout.members = RightLayout.members and
   all disj left, right: LeftLayout.members | left.id != right.id)
  implies
  all id: CorrectionId |
    { correction: LeftLayout.members | correction.id = id } =
      { correction: RightLayout.members | correction.id = id }
}

run admittedDuplicateCorrectionCanDisagree for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot
run admittedDuplicateResolutionCanDisagree for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot
run sameCorrectionFactsCanSwapFirstDuplicate for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot
run sameUniqueCorrectionFactsCanReorder for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot
check ReferentialAdmissionImpliesUniqueCorrectionIds for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot
check ReferentialAdmissionImpliesUniqueResolutionIds for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot
check UniqueCorrectionIdsMakeLookupSingle for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot
check UniqueResolutionIdsMakeLookupSingle for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot
check CorrectionIdentityLookupIgnoresLayoutOrder for exactly 3 Event, exactly 2 Correction, exactly 2 CorrectionId, exactly 2 Resolution, exactly 2 ResolutionId, exactly 1 Snapshot, exactly 2 Slot

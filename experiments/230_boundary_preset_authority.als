module experiments/observation_230_boundary_preset_authority

open util/ordering[Day] as ord

sig Day {}
sig Preset {}

sig PresetState {
  preset: one Preset,
  boundaries: set Day
}

sig Fact {
  occurs: one Day,
  regimes: set Preset
}

sig Receipt {
  start: one Day,
  endExclusive: one Day
}

fun atOrBefore[s: PresetState, d: Day] : set Day {
  { b: s.boundaries | ord/lte[b, d] }
}

fun strictlyAfter[s: PresetState, d: Day] : set Day {
  { b: s.boundaries | ord/lt[d, b] }
}

fun startFor[s: PresetState, d: Day] : set Day {
  { b: atOrBefore[s, d] |
      no later: atOrBefore[s, d] | ord/lt[b, later] }
}

fun endFor[s: PresetState, d: Day] : set Day {
  { b: strictlyAfter[s, d] |
      no earlier: strictlyAfter[s, d] | ord/lt[earlier, b] }
}

pred windowDefined[s: PresetState, d: Day] {
  one startFor[s, d]
  one endFor[s, d]
  ord/lt[startFor[s, d], endFor[s, d]]
}

fun windowFacts[s: PresetState, d: Day] : set Fact {
  { f: Fact |
      one startFor[s, d] and
      one endFor[s, d] and
      ord/lte[startFor[s, d], f.occurs] and
      ord/lt[f.occurs, endFor[s, d]] }
}

pred captures[r: Receipt, s: PresetState, d: Day] {
  windowDefined[s, d]
  r.start = startFor[s, d]
  r.endExclusive = endFor[s, d]
}

fun receiptFacts[r: Receipt] : set Fact {
  { f: Fact |
      ord/lte[r.start, f.occurs] and
      ord/lt[f.occurs, r.endExclusive] }
}

fun regimeFacts[p: Preset] : set Fact {
  { f: Fact | p in f.regimes }
}

pred presetEditChangesLiveWindowButReceiptStaysOld {
  some before, after: PresetState, p: Preset, d: Day, r: Receipt |
    before != after and
    before.preset = p and after.preset = p and
    before.boundaries != after.boundaries and
    windowDefined[before, d] and windowDefined[after, d] and
    captures[r, before, d] and
    (startFor[before, d] != startFor[after, d] or
     endFor[before, d] != endFor[after, d]) and
    receiptFacts[r] = windowFacts[before, d] and
    receiptFacts[r] != windowFacts[after, d]
}

pred replaceablePresetCanChangeCurrentQuestionWithoutChangingFacts {
  some before, after: PresetState, p: Preset, d: Day |
    before != after and
    before.preset = p and after.preset = p and
    before.boundaries != after.boundaries and
    windowDefined[before, d] and windowDefined[after, d] and
    windowFacts[before, d] != windowFacts[after, d]
}

pred explicitFactMembershipMakesPresetIdentityObservable {
  some disj left, right: Preset, leftState, rightState: PresetState |
    leftState.preset = left and
    rightState.preset = right and
    leftState.boundaries = rightState.boundaries and
    regimeFacts[left] != regimeFacts[right]
}

assert CapturedReceiptReplaysOriginalCoordinateAnswer {
  all r: Receipt, s: PresetState, d: Day |
    captures[r, s, d] implies receiptFacts[r] = windowFacts[s, d]
}

assert SameResolvedWindowGivesSameCoordinateAnswer {
  all left, right: PresetState, d: Day |
    windowDefined[left, d] and windowDefined[right, d] and
    startFor[left, d] = startFor[right, d] and
    endFor[left, d] = endFor[right, d]
      implies windowFacts[left, d] = windowFacts[right, d]
}

assert PresetIdentityAloneCannotChangeCoordinateAnswer {
  all left, right: PresetState, d: Day |
    left.boundaries = right.boundaries implies
      windowFacts[left, d] = windowFacts[right, d]
}

run presetEditChangesLiveWindowButReceiptStaysOld for exactly 6 Day, 2 PresetState, 1 Preset, 4 Fact, 1 Receipt
run replaceablePresetCanChangeCurrentQuestionWithoutChangingFacts for exactly 6 Day, 2 PresetState, 1 Preset, 4 Fact
run explicitFactMembershipMakesPresetIdentityObservable for exactly 4 Day, 2 PresetState, 2 Preset, 2 Fact
check CapturedReceiptReplaysOriginalCoordinateAnswer for 7 Day, 3 PresetState, 3 Preset, 6 Fact, 3 Receipt
check SameResolvedWindowGivesSameCoordinateAnswer for 7 Day, 3 PresetState, 3 Preset, 6 Fact
check PresetIdentityAloneCannotChangeCoordinateAnswer for 7 Day, 3 PresetState, 3 Preset, 6 Fact

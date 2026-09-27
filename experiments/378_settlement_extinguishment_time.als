module experiments/observation_378_settlement_extinguishment_time

open util/ordering[Moment] as time

sig Moment {}
sig Commitment {
  quantity: one Int,
  openedAt: one Moment
}

sig ExtinguishmentId {}

sig Extinguishment {
  id: one ExtinguishmentId,
  target: one Commitment,
  quantity: one Int,
  // Optional semantic occurrence time.
  // Absence means "the extinguishment is retained current evidence,
  // but its historical placement is unknown."
  effectiveAt: lone Moment
}

abstract sig World {
  commitments: set Commitment,
  extinguishments: set Extinguishment
}

one sig Left, Right extends World {}

fact QuantityShape {
  all c: Commitment | {
    c.quantity > 0
    c.quantity <= 10
  }
  all e: Extinguishment | {
    e.quantity > 0
    e.quantity <= 10
  }
}

fact SameRetainedRows {
  Left.commitments = Right.commitments
  Left.extinguishments = Right.extinguishments
}

fact EffectiveTimeNotBeforeCommitment {
  all w: World, e: w.extinguishments |
    some e.effectiveAt implies
      let opened = e.target.openedAt,
          effective = e.effectiveAt |
        opened = effective or time/lt[opened, effective]
}

fun totalExtinguished[w: World, c: Commitment]: one Int {
  sum e: w.extinguishments |
    (e.target = c => e.quantity else 0)
}

fun currentOutstanding[w: World, c: Commitment]: one Int {
  sub[c.quantity, totalExtinguished[w, c]]
}

fun placedExtinguishedBy[w: World, c: Commitment, cutoff: Moment]: one Int {
  sum e: w.extinguishments |
    (e.target = c and
     some e.effectiveAt and
     (e.effectiveAt = cutoff or time/lt[e.effectiveAt, cutoff]))
      => e.quantity else 0
}

fun historicalOutstandingAt[w: World, c: Commitment, cutoff: Moment]: one Int {
  sub[c.quantity, placedExtinguishedBy[w, c, cutoff]]
}

pred sameCurrentDifferentHistoricalPlacementWitness {
  some c: Commitment, e: Extinguishment,
       early, late, cutoff: Moment | {
    Left.commitments = c
    Right.commitments = c
    Left.extinguishments = e
    Right.extinguishments = e

    c.quantity = 10
    e.target = c
    e.quantity = 3

    e.effectiveAt = early
    time/lt[early, cutoff]
    time/lt[cutoff, late]

    // Rebind the same retained row to a later semantic placement in Right.
    // The worlds intentionally differ only in effective time.
    currentOutstanding[Left, c] = 7
    currentOutstanding[Right, c] = 7
  }
}

pred knownEarlyVersusUnknownWitness {
  some c: Commitment, e: Extinguishment, effective, cutoff: Moment | {
    Left.commitments = c
    Right.commitments = c
    Left.extinguishments = e
    Right.extinguishments = e

    c.quantity = 10
    e.target = c
    e.quantity = 3
    e.effectiveAt = effective
    time/lt[effective, cutoff]
  }
}

// A separate pair of rows is used to model equal non-temporal evidence where
// one world knows placement and the other does not.
sig TemporalProbe {
  known: one Extinguishment,
  unknown: one Extinguishment
}

pred optionalTimePreservesUnknownWitness {
  some probe: TemporalProbe, c: Commitment, effective, cutoff: Moment | {
    probe.known != probe.unknown
    probe.known.target = c
    probe.unknown.target = c
    probe.known.quantity = 3
    probe.unknown.quantity = 3

    some probe.known.effectiveAt
    probe.known.effectiveAt = effective
    no probe.unknown.effectiveAt

    time/lt[effective, cutoff]

    c.quantity = 10
  }
}

pred unknownStillDeterminesCurrentOutstandingWitness {
  some c: Commitment, e: Extinguishment | {
    c in Left.commitments
    e in Left.extinguishments
    e.target = c
    c.quantity = 10
    e.quantity = 3
    no e.effectiveAt

    currentOutstanding[Left, c] = 7
  }
}

assert CurrentOutstandingIgnoresTemporalPlacement {
  all w: World, c: w.commitments |
    currentOutstanding[w, c] =
      sub[c.quantity, totalExtinguished[w, c]]
}

assert KnownHistoricalPlacementDeterminesAsOfView {
  all w: World, c: w.commitments, cutoff: Moment |
    historicalOutstandingAt[w, c, cutoff] =
      sub[c.quantity, placedExtinguishedBy[w, c, cutoff]]
}

// Deliberately too strong: current state does not determine historical placement.
assert CurrentOutstandingDeterminesHistoricalOutstanding {
  all c: Commitment, cutoff: Moment |
    c in Left.commitments and c in Right.commitments and
    currentOutstanding[Left, c] = currentOutstanding[Right, c]
    implies
      historicalOutstandingAt[Left, c, cutoff] =
        historicalOutstandingAt[Right, c, cutoff]
}

// Deliberately too strong: missing effective time cannot be silently interpreted
// as commitment-open time for historical queries.
assert UnknownEffectiveTimeEqualsOpenTime {
  all e: Extinguishment, cutoff: Moment |
    no e.effectiveAt implies
      let c = e.target |
        historicalOutstandingAt[Left, c, cutoff] =
          sub[c.quantity,
            (c.openedAt = cutoff or time/lt[c.openedAt, cutoff])
              => e.quantity else 0]
}

run unknownStillDeterminesCurrentOutstandingWitness
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 1 ExtinguishmentId, exactly 1 Extinguishment, exactly 0 TemporalProbe,
      8 Int

run optionalTimePreservesUnknownWitness
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 2 ExtinguishmentId, exactly 2 Extinguishment, exactly 1 TemporalProbe,
      8 Int

check CurrentOutstandingIgnoresTemporalPlacement
  for exactly 2 World, exactly 3 Moment, exactly 2 Commitment,
      exactly 3 ExtinguishmentId, exactly 3 Extinguishment, exactly 0 TemporalProbe,
      8 Int

check KnownHistoricalPlacementDeterminesAsOfView
  for exactly 2 World, exactly 3 Moment, exactly 2 Commitment,
      exactly 3 ExtinguishmentId, exactly 3 Extinguishment, exactly 0 TemporalProbe,
      8 Int

check CurrentOutstandingDeterminesHistoricalOutstanding
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 1 ExtinguishmentId, exactly 1 Extinguishment, exactly 0 TemporalProbe,
      8 Int

check UnknownEffectiveTimeEqualsOpenTime
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 1 ExtinguishmentId, exactly 1 Extinguishment, exactly 0 TemporalProbe,
      8 Int

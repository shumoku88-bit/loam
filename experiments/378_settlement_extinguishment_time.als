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
  quantity: one Int
}

abstract sig World {
  commitments: set Commitment,
  extinguishments: set Extinguishment,

  // Candidate semantic occurrence coordinate.
  // Absence means historical placement is explicitly unknown.
  effectiveAt: Extinguishment -> lone Moment
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

fact SameNonTemporalEvidence {
  Left.commitments = Right.commitments
  Left.extinguishments = Right.extinguishments
}

fact ReferenceClosure {
  all w: World |
    w.extinguishments.target in w.commitments
}

pred atOrBefore[a, b: Moment] {
  a = b or time/lt[a, b]
}

fact EffectiveTimeShape {
  all w: World, e: Extinguishment | {
    some e.(w.effectiveAt) implies {
      e in w.extinguishments
      atOrBefore[e.target.openedAt, e.(w.effectiveAt)]
    }
    e not in w.extinguishments implies no e.(w.effectiveAt)
  }
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
     some e.(w.effectiveAt) and
     atOrBefore[e.(w.effectiveAt), cutoff])
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

    e.(Left.effectiveAt) = early
    e.(Right.effectiveAt) = late

    time/lt[early, cutoff]
    time/lt[cutoff, late]

    currentOutstanding[Left, c] = 7
    currentOutstanding[Right, c] = 7

    historicalOutstandingAt[Left, c, cutoff] = 7
    historicalOutstandingAt[Right, c, cutoff] = 10
  }
}

pred knownEarlyVersusUnknownWitness {
  some c: Commitment, e: Extinguishment,
       effective, cutoff: Moment | {
    Left.commitments = c
    Right.commitments = c
    Left.extinguishments = e
    Right.extinguishments = e

    c.quantity = 10
    e.target = c
    e.quantity = 3

    e.(Left.effectiveAt) = effective
    no e.(Right.effectiveAt)
    time/lt[effective, cutoff]

    currentOutstanding[Left, c] = 7
    currentOutstanding[Right, c] = 7

    historicalOutstandingAt[Left, c, cutoff] = 7
    historicalOutstandingAt[Right, c, cutoff] = 10
  }
}

pred unknownStillDeterminesCurrentOutstandingWitness {
  some c: Commitment, e: Extinguishment | {
    c in Left.commitments
    e in Left.extinguishments

    c.quantity = 10
    e.target = c
    e.quantity = 3
    no e.(Left.effectiveAt)

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

// Deliberately too strong: equal current state does not determine historical
// placement when effective times differ or are unknown.
assert CurrentOutstandingDeterminesHistoricalOutstanding {
  all c: Commitment, cutoff: Moment |
    c in Left.commitments and
    c in Right.commitments and
    currentOutstanding[Left, c] = currentOutstanding[Right, c]
    implies
      historicalOutstandingAt[Left, c, cutoff] =
        historicalOutstandingAt[Right, c, cutoff]
}

// Deliberately too strong: missing effective time must not silently mean the
// commitment's opening time.
assert UnknownEffectiveTimeEqualsOpenTime {
  all e: Left.extinguishments, cutoff: Moment |
    no e.(Left.effectiveAt) implies
      let c = e.target |
        historicalOutstandingAt[Left, c, cutoff] =
          sub[
            c.quantity,
            atOrBefore[c.openedAt, cutoff] => e.quantity else 0
          ]
}

run sameCurrentDifferentHistoricalPlacementWitness
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 1 ExtinguishmentId, exactly 1 Extinguishment, 8 Int

run knownEarlyVersusUnknownWitness
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 1 ExtinguishmentId, exactly 1 Extinguishment, 8 Int

run unknownStillDeterminesCurrentOutstandingWitness
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 1 ExtinguishmentId, exactly 1 Extinguishment, 8 Int

check CurrentOutstandingIgnoresTemporalPlacement
  for exactly 2 World, exactly 3 Moment, exactly 2 Commitment,
      exactly 3 ExtinguishmentId, exactly 3 Extinguishment, 8 Int

check KnownHistoricalPlacementDeterminesAsOfView
  for exactly 2 World, exactly 3 Moment, exactly 2 Commitment,
      exactly 3 ExtinguishmentId, exactly 3 Extinguishment, 8 Int

check CurrentOutstandingDeterminesHistoricalOutstanding
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 1 ExtinguishmentId, exactly 1 Extinguishment, 8 Int

check UnknownEffectiveTimeEqualsOpenTime
  for exactly 2 World, exactly 3 Moment, exactly 1 Commitment,
      exactly 1 ExtinguishmentId, exactly 1 Extinguishment, 8 Int

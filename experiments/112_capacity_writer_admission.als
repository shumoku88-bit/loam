module experiments/observation_112_capacity_writer_admission

open util/ordering[Day] as ord

sig Day {}

abstract sig Endpoint {}
one sig Unallocated extends Endpoint {}
sig Purpose extends Endpoint {}

sig Movement {
  source: one Endpoint,
  target: one Endpoint
}

sig World {
  effectiveOn: Movement -> Day
}

one sig Left, Right extends World {}

fact DistinctEndpoints {
  all m: Movement | m.source != m.target
}

fact EveryWorldDatesEveryMovement {
  all w: World, m: Movement |
    one m.(w.effectiveOn)
}

fun through[d: Day]: set Day {
  d.*(ord/prev)
}

fun received[w: World, p: Purpose, d: Day]: set Movement {
  { m: Movement |
    m.target = p and
    m.(w.effectiveOn) in through[d]
  }
}

fun sent[w: World, p: Purpose, d: Day]: set Movement {
  { m: Movement |
    m.source = p and
    m.(w.effectiveOn) in through[d]
  }
}

fun purposeBalance[w: World, p: Purpose, d: Day]: one Int {
  sub[#(received[w, p, d]), #(sent[w, p, d])]
}

fun unallocatedBalance[w: World, d: Day]: one Int {
  sub[
    #({ m: Movement |
        m.target = Unallocated and
        m.(w.effectiveOn) in through[d]
      }),
    #({ m: Movement |
        m.source = Unallocated and
        m.(w.effectiveOn) in through[d]
      })
  ]
}

pred purposeStockValid[w: World] {
  all p: Purpose, d: Day |
    purposeBalance[w, p, d] >= 0
}

pred finalPurposeNonnegative[w: World] {
  all p: Purpose |
    purposeBalance[w, p, ord/last] >= 0
}

pred representativeHraShapedCapacity {
  purposeStockValid[Left]
  some disj p, q: Purpose |
    some disj grant, move: Movement | {
      grant.source = Unallocated
      grant.target = p
      move.source = p
      move.target = q
      grant.(Left.effectiveOn) in move.(Left.effectiveOn).*(ord/prev)
    }
}

pred sameMovementSetDifferentTimeDifferentValidity {
  Left.effectiveOn != Right.effectiveOn
  purposeStockValid[Left]
  not purposeStockValid[Right]
}

pred finalNonnegativeHidesEarlierInvalidity {
  finalPurposeNonnegative[Left]
  not purposeStockValid[Left]
}

pred sameDayGrantAndTransferCanNet {
  purposeStockValid[Left]
  some disj p, q: Purpose |
    some disj grant, move: Movement | {
      grant.source = Unallocated
      grant.target = p
      move.source = p
      move.target = q
      grant.(Left.effectiveOn) = move.(Left.effectiveOn)
    }
}

pred unallocatedBoundaryCanBeNegative {
  purposeStockValid[Left]
  unallocatedBalance[Left, ord/last] < 0
}

assert UntimedMovementsDetermineHistoricalStockValidity {
  purposeStockValid[Left] iff purposeStockValid[Right]
}

assert TimedMovementsDetermineHistoricalStockValidity {
  Left.effectiveOn = Right.effectiveOn
  implies (purposeStockValid[Left] iff purposeStockValid[Right])
}

assert FinalPurposeTotalsDetermineHistoricalStockValidity {
  (all p: Purpose |
    purposeBalance[Left, p, ord/last] = purposeBalance[Right, p, ord/last])
  implies (purposeStockValid[Left] iff purposeStockValid[Right])
}

assert PurposeAndUnallocatedShareOneNonnegativeStockLaw {
  all w: World, d: Day |
    unallocatedBalance[w, d] >= 0
}

run representativeHraShapedCapacity for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World
run sameMovementSetDifferentTimeDifferentValidity for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World
run finalNonnegativeHidesEarlierInvalidity for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World
run sameDayGrantAndTransferCanNet for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World
run unallocatedBoundaryCanBeNegative for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World
check UntimedMovementsDetermineHistoricalStockValidity for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World
check TimedMovementsDetermineHistoricalStockValidity for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World
check FinalPurposeTotalsDetermineHistoricalStockValidity for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World
check PurposeAndUnallocatedShareOneNonnegativeStockLaw for exactly 2 Day, exactly 2 Movement, exactly 2 Purpose, exactly 2 World

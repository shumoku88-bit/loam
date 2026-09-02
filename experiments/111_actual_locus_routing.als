module experiments/observation_111_actual_locus_routing

open util/ordering[Day] as ord

sig Day {}
sig ActualEvent {}
sig Locus {}
sig Purpose {}

sig Effect {
  event: one ActualEvent,
  locus: one Locus
}

sig RoutingEvidence {
  locus: one Locus,
  effectiveOn: one Day,
  purpose: lone Purpose
}

sig World {
  routes: set RoutingEvidence,
  validOn: ActualEvent -> one Day
}

one sig Left, Right extends World {}

fact OneRoutePerLocusDay {
  all w: World, l: Locus, d: Day |
    lone { r: w.routes | r.locus = l and r.effectiveOn = d }
}

fun visibleRoutes[w: World, l: Locus, d: Day]: set RoutingEvidence {
  { r: w.routes |
    r.locus = l and
    r.effectiveOn in d.*(ord/prev)
  }
}

fun latestRoute[w: World, l: Locus, d: Day]: lone RoutingEvidence {
  { r: visibleRoutes[w, l, d] |
    no newer: visibleRoutes[w, l, d] - r |
      newer.effectiveOn in r.effectiveOn.^(ord/next)
  }
}

fun routedPurposeAt[w: World, l: Locus, d: Day]: lone Purpose {
  { p: Purpose |
    some r: latestRoute[w, l, d] |
      p in r.purpose
  }
}

fun managedEffects[w: World]: Effect -> Purpose {
  { e: Effect, p: Purpose |
    p in routedPurposeAt[w, e.locus, w.validOn[e.event]]
  }
}

fun unmanagedEffects[w: World]: set Effect {
  { e: Effect |
    some r: latestRoute[w, e.locus, w.validOn[e.event]] |
      no r.purpose
  }
}

fun unroutedEffects[w: World]: set Effect {
  { e: Effect |
    no latestRoute[w, e.locus, w.validOn[e.event]]
  }
}

fun currentManagedEffects[w: World]: Effect -> Purpose {
  { e: Effect, p: Purpose |
    p in routedPurposeAt[w, e.locus, ord/last]
  }
}

pred representativeLocusRoutedActual {
  some ev: ActualEvent | {
    let effects = ev.~event |
      #effects >= 3 and
      some effects & unmanagedEffects[Left] + effects & unroutedEffects[Left]

    #((ev.~event).(managedEffects[Left])) >= 2
  }
}

pred sameRoutesDifferentValidDayDifferentRouting {
  Left.routes = Right.routes
  Left.validOn != Right.validOn

  managedEffects[Left] != managedEffects[Right]
  or unmanagedEffects[Left] != unmanagedEffects[Right]
  or unroutedEffects[Left] != unroutedEffects[Right]
}

pred oneEventNeedsMultiplePurposes {
  some ev: ActualEvent |
    #((ev.~event).(managedEffects[Left])) >= 2
}

pred currentRouteCanMisreadEarlierActual {
  some e: Effect |
    e.(managedEffects[Left]) != e.(currentManagedEffects[Left])
}

pred explicitlyUnmanagedActual {
  some e: unmanagedEffects[Left]
}

assert RoutesWithoutValidDayDetermineSelectedRouting {
  Left.routes = Right.routes
  implies {
    managedEffects[Left] = managedEffects[Right]
    unmanagedEffects[Left] = unmanagedEffects[Right]
    unroutedEffects[Left] = unroutedEffects[Right]
  }
}

assert OneEventSinglePurposeAlwaysEnough {
  all w: World, ev: ActualEvent |
    lone ((ev.~event).(managedEffects[w]))
}

assert RoutesAndValidDayDetermineSelectedRouting {
  Left.routes = Right.routes and Left.validOn = Right.validOn
  implies {
    managedEffects[Left] = managedEffects[Right]
    unmanagedEffects[Left] = unmanagedEffects[Right]
    unroutedEffects[Left] = unroutedEffects[Right]
  }
}

assert SelectedRoutingPartitionsEffects {
  all w: World | {
    let managed = (managedEffects[w]).Purpose |
      managed + unmanagedEffects[w] + unroutedEffects[w] = Effect
      and no managed & unmanagedEffects[w]
      and no managed & unroutedEffects[w]
      and no unmanagedEffects[w] & unroutedEffects[w]
  }
}

assert LatestRouteIsUnique {
  all w: World, l: Locus, d: Day |
    lone latestRoute[w, l, d]
}

run representativeLocusRoutedActual for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
run sameRoutesDifferentValidDayDifferentRouting for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
run oneEventNeedsMultiplePurposes for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
run currentRouteCanMisreadEarlierActual for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
run explicitlyUnmanagedActual for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
check RoutesWithoutValidDayDetermineSelectedRouting for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
check OneEventSinglePurposeAlwaysEnough for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
check RoutesAndValidDayDetermineSelectedRouting for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
check SelectedRoutingPartitionsEffects for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World
check LatestRouteIsUnique for exactly 3 Day, exactly 2 ActualEvent, exactly 4 Effect, exactly 3 Locus, exactly 2 Purpose, exactly 5 RoutingEvidence, exactly 2 World

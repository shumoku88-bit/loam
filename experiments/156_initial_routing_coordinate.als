module experiments/observation_156_initial_routing_coordinate

open util/ordering[Day] as ord

sig Day {}
sig Subject {}
sig Purpose {}

abstract sig Effective {}
one sig Initial extends Effective {}
sig Dated extends Effective {
  day: one Day
}

sig Route {
  subject: one Subject,
  effective: one Effective,
  purpose: lone Purpose
}

sig World {
  routes: set Route
}

one sig Left, Right extends World {}

fact DatedCoordinatesMirrorDays {
  all d: Day | one e: Dated | e.day = d
  all disj a, b: Dated | a.day != b.day
}

fact OneRoutePerSubjectEffectiveCoordinate {
  all w: World, s: Subject, e: Effective |
    lone { r: w.routes | r.subject = s and r.effective = e }
}

pred effectiveLt[a, b: Effective] {
  (a = Initial and b in Dated)
  or
  (a in Dated and b in Dated and
    some ad: a & Dated, bd: b & Dated |
      ord/lt[ad.day, bd.day])
}

pred visibleAt[e: Effective, d: Day] {
  e = Initial
  or
  some ed: e & Dated |
    ed.day in d.*(ord/prev)
}

fun visibleRoutes[w: World, s: Subject, d: Day]: set Route {
  { r: w.routes |
    r.subject = s and visibleAt[r.effective, d]
  }
}

fun latestRoutes[w: World, s: Subject, d: Day]: set Route {
  { r: visibleRoutes[w, s, d] |
    no newer: visibleRoutes[w, s, d] - r |
      effectiveLt[r.effective, newer.effective]
  }
}

fun collapsedDay[e: Effective]: one Day {
  { d: Day |
    (e = Initial and d = ord/first)
    or
    some ed: e & Dated | d = ed.day
  }
}

pred initialThenFirstDayOverride {
  some s: Subject, disj initialPurpose, datedPurpose: Purpose,
       initialRoute, datedRoute: Route | {
    initialRoute + datedRoute in Left.routes
    initialRoute.subject = s
    initialRoute.effective = Initial
    initialRoute.purpose = initialPurpose

    datedRoute.subject = s
    datedRoute.effective in Dated
    some de: datedRoute.effective & Dated | de.day = ord/first
    datedRoute.purpose = datedPurpose

    latestRoutes[Left, s, ord/first] = datedRoute
  }
}

pred laterDatedOverrideAfterInitial {
  some s: Subject, disj initialPurpose, datedPurpose: Purpose,
       initialRoute, datedRoute: Route, d: Day | {
    initialRoute + datedRoute in Left.routes
    initialRoute.subject = s
    initialRoute.effective = Initial
    initialRoute.purpose = initialPurpose

    datedRoute.subject = s
    datedRoute.effective in Dated
    some de: datedRoute.effective & Dated | de.day = d
    datedRoute.purpose = datedPurpose
    ord/lt[ord/first, d]

    latestRoutes[Left, s, ord/first] = initialRoute
    latestRoutes[Left, s, d] = datedRoute
  }
}

pred fakeDateCollision {
  some s: Subject, initialRoute, datedRoute: Route | {
    initialRoute + datedRoute in Left.routes
    initialRoute.subject = s
    initialRoute.effective = Initial

    datedRoute.subject = s
    datedRoute.effective in Dated
    some de: datedRoute.effective & Dated | de.day = ord/first

    initialRoute != datedRoute
    collapsedDay[initialRoute.effective] = collapsedDay[datedRoute.effective]
  }
}

assert InitialIsVisibleAtEveryDay {
  all d: Day | visibleAt[Initial, d]
}

assert LatestVisibleRouteIsUnique {
  all w: World, s: Subject, d: Day |
    lone latestRoutes[w, s, d]
}

assert FakeDateCollapsePreservesEffectiveCoordinateIdentity {
  all a, b: Effective |
    collapsedDay[a] = collapsedDay[b] implies a = b
}

run initialThenFirstDayOverride for exactly 3 Day, exactly 2 Subject, exactly 3 Purpose, exactly 3 Dated, exactly 6 Route, exactly 2 World
run laterDatedOverrideAfterInitial for exactly 3 Day, exactly 2 Subject, exactly 3 Purpose, exactly 3 Dated, exactly 6 Route, exactly 2 World
run fakeDateCollision for exactly 3 Day, exactly 2 Subject, exactly 3 Purpose, exactly 3 Dated, exactly 6 Route, exactly 2 World
check InitialIsVisibleAtEveryDay for exactly 3 Day, exactly 2 Subject, exactly 3 Purpose, exactly 3 Dated, exactly 6 Route, exactly 2 World
check LatestVisibleRouteIsUnique for exactly 3 Day, exactly 2 Subject, exactly 3 Purpose, exactly 3 Dated, exactly 6 Route, exactly 2 World
check FakeDateCollapsePreservesEffectiveCoordinateIdentity for exactly 3 Day, exactly 2 Subject, exactly 3 Purpose, exactly 3 Dated, exactly 6 Route, exactly 2 World

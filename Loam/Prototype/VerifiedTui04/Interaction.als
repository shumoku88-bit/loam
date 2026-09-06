module Loam/Prototype/VerifiedTui04/Interaction

abstract sig Surface {}
one sig Home, Actual, Scheduled, RecordDraft extends Surface {}

abstract sig Focus {}
one sig ActualFocus, ScheduledFocus extends Focus {}

abstract sig Event {}
one sig Left, Right, Up, Down, Tab, Enter, Record, Back, Quit, Other extends Event {}

sig State {
  surface: one Surface,
  day: one Int,
  focus: one Focus
}

pred valid[s: State] {
  s.day >= 1
  s.day <= 30
}

fun clampDay[day, delta: Int]: one Int {
  let candidate = add[day, delta] |
    (candidate < 1 or candidate > 30) => day else candidate
}

fun nextDay[s: State, e: Event]: one Int {
  (s.surface = Home and e = Left) => clampDay[s.day, -1]
  else (s.surface = Home and e = Right) => clampDay[s.day, 1]
  else (s.surface = Home and e = Up) => clampDay[s.day, -7]
  else (s.surface = Home and e = Down) => clampDay[s.day, 7]
  else s.day
}

fun nextFocus[s: State, e: Event]: one Focus {
  (s.surface = Home and e = Tab and s.focus = ActualFocus) => ScheduledFocus
  else (s.surface = Home and e = Tab and s.focus = ScheduledFocus) => ActualFocus
  else s.focus
}

fun nextSurface[s: State, e: Event]: one Surface {
  (e = Enter and s.surface = Home and s.focus = ActualFocus) => Actual
  else (e = Enter and s.surface = Home and s.focus = ScheduledFocus) => Scheduled
  else (e = Record and (s.surface = Home or s.surface = Scheduled)) => RecordDraft
  else (e = Back and s.surface != Home) => Home
  else s.surface
}

pred next[s, sNext: State, e: Event] {
  valid[s]
  sNext.day = nextDay[s, e]
  sNext.focus = nextFocus[s, e]
  sNext.surface = nextSurface[s, e]
}

pred sameStateShape[a, b: State] {
  a.day = b.day
  a.focus = b.focus
  a.surface = b.surface
}

assert SelectionBounds {
  all s, sNext: State, e: Event |
    next[s, sNext, e] implies valid[sNext]
}

assert FocusClosure {
  all s, sNext: State, e: Event |
    next[s, sNext, e] implies
      (sNext.focus = ActualFocus or sNext.focus = ScheduledFocus)
}

assert EventDeterminism {
  all s, a, b: State, e: Event |
    next[s, a, e] and next[s, b, e] implies sameStateShape[a, b]
}

assert MonthBoundaryCloses {
  all s, sNext: State |
    valid[s] and s.surface = Home and s.day = 1 and next[s, sNext, Left]
      implies sNext.day = 1

  all s, sNext: State |
    valid[s] and s.surface = Home and s.day = 30 and next[s, sNext, Right]
      implies sNext.day = 30
}

assert NonHomeArrowStable {
  all s, sNext: State, e: Left + Right + Up + Down |
    valid[s] and s.surface != Home and next[s, sNext, e]
      implies sameStateShape[s, sNext]
}

pred calendarMovementWitness {
  some s, sNext: State |
    s.surface = Home and
    s.day = 15 and
    s.focus = ActualFocus and
    next[s, sNext, Down] and
    sNext.day = 22 and
    sNext.focus = ActualFocus and
    sNext.surface = Home
}

pred tabThenOpenScheduledWitness {
  some s, tabbed, opened: State |
    s.surface = Home and
    s.focus = ActualFocus and
    valid[s] and
    next[s, tabbed, Tab] and
    next[tabbed, opened, Enter] and
    opened.surface = Scheduled
}

run calendarMovementWitness for exactly 3 State, 7 Int
run tabThenOpenScheduledWitness for exactly 3 State, 7 Int
check SelectionBounds for 4 State, 7 Int
check FocusClosure for 4 State, 7 Int
check EventDeterminism for 4 State, 7 Int
check MonthBoundaryCloses for 4 State, 7 Int
check NonHomeArrowStable for 4 State, 7 Int

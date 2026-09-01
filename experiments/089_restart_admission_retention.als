module experiments/observation_089_restart_admission_retention

sig Coordinate {}
one sig Transfer {}

sig Event {
  coordinate: one Coordinate,
  operation: one Transfer
}

sig World {
  events: set Event,
  zeroOriginAdmission: Coordinate -> lone Event
}

fact AdmissionReferencesRetainedFacts {
  all w: World |
    w.zeroOriginAdmission in Coordinate -> w.events

  all w: World, c: Coordinate, e: Event |
    c -> e in w.zeroOriginAdmission implies e.coordinate = c
}

fun enrolled[w: World]: set Coordinate {
  { c: Coordinate | some c.(w.zeroOriginAdmission) }
}

pred sameEventSnapshotDifferentAdmission {
  some disj left, right: World |
    left.events = right.events and
    left.zeroOriginAdmission != right.zeroOriginAdmission
}

pred sameMembershipSnapshotDifferentOrigin {
  some disj left, right: World |
    left.events = right.events and
    enrolled[left] = enrolled[right] and
    some enrolled[left] and
    left.zeroOriginAdmission != right.zeroOriginAdmission
}

assert EventSnapshotDeterminesAdmission {
  all disj left, right: World |
    left.events = right.events implies
      left.zeroOriginAdmission = right.zeroOriginAdmission
}

assert EventAndMembershipSnapshotDeterminesOrigin {
  all disj left, right: World |
    left.events = right.events and
    enrolled[left] = enrolled[right] implies
      left.zeroOriginAdmission = right.zeroOriginAdmission
}

assert AdmissionAlwaysReferencesRetainedEvent {
  all w: World, c: Coordinate, e: Event |
    c -> e in w.zeroOriginAdmission implies e in w.events
}

assert ExplicitAdmissionDeterminesRestartMeaning {
  all disj left, right: World |
    left.events = right.events and
    left.zeroOriginAdmission = right.zeroOriginAdmission implies
      enrolled[left] = enrolled[right]
}

run sameEventSnapshotDifferentAdmission
  for exactly 2 World, exactly 1 Coordinate, exactly 2 Event

run sameMembershipSnapshotDifferentOrigin
  for exactly 2 World, exactly 1 Coordinate, exactly 2 Event

check EventSnapshotDeterminesAdmission
  for exactly 2 World, exactly 1 Coordinate, exactly 2 Event

check EventAndMembershipSnapshotDeterminesOrigin
  for exactly 2 World, exactly 1 Coordinate, exactly 2 Event

check AdmissionAlwaysReferencesRetainedEvent
  for exactly 2 World, exactly 1 Coordinate, exactly 2 Event

check ExplicitAdmissionDeterminesRestartMeaning
  for exactly 2 World, exactly 1 Coordinate, exactly 2 Event

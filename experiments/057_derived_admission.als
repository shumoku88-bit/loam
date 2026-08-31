module experiments/observation_057_derived_admission

sig Event {}

sig Relation {
  refs: some Event
}

abstract sig Snapshot {
  events: set Event,
  raw: set Relation,
  storedAdmission: set Relation
}

one sig Before, After extends Snapshot {}

fun derivedAdmission[s: Snapshot]: set Relation {
  { r: s.raw | r.refs in s.events }
}

pred appendOnlyInputs {
  Before.events in After.events
  Before.raw in After.raw
}

pred initialStoredAdmissionFresh {
  Before.storedAdmission = derivedAdmission[Before]
}

pred noAdmissionRewrite {
  After.storedAdmission = Before.storedAdmission
}

pred existingRelationBecomesAdmissible {
  appendOnlyInputs
  Before.raw = After.raw
  some r: Before.raw |
    r not in derivedAdmission[Before] and
    r in derivedAdmission[After]
}

pred storedAdmissionCanLag {
  initialStoredAdmissionFresh
  noAdmissionRewrite
  existingRelationBecomesAdmissible
  some derivedAdmission[After] - After.storedAdmission
}

pred derivedViewCanRevealLateEndpoint {
  existingRelationBecomesAdmissible
  some r: Before.raw |
    r not in derivedAdmission[Before] and
    r in derivedAdmission[After]
}

assert DerivedAdmissionSubsetRaw {
  all s: Snapshot | derivedAdmission[s] in s.raw
}

assert DerivedAdmissionClosed {
  all s: Snapshot |
    all r: derivedAdmission[s] | r.refs in s.events
}

assert DerivedAdmissionMonotoneUnderAppendOnlyInputs {
  appendOnlyInputs implies
    derivedAdmission[Before] in derivedAdmission[After]
}

assert StoredAdmissionWithoutRewriteAlwaysTracksInputs {
  (initialStoredAdmissionFresh and
   noAdmissionRewrite and
   existingRelationBecomesAdmissible)
    implies After.storedAdmission = derivedAdmission[After]
}

assert FreshStoredAdmissionIsFunctionallyDetermined {
  all left, right: Snapshot |
    (left.events = right.events and
     left.raw = right.raw and
     left.storedAdmission = derivedAdmission[left] and
     right.storedAdmission = derivedAdmission[right])
      implies left.storedAdmission = right.storedAdmission
}

run storedAdmissionCanLag for exactly 2 Event, exactly 1 Relation, exactly 2 Snapshot
run derivedViewCanRevealLateEndpoint for exactly 2 Event, exactly 1 Relation, exactly 2 Snapshot
check DerivedAdmissionSubsetRaw for exactly 2 Event, exactly 1 Relation, exactly 2 Snapshot
check DerivedAdmissionClosed for exactly 2 Event, exactly 1 Relation, exactly 2 Snapshot
check DerivedAdmissionMonotoneUnderAppendOnlyInputs for exactly 2 Event, exactly 1 Relation, exactly 2 Snapshot
check StoredAdmissionWithoutRewriteAlwaysTracksInputs for exactly 2 Event, exactly 1 Relation, exactly 2 Snapshot
check FreshStoredAdmissionIsFunctionallyDetermined for exactly 2 Event, exactly 1 Relation, exactly 2 Snapshot

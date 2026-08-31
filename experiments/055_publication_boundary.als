module experiments/observation_055_publication_boundary

sig Event {}

sig Correction {
  target: one Event,
  replacement: one Event
}

sig Resolution {
  parents: some Event,
  replacement: one Event
}

abstract sig Snapshot {
  events: set Event,
  corrections: set Correction,
  resolutions: set Resolution
}

one sig Old, Mid, New extends Snapshot {}

pred closed[s: Snapshot] {
  all c: s.corrections | {
    c.target in s.events
    c.replacement in s.events
  }
  all r: s.resolutions | {
    r.parents in s.events
    r.replacement in s.events
  }
}

pred appendUpdate {
  Old.events in New.events
  Old.corrections in New.corrections
  Old.resolutions in New.resolutions
  closed[Old]
  closed[New]
}

pred bundleMid {
  (Mid.events = Old.events and
   Mid.corrections = Old.corrections and
   Mid.resolutions = Old.resolutions)
  or
  (Mid.events = New.events and
   Mid.corrections = New.corrections and
   Mid.resolutions = New.resolutions)
}

pred independentMid {
  Mid.events = Old.events or Mid.events = New.events
  Mid.corrections = Old.corrections or Mid.corrections = New.corrections
  Mid.resolutions = Old.resolutions or Mid.resolutions = New.resolutions
}

pred eventsBeforeRelations {
  (Mid.corrections = New.corrections or Mid.resolutions = New.resolutions)
    implies Mid.events = New.events
}

fun admittedCorrections[s: Snapshot]: set Correction {
  { c: s.corrections |
      c.target in s.events and
      c.replacement in s.events }
}

fun admittedResolutions[s: Snapshot]: set Resolution {
  { r: s.resolutions |
      r.parents in s.events and
      r.replacement in s.events }
}

pred admittedClosed[s: Snapshot] {
  all c: admittedCorrections[s] | {
    c.target in s.events
    c.replacement in s.events
  }
  all r: admittedResolutions[s] | {
    r.parents in s.events
    r.replacement in s.events
  }
}

pred correctionPublicationCanTear {
  appendUpdate
  independentMid
  some c: New.corrections - Old.corrections |
    c.replacement in New.events - Old.events
  Mid.events = Old.events
  Mid.corrections = New.corrections
  Mid.resolutions = Old.resolutions
  not closed[Mid]
}

pred resolutionPublicationCanTear {
  appendUpdate
  independentMid
  some r: New.resolutions - Old.resolutions |
    some ((r.parents + r.replacement) & (New.events - Old.events))
  Mid.events = Old.events
  Mid.corrections = Old.corrections
  Mid.resolutions = New.resolutions
  not closed[Mid]
}

pred dependencyOrderedPublicationExists {
  appendUpdate
  independentMid
  eventsBeforeRelations
  some New.corrections - Old.corrections
  Mid.events = New.events
  Mid.corrections = New.corrections
  Mid.resolutions = Old.resolutions
  closed[Mid]
}

pred failClosedCanHideTornRelation {
  appendUpdate
  independentMid
  not closed[Mid]
  some Mid.corrections - admittedCorrections[Mid]
  admittedClosed[Mid]
}

assert AtomicBundlePreservesClosure {
  (appendUpdate and bundleMid) implies closed[Mid]
}

assert IndependentPublicationAlwaysPreservesClosure {
  (appendUpdate and independentMid) implies closed[Mid]
}

assert EventsBeforeRelationsPreservesClosure {
  (appendUpdate and independentMid and eventsBeforeRelations) implies closed[Mid]
}

assert FailClosedAdmissionPreservesClosure {
  all s: Snapshot | admittedClosed[s]
}

assert FinalClosedSnapshotAdmitsAllRelations {
  appendUpdate implies {
    admittedCorrections[New] = New.corrections
    admittedResolutions[New] = New.resolutions
  }
}

run correctionPublicationCanTear for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot
run resolutionPublicationCanTear for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot
run dependencyOrderedPublicationExists for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot
run failClosedCanHideTornRelation for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot
check AtomicBundlePreservesClosure for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot
check IndependentPublicationAlwaysPreservesClosure for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot
check EventsBeforeRelationsPreservesClosure for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot
check FailClosedAdmissionPreservesClosure for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot
check FinalClosedSnapshotAdmitsAllRelations for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 3 Snapshot

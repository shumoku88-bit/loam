module experiments/normalized_actual_cutover

sig Event {}
sig SemanticFact {}
sig ScheduledId {}

sig OldActual {
  events: set Event,
  facts: set SemanticFact
}

sig NewActual {
  events: set Event,
  facts: set SemanticFact
}

sig ScheduledGeneration {
  completions: ScheduledId -> lone Event
}

// The one-time migration projects exactly one frozen old checkpoint into one
// normalized candidate. This relation belongs to the migrator, not either runtime.
one sig Cutover {
  source: one OldActual,
  candidate: one NewActual,
  scheduled: one ScheduledGeneration
}

pred validatedProjection {
  Cutover.candidate.events = Cutover.source.events
  Cutover.candidate.facts = Cutover.source.facts
}

fact CandidateIsValidated {
  validatedProjection
}

abstract sig Runtime {}
one sig OldRuntime, NewRuntime extends Runtime {}

abstract sig WriterKind {}
one sig ActualWriter, ScheduledWriter extends WriterKind {}

abstract sig Phase {}
one sig ServingOld,
        OfflineOld,
        OfflinePrepared,
        OfflineNew,
        ServingNewRetained,
        ServingNewRetired extends Phase {}

sig State {
  phase: one Phase,
  runtime: lone Runtime,
  oldPresent: lone OldActual,
  newSelected: lone NewActual,
  activeWriters: set WriterKind
}

fact StateShape {
  all s: State | {
    s.phase = ServingOld implies {
      s.runtime = OldRuntime
      s.oldPresent = Cutover.source
      no s.newSelected
      s.activeWriters = WriterKind
    }

    s.phase in OfflineOld + OfflinePrepared implies {
      no s.runtime
      s.oldPresent = Cutover.source
      no s.newSelected
      no s.activeWriters
    }

    s.phase = OfflineNew implies {
      no s.runtime
      s.oldPresent = Cutover.source
      s.newSelected = Cutover.candidate
      no s.activeWriters
    }

    s.phase = ServingNewRetained implies {
      s.runtime = NewRuntime
      s.oldPresent = Cutover.source
      s.newSelected = Cutover.candidate
      s.activeWriters = WriterKind
    }

    s.phase = ServingNewRetired implies {
      s.runtime = NewRuntime
      no s.oldPresent
      s.newSelected = Cutover.candidate
      s.activeWriters = WriterKind
    }
  }
}

fun allowedPhaseSteps: Phase -> Phase {
    ServingOld->OfflineOld
  + OfflineOld->OfflinePrepared
  + OfflinePrepared->OfflineNew
  + OfflineNew->ServingNewRetained
  + ServingNewRetained->ServingNewRetired
  // Before the new selector is committed, abort can simply restart Old.
  + OfflineOld->ServingOld
  + OfflinePrepared->ServingOld
}

pred step[from, to: State] {
  from.phase->to.phase in allowedPhaseSteps
}

fun visibleScheduled[events: set Event]: ScheduledId -> Event {
  Cutover.scheduled.completions & (ScheduledId -> events)
}

// Positive witness: a complete quiesced cutover exists with Old serving first,
// no runtime while conversion/selection occurs, then New-only serving and old
// bytes retired.
pred quiescedCutoverWitness {
  some disj s0, s1, s2, s3, s4, s5: State | {
    s0.phase = ServingOld
    s1.phase = OfflineOld
    s2.phase = OfflinePrepared
    s3.phase = OfflineNew
    s4.phase = ServingNewRetained
    s5.phase = ServingNewRetired
    step[s0, s1]
    step[s1, s2]
    step[s2, s3]
    step[s3, s4]
    step[s4, s5]
  }
}

// Without quiescing/guarding the old source, a writer can advance the old world
// after the candidate was projected. Selecting that stale candidate would lose
// an admitted semantic fact. This witness is intentionally SAT.
pred unguardedOldWriterRace {
  some advanced: OldActual - Cutover.source | {
    advanced.events = Cutover.source.events
    advanced.facts != Cutover.source.facts
    Cutover.candidate.facts != advanced.facts
  }
}

pred abortBeforeSelectionWitness {
  some prepared, restarted: State | {
    prepared.phase = OfflinePrepared
    restarted.phase = ServingOld
    step[prepared, restarted]
  }
}

pred forwardRecoveryAfterSelectionWitness {
  some selected, restarted: State | {
    selected.phase = OfflineNew
    restarted.phase = ServingNewRetained
    step[selected, restarted]
  }
}

pred scheduledLinkWitness {
  some Cutover.scheduled.completions
  some visibleScheduled[Cutover.source.events]
}

assert OfflineCutoverHasNoActiveWriters {
  all s: State |
    s.phase in OfflineOld + OfflinePrepared + OfflineNew implies
      no s.activeWriters
}

assert ServingStatesNeverNeedDualRuntime {
  all s: State | {
    s.phase = ServingOld implies s.runtime = OldRuntime and no s.newSelected
    s.phase in ServingNewRetained + ServingNewRetired implies
      s.runtime = NewRuntime and s.newSelected = Cutover.candidate
  }
}

assert ValidatedNewPreservesActualObservation {
  Cutover.candidate.events = Cutover.source.events
  Cutover.candidate.facts = Cutover.source.facts
}

assert ValidatedNewPreservesScheduledVisibility {
  visibleScheduled[Cutover.candidate.events] =
    visibleScheduled[Cutover.source.events]
}

assert SelectionCannotRecoverByServingOld {
  all from, to: State |
    from.phase = OfflineNew and step[from, to] implies
      to.phase = ServingNewRetained
}

assert RetiringOldDoesNotChangeSelectedNew {
  all retained, retired: State |
    retained.phase = ServingNewRetained and
    retired.phase = ServingNewRetired and
    step[retained, retired] implies {
      retained.newSelected = retired.newSelected
      retained.runtime = retired.runtime
    }
}

run quiescedCutoverWitness for 8 but exactly 1 Event, exactly 2 SemanticFact, exactly 1 OldActual, exactly 1 NewActual, exactly 1 ScheduledGeneration, exactly 1 ScheduledId, exactly 6 State
run unguardedOldWriterRace for 6 but exactly 1 Event, exactly 2 SemanticFact, exactly 2 OldActual, exactly 1 NewActual, exactly 1 ScheduledGeneration, exactly 0 ScheduledId, exactly 0 State
run abortBeforeSelectionWitness for 6 but exactly 1 Event, exactly 1 SemanticFact, exactly 1 OldActual, exactly 1 NewActual, exactly 1 ScheduledGeneration, exactly 0 ScheduledId, exactly 2 State
run forwardRecoveryAfterSelectionWitness for 6 but exactly 1 Event, exactly 1 SemanticFact, exactly 1 OldActual, exactly 1 NewActual, exactly 1 ScheduledGeneration, exactly 0 ScheduledId, exactly 2 State
run scheduledLinkWitness for 6 but exactly 1 Event, exactly 1 SemanticFact, exactly 1 OldActual, exactly 1 NewActual, exactly 1 ScheduledGeneration, exactly 1 ScheduledId, exactly 0 State

check OfflineCutoverHasNoActiveWriters for 8
check ServingStatesNeverNeedDualRuntime for 8
check ValidatedNewPreservesActualObservation for 8
check ValidatedNewPreservesScheduledVisibility for 8
check SelectionCannotRecoverByServingOld for 8
check RetiringOldDoesNotChangeSelectedNew for 8

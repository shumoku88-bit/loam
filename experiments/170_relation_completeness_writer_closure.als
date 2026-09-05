module relation_completeness_writer_closure

abstract sig Meaning {}
one sig NoEdge, HasEdge extends Meaning {}

abstract sig Region {}
one sig Legacy, Covered extends Region {}

abstract sig SourcePath {}
one sig MovementSource, ScheduledSource, CorrectionSource,
        LowLevelSource, HistoricalSource extends SourcePath {}

abstract sig CoverageGate {}
one sig MovementGate, ScheduledGate, CorrectionGate,
        DateCorrectionGate, HistoricalGate extends CoverageGate {}

sig Event {}

sig World {
  present: set Event,
  validRegion: Event -> lone Region,
  meaning: Event -> lone Meaning,
  positive: set Event,
  source: Event -> lone SourcePath,
  coverageGate: Event -> lone CoverageGate,
  qualified: set CoverageGate,
  correctionTarget: Event -> lone Event
}

fact WellFormedWorlds {
  all w: World {
    all e: w.present | one w.source[e]
    all e: Event - w.present | {
      no w.source[e]
      no w.validRegion[e]
      no w.meaning[e]
      no w.coverageGate[e]
      no w.correctionTarget[e]
      e not in w.positive
    }

    all e: w.present | {
      (one w.validRegion[e]) iff (one w.coverageGate[e])
      (one w.validRegion[e]) iff (one w.meaning[e])
    }

    w.positive in {e: w.present | one w.validRegion[e]}
    all e: w.positive | w.meaning[e] = HasEdge

    all replacement: w.present |
      some w.correctionTarget[replacement] implies {
        w.source[replacement] = CorrectionSource
        w.correctionTarget[replacement] in w.present
        replacement != w.correctionTarget[replacement]
      }

    -- A qualified gate is relation-complete for covered valid-time.
    -- It emits a positive fact exactly when the retained meaning is an edge.
    all e: w.present |
      w.validRegion[e] = Covered and w.coverageGate[e] in w.qualified implies
        ((e in w.positive) iff (w.meaning[e] = HasEdge))
  }
}

pred projectedNone[w: World, e: Event] {
  e in w.present
  w.validRegion[e] = Covered
  e not in w.positive
}

pred blindMovementBreaksCutover {
  some w: World, e: Event | {
    e in w.present
    w.source[e] = MovementSource
    w.validRegion[e] = Covered
    w.coverageGate[e] = MovementGate
    MovementGate not in w.qualified
    w.meaning[e] = HasEdge
    e not in w.positive
    projectedNone[w, e]
  }
}

pred blindScheduledCompletionBreaksCutover {
  some w: World, e: Event | {
    e in w.present
    w.source[e] = ScheduledSource
    w.validRegion[e] = Covered
    w.coverageGate[e] = ScheduledGate
    ScheduledGate not in w.qualified
    w.meaning[e] = HasEdge
    e not in w.positive
    projectedNone[w, e]
  }
}

pred correctionReplacementNeedsOwnQualification {
  some w: World, target, replacement: Event | {
    target != replacement
    target + replacement in w.present

    w.source[target] = MovementSource
    w.validRegion[target] = Covered
    w.coverageGate[target] = MovementGate
    MovementGate in w.qualified
    w.meaning[target] = HasEdge
    target in w.positive

    w.source[replacement] = CorrectionSource
    w.correctionTarget[replacement] = target
    w.validRegion[replacement] = Covered
    w.coverageGate[replacement] = CorrectionGate
    CorrectionGate not in w.qualified
    w.meaning[replacement] = HasEdge
    replacement not in w.positive
    projectedNone[w, replacement]
  }
}

pred lowLevelThenDateCorrectionCanCrossCutover {
  some w: World, e: Event | {
    e in w.present
    w.source[e] = LowLevelSource
    w.validRegion[e] = Covered
    w.coverageGate[e] = DateCorrectionGate
    DateCorrectionGate not in w.qualified
    w.meaning[e] = HasEdge
    e not in w.positive
    projectedNone[w, e]
  }
}

pred dateCorrectionQualificationIsIndependentOfSource {
  some w: World, movementEvent, lowLevelEvent: Event | {
    movementEvent != lowLevelEvent
    movementEvent + lowLevelEvent in w.present

    w.source[movementEvent] = MovementSource
    w.source[lowLevelEvent] = LowLevelSource
    w.validRegion[movementEvent] = Covered
    w.validRegion[lowLevelEvent] = Covered
    w.coverageGate[movementEvent] = DateCorrectionGate
    w.coverageGate[lowLevelEvent] = DateCorrectionGate
    DateCorrectionGate in w.qualified
    no (movementEvent + lowLevelEvent) & w.positive
    w.meaning[movementEvent] = NoEdge
    w.meaning[lowLevelEvent] = NoEdge
  }
}

pred historicalPublisherCanRemainOutsideCoveredRegion {
  some w: World, e: Event | {
    e in w.present
    w.source[e] = HistoricalSource
    w.validRegion[e] = Legacy
    w.coverageGate[e] = HistoricalGate
    HistoricalGate not in w.qualified
    w.meaning[e] = HasEdge
    e not in w.positive
  }
}

pred historicalPublisherWouldNeedQualificationIfCovered {
  some w: World, e: Event | {
    e in w.present
    w.source[e] = HistoricalSource
    w.validRegion[e] = Covered
    w.coverageGate[e] = HistoricalGate
    HistoricalGate not in w.qualified
    w.meaning[e] = HasEdge
    e not in w.positive
    projectedNone[w, e]
  }
}

assert QualifiedCoveredAbsenceMeansNoEdge {
  all w: World, e: Event |
    e in w.present and
    w.validRegion[e] = Covered and
    w.coverageGate[e] in w.qualified and
    e not in w.positive implies
      w.meaning[e] = NoEdge
}

assert ClosedCoveredFrontierIsSound {
  all w: World |
    (all e: w.present |
      w.validRegion[e] = Covered implies w.coverageGate[e] in w.qualified)
    implies
    (all e: w.present |
      projectedNone[w, e] implies w.meaning[e] = NoEdge)
}

assert LegacyAbsenceMeansNoEdge {
  all w: World, e: Event |
    e in w.present and
    w.validRegion[e] = Legacy and
    e not in w.positive implies
      w.meaning[e] = NoEdge
}

run blindMovementBreaksCutover for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 3 Event, 2 World
run blindScheduledCompletionBreaksCutover for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 3 Event, 2 World
run correctionReplacementNeedsOwnQualification for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 4 Event, 2 World
run lowLevelThenDateCorrectionCanCrossCutover for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 3 Event, 2 World
run dateCorrectionQualificationIsIndependentOfSource for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 4 Event, 2 World
run historicalPublisherCanRemainOutsideCoveredRegion for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 3 Event, 2 World
run historicalPublisherWouldNeedQualificationIfCovered for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 3 Event, 2 World

check QualifiedCoveredAbsenceMeansNoEdge for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 5 Event, 3 World
check ClosedCoveredFrontierIsSound for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 5 Event, 3 World
check LegacyAbsenceMeansNoEdge for 8 but exactly 5 SourcePath, exactly 5 CoverageGate, 5 Event, 3 World

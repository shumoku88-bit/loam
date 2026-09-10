module experiments/observation_242_current_read_answer_basis

-- Observation 242: current read answer basis
--
-- Reconstruct the current product from answers first.  This model deliberately
-- contains no file, sidecar, manifest, codec, or module concept.  It records the
-- production dependency graph between retained household information, caller /
-- replaceable-query inputs, intermediate answers, and user-visible read answers.
--
-- This is a structural provenance model, not yet a behavioral proof that every
-- listed retained family is semantically indispensable.  Later observations can
-- challenge one retained family at a time with two-world counterexamples.

abstract sig Node {
  requires: set Node
}

abstract sig Retained extends Node {}
abstract sig QueryInput extends Node {}
abstract sig Answer extends Node {}
abstract sig Observable extends Answer {}
abstract sig Intermediate extends Answer {}

-- Retained household information currently used by read semantics.
one sig EventFact,
        ActualValidity,
        EventDescription,
        EventCorrection,
        ZeroOriginCoverage,
        CapacityMovement,
        CapacityEffective,
        ActualRouting,
        LocusAdmission,
        AccountingRole,
        ScheduledOccurrence,
        ScheduledCompletion,
        ScheduledRetirement,
        ScheduledReplacement,
        ScheduledRouting,
        AttentionItem,
        AttentionClosure extends Retained {}

-- Retained families selected by current authority machinery but not required by
-- the read-answer graph below.  They remain candidates for Q_write / safety.
one sig ActualReversal,
        RelationUnit,
        RelationDischarge extends Retained {}

-- Inputs that select or condition an answer but are not historical household
-- facts.  Their physical source may be config, the caller, or the environment.
one sig BalanceSelection,
        WindowCoordinate,
        ObservationDate,
        CompletenessAssumption,
        CycleFundingSelection,
        CurrentWindowSelection,
        AttentionSourceAvailability extends QueryInput {}

-- Shared intermediate answers already present in current production composition.
one sig EffectiveEntitlement,
        ActualConsumption,
        ScheduledCommitment,
        CycleFundingSummary extends Intermediate {}

-- Current user-visible / administration read answers represented in production.
one sig ActualRecords,
        ScheduledOpen,
        ScheduledDay,
        Balance,
        CapacityAllHistory,
        CurrentCoverage,
        ActualRoutingAdministration,
        StockFlow,
        TransactionsFlow,
        ConditionalBalancePath,
        CycleBudget,
        AttentionOpen extends Observable {}

fact LeavesHaveNoDependencies {
  no (Retained + QueryInput).requires
}

fact CurrentProductionReadDependencies {
  -- ActualReview: Event + correction frontier + date + description.
  ActualRecords.requires =
    EventFact + ActualValidity + EventDescription + EventCorrection

  -- ScheduledReview current-open and date-specific evidence use the four
  -- lifecycle facets plus Event identity closure.
  ScheduledOpen.requires =
    ScheduledOccurrence + ScheduledCompletion + ScheduledRetirement +
    ScheduledReplacement + EventFact
  ScheduledDay.requires =
    ScheduledOccurrence + ScheduledCompletion + ScheduledRetirement +
    ScheduledReplacement + EventFact + ObservationDate

  -- BalanceReview: current quantity is not admitted from arithmetic alone.
  Balance.requires =
    EventFact + EventCorrection + ZeroOriginCoverage + BalanceSelection

  -- CapacityReview's all-history view does not use effective coordinates.
  CapacityAllHistory.requires = CapacityMovement

  -- CurrentCoverageInspection factors through exactly these three computed
  -- quantities / frontiers. Remaining and Headroom are arithmetic results of
  -- these answers, not retained inputs.
  EffectiveEntitlement.requires =
    CapacityMovement + CapacityEffective + WindowCoordinate
  ActualConsumption.requires =
    EventFact + EventCorrection + ActualValidity + ActualRouting + WindowCoordinate
  ScheduledCommitment.requires =
    ScheduledOccurrence + ScheduledCompletion + ScheduledRetirement +
    ScheduledReplacement + EventFact + AccountingRole + ScheduledRouting +
    WindowCoordinate
  CurrentCoverage.requires =
    EffectiveEntitlement + ActualConsumption + ScheduledCommitment +
    WindowCoordinate + ObservationDate

  -- Current Actual-routing administration additionally asks which admitted
  -- Loci are explicit Expenses and which Purpose candidates currently exist.
  ActualRoutingAdministration.requires =
    LocusAdmission + AccountingRole + ActualRouting + CapacityMovement +
    ObservationDate

  -- Higher reports compose existing review answers instead of retaining report
  -- state or introducing a second Event world.
  StockFlow.requires = Balance + ActualRecords + WindowCoordinate
  TransactionsFlow.requires = ActualRecords + WindowCoordinate
  ConditionalBalancePath.requires =
    Balance + ScheduledOpen + ObservationDate + CompletenessAssumption

  CycleFundingSummary.requires =
    Balance + CurrentCoverage + CycleFundingSelection
  CycleBudget.requires =
    Balance + CurrentCoverage + CycleFundingSummary + CurrentWindowSelection +
    ObservationDate

  -- Attention availability is explicitly separate from lifecycle meaning.
  AttentionOpen.requires =
    AttentionItem + AttentionClosure + AttentionSourceAvailability
}

fact DependencyGraphIsAcyclic {
  no iden & ^requires
}

fun retainedBase[a: Answer] : set Retained {
  a.^requires & Retained
}

fun queryBase[a: Answer] : set QueryInput {
  a.^requires & QueryInput
}

fun readVocabulary : set Observable {
  ActualRecords + ScheduledOpen + ScheduledDay + Balance + CapacityAllHistory +
  CurrentCoverage + ActualRoutingAdministration + StockFlow + TransactionsFlow +
  ConditionalBalancePath + CycleBudget + AttentionOpen
}

fun allReadRetained : set Retained {
  readVocabulary.^requires & Retained
}

pred showCurrentReadGraph {
  some readVocabulary
  some allReadRetained
}

-- The CurrentCoverage retained basis follows from its three production
-- components. Remaining and Headroom add no new retained information.
assert CurrentCoverageBaseMatchesProductionComposition {
  retainedBase[CurrentCoverage] =
    CapacityMovement + CapacityEffective +
    EventFact + EventCorrection + ActualValidity + ActualRouting +
    ScheduledOccurrence + ScheduledCompletion + ScheduledRetirement +
    ScheduledReplacement + AccountingRole + ScheduledRouting
}

assert StockFlowAddsNoRetainedFamilyBeyondItsInputs {
  retainedBase[StockFlow] = retainedBase[Balance] + retainedBase[ActualRecords]
}

assert TransactionsFlowAddsNoRetainedFamilyBeyondActualReview {
  retainedBase[TransactionsFlow] = retainedBase[ActualRecords]
}

assert ConditionalPathAddsNoRetainedFamilyBeyondBalanceAndScheduled {
  retainedBase[ConditionalBalancePath] =
    retainedBase[Balance] + retainedBase[ScheduledOpen]
}

-- These selected families may still be required by mutation admission,
-- publication, integrity, or recovery.  The narrower result here is only that
-- the reconstructed current READ answer graph does not consume them.
assert MutationOnlyCandidatesAreAbsentFromReadBasis {
  no (ActualReversal + RelationUnit + RelationDischarge) & allReadRetained
}

-- Relative to the declared production dependency graph, its union is
-- inclusion-minimal: removing one member necessarily leaves at least one read
-- answer without one of its declared retained prerequisites.  This is not yet a
-- semantic indispensability proof; the prerequisites themselves are challenged
-- in later two-world models.
assert DeclaredReadBasisIsInclusionMinimal {
  no basis: set Retained |
    basis in allReadRetained and
    basis != allReadRetained and
    all answer: readVocabulary | retainedBase[answer] in basis
}

run showCurrentReadGraph for 40 but exactly 1 EventFact, exactly 1 ActualValidity,
  exactly 1 EventDescription, exactly 1 EventCorrection, exactly 1 ZeroOriginCoverage,
  exactly 1 CapacityMovement, exactly 1 CapacityEffective, exactly 1 ActualRouting,
  exactly 1 LocusAdmission, exactly 1 AccountingRole, exactly 1 ScheduledOccurrence,
  exactly 1 ScheduledCompletion, exactly 1 ScheduledRetirement, exactly 1 ScheduledReplacement,
  exactly 1 ScheduledRouting, exactly 1 AttentionItem, exactly 1 AttentionClosure,
  exactly 1 ActualReversal, exactly 1 RelationUnit, exactly 1 RelationDischarge
check CurrentCoverageBaseMatchesProductionComposition for 40
check StockFlowAddsNoRetainedFamilyBeyondItsInputs for 40
check TransactionsFlowAddsNoRetainedFamilyBeyondActualReview for 40
check ConditionalPathAddsNoRetainedFamilyBeyondBalanceAndScheduled for 40
check MutationOnlyCandidatesAreAbsentFromReadBasis for 40
check DeclaredReadBasisIsInclusionMinimal for 40

module experiments/observation_242_current_read_answer_basis

-- Observation 242: current read answer basis
--
-- Reconstruct the current product from answers first. This model deliberately
-- contains no file, sidecar, manifest, codec, or module concept. It records the
-- production dependency graph between retained household information, caller /
-- replaceable-query inputs, intermediate answers, and user-visible read answers.
--
-- The second half revisits the older household-minimum-vocabulary checkpoint:
-- current detailed retained names are factored into a small number of semantic
-- regions plus reusable evidence mechanics. This is a candidate decomposition,
-- not yet a proof that every current type can be physically or nominally merged.

abstract sig Node {
  requires: set Node
}

abstract sig SemanticRegion {}
one sig ActualRegion,
        ScheduledRegion,
        CapacityRegion,
        AttentionRegion,
        OrthogonalRegion extends SemanticRegion {}

abstract sig Mechanic {}
one sig QuantityEffectMechanic,
        TemporalMechanic,
        ContextMechanic,
        LifecycleMechanic,
        RoutingMechanic,
        ClassificationMechanic,
        CompletenessMechanic,
        AdmissionMechanic,
        DueMechanic,
        RelationQuantityMechanic extends Mechanic {}

abstract sig Retained extends Node {
  region: one SemanticRegion,
  mechanics: some Mechanic
}
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
-- the read-answer graph below. They remain candidates for Q_write / Q_safe.
one sig ActualReversal,
        RelationUnit,
        RelationDischarge extends Retained {}

-- Inputs that select or condition an answer but are not historical household
-- facts. Their physical source may be config, the caller, or the environment.
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
-- AccountingUnavailable and LiquidityUnknown are deliberate evidence-limit
-- answers: current production exposes them without pretending it has canonical
-- information sufficient for a stronger report.
one sig ActualRecords,
        ScheduledOpen,
        ScheduledDay,
        Balance,
        CapacityAllHistory,
        BudgetWindow,
        CurrentCoverage,
        ActualRoutingAdministration,
        StockFlow,
        TransactionsFlow,
        ConditionalBalancePath,
        CycleBudget,
        AttentionOpen,
        AccountingUnavailable,
        LiquidityUnknown extends Observable {}

fact LeavesHaveNoDependencies {
  no (Retained + QueryInput).requires
}

-- Candidate factorization of current detailed names. Four household semantic
-- regions remain visible; cross-cutting evidence such as completeness,
-- classification and admission is deliberately orthogonal rather than promoted
-- into a fifth household occurrence kind.
fact CurrentRetainedFactorization {
  EventFact.region = ActualRegion
  EventFact.mechanics = QuantityEffectMechanic
  ActualValidity.region = ActualRegion
  ActualValidity.mechanics = TemporalMechanic
  EventDescription.region = ActualRegion
  EventDescription.mechanics = ContextMechanic
  EventCorrection.region = ActualRegion
  EventCorrection.mechanics = LifecycleMechanic
  ActualRouting.region = ActualRegion
  ActualRouting.mechanics = RoutingMechanic + TemporalMechanic
  ActualReversal.region = ActualRegion
  ActualReversal.mechanics = LifecycleMechanic

  ScheduledOccurrence.region = ScheduledRegion
  ScheduledOccurrence.mechanics = QuantityEffectMechanic + TemporalMechanic
  ScheduledCompletion.region = ScheduledRegion
  ScheduledCompletion.mechanics = LifecycleMechanic
  ScheduledRetirement.region = ScheduledRegion
  ScheduledRetirement.mechanics = LifecycleMechanic
  ScheduledReplacement.region = ScheduledRegion
  ScheduledReplacement.mechanics = LifecycleMechanic
  ScheduledRouting.region = ScheduledRegion
  ScheduledRouting.mechanics = RoutingMechanic + TemporalMechanic

  CapacityMovement.region = CapacityRegion
  CapacityMovement.mechanics = QuantityEffectMechanic
  CapacityEffective.region = CapacityRegion
  CapacityEffective.mechanics = TemporalMechanic

  AttentionItem.region = AttentionRegion
  AttentionItem.mechanics = ContextMechanic + DueMechanic
  AttentionClosure.region = AttentionRegion
  AttentionClosure.mechanics = LifecycleMechanic

  ZeroOriginCoverage.region = OrthogonalRegion
  ZeroOriginCoverage.mechanics = CompletenessMechanic
  LocusAdmission.region = OrthogonalRegion
  LocusAdmission.mechanics = AdmissionMechanic
  AccountingRole.region = OrthogonalRegion
  AccountingRole.mechanics = ClassificationMechanic
  RelationUnit.region = OrthogonalRegion
  RelationUnit.mechanics = RelationQuantityMechanic
  RelationDischarge.region = OrthogonalRegion
  RelationDischarge.mechanics = RelationQuantityMechanic + LifecycleMechanic
}

fact CurrentProductionReadDependencies {
  ActualRecords.requires =
    EventFact + ActualValidity + EventDescription + EventCorrection

  ScheduledOpen.requires =
    ScheduledOccurrence + ScheduledCompletion + ScheduledRetirement +
    ScheduledReplacement + EventFact
  ScheduledDay.requires =
    ScheduledOccurrence + ScheduledCompletion + ScheduledRetirement +
    ScheduledReplacement + EventFact + ObservationDate

  Balance.requires =
    EventFact + EventCorrection + ZeroOriginCoverage + BalanceSelection

  CapacityAllHistory.requires = CapacityMovement

  BudgetWindow.requires =
    CapacityMovement + CapacityEffective + EventFact + EventCorrection +
    ActualValidity + ActualRouting + WindowCoordinate

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

  ActualRoutingAdministration.requires =
    LocusAdmission + AccountingRole + ActualRouting + CapacityMovement +
    ObservationDate

  StockFlow.requires = Balance + ActualRecords + WindowCoordinate
  TransactionsFlow.requires = ActualRecords + WindowCoordinate
  ConditionalBalancePath.requires =
    Balance + ScheduledOpen + ObservationDate + CompletenessAssumption

  CycleFundingSummary.requires =
    Balance + CurrentCoverage + CycleFundingSelection
  CycleBudget.requires =
    Balance + CurrentCoverage + CycleFundingSummary + CurrentWindowSelection +
    ObservationDate

  AttentionOpen.requires =
    AttentionItem + AttentionClosure + AttentionSourceAvailability

  no AccountingUnavailable.requires
  no LiquidityUnknown.requires
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
  BudgetWindow + CurrentCoverage + ActualRoutingAdministration + StockFlow +
  TransactionsFlow + ConditionalBalancePath + CycleBudget + AttentionOpen +
  AccountingUnavailable + LiquidityUnknown
}

fun allReadRetained : set Retained {
  readVocabulary.^requires & Retained
}

fun primaryReadRetained : set Retained {
  { r: allReadRetained | r.region != OrthogonalRegion }
}

pred showCurrentReadGraph {
  some readVocabulary
  some allReadRetained
}

-- Current read-side domain subjects still occupy only the four historical
-- household semantic regions. Cross-cutting policy/evidence remains Orthogonal.
assert ReadSubjectsFitFourHouseholdRegions {
  all r: primaryReadRetained |
    r.region in ActualRegion + ScheduledRegion + CapacityRegion + AttentionRegion
}

-- Reusing the same mechanics must not erase semantic authority. Current LOAM has
-- concrete examples where identical implementation shapes serve different
-- household meanings.
pred quantityMechanicSpansSemanticRegions {
  some disj left, right: allReadRetained |
    QuantityEffectMechanic in left.mechanics and
    QuantityEffectMechanic in right.mechanics and
    left.region != right.region
}

pred temporalMechanicSpansSemanticRegions {
  some disj left, right: allReadRetained |
    TemporalMechanic in left.mechanics and
    TemporalMechanic in right.mechanics and
    left.region != right.region
}

pred lifecycleMechanicSpansSemanticRegions {
  some disj left, right: allReadRetained |
    LifecycleMechanic in left.mechanics and
    LifecycleMechanic in right.mechanics and
    left.region != right.region
}

-- Deliberately too strong: a mechanic is implementation structure, not semantic
-- authority. A counterexample is expected whenever one mechanic crosses regions.
assert MechanicsDetermineSemanticRegion {
  all left, right: allReadRetained |
    left.mechanics = right.mechanics implies left.region = right.region
}

assert CurrentCoverageBaseMatchesProductionComposition {
  retainedBase[CurrentCoverage] =
    CapacityMovement + CapacityEffective +
    EventFact + EventCorrection + ActualValidity + ActualRouting +
    ScheduledOccurrence + ScheduledCompletion + ScheduledRetirement +
    ScheduledReplacement + AccountingRole + ScheduledRouting
}

assert BudgetWindowBaseMatchesProductionComposition {
  retainedBase[BudgetWindow] =
    CapacityMovement + CapacityEffective + EventFact + EventCorrection +
    ActualValidity + ActualRouting
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

assert EvidenceLimitReportsAddNoRetainedBasis {
  no retainedBase[AccountingUnavailable]
  no retainedBase[LiquidityUnknown]
}

assert MutationOnlyCandidatesAreAbsentFromReadBasis {
  no (ActualReversal + RelationUnit + RelationDischarge) & allReadRetained
}

-- Relative to the declared production dependency graph, its union is
-- inclusion-minimal. This is not yet semantic indispensability: later
-- two-world models challenge whether each declared prerequisite can itself be
-- reconstructed from a smaller common basis.
assert DeclaredReadBasisIsInclusionMinimal {
  no basis: set Retained |
    basis in allReadRetained and
    basis != allReadRetained and
    all answer: readVocabulary | retainedBase[answer] in basis
}

run showCurrentReadGraph for 64
run quantityMechanicSpansSemanticRegions for 64
run temporalMechanicSpansSemanticRegions for 64
run lifecycleMechanicSpansSemanticRegions for 64
check ReadSubjectsFitFourHouseholdRegions for 64
check MechanicsDetermineSemanticRegion for 64
check CurrentCoverageBaseMatchesProductionComposition for 64
check BudgetWindowBaseMatchesProductionComposition for 64
check StockFlowAddsNoRetainedFamilyBeyondItsInputs for 64
check TransactionsFlowAddsNoRetainedFamilyBeyondActualReview for 64
check ConditionalPathAddsNoRetainedFamilyBeyondBalanceAndScheduled for 64
check EvidenceLimitReportsAddNoRetainedBasis for 64
check MutationOnlyCandidatesAreAbsentFromReadBasis for 64
check DeclaredReadBasisIsInclusionMinimal for 64

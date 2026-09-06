module experiments/observation_207_derived_posting_assertion_boundary

abstract sig Quantity {}
one sig Q0, Q1, Q2, Q3 extends Quantity {}

abstract sig Horizon {}
one sig H0, H1 extends Horizon {}

abstract sig ReportRealness {}
one sig RealOnly, IncludeAccounting extends ReportRealness {}

abstract sig AutoMode {}
one sig AutoOff, AutoOn extends AutoMode {}

sig World {
  originalPhysical : one Quantity,
  correctedPhysical : lone Quantity,
  correctionKnownAt : lone Horizon,
  queryHorizon : one Horizon,

  accountingOnly : one Quantity,
  generatedByRule : one Quantity,
  autoMode : one AutoMode,
  reportRealness : one ReportRealness,
  asserted : one Quantity
}

fact CorrectionShape {
  all w : World |
    ((some w.correctedPhysical) iff (w.correctionKnownAt = H1))
}

pred add[a, b, c : Quantity] {
  (a = Q0 and b = Q0 and c = Q0) or
  (a = Q0 and b = Q1 and c = Q1) or
  (a = Q0 and b = Q2 and c = Q2) or
  (a = Q0 and b = Q3 and c = Q3) or
  (a = Q1 and b = Q0 and c = Q1) or
  (a = Q2 and b = Q0 and c = Q2) or
  (a = Q3 and b = Q0 and c = Q3) or
  (a = Q1 and b = Q1 and c = Q2) or
  (a = Q1 and b = Q2 and c = Q3) or
  (a = Q2 and b = Q1 and c = Q3)
}

pred selectedPhysical[w : World, q : Quantity] {
  (no w.correctedPhysical and q = w.originalPhysical) or
  (some w.correctedPhysical and w.queryHorizon = H0 and q = w.originalPhysical) or
  (some w.correctedPhysical and w.queryHorizon = H1 and q = w.correctedPhysical)
}

pred selectedAccountingForReport[w : World, q : Quantity] {
  (w.reportRealness = RealOnly and q = Q0) or
  (w.reportRealness = IncludeAccounting and q = w.accountingOnly)
}

pred selectedGenerated[w : World, q : Quantity] {
  (w.autoMode = AutoOff and q = Q0) or
  (w.autoMode = AutoOn and q = w.generatedByRule)
}

pred reportBalance[w : World, q : Quantity] {
  some p, a, g, pa : Quantity |
    selectedPhysical[w, p] and
    selectedAccountingForReport[w, a] and
    selectedGenerated[w, g] and
    add[p, a, pa] and
    add[pa, g, q]
}

pred assertionBalance[w : World, q : Quantity] {
  some p, g, pa : Quantity |
    selectedPhysical[w, p] and
    selectedGenerated[w, g] and
    add[p, w.accountingOnly, pa] and
    add[pa, g, q]
}

pred assertionPasses[w : World] {
  assertionBalance[w, w.asserted]
}

pred reportBalanceDefined[w : World] {
  some q : Quantity | reportBalance[w, q]
}

pred assertionBalanceDefined[w : World] {
  some q : Quantity | assertionBalance[w, q]
}

pred selectedViewsDefined[w : World] {
  reportBalanceDefined[w]
  assertionBalanceDefined[w]
}

pred sameSelectedPhysical[a, b : World] {
  some q : Quantity | selectedPhysical[a, q] and selectedPhysical[b, q]
}

pred sameReportBalance[a, b : World] {
  some q : Quantity | reportBalance[a, q] and reportBalance[b, q]
}

pred sameRetainedHistory[a, b : World] {
  a.originalPhysical = b.originalPhysical
  a.correctedPhysical = b.correctedPhysical
  a.correctionKnownAt = b.correctionKnownAt
}

pred sameNonReportSelection[a, b : World] {
  sameRetainedHistory[a, b]
  a.queryHorizon = b.queryHorizon
  a.accountingOnly = b.accountingOnly
  a.generatedByRule = b.generatedByRule
  a.autoMode = b.autoMode
  a.asserted = b.asserted
}

pred representativeRealReportVsAssertion {
  some w : World |
    no w.correctedPhysical and
    w.originalPhysical = Q1 and
    w.accountingOnly = Q1 and
    w.generatedByRule = Q0 and
    w.autoMode = AutoOff and
    w.reportRealness = RealOnly and
    w.asserted = Q2 and
    reportBalance[w, Q1] and
    assertionPasses[w]
}

pred sameRealReportDifferentAssertionOutcome {
  some disj a, b : World |
    no a.correctedPhysical and no b.correctedPhysical and
    a.originalPhysical = Q1 and b.originalPhysical = Q1 and
    a.accountingOnly = Q0 and b.accountingOnly = Q1 and
    a.generatedByRule = Q0 and b.generatedByRule = Q0 and
    a.autoMode = AutoOff and b.autoMode = AutoOff and
    a.reportRealness = RealOnly and b.reportRealness = RealOnly and
    a.asserted = Q2 and b.asserted = Q2 and
    reportBalance[a, Q1] and reportBalance[b, Q1] and
    not assertionPasses[a] and assertionPasses[b]
}

pred sameSelectedScalarDifferentProvenance {
  some disj a, b : World |
    no a.correctedPhysical and no b.correctedPhysical and
    a.originalPhysical = Q2 and b.originalPhysical = Q1 and
    a.accountingOnly = Q0 and b.accountingOnly = Q1 and
    a.generatedByRule = Q0 and b.generatedByRule = Q0 and
    a.autoMode = AutoOff and b.autoMode = AutoOff and
    a.reportRealness = IncludeAccounting and b.reportRealness = IncludeAccounting and
    a.asserted = Q2 and b.asserted = Q2 and
    reportBalance[a, Q2] and reportBalance[b, Q2]
}

pred autoModeChangesAssertionOutcome {
  some disj a, b : World |
    no a.correctedPhysical and no b.correctedPhysical and
    a.originalPhysical = Q1 and b.originalPhysical = Q1 and
    a.accountingOnly = Q1 and b.accountingOnly = Q1 and
    a.generatedByRule = Q1 and b.generatedByRule = Q1 and
    a.autoMode = AutoOff and b.autoMode = AutoOn and
    a.reportRealness = RealOnly and b.reportRealness = RealOnly and
    a.asserted = Q2 and b.asserted = Q2 and
    assertionPasses[a] and not assertionPasses[b]
}

pred correctionHorizonChangesDerivedAssertion {
  some disj oldView, currentView : World |
    oldView.originalPhysical = Q1 and currentView.originalPhysical = Q1 and
    oldView.correctedPhysical = Q2 and currentView.correctedPhysical = Q2 and
    oldView.correctionKnownAt = H1 and currentView.correctionKnownAt = H1 and
    oldView.queryHorizon = H0 and currentView.queryHorizon = H1 and
    oldView.accountingOnly = Q0 and currentView.accountingOnly = Q0 and
    oldView.generatedByRule = Q1 and currentView.generatedByRule = Q1 and
    oldView.autoMode = AutoOn and currentView.autoMode = AutoOn and
    oldView.reportRealness = RealOnly and currentView.reportRealness = RealOnly and
    oldView.asserted = Q2 and currentView.asserted = Q2 and
    assertionPasses[oldView] and not assertionPasses[currentView]
}

assert ReportScalarDeterminesAssertionOutcome {
  all a, b : World |
    (a.reportRealness = RealOnly and b.reportRealness = RealOnly and
     a.autoMode = b.autoMode and
     a.asserted = b.asserted and
     assertionBalanceDefined[a] and assertionBalanceDefined[b] and
     sameSelectedPhysical[a, b] and
     sameReportBalance[a, b])
      => (assertionPasses[a] iff assertionPasses[b])
}

assert SelectedScalarDeterminesPlaneProvenance {
  all a, b : World |
    (a.reportRealness = b.reportRealness and
     a.autoMode = b.autoMode and
     sameReportBalance[a, b])
      => (a.originalPhysical = b.originalPhysical and
          a.accountingOnly = b.accountingOnly and
          a.generatedByRule = b.generatedByRule)
}

assert PhysicalSelectionAndAssertionDetermineValidation {
  all a, b : World |
    (assertionBalanceDefined[a] and assertionBalanceDefined[b] and
     sameSelectedPhysical[a, b] and a.asserted = b.asserted)
      => (assertionPasses[a] iff assertionPasses[b])
}

assert AssertionIndependentOfReportRealness {
  all a, b : World |
    (assertionBalanceDefined[a] and assertionBalanceDefined[b] and
     sameNonReportSelection[a, b])
      => (assertionPasses[a] iff assertionPasses[b])
}

assert ExplicitLayersDetermineSelectedViews {
  all a, b : World |
    (selectedViewsDefined[a] and selectedViewsDefined[b] and
     sameNonReportSelection[a, b] and a.reportRealness = b.reportRealness)
      => (sameReportBalance[a, b] and
          (assertionPasses[a] iff assertionPasses[b]))
}

assert LaterCorrectionDoesNotRewriteOldHorizon {
  all corrected, prior : World |
    (selectedViewsDefined[corrected] and selectedViewsDefined[prior] and
     some corrected.correctedPhysical and
     corrected.correctionKnownAt = H1 and
     corrected.queryHorizon = H0 and
     no prior.correctedPhysical and
     corrected.originalPhysical = prior.originalPhysical and
     prior.queryHorizon = H0 and
     corrected.accountingOnly = prior.accountingOnly and
     corrected.generatedByRule = prior.generatedByRule and
     corrected.autoMode = prior.autoMode and
     corrected.reportRealness = prior.reportRealness and
     corrected.asserted = prior.asserted)
      => (sameReportBalance[corrected, prior] and
          (assertionPasses[corrected] iff assertionPasses[prior]))
}

run representativeRealReportVsAssertion for 6 World
run sameRealReportDifferentAssertionOutcome for 6 World
run sameSelectedScalarDifferentProvenance for 6 World
run autoModeChangesAssertionOutcome for 6 World
run correctionHorizonChangesDerivedAssertion for 6 World

check ReportScalarDeterminesAssertionOutcome for 6 World
check SelectedScalarDeterminesPlaneProvenance for 6 World
check PhysicalSelectionAndAssertionDetermineValidation for 6 World
check AssertionIndependentOfReportRealness for 6 World
check ExplicitLayersDetermineSelectedViews for 6 World
check LaterCorrectionDoesNotRewriteOldHorizon for 6 World

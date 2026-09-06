module experiments/observation_210_ledger_lot_gain_composition

abstract sig Value {}
one sig V0, V1, V2, V3, V4 extends Value {}

abstract sig Delta {}
one sig Loss4, Loss3, Loss2, Loss1, Flat, Gain1, Gain2, Gain3, Gain4 extends Delta {}

abstract sig Acquisition {}
one sig AcquisitionA, AcquisitionB extends Acquisition {}

abstract sig ReportMode {}
one sig CostMode, MarketMode extends ReportMode {}

sig World {
  basis : Acquisition -> one Value,
  disposedFrom : one Acquisition,
  saleProceeds : one Value,
  remainingMarketValue : one Value,
  reportMode : one ReportMode
}

fun remainingAcquisition[w : World] : one Acquisition {
  Acquisition - w.disposedFrom
}

pred difference[left, right : Value, result : Delta] {
  (left = V0 and right = V0 and result = Flat) or
  (left = V0 and right = V1 and result = Loss1) or
  (left = V0 and right = V2 and result = Loss2) or
  (left = V0 and right = V3 and result = Loss3) or
  (left = V0 and right = V4 and result = Loss4) or

  (left = V1 and right = V0 and result = Gain1) or
  (left = V1 and right = V1 and result = Flat) or
  (left = V1 and right = V2 and result = Loss1) or
  (left = V1 and right = V3 and result = Loss2) or
  (left = V1 and right = V4 and result = Loss3) or

  (left = V2 and right = V0 and result = Gain2) or
  (left = V2 and right = V1 and result = Gain1) or
  (left = V2 and right = V2 and result = Flat) or
  (left = V2 and right = V3 and result = Loss1) or
  (left = V2 and right = V4 and result = Loss2) or

  (left = V3 and right = V0 and result = Gain3) or
  (left = V3 and right = V1 and result = Gain2) or
  (left = V3 and right = V2 and result = Gain1) or
  (left = V3 and right = V3 and result = Flat) or
  (left = V3 and right = V4 and result = Loss1) or

  (left = V4 and right = V0 and result = Gain4) or
  (left = V4 and right = V1 and result = Gain3) or
  (left = V4 and right = V2 and result = Gain2) or
  (left = V4 and right = V3 and result = Gain1) or
  (left = V4 and right = V4 and result = Flat)
}

pred disposedBasis[w : World, value : Value] {
  value in w.disposedFrom.(w.basis)
}

pred remainingBasis[w : World, value : Value] {
  value in remainingAcquisition[w].(w.basis)
}

pred realisedGain[w : World, result : Delta] {
  some basisValue : Value |
    disposedBasis[w, basisValue] and
    difference[w.saleProceeds, basisValue, result]
}

pred unrealisedGain[w : World, result : Delta] {
  some basisValue : Value |
    remainingBasis[w, basisValue] and
    difference[w.remainingMarketValue, basisValue, result]
}

pred selectedRemainingValue[w : World, value : Value] {
  (w.reportMode = CostMode and remainingBasis[w, value]) or
  (w.reportMode = MarketMode and value = w.remainingMarketValue)
}

pred representativeLotGain {
  some w : World |
    AcquisitionA->V1 in w.basis and
    AcquisitionB->V2 in w.basis and
    w.disposedFrom = AcquisitionA and
    w.saleProceeds = V3 and
    w.remainingMarketValue = V4 and
    w.reportMode = CostMode and
    realisedGain[w, Gain2] and
    unrealisedGain[w, Gain2] and
    selectedRemainingValue[w, V2]
}

pred lotSelectionChangesRealisedAndUnrealisedGain {
  some disj a, b : World |
    a.basis = b.basis and
    AcquisitionA->V1 in a.basis and
    AcquisitionB->V2 in a.basis and
    a.saleProceeds = V3 and b.saleProceeds = V3 and
    a.remainingMarketValue = V4 and b.remainingMarketValue = V4 and
    a.disposedFrom = AcquisitionA and
    b.disposedFrom = AcquisitionB and
    realisedGain[a, Gain2] and
    realisedGain[b, Gain1] and
    unrealisedGain[a, Gain2] and
    unrealisedGain[b, Gain3]
}

pred sameMarketDifferentRemainingBasisChangesUnrealisedGain {
  some disj a, b : World |
    a.disposedFrom = AcquisitionA and
    b.disposedFrom = AcquisitionA and
    AcquisitionA->V1 in a.basis and
    AcquisitionA->V1 in b.basis and
    AcquisitionB->V1 in a.basis and
    AcquisitionB->V2 in b.basis and
    a.saleProceeds = V3 and b.saleProceeds = V3 and
    a.remainingMarketValue = V4 and b.remainingMarketValue = V4 and
    realisedGain[a, Gain2] and
    realisedGain[b, Gain2] and
    unrealisedGain[a, Gain3] and
    unrealisedGain[b, Gain2]
}

pred sameBasisDifferentMarketChangesUnrealisedOnly {
  some disj a, b : World |
    a.basis = b.basis and
    AcquisitionA->V1 in a.basis and
    AcquisitionB->V2 in a.basis and
    a.disposedFrom = AcquisitionA and
    b.disposedFrom = AcquisitionA and
    a.saleProceeds = V3 and b.saleProceeds = V3 and
    a.remainingMarketValue = V3 and
    b.remainingMarketValue = V4 and
    realisedGain[a, Gain2] and
    realisedGain[b, Gain2] and
    unrealisedGain[a, Gain1] and
    unrealisedGain[b, Gain2]
}

pred sameRealisedGainDifferentProvenance {
  some disj a, b : World |
    AcquisitionA->V1 in a.basis and
    AcquisitionB->V2 in a.basis and
    AcquisitionA->V1 in b.basis and
    AcquisitionB->V2 in b.basis and
    a.disposedFrom = AcquisitionA and
    b.disposedFrom = AcquisitionB and
    a.saleProceeds = V3 and
    b.saleProceeds = V4 and
    realisedGain[a, Gain2] and
    realisedGain[b, Gain2]
}

pred reportModeChangesSelectedRemainingValue {
  some disj a, b : World |
    a.basis = b.basis and
    AcquisitionA->V1 in a.basis and
    AcquisitionB->V2 in a.basis and
    a.disposedFrom = b.disposedFrom and
    a.disposedFrom = AcquisitionA and
    a.saleProceeds = b.saleProceeds and
    a.remainingMarketValue = b.remainingMarketValue and
    a.remainingMarketValue = V4 and
    a.reportMode = CostMode and
    b.reportMode = MarketMode and
    selectedRemainingValue[a, V2] and
    selectedRemainingValue[b, V4]
}

assert BasisAndProceedsDetermineRealisedGain {
  all a, b : World |
    (a.basis = b.basis and a.saleProceeds = b.saleProceeds)
      => (all result : Delta | realisedGain[a, result] iff realisedGain[b, result])
}

assert MarketValueDeterminesUnrealisedGain {
  all a, b : World |
    a.remainingMarketValue = b.remainingMarketValue
      => (all result : Delta | unrealisedGain[a, result] iff unrealisedGain[b, result])
}

assert RealisedGainScalarDeterminesDisposalProvenance {
  all a, b : World |
    (all result : Delta | realisedGain[a, result] iff realisedGain[b, result])
      => a.disposedFrom = b.disposedFrom
}

assert BasisDeterminesMarketValue {
  all a, b : World |
    (a.basis = b.basis and a.disposedFrom = b.disposedFrom)
      => a.remainingMarketValue = b.remainingMarketValue
}

assert ExplicitValuationInputsDetermineGains {
  all a, b : World |
    (a.basis = b.basis and
     a.disposedFrom = b.disposedFrom and
     a.saleProceeds = b.saleProceeds and
     a.remainingMarketValue = b.remainingMarketValue)
      => ((all result : Delta | realisedGain[a, result] iff realisedGain[b, result]) and
          (all result : Delta | unrealisedGain[a, result] iff unrealisedGain[b, result]) and
          (all value : Value | remainingBasis[a, value] iff remainingBasis[b, value]))
}

assert ExplicitReportInputsDetermineSelectedValue {
  all a, b : World |
    (a.basis = b.basis and
     a.disposedFrom = b.disposedFrom and
     a.remainingMarketValue = b.remainingMarketValue and
     a.reportMode = b.reportMode)
      => (all value : Value |
            selectedRemainingValue[a, value] iff selectedRemainingValue[b, value])
}

assert ExplicitInputsDetermineSelectedAnswers {
  all a, b : World |
    (a.basis = b.basis and
     a.disposedFrom = b.disposedFrom and
     a.saleProceeds = b.saleProceeds and
     a.remainingMarketValue = b.remainingMarketValue and
     a.reportMode = b.reportMode)
      => ((all result : Delta | realisedGain[a, result] iff realisedGain[b, result]) and
          (all result : Delta | unrealisedGain[a, result] iff unrealisedGain[b, result]) and
          (all value : Value | selectedRemainingValue[a, value] iff selectedRemainingValue[b, value]))
}

run representativeLotGain for 8 World
run lotSelectionChangesRealisedAndUnrealisedGain for 8 World
run sameMarketDifferentRemainingBasisChangesUnrealisedGain for 8 World
run sameBasisDifferentMarketChangesUnrealisedOnly for 8 World
run sameRealisedGainDifferentProvenance for 8 World
run reportModeChangesSelectedRemainingValue for 8 World

check BasisAndProceedsDetermineRealisedGain for 8 World
check MarketValueDeterminesUnrealisedGain for 8 World
check RealisedGainScalarDeterminesDisposalProvenance for 8 World
check BasisDeterminesMarketValue for 8 World
check ExplicitValuationInputsDetermineGains for 8 World
check ExplicitReportInputsDetermineSelectedValue for 8 World
check ExplicitInputsDetermineSelectedAnswers for 8 World

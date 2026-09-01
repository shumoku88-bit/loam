abstract sig CorrectionShape {}
one sig ZeroCorrections, SingleCorrection, MultipleCorrections extends CorrectionShape {}

abstract sig RetainedResult {
  supports: set CorrectionShape,
  blocks: set CorrectionShape
}

one sig RecordedAggregateLaw,
        SingleCorrectionQuantityLaw,
        SiblingConflictLaw extends RetainedResult {}

one sig KnowledgeBundle {
  results: set RetainedResult
}

sig LaterQuestion {
  shape: one CorrectionShape,
  retained: one KnowledgeBundle
}

fact ExistingLoamBoundary {
  RecordedAggregateLaw.supports = ZeroCorrections
  no RecordedAggregateLaw.blocks

  SingleCorrectionQuantityLaw.supports = SingleCorrection
  no SingleCorrectionQuantityLaw.blocks

  no SiblingConflictLaw.supports
  SiblingConflictLaw.blocks = MultipleCorrections

  KnowledgeBundle.results = RetainedResult
  all q: LaterQuestion | q.retained = KnowledgeBundle
}

fun supportedShapes[b: KnowledgeBundle] : set CorrectionShape {
  b.results.supports
}

fun blockedShapes[b: KnowledgeBundle] : set CorrectionShape {
  b.results.blocks
}

pred reusable[q: LaterQuestion] {
  q.shape in supportedShapes[q.retained]
  q.shape not in blockedShapes[q.retained]
}

pred currentPracticalBoundary {
  some disj zero, single, multiple: LaterQuestion |
    zero.shape = ZeroCorrections and
    single.shape = SingleCorrection and
    multiple.shape = MultipleCorrections and
    reusable[zero] and
    reusable[single] and
    not reusable[multiple]
}

-- PR #139's practical surface has a real witness with supported zero/single
-- correction contexts and a fail-closed multiple-correction context.
run currentPracticalBoundary for exactly 3 LaterQuestion

-- If later context is forgotten, the same retained knowledge appears to demand
-- one context-free reuse decision. The current LOAM boundary should refute that.
assert RetainedKnowledgeAloneDeterminesReuse {
  all disj left, right: LaterQuestion |
    left.retained = right.retained implies
      (reusable[left] iff reusable[right])
}
check RetainedKnowledgeAloneDeterminesReuse for exactly 3 LaterQuestion

-- Within this deliberately narrow model, retaining the later correction shape
-- together with the same knowledge bundle is enough to recover the decision.
-- This is not claimed as a universal receipt schema.
assert RetainedKnowledgeAndShapeDetermineReuse {
  all disj left, right: LaterQuestion |
    left.retained = right.retained and left.shape = right.shape implies
      (reusable[left] iff reusable[right])
}
check RetainedKnowledgeAndShapeDetermineReuse for exactly 4 LaterQuestion

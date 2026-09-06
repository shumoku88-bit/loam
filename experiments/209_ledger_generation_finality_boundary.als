module experiments/observation_209_ledger_generation_finality_boundary

abstract sig Balance {}
one sig B0, B1, B2 extends Balance {}

abstract sig Delta {}
one sig Minus2, Minus1, ZeroDelta, Plus1, Plus2 extends Delta {}

abstract sig Mode {}
one sig CloseMode, OpenMode, RetainMode, AssignMode, AssertMode extends Mode {}

abstract sig SelectionContext {}
one sig FullContext, FilteredContext extends SelectionContext {}

abstract sig OrderPolicy {}
one sig ParseOnly, DateThenParse extends OrderPolicy {}

abstract sig Flag {}
one sig No, Yes extends Flag {}

abstract sig Date {}
one sig D0, D1 extends Date {}

sig World {
  fullBalance : one Balance,
  filteredBalance : one Balance,
  generationContext : one SelectionContext,
  validationContext : one SelectionContext,

  mode : one Mode,
  assignmentTarget : one Balance,
  admitted : one Flag,

  orderPolicy : one OrderPolicy,
  priorPostingDelta : one Delta,
  postingParseBefore : one Flag,
  postingDate : one Date,
  assertionDate : one Date,
  assertedPrefix : one Balance
}

fact PriorPostingShape {
  all w : World | w.priorPostingDelta in ZeroDelta + Plus1 + Plus2
}

pred opposite[a, b : Delta] {
  (a = Minus2 and b = Plus2) or
  (a = Minus1 and b = Plus1) or
  (a = ZeroDelta and b = ZeroDelta) or
  (a = Plus1 and b = Minus1) or
  (a = Plus2 and b = Minus2)
}

pred applyDelta[start : Balance, delta : Delta, result : Balance] {
  (start = B0 and delta = ZeroDelta and result = B0) or
  (start = B1 and delta = ZeroDelta and result = B1) or
  (start = B2 and delta = ZeroDelta and result = B2) or

  (start = B0 and delta = Plus1 and result = B1) or
  (start = B1 and delta = Plus1 and result = B2) or
  (start = B0 and delta = Plus2 and result = B2) or

  (start = B1 and delta = Minus1 and result = B0) or
  (start = B2 and delta = Minus1 and result = B1) or
  (start = B2 and delta = Minus2 and result = B0)
}

pred closeDelta[balance : Balance, delta : Delta] {
  (balance = B0 and delta = ZeroDelta) or
  (balance = B1 and delta = Minus1) or
  (balance = B2 and delta = Minus2)
}

pred openDelta[balance : Balance, delta : Delta] {
  (balance = B0 and delta = ZeroDelta) or
  (balance = B1 and delta = Plus1) or
  (balance = B2 and delta = Plus2)
}

pred assignmentDelta[current, target : Balance, delta : Delta] {
  (current = B0 and target = B0 and delta = ZeroDelta) or
  (current = B0 and target = B1 and delta = Plus1) or
  (current = B0 and target = B2 and delta = Plus2) or

  (current = B1 and target = B0 and delta = Minus1) or
  (current = B1 and target = B1 and delta = ZeroDelta) or
  (current = B1 and target = B2 and delta = Plus1) or

  (current = B2 and target = B0 and delta = Minus2) or
  (current = B2 and target = B1 and delta = Minus1) or
  (current = B2 and target = B2 and delta = ZeroDelta)
}

pred contextBalance[w : World, context : SelectionContext, balance : Balance] {
  (context = FullContext and balance = w.fullBalance) or
  (context = FilteredContext and balance = w.filteredBalance)
}

pred generationBalance[w : World, balance : Balance] {
  contextBalance[w, w.generationContext, balance]
}

pred validationBalance[w : World, balance : Balance] {
  contextBalance[w, w.validationContext, balance]
}

pred postingBeforeAssertion[w : World] {
  (w.orderPolicy = ParseOnly and w.postingParseBefore = Yes) or
  (w.orderPolicy = DateThenParse and
    ((w.postingDate = D0 and w.assertionDate = D1) or
     (w.postingDate = w.assertionDate and w.postingParseBefore = Yes)))
}

pred prefixBalance[w : World, balance : Balance] {
  (postingBeforeAssertion[w] and applyDelta[B0, w.priorPostingDelta, balance]) or
  (not postingBeforeAssertion[w] and balance = B0)
}

pred finalBalance[w : World, balance : Balance] {
  applyDelta[B0, w.priorPostingDelta, balance]
}

pred generatedAccountDelta[w : World, delta : Delta] {
  (w.mode in CloseMode + RetainMode and
    some balance : Balance | generationBalance[w, balance] and closeDelta[balance, delta]) or
  (w.mode = OpenMode and
    some balance : Balance | generationBalance[w, balance] and openDelta[balance, delta]) or
  (w.mode = AssignMode and
    some current : Balance | prefixBalance[w, current] and assignmentDelta[current, w.assignmentTarget, delta]) or
  (w.mode = AssertMode and delta = ZeroDelta)
}

pred generatedCounterDelta[w : World, delta : Delta] {
  w.mode != AssertMode
  some accountDelta : Delta |
    generatedAccountDelta[w, accountDelta] and opposite[accountDelta, delta]
}

pred retainedGeneratedDelta[w : World, delta : Delta] {
  w.admitted = Yes
  w.mode != AssertMode
  generatedAccountDelta[w, delta]
}

pred sourceAssertionPasses[w : World] {
  some balance : Balance |
    prefixBalance[w, balance] and balance = w.assertedPrefix
}

pred generatedCloseAssertionPasses[w : World] {
  w.mode = CloseMode
  some opening : Balance, delta : Delta |
    validationBalance[w, opening] and
    generatedAccountDelta[w, delta] and
    applyDelta[opening, delta, B0]
}

pred representativeClosePreview {
  some w : World |
    w.mode = CloseMode and
    w.fullBalance = B2 and
    w.filteredBalance = B1 and
    w.generationContext = FilteredContext and
    w.admitted = No and
    generatedAccountDelta[w, Minus1] and
    generatedCounterDelta[w, Plus1] and
    no delta : Delta | retainedGeneratedDelta[w, delta]
}

pred sameGeneratedDifferentMode {
  some disj a, b : World |
    a.mode = CloseMode and
    a.generationContext = FullContext and
    a.fullBalance = B1 and
    generatedAccountDelta[a, Minus1] and
    generatedCounterDelta[a, Plus1] and

    b.mode = AssignMode and
    b.orderPolicy = ParseOnly and
    b.postingParseBefore = Yes and
    b.priorPostingDelta = Plus2 and
    b.assignmentTarget = B1 and
    generatedAccountDelta[b, Minus1] and
    generatedCounterDelta[b, Plus1]
}

pred assignmentOrderingChangesGeneratedAmount {
  some disj a, b : World |
    a.mode = AssignMode and b.mode = AssignMode and
    a.assignmentTarget = B2 and b.assignmentTarget = B2 and
    a.priorPostingDelta = Plus1 and b.priorPostingDelta = Plus1 and
    a.postingParseBefore = Yes and b.postingParseBefore = Yes and
    a.postingDate = D1 and b.postingDate = D1 and
    a.assertionDate = D0 and b.assertionDate = D0 and
    a.orderPolicy = ParseOnly and b.orderPolicy = DateThenParse and
    generatedAccountDelta[a, Plus1] and
    generatedAccountDelta[b, Plus2]
}

pred sameGeneratorDifferentAdmission {
  some disj a, b : World |
    a.mode = b.mode and
    a.mode = CloseMode and
    a.fullBalance = b.fullBalance and
    a.filteredBalance = b.filteredBalance and
    a.generationContext = b.generationContext and
    a.assignmentTarget = b.assignmentTarget and
    a.orderPolicy = b.orderPolicy and
    a.priorPostingDelta = b.priorPostingDelta and
    a.postingParseBefore = b.postingParseBefore and
    a.postingDate = b.postingDate and
    a.assertionDate = b.assertionDate and
    a.admitted = No and b.admitted = Yes and
    some delta : Delta |
      generatedAccountDelta[a, delta] and
      generatedAccountDelta[b, delta] and
      not retainedGeneratedDelta[a, delta] and
      retainedGeneratedDelta[b, delta]
}

pred closeValidationContextChangesAssertion {
  some disj a, b : World |
    a.mode = CloseMode and b.mode = CloseMode and
    a.fullBalance = B2 and b.fullBalance = B2 and
    a.filteredBalance = B1 and b.filteredBalance = B1 and
    a.generationContext = FilteredContext and
    b.generationContext = FilteredContext and
    a.validationContext = FilteredContext and
    b.validationContext = FullContext and
    generatedAccountDelta[a, Minus1] and
    generatedAccountDelta[b, Minus1] and
    generatedCloseAssertionPasses[a] and
    not generatedCloseAssertionPasses[b]
}

pred sameFinalBalanceDifferentPrefixAssertion {
  some disj a, b : World |
    a.priorPostingDelta = Plus1 and b.priorPostingDelta = Plus1 and
    a.postingParseBefore = Yes and b.postingParseBefore = Yes and
    a.postingDate = D1 and b.postingDate = D1 and
    a.assertionDate = D0 and b.assertionDate = D0 and
    a.assertedPrefix = B0 and b.assertedPrefix = B0 and
    a.orderPolicy = DateThenParse and b.orderPolicy = ParseOnly and
    finalBalance[a, B1] and finalBalance[b, B1] and
    sourceAssertionPasses[a] and
    not sourceAssertionPasses[b]
}

assert GeneratedOutputDeterminesMode {
  all a, b : World |
    ((all delta : Delta | generatedAccountDelta[a, delta] iff generatedAccountDelta[b, delta]) and
     (all delta : Delta | generatedCounterDelta[a, delta] iff generatedCounterDelta[b, delta]))
      => a.mode = b.mode
}

assert GenerationDeterminesRetention {
  all a, b : World |
    (a.mode = b.mode and
     a.fullBalance = b.fullBalance and
     a.filteredBalance = b.filteredBalance and
     a.generationContext = b.generationContext and
     a.assignmentTarget = b.assignmentTarget and
     a.orderPolicy = b.orderPolicy and
     a.priorPostingDelta = b.priorPostingDelta and
     a.postingParseBefore = b.postingParseBefore and
     a.postingDate = b.postingDate and
     a.assertionDate = b.assertionDate)
      => (all delta : Delta | retainedGeneratedDelta[a, delta] iff retainedGeneratedDelta[b, delta])
}

assert FinalBalanceDeterminesAssertionOutcome {
  all a, b : World |
    ((all balance : Balance | finalBalance[a, balance] iff finalBalance[b, balance]) and
     a.assertedPrefix = b.assertedPrefix)
      => (sourceAssertionPasses[a] iff sourceAssertionPasses[b])
}

assert ExplicitGenerationInputsDetermineOutput {
  all a, b : World |
    (a.fullBalance = b.fullBalance and
     a.filteredBalance = b.filteredBalance and
     a.generationContext = b.generationContext and
     a.mode = b.mode and
     a.assignmentTarget = b.assignmentTarget and
     a.orderPolicy = b.orderPolicy and
     a.priorPostingDelta = b.priorPostingDelta and
     a.postingParseBefore = b.postingParseBefore and
     a.postingDate = b.postingDate and
     a.assertionDate = b.assertionDate)
      => ((all delta : Delta | generatedAccountDelta[a, delta] iff generatedAccountDelta[b, delta]) and
          (all delta : Delta | generatedCounterDelta[a, delta] iff generatedCounterDelta[b, delta]))
}

assert ExplicitOrderingInputsDeterminePrefixAssertion {
  all a, b : World |
    (a.orderPolicy = b.orderPolicy and
     a.priorPostingDelta = b.priorPostingDelta and
     a.postingParseBefore = b.postingParseBefore and
     a.postingDate = b.postingDate and
     a.assertionDate = b.assertionDate and
     a.assertedPrefix = b.assertedPrefix)
      => (sourceAssertionPasses[a] iff sourceAssertionPasses[b])
}

assert ExplicitCloseContextsDetermineGeneratedAssertion {
  all a, b : World |
    (a.mode = CloseMode and b.mode = CloseMode and
     a.fullBalance = b.fullBalance and
     a.filteredBalance = b.filteredBalance and
     a.generationContext = b.generationContext and
     a.validationContext = b.validationContext)
      => (generatedCloseAssertionPasses[a] iff generatedCloseAssertionPasses[b])
}

assert ExplicitInputsDetermineSelectedOutputs {
  all a, b : World |
    (a.fullBalance = b.fullBalance and
     a.filteredBalance = b.filteredBalance and
     a.generationContext = b.generationContext and
     a.validationContext = b.validationContext and
     a.mode = b.mode and
     a.assignmentTarget = b.assignmentTarget and
     a.admitted = b.admitted and
     a.orderPolicy = b.orderPolicy and
     a.priorPostingDelta = b.priorPostingDelta and
     a.postingParseBefore = b.postingParseBefore and
     a.postingDate = b.postingDate and
     a.assertionDate = b.assertionDate and
     a.assertedPrefix = b.assertedPrefix)
      => ((all delta : Delta | generatedAccountDelta[a, delta] iff generatedAccountDelta[b, delta]) and
          (all delta : Delta | retainedGeneratedDelta[a, delta] iff retainedGeneratedDelta[b, delta]) and
          (sourceAssertionPasses[a] iff sourceAssertionPasses[b]) and
          (generatedCloseAssertionPasses[a] iff generatedCloseAssertionPasses[b]))
}

run representativeClosePreview for 8 World
run sameGeneratedDifferentMode for 8 World
run assignmentOrderingChangesGeneratedAmount for 8 World
run sameGeneratorDifferentAdmission for 8 World
run closeValidationContextChangesAssertion for 8 World
run sameFinalBalanceDifferentPrefixAssertion for 8 World

check GeneratedOutputDeterminesMode for 8 World
check GenerationDeterminesRetention for 8 World
check FinalBalanceDeterminesAssertionOutcome for 8 World
check ExplicitGenerationInputsDetermineOutput for 8 World
check ExplicitOrderingInputsDeterminePrefixAssertion for 8 World
check ExplicitCloseContextsDetermineGeneratedAssertion for 8 World
check ExplicitInputsDetermineSelectedOutputs for 8 World

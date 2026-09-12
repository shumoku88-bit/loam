module experiments/minimal_actual_publication

sig Event {}

sig Correction {
  target: one Event,
  replacement: one Event
}

sig Reversal {
  target: one Event,
  inverse: one Event
}

// A complete immutable canonical Actual generation.
sig Generation {
  events: set Event,
  corrections: set Correction,
  reversals: set Reversal
}

pred closed[g: Generation] {
  all c: g.corrections |
    c.target in g.events and c.replacement in g.events
  all r: g.reversals |
    r.target in g.events and r.inverse in g.events
}

// One reader-visible state. Prepared generation bytes are intentionally absent
// from this semantic state: only selected authority can answer queries.
sig Visible {
  selected: one Generation
}

// Old and New model two admitted generations around one publication.
one sig Old, New extends Generation {}

fact EndpointsAreClosed {
  closed[Old]
  closed[New]
}

// Atomic generation publication permits readers to see either complete endpoint,
// never a field-wise mixture.
pred atomicVisible[v: Visible] {
  v.selected = Old or v.selected = New
}

// Current split sidecar topology can expose relation-first intermediate state:
// correction/reversal authority has advanced while selected Event authority has not.
sig SplitSnapshot {
  events: set Event,
  corrections: set Correction,
  reversals: set Reversal
}

pred splitCorrectionMid[s: SplitSnapshot] {
  s.events = Old.events
  s.corrections = New.corrections
  s.reversals = Old.reversals
}

pred splitReversalMid[s: SplitSnapshot] {
  s.events = Old.events
  s.corrections = Old.corrections
  s.reversals = New.reversals
}

pred splitClosed[s: SplitSnapshot] {
  all c: s.corrections |
    c.target in s.events and c.replacement in s.events
  all r: s.reversals |
    r.target in s.events and r.inverse in s.events
}

// Construct pressure where New appends one Event plus its correction edge.
pred correctionPublicationCanDangle {
  some disj original, replacement: Event,
       c: Correction,
       s: SplitSnapshot | {
    original in Old.events
    replacement not in Old.events
    New.events = Old.events + replacement
    c.target = original
    c.replacement = replacement
    New.corrections = Old.corrections + c
    New.reversals = Old.reversals
    splitCorrectionMid[s]
    not splitClosed[s]
  }
}

// Same pressure for an inverse Event plus explicit reversal meaning.
pred reversalPublicationCanDangle {
  some disj original, inverse: Event,
       r: Reversal,
       s: SplitSnapshot | {
    original in Old.events
    inverse not in Old.events
    New.events = Old.events + inverse
    r.target = original
    r.inverse = inverse
    New.reversals = Old.reversals + r
    New.corrections = Old.corrections
    splitReversalMid[s]
    not splitClosed[s]
  }
}

// Prepared candidate may exist physically while Old remains selected. Its contents
// cannot affect the semantic view until the one authority edge changes.
pred preparedNewWhileOldSelected {
  some v: Visible | {
    v.selected = Old
    Old != New
    closed[New]
  }
}

pred switchedToNew {
  some v: Visible | {
    v.selected = New
    Old != New
    closed[Old]
  }
}

assert AtomicSelectedGenerationPreservesClosure {
  all v: Visible |
    atomicVisible[v] implies closed[v.selected]
}

// There is no semantic state in the atomic protocol where selected Event membership
// is Old while selected correction/reversal membership is New, because membership
// is not independently selected at all.
assert AtomicViewCannotTearFamilies {
  all v: Visible |
    atomicVisible[v] implies
      (v.selected.events = Old.events and
       v.selected.corrections = Old.corrections and
       v.selected.reversals = Old.reversals)
      or
      (v.selected.events = New.events and
       v.selected.corrections = New.corrections and
       v.selected.reversals = New.reversals)
}

run correctionPublicationCanDangle for 8 but exactly 3 Event, 2 Generation, 1 Correction, 0 Reversal, 1 SplitSnapshot
run reversalPublicationCanDangle for 8 but exactly 3 Event, 2 Generation, 0 Correction, 1 Reversal, 1 SplitSnapshot
run preparedNewWhileOldSelected for 8 but exactly 2 Generation, 2 Visible
run switchedToNew for 8 but exactly 2 Generation, 2 Visible
check AtomicSelectedGenerationPreservesClosure for 10 but exactly 2 Generation
check AtomicViewCannotTearFamilies for 10 but exactly 2 Generation

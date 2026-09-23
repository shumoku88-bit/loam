module experiments/observation_324_interpretation_carrier_compression

open util/ordering[Moment] as time

sig Moment {}
sig Text {}
sig Fact {}
sig Note {}

abstract sig World {
  noteText: Note -> one Text,
  subject: Note -> one Fact,
  recordedAt: Note -> one Moment,
  attributedAt: Note -> one Moment
}

one sig Left, Right extends World {}

// Candidate existing carrier if a zero-effect Event + EventDescription is given
// one ActualValidity-like time coordinate.
abstract sig CarrierMode {}
one sig UseRecordedAt, UseAttributedAt extends CarrierMode {}

fun carrierTime[w: World, mode: CarrierMode, n: Note]: one Moment {
  { m: Moment |
      (mode = UseRecordedAt and m = n.(w.recordedAt)) or
      (mode = UseAttributedAt and m = n.(w.attributedAt))
  }
}

pred sameCarrier[a, b: World, mode: CarrierMode] {
  a.noteText = b.noteText
  all n: Note | carrierTime[a, mode, n] = carrierTime[b, mode, n]
}

fun notesFor[w: World, f: Fact]: set Note {
  { n: Note | n.(w.subject) = f }
}

fun recordedBy[w: World, cutoff: Moment]: set Note {
  { n: Note | n.(w.recordedAt) = cutoff or time/lt[n.(w.recordedAt), cutoff] }
}

fun attributedBy[w: World, cutoff: Moment]: set Note {
  { n: Note | n.(w.attributedAt) = cutoff or time/lt[n.(w.attributedAt), cutoff] }
}

pred recordedCarrierLosesSubject {
  sameCarrier[Left, Right, UseRecordedAt]
  Left.subject != Right.subject
  some f: Fact | notesFor[Left, f] != notesFor[Right, f]
}

pred recordedCarrierLosesAttributedTime {
  sameCarrier[Left, Right, UseRecordedAt]
  Left.attributedAt != Right.attributedAt
  some cutoff: Moment | attributedBy[Left, cutoff] != attributedBy[Right, cutoff]
}

pred attributedCarrierLosesSubject {
  sameCarrier[Left, Right, UseAttributedAt]
  Left.subject != Right.subject
  some f: Fact | notesFor[Left, f] != notesFor[Right, f]
}

pred attributedCarrierLosesRecordedTime {
  sameCarrier[Left, Right, UseAttributedAt]
  Left.recordedAt != Right.recordedAt
  some cutoff: Moment | recordedBy[Left, cutoff] != recordedBy[Right, cutoff]
}

assert RecordedCarrierDeterminesFullMeaning {
  sameCarrier[Left, Right, UseRecordedAt] implies {
    Left.subject = Right.subject
    Left.recordedAt = Right.recordedAt
    Left.attributedAt = Right.attributedAt
  }
}

assert AttributedCarrierDeterminesFullMeaning {
  sameCarrier[Left, Right, UseAttributedAt] implies {
    Left.subject = Right.subject
    Left.recordedAt = Right.recordedAt
    Left.attributedAt = Right.attributedAt
  }
}

run recordedCarrierLosesSubject
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 2 Fact, exactly 1 Note, exactly 2 CarrierMode

run recordedCarrierLosesAttributedTime
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note, exactly 2 CarrierMode

run attributedCarrierLosesSubject
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 2 Fact, exactly 1 Note, exactly 2 CarrierMode

run attributedCarrierLosesRecordedTime
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note, exactly 2 CarrierMode

check RecordedCarrierDeterminesFullMeaning
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 2 Fact, exactly 1 Note, exactly 2 CarrierMode

check AttributedCarrierDeterminesFullMeaning
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 2 Fact, exactly 1 Note, exactly 2 CarrierMode

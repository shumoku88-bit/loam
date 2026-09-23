module experiments/observation_322_interpretation_recorded_time

open util/ordering[Moment] as time

sig Moment {}
sig Text {}
sig Fact {}
sig Note {}

abstract sig World {
  factTime: Fact -> one Moment,
  noteText: Note -> one Text,
  subject: Note -> one Fact,
  recordedAt: Note -> one Moment
}

one sig Left, Right extends World {}

pred atOrBefore[a, b: Moment] {
  a = b or time/lt[a, b]
}

fun notesKnownBy[w: World, f: Fact, cutoff: Moment]: set Note {
  {
    n: Note |
      n.(w.subject) = f and
      atOrBefore[n.(w.recordedAt), cutoff]
  }
}

pred sameNonRecordedEvidence[a, b: World] {
  a.factTime = b.factTime
  a.noteText = b.noteText
  a.subject = b.subject
}

fact InterpretationDoesNotPrecedeItsSubjectFact {
  all w: World, n: Note |
    let f = n.(w.subject) |
      atOrBefore[f.(w.factTime), n.(w.recordedAt)]
}

fact SameBaseEvidence {
  sameNonRecordedEvidence[Left, Right]
}

pred laterRecordingExists {
  some w: World, n: Note |
    let f = n.(w.subject) |
      time/lt[f.(w.factTime), n.(w.recordedAt)]
}

pred sameBaseDifferentRecording {
  Left.recordedAt != Right.recordedAt
}

pred sameBaseDifferentAsOfAnswer {
  sameBaseDifferentRecording
  some f: Fact, cutoff: Moment |
    notesKnownBy[Left, f, cutoff] !=
      notesKnownBy[Right, f, cutoff]
}

assert NonRecordedEvidenceDeterminesAsOfView {
  all f: Fact, cutoff: Moment |
    notesKnownBy[Left, f, cutoff] =
      notesKnownBy[Right, f, cutoff]
}

assert RecordedTimeDeterminesAsOfView {
  (sameNonRecordedEvidence[Left, Right] and
   Left.recordedAt = Right.recordedAt) implies
    all f: Fact, cutoff: Moment |
      notesKnownBy[Left, f, cutoff] =
        notesKnownBy[Right, f, cutoff]
}

run laterRecordingExists
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

run sameBaseDifferentRecording
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

run sameBaseDifferentAsOfAnswer
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

check NonRecordedEvidenceDeterminesAsOfView
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

check RecordedTimeDeterminesAsOfView
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

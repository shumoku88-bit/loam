module experiments/observation_323_interpretation_attributed_time

open util/ordering[Moment] as time

sig Moment {}
sig Text {}
sig Fact {}
sig Note {}

abstract sig World {
  factTime: Fact -> one Moment,
  noteText: Note -> one Text,
  subject: Note -> one Fact,
  recordedAt: Note -> one Moment,

  // Candidate coordinate under test:
  // when the retained note says this perspective belonged.
  attributedAt: Note -> one Moment
}

one sig Left, Right extends World {}

pred atOrBefore[a, b: Moment] {
  a = b or time/lt[a, b]
}

pred sameWithoutAttributedTime[a, b: World] {
  a.factTime = b.factTime
  a.noteText = b.noteText
  a.subject = b.subject
  a.recordedAt = b.recordedAt
}

fact SameBaseEvidence {
  sameWithoutAttributedTime[Left, Right]
}

// This probe studies retrospective interpretation of an already-occurred Fact.
// attributedAt is constrained to the interval from Fact time through recording time.
fact AttributionWindow {
  all w: World, n: Note |
    let f = n.(w.subject),
        ft = f.(w.factTime),
        at = n.(w.attributedAt),
        rt = n.(w.recordedAt) | {
      atOrBefore[ft, at]
      atOrBefore[at, rt]
    }
}

fun notesAttributedBy[w: World, f: Fact, cutoff: Moment]: set Note {
  {
    n: Note |
      n.(w.subject) = f and
      atOrBefore[n.(w.attributedAt), cutoff]
  }
}

pred sameBaseDifferentAttribution {
  Left.attributedAt != Right.attributedAt
}

pred contemporaneousVersusLaterExists {
  some n: Note | {
    let f = n.(Left.subject) |
      n.(Left.attributedAt) = f.(Left.factTime)
    time/lt[n.(Right.subject).(Right.factTime), n.(Right.attributedAt)]
    n.(Right.attributedAt) = n.(Right.recordedAt)
  }
}

pred sameBaseDifferentAttributedAsOfAnswer {
  sameBaseDifferentAttribution
  some f: Fact, cutoff: Moment |
    notesAttributedBy[Left, f, cutoff] !=
      notesAttributedBy[Right, f, cutoff]
}

assert FactAndRecordingTimesDetermineAttributionView {
  all f: Fact, cutoff: Moment |
    notesAttributedBy[Left, f, cutoff] =
      notesAttributedBy[Right, f, cutoff]
}

assert AttributedTimeDeterminesAttributionView {
  (sameWithoutAttributedTime[Left, Right] and
   Left.attributedAt = Right.attributedAt) implies
    all f: Fact, cutoff: Moment |
      notesAttributedBy[Left, f, cutoff] =
        notesAttributedBy[Right, f, cutoff]
}

run sameBaseDifferentAttribution
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

run contemporaneousVersusLaterExists
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

run sameBaseDifferentAttributedAsOfAnswer
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

check FactAndRecordingTimesDetermineAttributionView
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

check AttributedTimeDeterminesAttributionView
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

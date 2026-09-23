module experiments/observation_325_interpretation_attribution_unknown

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
  attributedAt: Note -> lone Moment
}

one sig Left, Right extends World {}

pred atOrBefore[a, b: Moment] {
  a = b or time/lt[a, b]
}

pred sameWithoutAttribution[a, b: World] {
  a.factTime = b.factTime
  a.noteText = b.noteText
  a.subject = b.subject
  a.recordedAt = b.recordedAt
}

fact SameBaseEvidence {
  sameWithoutAttribution[Left, Right]
}

fact ExplicitAttributionWindow {
  all w: World, n: Note |
    some n.(w.attributedAt) implies
      let f = n.(w.subject),
          ft = f.(w.factTime),
          at = n.(w.attributedAt),
          rt = n.(w.recordedAt) | {
        atOrBefore[ft, at]
        atOrBefore[at, rt]
      }
}

fun explicitlyAttributedBy[w: World, f: Fact, cutoff: Moment]: set Note {
  { n: Note |
      n.(w.subject) = f and
      some n.(w.attributedAt) and
      atOrBefore[n.(w.attributedAt), cutoff]
  }
}

pred unknownVersusFactTimeExists {
  some n: Note | {
    no n.(Left.attributedAt)
    let f = n.(Right.subject) |
      n.(Right.attributedAt) = f.(Right.factTime)
  }
}

pred unknownVersusRecordedTimeExists {
  some n: Note | {
    no n.(Left.attributedAt)
    n.(Right.attributedAt) = n.(Right.recordedAt)
  }
}

pred unknownChangesExplicitAsOfAnswer {
  some n: Note, f: Fact, cutoff: Moment | {
    n.(Left.subject) = f
    n.(Right.subject) = f
    no n.(Left.attributedAt)
    some n.(Right.attributedAt)
    atOrBefore[n.(Right.attributedAt), cutoff]
    explicitlyAttributedBy[Left, f, cutoff] !=
      explicitlyAttributedBy[Right, f, cutoff]
  }
}

// Probe the tempting default: treat missing attribution as Fact time.
pred defaultToFactCollapsesDistinctMeaning {
  some n: Note | {
    no n.(Left.attributedAt)
    let f = n.(Right.subject) |
      n.(Right.attributedAt) = f.(Right.factTime)
  }
}

// Probe the other tempting default: treat missing attribution as recording time.
pred defaultToRecordedCollapsesDistinctMeaning {
  some n: Note | {
    no n.(Left.attributedAt)
    n.(Right.attributedAt) = n.(Right.recordedAt)
  }
}

assert BaseEvidenceDeterminesAttributionPresence {
  all n: Note |
    (some n.(Left.attributedAt)) iff (some n.(Right.attributedAt))
}

assert EqualOptionalAttributionDeterminesExplicitAsOfView {
  Left.attributedAt = Right.attributedAt implies
    all f: Fact, cutoff: Moment |
      explicitlyAttributedBy[Left, f, cutoff] =
        explicitlyAttributedBy[Right, f, cutoff]
}

run unknownVersusFactTimeExists
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

run unknownVersusRecordedTimeExists
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

run unknownChangesExplicitAsOfAnswer
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

run defaultToFactCollapsesDistinctMeaning
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

run defaultToRecordedCollapsesDistinctMeaning
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

check BaseEvidenceDeterminesAttributionPresence
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

check EqualOptionalAttributionDeterminesExplicitAsOfView
  for exactly 2 World, exactly 3 Moment, exactly 1 Text,
      exactly 1 Fact, exactly 1 Note

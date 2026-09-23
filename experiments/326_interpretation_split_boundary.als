module experiments/observation_326_interpretation_split_boundary

open util/ordering[Moment] as time

sig Moment {}
sig Text {}
sig Fact {}
sig Note {}

sig Interpretation {
  note: one Note,
  text: one Text,
  subject: one Fact,
  recordedAt: one Moment,
  attributedAt: lone Moment
}

sig Carrier {
  householdFacts: set Fact,
  noteEvents: set Note,
  descriptions: Note -> lone Text,
  subjects: Note -> lone Fact,
  recorded: Note -> lone Moment,
  attributed: Note -> lone Moment
}

pred atOrBefore[a, b: Moment] {
  a = b or time/lt[a, b]
}

pred admitted[c: Carrier] {
  all n: Note | {
    (some n.(c.descriptions)) implies n in c.noteEvents
    (some n.(c.subjects)) implies n in c.noteEvents
    (some n.(c.recorded)) implies n in c.noteEvents
    (some n.(c.attributed)) implies n in c.noteEvents
  }

  all n: c.noteEvents | {
    one n.(c.descriptions)
    one n.(c.subjects)
    one n.(c.recorded)
    n.(c.subjects) in c.householdFacts
    some n.(c.attributed) implies
      atOrBefore[n.(c.attributed), n.(c.recorded)]
  }
}

pred represents[c: Carrier, i: Interpretation] {
  admitted[c]
  i.note in c.noteEvents
  i.text = i.note.(c.descriptions)
  i.subject = i.note.(c.subjects)
  i.recordedAt = i.note.(c.recorded)
  i.attributedAt = i.note.(c.attributed)
}

fun notesForSubject[c: Carrier, f: Fact]: set Note {
  { n: c.noteEvents | n.(c.subjects) = f }
}

fun notesKnownBy[c: Carrier, f: Fact, cutoff: Moment]: set Note {
  { n: c.noteEvents |
      n.(c.subjects) = f and
      atOrBefore[n.(c.recorded), cutoff]
  }
}

fun notesExplicitlyAttributedBy[c: Carrier, f: Fact, cutoff: Moment]: set Note {
  { n: c.noteEvents |
      n.(c.subjects) = f and
      some n.(c.attributed) and
      atOrBefore[n.(c.attributed), cutoff]
  }
}

pred completeSingleInterpretationCarrierExists {
  some c: Carrier, i: Interpretation | {
    c.noteEvents = i.note
    c.householdFacts = i.subject
    represents[c, i]
  }
}

pred unknownAttributionCarrierExists {
  some c: Carrier, i: Interpretation | {
    no i.attributedAt
    represents[c, i]
  }
}

pred rawOrphanSubjectExists {
  some c: Carrier, n: Note, f: Fact, t: Text, m: Moment | {
    n in c.noteEvents
    n.(c.descriptions) = t
    n.(c.subjects) = f
    n.(c.recorded) = m
    f not in c.householdFacts
    not admitted[c]
  }
}

pred rawOrphanNoteMetadataExists {
  some c: Carrier, n: Note, f: Fact, m: Moment | {
    n not in c.noteEvents
    n.(c.subjects) = f
    n.(c.recorded) = m
    not admitted[c]
  }
}

pred rawMissingDescriptionExists {
  some c: Carrier, n: Note, f: Fact, m: Moment | {
    n in c.noteEvents
    f in c.householdFacts
    n.(c.subjects) = f
    n.(c.recorded) = m
    no n.(c.descriptions)
    not admitted[c]
  }
}

assert RepresentationIsFieldFaithful {
  all c: Carrier, disj left, right: Interpretation |
    (represents[c, left] and represents[c, right] and left.note = right.note)
      implies {
        left.text = right.text
        left.subject = right.subject
        left.recordedAt = right.recordedAt
        left.attributedAt = right.attributedAt
      }
}

assert AdmittedCarrierClosesSubjects {
  all c: Carrier | admitted[c] implies
    all n: c.noteEvents | n.(c.subjects) in c.householdFacts
}

assert AdmittedCarrierClosesNoteMetadata {
  all c: Carrier | admitted[c] implies
    all n: Note - c.noteEvents | {
      no n.(c.descriptions)
      no n.(c.subjects)
      no n.(c.recorded)
      no n.(c.attributed)
    }
}

run completeSingleInterpretationCarrierExists
  for exactly 3 Moment, exactly 2 Text, exactly 2 Fact,
      exactly 2 Note, exactly 1 Interpretation, exactly 1 Carrier

run unknownAttributionCarrierExists
  for exactly 3 Moment, exactly 2 Text, exactly 2 Fact,
      exactly 2 Note, exactly 1 Interpretation, exactly 1 Carrier

run rawOrphanSubjectExists
  for exactly 3 Moment, exactly 2 Text, exactly 2 Fact,
      exactly 2 Note, exactly 0 Interpretation, exactly 1 Carrier

run rawOrphanNoteMetadataExists
  for exactly 3 Moment, exactly 2 Text, exactly 2 Fact,
      exactly 2 Note, exactly 0 Interpretation, exactly 1 Carrier

run rawMissingDescriptionExists
  for exactly 3 Moment, exactly 2 Text, exactly 2 Fact,
      exactly 2 Note, exactly 0 Interpretation, exactly 1 Carrier

check RepresentationIsFieldFaithful
  for exactly 3 Moment, exactly 2 Text, exactly 2 Fact,
      exactly 2 Note, exactly 2 Interpretation, exactly 1 Carrier

check AdmittedCarrierClosesSubjects
  for exactly 3 Moment, exactly 2 Text, exactly 2 Fact,
      exactly 2 Note, exactly 0 Interpretation, exactly 1 Carrier

check AdmittedCarrierClosesNoteMetadata
  for exactly 3 Moment, exactly 2 Text, exactly 2 Fact,
      exactly 2 Note, exactly 0 Interpretation, exactly 1 Carrier

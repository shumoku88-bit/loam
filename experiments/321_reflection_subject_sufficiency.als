module experiments/observation_321_reflection_subject_sufficiency

sig Text {}
sig Fact {}
sig Note {}
sig Attention {}

abstract sig World {
  factDescription: Fact -> lone Text,
  noteText: Note -> one Text,
  attentionContext: Attention -> one Text,

  // Candidate information that current EventDescription / personal-memory text /
  // Attention context does not retain.
  subject: Note -> lone Fact
}

one sig Left, Right extends World {}

fun descriptionOf[w: World, f: Fact]: set Text {
  f.(w.factDescription)
}

fun textOfNote[w: World, n: Note]: one Text {
  n.(w.noteText)
}

fun contextOf[w: World, a: Attention]: one Text {
  a.(w.attentionContext)
}

fun subjectOf[w: World, n: Note]: set Fact {
  n.(w.subject)
}

fun notesFor[w: World, f: Fact]: set Note {
  { n: Note | f in subjectOf[w, n] }
}

pred sameExistingEvidence[a, b: World] {
  a.factDescription = b.factDescription
  a.noteText = b.noteText
  a.attentionContext = b.attentionContext
}

fact ClosedCandidateSubjects {
  all w: World, n: Note |
    one subjectOf[w, n]
}

// Make the two household facts distinguishable from their retained descriptions.
// The ambiguity below therefore does not depend on two anonymous Facts being
// interchangeable.
fact RecognizableFacts {
  all f: Fact | one descriptionOf[Left, f]
  all disj f1, f2: Fact |
    descriptionOf[Left, f1] != descriptionOf[Left, f2]
}

// The two worlds are deliberately identical under evidence that production LOAM
// or the existing PersonalSemanticMemory example can already retain here.
fact ExistingEvidenceCollision {
  sameExistingEvidence[Left, Right]
}

// Even copying the note text into ordinary Attention does not add subject
// semantics: it remains the same opaque human text in both worlds.
fact AttentionCopiesNoteText {
  all w: World, n: Note, a: Attention |
    textOfNote[w, n] = contextOf[w, a]
}

pred sameExistingEvidenceDifferentSubjectAnswer {
  Left.subject != Right.subject
  some f: Fact |
    notesFor[Left, f] != notesFor[Right, f]
}

pred attentionCopyStillCannotSelectSubject {
  some n: Note, a: Attention | {
    textOfNote[Left, n] = contextOf[Left, a]
    textOfNote[Right, n] = contextOf[Right, a]
  }
  Left.subject != Right.subject
}

assert ExistingEvidenceDeterminesSubject {
  sameExistingEvidence[Left, Right] implies
    Left.subject = Right.subject
}

assert ExplicitSubjectDeterminesPerFactQuery {
  Left.subject = Right.subject implies
    all f: Fact |
      notesFor[Left, f] = notesFor[Right, f]
}

run sameExistingEvidenceDifferentSubjectAnswer
  for exactly 2 World, exactly 2 Fact, exactly 1 Note,
      exactly 1 Attention, exactly 3 Text

run attentionCopyStillCannotSelectSubject
  for exactly 2 World, exactly 2 Fact, exactly 1 Note,
      exactly 1 Attention, exactly 3 Text

check ExistingEvidenceDeterminesSubject
  for exactly 2 World, exactly 2 Fact, exactly 1 Note,
      exactly 1 Attention, exactly 3 Text

check ExplicitSubjectDeterminesPerFactQuery
  for exactly 2 World, exactly 2 Fact, exactly 1 Note,
      exactly 1 Attention, exactly 3 Text

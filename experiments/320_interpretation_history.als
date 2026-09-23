module experiments/observation_320_interpretation_history

open util/ordering[Moment] as time

abstract sig Moment {}

abstract sig Stance {}
one sig Supports, Rejects extends Stance {}

abstract sig Meaning {}
one sig OneMeaning extends Meaning {}

sig Fact {
  occurredAt: one Moment
}

sig Reflection {
  subject: one Fact,
  meaning: one Meaning,
  stance: one Stance,
  recordedAt: one Moment,
  attributedAt: lone Moment
}

abstract sig Snapshot {
  facts: set Fact,
  reflections: set Reflection
}
one sig Before, After extends Snapshot {}

fact ReflectionSubjectsArePresent {
  all s: Snapshot |
    all r: s.reflections |
      r.subject in s.facts
}

// attributedAt is only what a later reflection attributes to an earlier moment.
// It is not promoted into a Fact and may equal recordedAt for a present-tense
// reflection, but it may not lie in the future of the recording.
fact AttributionIsNotFuture {
  all r: Reflection |
    some r.attributedAt implies
      (r.attributedAt = r.recordedAt or
       time/lt[r.attributedAt, r.recordedAt])
}

pred weakReflectionAppend[a, b: Snapshot] {
  a.reflections in b.reflections
  some b.reflections - a.reflections
}

// The strong candidate law is intentionally explicit about the Fact frame.
// Adding interpretation evidence is not allowed to rewrite what happened.
pred reflectionAppend[a, b: Snapshot] {
  weakReflectionAppend[a, b]
  a.facts = b.facts
}

fun latestFor[s: Snapshot, f: Fact]: set Reflection {
  {
    r: s.reflections |
      r.subject = f and
      no later: s.reflections |
        later.subject = f and
        time/lt[r.recordedAt, later.recordedAt]
  }
}

pred retrospectiveReflectionExists {
  reflectionAppend[Before, After]
  some f: Before.facts, r: After.reflections - Before.reflections | {
    r.subject = f
    time/lt[f.occurredAt, r.recordedAt]
  }
}

pred opposedReflectionAppendExists {
  reflectionAppend[Before, After]
  some old: Before.reflections,
       fresh: After.reflections - Before.reflections | {
    old.subject = fresh.subject
    old.meaning = fresh.meaning
    old.stance != fresh.stance
  }
}

// A later recording may say "I now remember that, at the time of the event,
// I saw it this way" without turning that attribution into an earlier record.
pred rememberedPastAttributionExists {
  reflectionAppend[Before, After]
  some r: After.reflections - Before.reflections | {
    some r.attributedAt
    r.attributedAt = r.subject.occurredAt
    time/lt[r.attributedAt, r.recordedAt]
  }
}

// Time alone does not force one current interpretation. Two opposed
// reflections can be equally latest for the same Fact.
pred ambiguousLatestReflectionExists {
  reflectionAppend[Before, After]
  some f: After.facts,
       old: Before.reflections,
       fresh: After.reflections - Before.reflections | {
    old.subject = f
    fresh.subject = f
    old in latestFor[After, f]
    fresh in latestFor[After, f]
    old.meaning = fresh.meaning
    old.stance != fresh.stance
    old.recordedAt = fresh.recordedAt
  }
}

// This is a deliberate counterexample probe. If "append a reflection" only
// means monotone Reflection membership, Fact preservation is not automatic.
pred weakAppendCanRewriteFacts {
  weakReflectionAppend[Before, After]
  Before.facts != After.facts
}

assert ReflectionAppendPreservesFacts {
  reflectionAppend[Before, After] implies
    Before.facts = After.facts
}

assert ReflectionAppendPreservesPriorReflections {
  reflectionAppend[Before, After] implies
    Before.reflections in After.reflections
}

assert ReflectionAppendKeepsSubjectsPresent {
  reflectionAppend[Before, After] implies
    all r: After.reflections |
      r.subject in After.facts
}

run retrospectiveReflectionExists
  for exactly 3 Moment, exactly 2 Snapshot, exactly 2 Stance,
      exactly 1 Meaning, exactly 2 Fact, exactly 2 Reflection

run opposedReflectionAppendExists
  for exactly 3 Moment, exactly 2 Snapshot, exactly 2 Stance,
      exactly 1 Meaning, exactly 1 Fact, exactly 2 Reflection

run rememberedPastAttributionExists
  for exactly 3 Moment, exactly 2 Snapshot, exactly 2 Stance,
      exactly 1 Meaning, exactly 1 Fact, exactly 1 Reflection

run ambiguousLatestReflectionExists
  for exactly 3 Moment, exactly 2 Snapshot, exactly 2 Stance,
      exactly 1 Meaning, exactly 1 Fact, exactly 2 Reflection

run weakAppendCanRewriteFacts
  for exactly 3 Moment, exactly 2 Snapshot, exactly 2 Stance,
      exactly 1 Meaning, exactly 2 Fact, exactly 1 Reflection

check ReflectionAppendPreservesFacts
  for exactly 3 Moment, exactly 2 Snapshot, exactly 2 Stance,
      exactly 1 Meaning, exactly 2 Fact, exactly 2 Reflection

check ReflectionAppendPreservesPriorReflections
  for exactly 3 Moment, exactly 2 Snapshot, exactly 2 Stance,
      exactly 1 Meaning, exactly 2 Fact, exactly 2 Reflection

check ReflectionAppendKeepsSubjectsPresent
  for exactly 3 Moment, exactly 2 Snapshot, exactly 2 Stance,
      exactly 1 Meaning, exactly 2 Fact, exactly 2 Reflection

module experiments/observation_115_scheduled_subject_locus

sig ScheduledId {}
one sig S1 extends ScheduledId {}

sig Day {}
one sig D1 extends Day {}

sig Amount {}
one sig A1 extends Amount {}

abstract sig Locus {}
one sig Wallet, Communications extends Locus {}

abstract sig Service extends Locus {}
one sig NetworkService, MobileService extends Service {}

sig ClassifiedRecord {
  id: one ScheduledId,
  day: one Day,
  source: one Locus,
  amount: one Amount,
  destination: one Locus
}

sig DirectRecord {
  id: one ScheduledId,
  day: one Day,
  source: one Locus,
  amount: one Amount,
  destination: one Locus
}

sig World {
  subject: one Service,
  classified: one ClassifiedRecord,
  direct: one DirectRecord
}

one sig Left, Right extends World {}

fun classOf[s: Service]: one Locus {
  Communications
}

fact RecordShape {
  all w: World | {
    w.classified.id = S1
    w.classified.day = D1
    w.classified.source = Wallet
    w.classified.amount = A1
    w.classified.destination = classOf[w.subject]

    w.direct.id = S1
    w.direct.day = D1
    w.direct.source = Wallet
    w.direct.amount = A1
    w.direct.destination = w.subject
  }
}

pred sameClassifiedCanonical[a, b: World] {
  a.classified.id = b.classified.id
  a.classified.day = b.classified.day
  a.classified.source = b.classified.source
  a.classified.amount = b.classified.amount
  a.classified.destination = b.classified.destination
}

pred sameDirectCanonical[a, b: World] {
  a.direct.id = b.direct.id
  a.direct.day = b.direct.day
  a.direct.source = b.direct.source
  a.direct.amount = b.direct.amount
  a.direct.destination = b.direct.destination
}

pred classifiedCollapsesDistinctSubjects {
  Left.subject != Right.subject
  sameClassifiedCanonical[Left, Right]
}

pred directKeepsDistinctSubjects {
  Left.subject != Right.subject
  not sameDirectCanonical[Left, Right]
}

assert ClassifiedCanonicalDeterminesSubject {
  all a, b: World |
    sameClassifiedCanonical[a, b] implies a.subject = b.subject
}

assert DirectCanonicalDeterminesSubject {
  all a, b: World |
    sameDirectCanonical[a, b] implies a.subject = b.subject
}

run classifiedCollapsesDistinctSubjects for exactly 1 ScheduledId, exactly 1 Day, exactly 1 Amount, exactly 4 Locus, exactly 2 Service, exactly 2 ClassifiedRecord, exactly 2 DirectRecord, exactly 2 World
run directKeepsDistinctSubjects for exactly 1 ScheduledId, exactly 1 Day, exactly 1 Amount, exactly 4 Locus, exactly 2 Service, exactly 2 ClassifiedRecord, exactly 2 DirectRecord, exactly 2 World

check ClassifiedCanonicalDeterminesSubject for exactly 1 ScheduledId, exactly 1 Day, exactly 1 Amount, exactly 4 Locus, exactly 2 Service, exactly 2 ClassifiedRecord, exactly 2 DirectRecord, exactly 2 World
check DirectCanonicalDeterminesSubject for exactly 1 ScheduledId, exactly 1 Day, exactly 1 Amount, exactly 4 Locus, exactly 2 Service, exactly 2 ClassifiedRecord, exactly 2 DirectRecord, exactly 2 World

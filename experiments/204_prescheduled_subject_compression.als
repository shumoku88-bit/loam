module experiments/observation_204_prescheduled_subject_compression

sig Subject {}
sig Amount {}
sig Due {}

one sig S1, S2 extends Subject {}
one sig A1, A2 extends Amount {}
one sig D1, D2 extends Due {}

abstract sig World {
  known: set Subject,
  amount: Subject -> lone Amount,
  due: Subject -> lone Due
}

one sig Left, Right extends World {}

fact AttachmentsRequireKnownSubject {
  all w: World, s: Subject |
    (some w.amount[s] or some w.due[s]) implies s in w.known
}

fun amountPool[w: World]: set Amount {
  w.amount[Subject]
}

fun duePool[w: World]: set Due {
  w.due[Subject]
}

fun completePairs[w: World]: Subject -> Amount -> Due {
  { s: Subject, a: Amount, d: Due |
      s in w.known and w.amount[s] = a and w.due[s] = d }
}

pred representativeExistenceThenAmountBeforeDue {
  Left.known = S1
  no Left.amount[S1]
  no Left.due[S1]

  Right.known = S1
  Right.amount[S1] = A1
  no Right.due[S1]
}

pred sameAmountDifferentDueKnowledge {
  Left.known = S1
  Left.amount[S1] = A1
  no Left.due[S1]

  Right.known = S1
  Right.amount[S1] = A1
  Right.due[S1] = D1
}

pred sameLoosePoolsDifferentPairing {
  Left.known = S1 + S2
  Right.known = S1 + S2

  Left.amount = (S1 -> A1) + (S2 -> A2)
  Right.amount = (S1 -> A1) + (S2 -> A2)

  Left.due = (S1 -> D1) + (S2 -> D2)
  Right.due = (S1 -> D2) + (S2 -> D1)

  amountPool[Left] = amountPool[Right]
  duePool[Left] = duePool[Right]
  completePairs[Left] != completePairs[Right]
}

assert AttachmentsDetermineKnownSubjects {
  Left.amount = Right.amount and Left.due = Right.due implies
    Left.known = Right.known
}

assert KnownAndAmountDetermineDuePlacement {
  Left.known = Right.known and Left.amount = Right.amount implies
    Left.due = Right.due
}

assert LoosePoolsDetermineSubjectPairing {
  Left.known = Right.known and
  amountPool[Left] = amountPool[Right] and
  duePool[Left] = duePool[Right] implies
    completePairs[Left] = completePairs[Right]
}

assert SubjectAttachedCarrierDeterminesSelectedViews {
  Left.known = Right.known and
  Left.amount = Right.amount and
  Left.due = Right.due implies
    (amountPool[Left] = amountPool[Right] and
     duePool[Left] = duePool[Right] and
     completePairs[Left] = completePairs[Right])
}

run representativeExistenceThenAmountBeforeDue for exactly 2 Subject, exactly 2 Amount, exactly 2 Due, exactly 2 World
run sameAmountDifferentDueKnowledge for exactly 2 Subject, exactly 2 Amount, exactly 2 Due, exactly 2 World
run sameLoosePoolsDifferentPairing for exactly 2 Subject, exactly 2 Amount, exactly 2 Due, exactly 2 World
check AttachmentsDetermineKnownSubjects for exactly 2 Subject, exactly 2 Amount, exactly 2 Due, exactly 2 World
check KnownAndAmountDetermineDuePlacement for exactly 2 Subject, exactly 2 Amount, exactly 2 Due, exactly 2 World
check LoosePoolsDetermineSubjectPairing for exactly 2 Subject, exactly 2 Amount, exactly 2 Due, exactly 2 World
check SubjectAttachedCarrierDeterminesSelectedViews for exactly 2 Subject, exactly 2 Amount, exactly 2 Due, exactly 2 World

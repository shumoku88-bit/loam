module experiments/observation_327_interpretation_subject_correction

sig Event {}
sig Note {
  storedSubject: one Event
}

sig World {
  replacement: Event -> lone Event
}

pred admitted[w: World] {
  no iden & ^(w.replacement)
  all e: Event | lone e.~(w.replacement)
}

fun reachable[w: World, e: Event]: set Event {
  e.*(w.replacement)
}

fun terminal[w: World, e: Event]: set Event {
  { t: reachable[w, e] | no t.(w.replacement) }
}

fun currentSubject[w: World, n: Note]: set Event {
  terminal[w, n.storedSubject]
}

pred untouchedSubjectStaysItself {
  some w: World, n: Note | {
    admitted[w]
    no n.storedSubject.(w.replacement)
    currentSubject[w, n] = n.storedSubject
  }
}

pred correctedSubjectProjectsToTerminal {
  some w: World, n: Note, disj first, second: Event | {
    admitted[w]
    n.storedSubject -> first in w.replacement
    first -> second in w.replacement
    no second.(w.replacement)
    currentSubject[w, n] = second
    n.storedSubject != second
  }
}

pred malformedMergeExists {
  some w: World, disj left, right, successor: Event | {
    left -> successor in w.replacement
    right -> successor in w.replacement
    not admitted[w]
  }
}

pred malformedCycleExists {
  some w: World, disj left, right: Event | {
    left -> right in w.replacement
    right -> left in w.replacement
    not admitted[w]
  }
}

assert AdmittedCurrentSubjectIsUnique {
  all w: World, n: Note |
    admitted[w] implies one currentSubject[w, n]
}

assert ProjectionNeverRewritesStoredSubject {
  all w: World, n: Note |
    admitted[w] implies n.storedSubject in reachable[w, n.storedSubject]
}

assert CurrentSubjectIsReachableFromStoredSubject {
  all w: World, n: Note |
    admitted[w] implies currentSubject[w, n] in reachable[w, n.storedSubject]
}

run untouchedSubjectStaysItself
  for exactly 4 Event, exactly 1 Note, exactly 1 World

run correctedSubjectProjectsToTerminal
  for exactly 4 Event, exactly 1 Note, exactly 1 World

run malformedMergeExists
  for exactly 4 Event, exactly 0 Note, exactly 1 World

run malformedCycleExists
  for exactly 4 Event, exactly 0 Note, exactly 1 World

check AdmittedCurrentSubjectIsUnique
  for exactly 5 Event, exactly 2 Note, exactly 2 World

check ProjectionNeverRewritesStoredSubject
  for exactly 5 Event, exactly 2 Note, exactly 2 World

check CurrentSubjectIsReachableFromStoredSubject
  for exactly 5 Event, exactly 2 Note, exactly 2 World

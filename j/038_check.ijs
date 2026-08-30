NB. Observation 038: can exact as-of frontier meaning be represented by change points?
NB.
NB. Knowledge times are t1..t6.  c0 is the implicit frontier at t0.
NB. Event codes:
NB.   0 = no new interpretation
NB.   1 = kA, correction of c0
NB.   2 = kB, independent correction of c0
NB.   3 = r0, whole-frontier resolution of {kA,kB}
NB.
NB. Each interpretation may occur at most once.  r0 may occur only after both
NB. sibling Corrections have already been learned.

allSchedules =: (6 $ 4) #: i. 4 ^ 6

admissible =: 3 : 0
  if. 1 < +/ y = 1 do. 0 return. end.
  if. 1 < +/ y = 2 do. 0 return. end.
  if. 1 < +/ y = 3 do. 0 return. end.

  if. 3 e. y do.
    rpos =. y i. 3
    beforeR =. rpos {. y
    if. -. (1 e. beforeR) *. (2 e. beforeR) do. 0 return. end.
  end.

  1
)

histories =: (admissible"1 allSchedules) # allSchedules

NB. Frontier codes:
NB.   0 = {c0}
NB.   1 = {kA}
NB.   2 = {kB}
NB.   3 = {kA,kB}
NB.   4 = {r0}
frontier =: 3 : 0
  hasA =. 1 e. y
  hasB =. 2 e. y
  hasR =. 3 e. y
  if. hasR do. 4 return. end.
  if. hasA *. hasB do. 3 return. end.
  if. hasA do. 1 return. end.
  if. hasB do. 2 return. end.
  0
)

frontierTimeline =: 3 : 0
  out =. i. 0
  for_n. 1 + i. # y do.
    out =. out , frontier n {. y
  end.
  out
)

dense =: frontierTimeline"1 histories

NB. Fixed-width experimental encoding of a variable-length change-point list.
NB. _1 means "no change here".  A real representation would retain only the
NB. non-_1 pairs (knowledge time, new frontier).
encodeChangePoints =: 3 : 0
  prior =. 0 , }: y
  changed =. y ~: prior
  (changed * (1 + y)) - 1
)

decodeChangePoints =: 3 : 0
  state =. 0
  out =. i. 0
  for_v. y do.
    if. _1 ~: v do. state =. v end.
    out =. out , state
  end.
  out
)

encoded =: encodeChangePoints"1 dense
decoded =: decodeChangePoints"1 encoded

changeCounts =: +/"1 _1 ~: encoded
eventCounts =: +/"1 histories ~: 0

classSizes =: 3 : 0
  /:~ #/.~ y
)

irredundant =: 3 : 0
  cp =. y
  target =. decodeChangePoints cp
  for_i. i. # cp do.
    if. _1 ~: i { cp do.
      dropped =. _1 i} cp
      assert. -. target -: decodeChangePoints dropped
    end.
  end.
  1
)

smoutput 'diagnostic event records:'
smoutput +/ eventCounts
smoutput 'diagnostic change-point records:'
smoutput +/ changeCounts
smoutput 'diagnostic event-count classes:'
smoutput classSizes eventCounts
smoutput 'diagnostic change-count classes:'
smoutput classSizes changeCounts

checkObservation =: 3 : 0
  NB. Six knowledge slots with at most three semantic interpretation changes
  NB. produce 83 admissible schedules in this bounded model.
  assert. 83 = # histories
  assert. 83 = # ~. dense

  NB. Change points preserve every exact as-of frontier answer.
  assert. dense -: decoded
  assert. 83 = # ~. encoded

  NB. There are 498 dense frontier cells but only 192 actual change records.
  NB. This compares record counts, not bytes: each sparse record must also carry
  NB. its knowledge coordinate.
  assert. 498 = */ $ dense
  assert. 192 = +/ changeCounts
  assert. 1 12 30 40 -: classSizes changeCounts

  NB. In this clean model every admitted interpretation changes the frontier,
  NB. so change-point count equals semantic event count.  Change points remove
  NB. idle time cells; they do not magically erase meaningful changes.
  assert. changeCounts -: eventCounts

  NB. Relative to the vocabulary asking the exact frontier at every knowledge
  NB. time, every emitted change point is necessary: dropping any one changes
  NB. at least one answer in the reconstructed timeline.
  assert. *./ irredundant"1 encoded

  1
)

checkObservation 0

smoutput 'Observation 038 / change-point frontier representation'
smoutput 'admissible six-slot histories:'
smoutput # histories
smoutput 'dense frontier cells:'
smoutput */ $ dense
smoutput 'change-point records:'
smoutput +/ changeCounts
smoutput 'histories by change-point count 0..3:'
smoutput classSizes changeCounts
smoutput 'distinct dense timelines:'
smoutput # ~. dense
smoutput 'distinct change-point encodings:'
smoutput # ~. encoded
smoutput 'round trip exact:'
smoutput dense -: decoded
smoutput 'all emitted change points irredundant:'
smoutput *./ irredundant"1 encoded

exit 0

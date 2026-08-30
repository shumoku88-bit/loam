NB. Observation 037: how much bitemporal frontier history must be remembered?
NB.
NB. Each row is one admissible learned-event schedule for knowledge times t1..t3.
NB. Event codes:
NB.   0 = no new interpretation
NB.   1 = kA, correction of c0
NB.   2 = kB, correction of c0
NB.   3 = r0, whole-frontier resolution of {kA,kB}
NB.
NB. c0 is already known at t0.  kA and kB may arrive independently.  r0 may
NB. appear only in the two schedules where both corrections were learned first.

histories =: 15 3 $ \
  0 0 0  \
  1 0 0  \
  0 1 0  \
  0 0 1  \
  2 0 0  \
  0 2 0  \
  0 0 2  \
  1 2 0  \
  1 0 2  \
  2 1 0  \
  0 1 2  \
  2 0 1  \
  0 2 1  \
  1 2 3  \
  2 1 3

NB. Frontier codes:
NB.   0 = {c0}
NB.   1 = {kA}
NB.   2 = {kB}
NB.   3 = {kA,kB}  unresolved conflict
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

zeros =: 15 $ 0
prefix1 =: (0 {"1 histories) ,. zeros ,. zeros
prefix2 =: (0 1 {"1 histories) ,. zeros

f1 =: frontier"1 prefix1
f2 =: frontier"1 prefix2
f3 =: frontier"1 histories

NB. A coarser observer sees only whether each knowledge-time frontier is a
NB. conflict.  t0 is fixed at {c0}, so it adds no distinction in this scope.
kindTimeline =: (3 = f1) ,. (3 = f2) ,. (3 = f3)

NB. Nested future vocabularies.  V0 is empty.  V1 asks only whether the current
NB. frontier is conflict.  V2 asks the exact current frontier.  V3 also asks the
NB. settled/conflict kind at every knowledge time.  V4 additionally asks the
NB. exact frontier at t2.  V5 additionally asks the exact frontier at t1,
NB. completing the exact t1..t3 frontier timeline.
sig0 =: 15 1 $ 0
sig1 =: ,. 3 = f3
sig2 =: ,. f3
sig3 =: f3 ,. kindTimeline
sig4 =: f3 ,. f2 ,. kindTimeline
sig5 =: f3 ,. f2 ,. f1

classSizes =: 3 : 0
  /:~ #/.~ y
)

counts =: (# ~. sig0) , (# ~. sig1) , (# ~. sig2) , (# ~. sig3) , (# ~. sig4) , (# ~. sig5)
kindOnlyCount =: # ~. kindTimeline

checkObservation =: 3 : 0
  assert. 15 = # histories
  assert. 1 2 5 6 9 15 -: counts

  assert. (,15) -: classSizes sig0
  assert. 6 9 -: classSizes sig1
  assert. 1 2 3 3 6 -: classSizes sig2
  assert. 1 2 2 3 3 4 -: classSizes sig3
  assert. 1 1 1 2 2 2 2 2 2 -: classSizes sig4
  assert. (15 # 1) -: classSizes sig5

  NB. If the future asks only settled/conflict through time, four classes are
  NB. enough even though exact frontier identity yields fifteen timelines.
  assert. 4 = kindOnlyCount

  NB. Current exact frontier alone cannot recover an earlier exact frontier.
  NB. A@t1 and A@t2 both end at {kA}, but differ at t1.
  assert. (1 { f3) = (2 { f3)
  assert. -. ((1 { f1) = (2 { f1))

  NB. Even exact t2 + current frontier does not recover exact t1.  The two
  NB. arrival orders both have {kA,kB} at t2/current but different t1 tips.
  assert. (7 { f2) = (9 { f2)
  assert. (7 { f3) = (9 { f3)
  assert. -. ((7 { f1) = (9 { f1))

  NB. In this deliberately small world every admitted event changes the exact
  NB. frontier, so the complete exact frontier timeline distinguishes all 15
  NB. schedules.  This is a bounded result, not a global no-compression theorem.
  assert. 15 = # ~. sig5

  1
)

checkObservation 0

smoutput 'Observation 037 / bitemporal memory quotient'
smoutput 'admissible histories:'
smoutput # histories
smoutput 'nested class counts V0..V5:'
smoutput counts
smoutput 'kind-only full timeline classes:'
smoutput kindOnlyCount
smoutput 'V2 current exact frontier class sizes:'
smoutput classSizes sig2
smoutput 'V4 current+t2 exact class sizes:'
smoutput classSizes sig4
smoutput 'V5 full exact frontier timeline class sizes:'
smoutput classSizes sig5

exit 0

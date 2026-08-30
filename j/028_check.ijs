NB. Observation 028: richer future vocabulary refines remembered provenance.
NB.
NB. Each row is one possible Origin provenance state over three neutral marks:
NB.   A B Hidden
NB.
NB. The future vocabulary grows by adding acceptance questions.  Two origins
NB. are observationally equivalent when they return the same answer vector for
NB. every question currently present in the vocabulary.

states =: 8 3 $ 0 0 0  0 0 1  0 1 0  0 1 1  1 0 0  1 0 1  1 1 0  1 1 1

NB. Return answers to five candidate future questions, one column per question:
NB.   Either(A,B), A, B, Both(A,B), Hidden
answerTable =: 3 : 0
  a =. 0 {"1 y
  b =. 1 {"1 y
  h =. 2 {"1 y
  (a +. b) ,. a ,. b ,. (a *. b) ,. h
)

answers =: answerTable states

NB. Nested future vocabularies.  sig0 represents the unique empty answer vector
NB. by a shared zero column so quotient counting remains rank-stable in J.
sig0 =: 8 1 $ 0
sig1 =: 0 {"1 answers
sig2 =: 0 1 {"1 answers
sig3 =: 0 1 2 {"1 answers
sig4 =: 0 1 2 3 {"1 answers
sig5 =: 0 1 2 3 4 {"1 answers

NB. #/.~ is the J frequency idiom: count equal items/rows, then sort sizes.
classSizes =: 3 : 0
  /:~ #/.~ y
)

counts =: (# ~. sig0) , (# ~. sig1) , (# ~. sig2) , (# ~. sig3) , (# ~. sig4) , (# ~. sig5)

checkObservation =: 3 : 0
  NB. Growing the vocabulary reveals 1, 2, 3, then 4 provenance classes.
  NB. Adding Both(A,B) is redundant once A and B are already observable.
  NB. Adding Hidden finally splits each remaining pair.
  assert. 1 2 3 4 4 8 -: counts

  assert. 8 -: classSizes sig0
  assert. 2 6 -: classSizes sig1
  assert. 2 2 4 -: classSizes sig2
  assert. 2 2 2 2 -: classSizes sig3
  assert. 2 2 2 2 -: classSizes sig4
  assert. (8 # 1) -: classSizes sig5

  NB. The fourth question adds no distinction: Both is derivable from A and B.
  assert. (3 {"1 answers) -: (1 {"1 answers) *. (2 {"1 answers)
  assert. (# ~. sig3) = (# ~. sig4)

  NB. Hidden provenance was safely merged before the Hidden question existed,
  NB. then becomes observable when that question joins the vocabulary.
  assert. (0 { sig4) -: (1 { sig4)
  assert. -. ((0 { sig5) -: (1 { sig5))

  1
)

checkObservation 0

smoutput 'Observation 028 / future vocabulary refinement'
smoutput 'class counts V0..V5:'
smoutput counts
smoutput 'V0 class sizes:'
smoutput classSizes sig0
smoutput 'V1 class sizes:'
smoutput classSizes sig1
smoutput 'V2 class sizes:'
smoutput classSizes sig2
smoutput 'V3 class sizes:'
smoutput classSizes sig3
smoutput 'V4 class sizes (redundant Both question):'
smoutput classSizes sig4
smoutput 'V5 class sizes (Hidden becomes observable):'
smoutput classSizes sig5

exit 0

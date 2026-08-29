NB. Observation 016: operation vocabulary induces the commitment quotient.

states =: 16 4 $ 0 0 0 0  0 0 0 1  0 0 1 0  0 0 1 1  0 1 0 0  0 1 0 1  0 1 1 0  0 1 1 1  1 0 0 0  1 0 0 1  1 0 1 0  1 0 1 1  1 1 0 0  1 1 0 1  1 1 1 0  1 1 1 1

NB. U0,U1 are at P0. U2,U3 are at P1.
totalEncode =: 3 : 0
  +/"1 y
)

purposeEncode =: 3 : 0
  (+/"1 (0 1 {"1 y)) ,. +/"1 (2 3 {"1 y)
)

identityEncode =: ]

classSizes =: 3 : 0
  data =. y
  if. 1 = # $ data do.
    data =. ,. data
  end.
  uniq =. ~. data
  sizes =. i. 0
  for_i. i. # uniq do.
    row =. i { uniq
    sizes =. sizes , +/ *./"1 data = row
  end.
  /:~ sizes
)

checkObservation =: 3 : 0
  total =. totalEncode states
  purpose =. purposeEncode states
  identity =. identityEncode states

  NB. Three operation vocabularies induce three quotient resolutions.
  assert. 5 = # ~. total
  assert. 9 = # ~. purpose
  assert. 16 = # ~. identity

  NB. Collision geometry in the 16 possible committed-membership states.
  assert. 1 1 4 4 6 -: classSizes total
  assert. 1 1 1 1 2 2 2 2 4 -: classSizes purpose
  assert. (16 # 1) -: classSizes identity

  NB. Refinement is strict: purpose counts preserve total count, identity preserves purpose counts.
  assert. total -: +/"1 purpose
  assert. purpose -: purposeEncode identity

  1
)

checkObservation 0

smoutput 'Observation 016 / J vocabulary quotient'
smoutput 'total-count classes:'
smoutput # ~. totalEncode states
smoutput 'purpose-count classes:'
smoutput # ~. purposeEncode states
smoutput 'identity classes:'
smoutput # ~. identityEncode states
smoutput 'total class sizes:'
smoutput classSizes totalEncode states
smoutput 'purpose class sizes:'
smoutput classSizes purposeEncode states
smoutput 'identity class sizes:'
smoutput classSizes identityEncode states

exit 0

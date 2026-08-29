NB. Observation 009: informational equivalence does not force equal update footprint.

states =: 4 2 $ 0 0  1 0  0 1  1 1

altEncode =: 3 : 0
  (0 {"1 y) ,. +/"1 y
)

hamming =: 4 : 0
  +/ x ~: y
)

profile =: 3 : 0
  alt =. altEncode y
  directOne =. 0
  directTwo =. 0
  altOne =. 0
  altTwo =. 0
  directTotal =. 0
  altTotal =. 0

  for_i. i. # y do.
    for_j. i. # y do.
      if. i ~: j do.
        dc =. (i { y) hamming (j { y)
        ac =. (i { alt) hamming (j { alt)
        directTotal =. directTotal + dc
        altTotal =. altTotal + ac
        if. 1 = dc do. directOne =. directOne + 1 end.
        if. 2 = dc do. directTwo =. directTwo + 1 end.
        if. 1 = ac do. altOne =. altOne + 1 end.
        if. 2 = ac do. altTwo =. altTwo + 1 end.
      end.
    end.
  end.

  directOne,directTwo,altOne,altTwo,directTotal,altTotal
)

checkObservation =: 3 : 0
  alt =. altEncode states

  NB. Both encodings distinguish the same four history classes.
  assert. 4 = # ~. states
  assert. 4 = # ~. alt

  NB. 00 -> 10 changes one direct coordinate, but both alternative coordinates.
  assert. 1 = (0 { states) hamming (1 { states)
  assert. 2 = (0 { alt) hamming (1 { alt)

  NB. Exhaust all 12 directed transitions between distinct states.
  assert. 8 4 6 6 16 18 -: profile states
  1
)

checkObservation 0

smoutput 'Observation 009 / J update footprint'
smoutput 'direct encoding (u0,u1):'
smoutput states
smoutput 'alternative encoding (u0,count):'
smoutput altEncode states
smoutput 'profile: direct-one direct-two alt-one alt-two direct-total alt-total'
smoutput profile states

exit 0

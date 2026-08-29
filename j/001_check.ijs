NB. Executable checks for Observation 001.
NB. Assertions are control words, so they live inside an explicit definition.

0!:0 < 'j/001_observe.ijs'

checkObservation =: 3 : 0
  assert. 5 5 5 -: timeTotals alloyWitness
  assert. 1 = conserved alloyWitness
  assert. 0 0 0 -: stablePurposeCounts alloyWitness
  assert. (2 3 $ 1 _2 1  _1 0 1) -: deltas alloyWitness

  assert. 5 5 5 -: timeTotals stableCountWorld
  assert. 1 = conserved stableCountWorld
  assert. 1 0 0 -: stablePurposeCounts stableCountWorld
  assert. (2 3 $ 0 _1 1  0 0 0) -: deltas stableCountWorld
  1
)

checkObservation 0

smoutput 'Observation 001 / J projection'
smoutput 'Alloy witness counts (Time x Purpose):'
smoutput alloyWitness
smoutput 'time totals:'
smoutput timeTotals alloyWitness
smoutput 'stable purpose counts:'
smoutput stablePurposeCounts alloyWitness
smoutput 'deltas:'
smoutput deltas alloyWitness
smoutput 'conserved: ', ": conserved alloyWitness
smoutput ''
smoutput 'Synthetic stable-count contrast:'
smoutput stableCountWorld
smoutput 'stable purpose counts:'
smoutput stablePurposeCounts stableCountWorld

exit 0

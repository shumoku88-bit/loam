NB. Executable checks for Observation 001.
NB. Keep this file separate from the exploratory lens so the lens remains
NB. useful interactively.

0!:0 < 'j/001_observe.ijs'

assert. 5 5 5 -: timeTotals sample
assert. 1 = conserved sample
assert. 1 0 0 -: stablePurposeCounts sample
assert. (2 3 $ 0 _1 1  0 0 0) -: deltas sample

smoutput 'Observation 001 / J projection'
smoutput 'sample:'
smoutput sample
smoutput 'time totals:'
smoutput timeTotals sample
smoutput 'stable purpose counts:'
smoutput stablePurposeCounts sample
smoutput 'deltas:'
smoutput deltas sample
smoutput 'conserved: ', ": conserved sample

exit 0

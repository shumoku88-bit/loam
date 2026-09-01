smoutput 'Observation 083 / separate marginals lose joint correlation'

left =: 2 2 $ 2 0 0 2
right =: 2 2 $ 0 2 2 0

leftRows =: +/"1 left
rightRows =: +/"1 right
leftCols =: +/ left
rightCols =: +/ right

smoutput 'left joint matrix:'
smoutput left
smoutput 'right joint matrix:'
smoutput right
smoutput 'same row marginals:'
smoutput leftRows -: rightRows
smoutput 'same column marginals:'
smoutput leftCols -: rightCols
smoutput 'same joint matrix:'
smoutput left -: right

assert. leftRows -: rightRows
assert. leftCols -: rightCols
assert. -. left -: right

exit 0

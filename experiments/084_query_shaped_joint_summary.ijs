smoutput 'Observation 084 / query-shaped joint summary sufficiency'

left2 =: 2 2 $ 2 0 0 2
row2 =: +/"1 left2
col2 =: +/ left2
anchor2 =: {. , left2

reconstructed2 =: 2 2 $ anchor2,(({. row2) - anchor2),(({. col2) - anchor2),(({: row2) - (({. col2) - anchor2))

smoutput '2x2 reconstructed from marginals plus one anchor:'
smoutput reconstructed2
smoutput '2x2 reconstruction exact:'
smoutput left2 -: reconstructed2

left3 =: 3 3 $ 2 0 0 0 2 0 0 0 2
right3 =: 3 3 $ 2 0 0 0 0 2 0 2 0

left3Rows =: +/"1 left3
right3Rows =: +/"1 right3
left3Cols =: +/ left3
right3Cols =: +/ right3
left3Anchor =: {. , left3
right3Anchor =: {. , right3

smoutput '3x3 same row marginals:'
smoutput left3Rows -: right3Rows
smoutput '3x3 same column marginals:'
smoutput left3Cols -: right3Cols
smoutput '3x3 same anchor:'
smoutput left3Anchor -: right3Anchor
smoutput '3x3 same joint matrix:'
smoutput left3 -: right3

assert. left2 -: reconstructed2
assert. left3Rows -: right3Rows
assert. left3Cols -: right3Cols
assert. left3Anchor -: right3Anchor
assert. -. left3 -: right3

exit 0

NB. Executable checks for Observation 002.

0!:0 < 'j/002_observe.ijs'

checkObservation =: 3 : 0
  assert. 0 = leftHistory -: rightHistory
  assert. expectedProjection -: projectCounts leftHistory
  assert. expectedProjection -: projectCounts rightHistory
  assert. (0 1 0 0) -: 1 persistentAt leftHistory
  assert. (0 0 0 0) -: 1 persistentAt rightHistory
  1
)

checkObservation 0

smoutput 'Observation 002 / projection collision'
smoutput 'Left identity history (Time x Unit):'
smoutput leftHistory
smoutput 'Right identity history (Time x Unit):'
smoutput rightHistory
smoutput 'Left count projection:'
smoutput projectCounts leftHistory
smoutput 'Right count projection:'
smoutput projectCounts rightHistory
smoutput 'Persistent-at-Purpose-1 / Left:'
smoutput 1 persistentAt leftHistory
smoutput 'Persistent-at-Purpose-1 / Right:'
smoutput 1 persistentAt rightHistory

exit 0

NB. Observation 002: Same Projection, Different History
NB.
NB. Each history is Time x Unit.  Cell values are Purpose indices 0 or 1.
NB. These are the concrete Left and Right histories emitted by Alloy 6.2.0.
NB.
NB. J derives the Time x Purpose count projection from the identity-bearing
NB. histories.  If the projections are equal, that equality is an observed
NB. consequence of forgetting Unit identity rather than hand-entered counts.

NB. Count Units at Purpose 0 and Purpose 1 for every Time.
projectCounts =: 3 : '((+/"1 0 = y)) ,. (+/"1 1 = y)'

NB. For a Purpose index x and Time x Unit history y, report which Units stay
NB. at that Purpose through every Time.
persistentAt =: 4 : '*./"1 x = |: y'

NB. Alloy SAT witness, rows are Time 0..2 and columns are Unit 0..3.
leftHistory =: 3 4 $ 0 1 0 1  1 1 0 0  0 1 0 0
rightHistory =: 3 4 $ 0 0 1 1  1 1 0 0  1 0 0 0

expectedProjection =: 3 2 $ 2 2  2 2  3 1

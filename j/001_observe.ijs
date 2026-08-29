NB. Observation 001: A World Before Envelopes
NB.
NB. J deliberately begins with a lossy projection of an Alloy world.
NB. A matrix is Time x Purpose. Each cell is the number of persistent
NB. resource Units currently placed at that Purpose.
NB.
NB. Unit identity is visible to Alloy but not to this first J view.
NB. That mismatch is intentional: quantity stability and identity persistence
NB. should not be treated as the same thing without evidence.

NB. Total quantity visible at each time.
timeTotals =: 3 : '+/"1 y'

NB. Change in purpose totals between adjacent times.
deltas =: 3 : '(}. y) - }: y'

NB. Range of each purpose's quantity through time.
purposeRange =: 3 : '(>./ y) - <./ y'

NB. Which purpose totals remain numerically stable through the whole trace.
stablePurposeCounts =: 3 : '0 = purposeRange y'

NB. Whether the projected total quantity is conserved at every time.
conserved =: 3 : '1 = # ~. timeTotals y'

NB. Projection of the first SAT witness emitted by Alloy 6.2.0 / Sat4j.
NB. Purpose order is Purpose$0, Purpose$1, Purpose$2.
NB.
NB. Alloy still knows that Unit$3 remains at Purpose$0 at every Time, while
NB. this matrix deliberately forgets that identity. Purpose$0's aggregate
NB. count is nevertheless 1, 2, 1 rather than stable.
alloyWitness =: 3 3 $ 1 3 1  2 1 2  1 1 3

NB. A synthetic contrast: Purpose$0's count is stable at 2, but a count-only
NB. projection cannot tell whether those are the same Units through time.
stableCountWorld =: 3 3 $ 2 2 1  2 1 2  2 1 2

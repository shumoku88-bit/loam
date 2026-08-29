NB. Observation 001: A World Before Envelopes
NB.
NB. J deliberately begins with a lossy projection of an Alloy world.
NB. A matrix is Time x Purpose.  Each cell is the number of persistent
NB. resource Units currently placed at that Purpose.
NB.
NB. Unit identity is therefore visible to Alloy but not to this first J view.
NB. That mismatch is intentional: if an envelope-like structure appears in
NB. both views, it should not depend accidentally on one representation.

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

NB. Five Units, three Purposes, three Times.
NB. The first Purpose keeps a total of 2 while the others exchange quantity.
sample =: 3 3 $ 2 2 1  2 1 2  2 1 2

---- MODULE MeasureScalePublicationOrder ----
EXTENDS Integers, FiniteSets

Authorities == {"Actual", "Scheduled", "Capacity", "Anchor"}
Scales == {0, 2}
NoScale == -1

VARIABLES scale, used, historical, busy,
          naivePhase, lockedPhase, locked

vars == <<scale, used, historical, busy, naivePhase, lockedPhase, locked>>

Init ==
  /\ scale = 0
  /\ used = {}
  /\ historical = [a \in Authorities |-> NoScale]
  /\ busy = {}
  /\ naivePhase = "idle"
  /\ lockedPhase = "idle"
  /\ locked = {}

TypeOK ==
  /\ scale \in Scales
  /\ used \subseteq Authorities
  /\ busy \subseteq Authorities
  /\ historical \in [Authorities -> (Scales \cup {NoScale})]
  /\ naivePhase \in {"idle", "checked"}
  /\ lockedPhase \in {"idle", "locked"}
  /\ locked \subseteq Authorities

UsedHasHistoricalScale ==
  \A a \in used : historical[a] \in Scales

HistoricalScaleOnlyAfterUse ==
  \A a \in Authorities : historical[a] # NoScale => a \in used

MeaningStable ==
  \A a \in used : historical[a] = scale

LockShape ==
  locked = {} \/ locked = Authorities

BusyAndScaleLockDisjoint ==
  busy \intersect locked = {}

\* Naive administration checks that the Measure is unused, then later commits
\* the scale change. Quantity publication does not participate in that check.
NaiveBeginScaleChange ==
  /\ naivePhase = "idle"
  /\ scale = 0
  /\ used = {}
  /\ naivePhase' = "checked"
  /\ UNCHANGED <<scale, used, historical, busy, lockedPhase, locked>>

NaiveCommitScaleChange ==
  /\ naivePhase = "checked"
  /\ scale' = 2
  /\ naivePhase' = "idle"
  /\ UNCHANGED <<used, historical, busy, lockedPhase, locked>>

NaiveBeginQuantity(a) ==
  /\ a \in Authorities
  /\ a \notin busy
  /\ busy' = busy \cup {a}
  /\ UNCHANGED <<scale, used, historical, naivePhase, lockedPhase, locked>>

NaiveCommitQuantity(a) ==
  /\ a \in busy
  /\ busy' = busy \ {a}
  /\ used' = used \cup {a}
  /\ historical' =
      [historical EXCEPT ![a] = IF @ = NoScale THEN scale ELSE @]
  /\ UNCHANGED <<scale, naivePhase, lockedPhase, locked>>

NaiveNext ==
  \/ NaiveBeginScaleChange
  \/ NaiveCommitScaleChange
  \/ \E a \in Authorities : NaiveBeginQuantity(a)
  \/ \E a \in Authorities : NaiveCommitQuantity(a)

NaiveSpec == Init /\ [][NaiveNext]_vars

\* Candidate production protocol:
\* scale administration acquires the complete retained-quantity authority set
\* only when no quantity publication is in flight. Quantity writers continue to
\* own only their existing authority, but cannot begin while the scale
\* administrator holds the aggregate lock.
LockedBeginScaleChange ==
  /\ lockedPhase = "idle"
  /\ scale = 0
  /\ used = {}
  /\ busy = {}
  /\ locked = {}
  /\ locked' = Authorities
  /\ lockedPhase' = "locked"
  /\ UNCHANGED <<scale, used, historical, busy, naivePhase>>

LockedCommitScaleChange ==
  /\ lockedPhase = "locked"
  /\ locked = Authorities
  /\ used = {}
  /\ scale' = 2
  /\ locked' = {}
  /\ lockedPhase' = "idle"
  /\ UNCHANGED <<used, historical, busy, naivePhase>>

LockedBeginQuantity(a) ==
  /\ a \in Authorities
  /\ a \notin busy
  /\ a \notin locked
  /\ busy' = busy \cup {a}
  /\ UNCHANGED <<scale, used, historical, naivePhase, lockedPhase, locked>>

LockedCommitQuantity(a) ==
  /\ a \in busy
  /\ busy' = busy \ {a}
  /\ used' = used \cup {a}
  /\ historical' =
      [historical EXCEPT ![a] = IF @ = NoScale THEN scale ELSE @]
  /\ UNCHANGED <<scale, naivePhase, lockedPhase, locked>>

LockedNext ==
  \/ LockedBeginScaleChange
  \/ LockedCommitScaleChange
  \/ \E a \in Authorities : LockedBeginQuantity(a)
  \/ \E a \in Authorities : LockedCommitQuantity(a)

LockedSpec == Init /\ [][LockedNext]_vars

NeverScale2 == scale # 2
NeverUsed == used = {}

====

---------------- MODULE application_019_publication_topology ----------------
EXTENDS Naturals

CONSTANT Protocol

Separate == "separate-streams"
Typed == "typed-sequential-stream"
Marked == "commit-marked-stream"
Atomic == "atomic-bundle"
Protocols == {Separate, Typed, Marked, Atomic}

DateFact == "actual-validity"
DescriptionFact == "event-description"
RelationFact == "relation-unit"
DischargeFact == "relation-discharge"
EventFact == "event"
AllFacts == {DateFact, DescriptionFact, RelationFact, DischargeFact, EventFact}

NoneVisible == "none"
CompleteVisible == "complete"
PartialVisible == "partial"
ReaderStates == {NoneVisible, CompleteVisible, PartialVisible}

VARIABLES durable, stage, step, marker, observed, crashed
vars == <<durable, stage, step, marker, observed, crashed>>

FactFor(i) ==
  CASE i = 1 -> DateFact
    [] i = 2 -> DescriptionFact
    [] i = 3 -> RelationFact
    [] i = 4 -> DischargeFact
    [] OTHER -> EventFact

Init ==
  /\ Protocol \in Protocols
  /\ durable = {}
  /\ stage = {}
  /\ step = 0
  /\ marker = FALSE
  /\ observed = {}
  /\ crashed = FALSE

\* Current separate streams and a single typed stream that still appends one
\* fact at a time have the same temporal publication shape in this model.
SequentialWrite ==
  /\ Protocol \in {Separate, Typed}
  /\ ~marker
  /\ step < 5
  /\ step' = step + 1
  /\ durable' = durable \cup {FactFor(step + 1)}
  /\ UNCHANGED <<stage, marker, observed, crashed>>

\* A commit-marked stream still writes each semantic fact durably before the
\* commit marker. The marker changes reader visibility, not the existence of
\* pre-commit authority-store residue.
MarkedWrite ==
  /\ Protocol = Marked
  /\ ~marker
  /\ step < 5
  /\ step' = step + 1
  /\ durable' = durable \cup {FactFor(step + 1)}
  /\ UNCHANGED <<stage, marker, observed, crashed>>

MarkedCommit ==
  /\ Protocol = Marked
  /\ ~marker
  /\ step = 5
  /\ durable = AllFacts
  /\ marker' = TRUE
  /\ step' = 6
  /\ UNCHANGED <<durable, stage, observed, crashed>>

\* Atomic-bundle topology allows partial work only outside the authority store.
\* The final publication step moves the complete bundle into authority at once.
AtomicStage ==
  /\ Protocol = Atomic
  /\ ~marker
  /\ step < 5
  /\ step' = step + 1
  /\ stage' = stage \cup {FactFor(step + 1)}
  /\ UNCHANGED <<durable, marker, observed, crashed>>

AtomicPublish ==
  /\ Protocol = Atomic
  /\ ~marker
  /\ step = 5
  /\ stage = AllFacts
  /\ durable' = AllFacts
  /\ marker' = TRUE
  /\ step' = 6
  /\ UNCHANGED <<stage, observed, crashed>>

\* One interruption is enough to expose the recovery frontier. Durable or
\* staged bytes survive. The writer only loses its local progress cursor.
Crash ==
  /\ ~crashed
  /\ ~marker
  /\ crashed' = TRUE
  /\ step' = 0
  /\ UNCHANGED <<durable, stage, marker, observed>>

ReaderState ==
  IF Protocol \in {Separate, Typed}
  THEN IF EventFact \in durable
       THEN IF durable = AllFacts THEN CompleteVisible ELSE PartialVisible
       ELSE NoneVisible
  ELSE IF marker
       THEN IF durable = AllFacts THEN CompleteVisible ELSE PartialVisible
       ELSE NoneVisible

Observe ==
  /\ observed' = observed \cup {ReaderState}
  /\ UNCHANGED <<durable, stage, step, marker, crashed>>

Next ==
  \/ SequentialWrite
  \/ MarkedWrite
  \/ MarkedCommit
  \/ AtomicStage
  \/ AtomicPublish
  \/ Crash
  \/ Observe

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ Protocol \in Protocols
  /\ durable \subseteq AllFacts
  /\ stage \subseteq AllFacts
  /\ step \in 0..6
  /\ marker \in BOOLEAN
  /\ observed \subseteq ReaderStates
  /\ crashed \in BOOLEAN

ReadersNeverSeePartial == PartialVisible \notin observed

AuthorityStorePartial == durable # {} /\ durable # AllFacts
NoPartialAuthorityStore == ~AuthorityStorePartial

StagePartial == stage # {} /\ stage # AllFacts
NoPartialStage == ~StagePartial

\* Reachability boundary. Dedicated TLC configurations require this invariant
\* to fail, proving that each topology can actually complete publication.
NoCompletePublication == ReaderState # CompleteVisible

=============================================================================

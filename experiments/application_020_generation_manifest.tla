---------------- MODULE application_020_generation_manifest ----------------
EXTENDS FiniteSets

CONSTANT Families, Changed

Old == "old"
New == "new"
Refs == {Old, New}
ReaderPhases == {"idle", "reading"}

VARIABLES prepared, manifest, readerPhase, readerManifest, observed, published, crashed

vars == <<prepared, manifest, readerPhase, readerManifest, observed, published, crashed>>

OldManifest == [f \in Families |-> Old]
CandidateManifest == [f \in Families |-> IF f \in Changed THEN New ELSE Old]

Init ==
  /\ Changed \subseteq Families
  /\ prepared = {}
  /\ manifest = OldManifest
  /\ readerPhase = "idle"
  /\ readerManifest = OldManifest
  /\ observed = {}
  /\ published = FALSE
  /\ crashed = FALSE

TypeOK ==
  /\ prepared \subseteq Families
  /\ manifest \in [Families -> Refs]
  /\ readerPhase \in ReaderPhases
  /\ readerManifest \in [Families -> Refs]
  /\ observed \subseteq [Families -> Refs]
  /\ published \in BOOLEAN
  /\ crashed \in BOOLEAN

Prepare(f) ==
  /\ ~published
  /\ ~crashed
  /\ f \in Changed
  /\ f \notin prepared
  /\ prepared' = prepared \cup {f}
  /\ UNCHANGED <<manifest, readerPhase, readerManifest, observed, published, crashed>>

Crash ==
  /\ ~published
  /\ ~crashed
  /\ prepared # {}
  /\ crashed' = TRUE
  /\ UNCHANGED <<prepared, manifest, readerPhase, readerManifest, observed, published>>

Restart ==
  /\ crashed
  /\ crashed' = FALSE
  /\ UNCHANGED <<prepared, manifest, readerPhase, readerManifest, observed, published>>

PublishManifest ==
  /\ ~published
  /\ ~crashed
  /\ Changed \subseteq prepared
  /\ manifest' = CandidateManifest
  /\ published' = TRUE
  /\ UNCHANGED <<prepared, readerPhase, readerManifest, observed, crashed>>

BeginRead ==
  /\ readerPhase = "idle"
  /\ readerManifest' = manifest
  /\ readerPhase' = "reading"
  /\ UNCHANGED <<prepared, manifest, observed, published, crashed>>

FinishRead ==
  /\ readerPhase = "reading"
  /\ observed' = observed \cup {readerManifest}
  /\ readerPhase' = "idle"
  /\ UNCHANGED <<prepared, manifest, readerManifest, published, crashed>>

Next ==
  \/ \E f \in Changed : Prepare(f)
  \/ Crash
  \/ Restart
  \/ PublishManifest
  \/ BeginRead
  \/ FinishRead

Spec == Init /\ [][Next]_vars

PreparedOnlyChanged ==
  prepared \subseteq Changed

AuthorityManifestWhole ==
  manifest = OldManifest \/ manifest = CandidateManifest

ReadersSeeOnlyWholeManifests ==
  \A m \in observed : m = OldManifest \/ m = CandidateManifest

UnchangedReferencesStable ==
  \A f \in (Families \ Changed) : manifest[f] = Old

PublishedSelectsCandidate ==
  ~published \/ manifest = CandidateManifest

\* Reachability boundaries used by dedicated TLC configurations.
NoPartialPreparation ==
  prepared = {} \/ prepared = Changed

NoInterruptedPreparation ==
  ~(crashed /\ prepared # {} /\ ~published)

NoPublishedState ==
  ~published

\* Intentionally too strong for a one-family update. A manifest switch may be
\* published after preparing only the changed family image.
AllFamiliesPreparedIfPublished ==
  ~published \/ prepared = Families

=============================================================================

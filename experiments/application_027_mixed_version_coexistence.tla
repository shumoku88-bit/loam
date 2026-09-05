---- MODULE application_027_mixed_version_coexistence ----
EXTENDS Naturals

CONSTANTS Mode, MaxGen

VARIABLES authority, sidecarGen, manifestGen, legacyEnabled, cutoverDone

vars == <<authority, sidecarGen, manifestGen, legacyEnabled, cutoverDone>>

TypeOK ==
  /\ authority \in {"SIDECAR", "MANIFEST"}
  /\ sidecarGen \in 0..MaxGen
  /\ manifestGen \in 0..MaxGen
  /\ legacyEnabled \in BOOLEAN
  /\ cutoverDone \in BOOLEAN

Init ==
  /\ authority = "SIDECAR"
  /\ sidecarGen = 0
  /\ manifestGen = 0
  /\ legacyEnabled = TRUE
  /\ cutoverDone = FALSE

\* Preparing the candidate manifest is not authority publication.
PrepareManifest ==
  /\ authority = "SIDECAR"
  /\ manifestGen # sidecarGen
  /\ manifestGen' = sidecarGen
  /\ UNCHANGED <<authority, sidecarGen, legacyEnabled, cutoverDone>>

\* One complete legacy operation already owns/releases the existing writer lock.
\* The action is deliberately atomic here: the question is version fencing after
\* ownership release, not interleaving inside a writer operation.
LegacyWrite ==
  /\ legacyEnabled
  /\ sidecarGen < MaxGen
  /\ sidecarGen' = sidecarGen + 1
  /\ UNCHANGED <<authority, manifestGen, legacyEnabled, cutoverDone>>

Cutover ==
  /\ authority = "SIDECAR"
  /\ sidecarGen = manifestGen
  /\ authority' = "MANIFEST"
  /\ legacyEnabled' = IF Mode = "quiescent" THEN FALSE ELSE legacyEnabled
  /\ cutoverDone' = TRUE
  /\ UNCHANGED <<sidecarGen, manifestGen>>

ManifestWrite ==
  /\ authority = "MANIFEST"
  /\ manifestGen < MaxGen
  /\ manifestGen' = manifestGen + 1
  /\ UNCHANGED <<authority, sidecarGen, legacyEnabled, cutoverDone>>

Next ==
  PrepareManifest \/ LegacyWrite \/ Cutover \/ ManifestWrite

Spec == Init /\ [][Next]_vars

LegacyRead == sidecarGen
AwareRead == IF authority = "SIDECAR" THEN sidecarGen ELSE manifestGen

\* Stable coexistence would require every still-enabled legacy reader to agree
\* with the selected authority after cutover.
NoSplitView ==
  ~(cutoverDone /\ legacyEnabled /\ LegacyRead # AwareRead)

\* The short equivalent coexistence window from Application 026 is reachable.
NoEquivalentCoexistenceWindow ==
  ~(cutoverDone /\ authority = "MANIFEST" /\ legacyEnabled /\ sidecarGen = manifestGen)

\* Either version can create a split after cutover when legacy execution remains enabled.
NoLegacyOnlyDivergence ==
  ~(cutoverDone /\ sidecarGen > manifestGen)

NoManifestOnlyDivergence ==
  ~(cutoverDone /\ manifestGen > sidecarGen)

\* Quiescent cutover is modeled as disabling all legacy authority consumers before
\* the new epoch is allowed to proceed.
QuiescentFence ==
  cutoverDone => ~legacyEnabled

NoPostCutoverLegacyAhead ==
  ~(cutoverDone /\ sidecarGen > manifestGen)

\* Non-vacuity: the new manifest epoch can still advance after the quiescent cut.
NoQuiescentManifestAdvance ==
  ~(cutoverDone /\ ~legacyEnabled /\ manifestGen > sidecarGen)

=============================================================================

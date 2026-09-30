# Settlement production boundary — durable audit

Status: **CURRENT PRODUCTION BOUNDARY**

This document keeps the durable conclusions from the settlement promotion and
persistence-topology work that began with Observations 371–372.

The detailed promotion checkpoints have graduated to Git history. Current code,
tests, and live research witnesses now own the relevant obligations directly.

## Current semantic split

Settlement remains additive beside `OpenRelation`.

`RelationUnit` stays source-Effect-Measure bounded. Settlement commitments may
carry independently evidenced settlement Measure and Quantity, so widening
`OpenRelation` would erase a real distinction.

The current settlement family preserves these separate meanings:

- commitment: an independently evidenced obligation with source provenance;
- direct correspondence: exact attribution from a later physical Effect;
- netting context/member: one explicit net-settlement occasion and its members;
- commitment revision: correction or retraction of commitment evidence;
- non-settlement extinguishment: a valid obligation later loses exact quantity
  without physical/net settlement;
- extinguishment revision: correction or retraction of that reduction evidence.

Physical settlement, evidence correction, evidence retraction, and
non-settlement reduction are not one generic cancel operation.

## Current production owners

### Raw retained vocabulary

`Loam/Core/Settlement.lean` owns raw provenance and retained identities.

It deliberately does not decide reference closure, current-row selection,
quantity admissibility, direction/sign agreement, cross-mode conservation, or
wire/storage behavior.

### Application admission and current frontier

`Loam/Application/SettlementFrontier.lean` owns the admitted settlement image.

It:

- selects current commitment revisions;
- reuses generic `ReplacementFrontier` mechanics where the graph law is
  genuinely shared;
- admits current direct correspondences, extinguishments, contexts, and members;
- resolves Event / Effect references;
- enforces local quantity and direction laws;
- enforces cross-mode target conservation;
- enforces physical-Effect conservation;
- derives current settled/outstanding answers rather than retaining aggregate
  balances.

Superseded rows remain historical evidence but are not re-admitted as current
settlement facts.

### One Actual authority generation

`Loam/ActualEvidence.lean` retains one grouped `SettlementEvidence` family
inside the ordinary Actual aggregate.

`Loam/Persistence/NormalizedActualAdmission.lean` carries the admitted
settlement projection inside `AdmittedActualImage`, with a proof field tying it
to the same retained Event generation.

Settlement is therefore not a second read authority.

### Normalized Actual wire

`Loam/Persistence/NormalizedActualPersistence.lean` owns the current wire.

The retained evolution is explicit:

- v1: TX-only Actual, used while settlement evidence is empty;
- v2: document-level base settlement evidence;
- v3: append-only settlement commitment revisions;
- v4: quantity-bearing non-settlement extinguishment evidence.

Settlement rows live at document scope rather than being forced inside an
arbitrary owning TX. Zero-net settlement therefore does not require a fake Event
or zero-quantity physical Effect.

The encoder selects the smallest current version required by retained evidence.
Decoding remains fail-closed.

### Publication

`Loam/Publisher/SettlementPublisher.lean` publishes explicit append-only settlement
batches.

It:

- performs no amount/date matching or inference;
- re-reads under ordinary Actual writer ownership;
- builds a complete candidate Actual generation;
- reuses `admitActualImage?` rather than duplicating settlement admission;
- publishes through the existing atomic Actual authority boundary.

`Loam/Publisher/SettlementActionPublisher.lean` translates a small human-facing lifecycle
vocabulary into that explicit evidence boundary. Commitment correction,
retraction, non-payment reduction, and reduction correction/retraction retain
their distinct meanings.

### Read and TUI surfaces

`Loam/SettlementReview.lean` owns the shared production read projection.

`Loam/Tui/SettlementWorkspace.lean`,
`Loam/Tui/SettlementAction.lean`, and
`Loam/Tui/SettlementActionSession.lean` own the current terminal interaction
surface without becoming new settlement authorities.

## Current qualification owners

The production boundary is protected directly by current tests:

- `Loam/Tests/SettlementFrontier.lean` — semantic admission/frontier laws;
- `Loam/Tests/ActualSettlementAdmission.lean` — settlement inside one admitted
  Actual image and whole-generation fail-closed behavior;
- `Loam/Tests/SettlementNormalizedActualV2.lean` — normalized settlement wire
  compatibility and retained settlement families;
- `Loam/Tests/SettlementActualAuthorityPreservation.lean` — unrelated Actual
  publication preserves settlement evidence and authority switching stays safe;
- `Loam/Tests/SettlementPublisher.lean` — explicit writer behavior;
- `Loam/Tests/SettlementReview.lean` — shared read projection;
- `Loam/Tests/TuiSettlement.lean` — user-facing settlement interaction;
- `Loam/Tests/DeterministicSettlementScenario.lean` — deterministic
  production-history lifecycle composition.

The deterministic scenario is a production-history regression barrier. It is
not presented as TigerBeetle-style fault-injection DST.

## Live research that remains live

Observations 373–379 still run independent Alloy witnesses. They remain because
they test settlement lifecycle distinctions that are useful beyond one current
implementation path.

Observation 380 remains a selected Lean correspondence witness for balance-level
valuation laws and deliberately does not promote a richer external ledger
ontology into LOAM.

Those witnesses are not retired by this audit.

## What Observations 371–372 contributed

Observation 371 selected the production seam:

- settlement stays distinct from OpenRelation;
- raw retained vocabulary stays in Core;
- semantic admission stays in Application;
- structural replacement mechanics may be shared without merging authorities;
- outstanding and net aggregate answers remain derived;
- FX valuation, fees/tax/basis, automatic matching, and institutional finality
  remain outside the base family.

Observation 372 selected the persistence topology:

- keep one `actual.loam` authority generation;
- retain settlement as document-level rows;
- keep TX-local meanings unchanged;
- admit settlement against the same Event generation;
- publish atomically through the existing Actual boundary;
- preserve old wire compatibility explicitly rather than silently widening v1.

Those decisions are now represented directly by production code and tests, so
the two long promotion checkpoint documents no longer need to remain in the
working tree.

## Durable non-goals

Do not infer from the current settlement family that LOAM has earned:

- a universal Settlement supertype;
- a universal Transaction/Group/Batch/Finality ontology;
- broader `RelationUnit` semantics;
- automatic settlement matching as canonical authority;
- FX valuation or rate authority;
- fee/tax/cost-basis decomposition;
- legal close-out netting;
- securities-specific lifecycle semantics;
- stored outstanding balances or stored aggregate net amounts;
- a settlement-only authority file or writer lock.

New meanings should remain additive and must earn independent authority from a
concrete unsupported workflow.

## Graduation note

The exact Observation 371 and 372 checkpoint prose remains available in Git
history.

Observation 341 has now graduated as well. Its falsification of
`RelationDischarge` as cross-Measure physical-settlement authority remains a
narrower-boundary lesson: `RelationDischarge` stays source-bounded, while
`SettlementCommitment` carries independent settlement Measure/Quantity and
`SettlementEffectCorrespondence` names the exact later Event/Effect/quantity.
The focused cross-Measure card regression in `SettlementFrontier` now owns the
selected executable behavior.

The original Lean precursors for Observations 359 and 360 have also graduated
from the working tree. Their durable conclusions are now direct production
contracts: independently measured settlement commitments remain additive beside
source-bounded OpenRelation, and direct settlement names an exact later
Event/Effect rather than relying on Event-level discharge alone.

Observations 361 and 362 have likewise graduated. Production now directly owns
exact per-correspondence quantity, partial and multi-target direct allocation,
aggregate physical/target bounds, version-capable correspondence identity,
generic replacement-frontier correction, conflict refusal, and atomic explicit
batch publication. Observation 363 remains live because a workflow-level
"complete allocation" promise is stronger than those incremental settlement
laws and has not been promoted.

Observations 364–367 and 370 have now graduated as well. Production directly owns
endpoint-directed physical sign admission, opposite-direction netting with
explicit gross membership, zero-net outcome without synthetic movement,
version-capable netting-member correction through the generic replacement
frontier, and one composed conservation boundary across direct and net modes.
Observations 368 and 369 remain live because the current base family still does
not promise an as-finalized publication layer or append-only correction of that
finality evidence.

The working tree now keeps the current owners, current qualification surfaces,
live independent settlement research, and this compressed durable rationale.

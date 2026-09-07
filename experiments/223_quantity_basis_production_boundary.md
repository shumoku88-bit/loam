# Observation 223: qualify the current QuantityBasis production retirement boundary

Status: **QUALIFIED PRODUCTION CUT BOUNDARY, IMPLEMENTATION NOT YET LANDED**

Research starting point:

- LOAM `434ae07c3766faca1cda8f5ab069ba879b0ba0aa`
- household data `7bed82bfaed4505fddacaf6707b3dd70cb75798a`

## Question

Can the current household production balance path retire the practical use of:

```text
QuantityBasis
QuantityBasisCorrection
QuantityBasisFrontier
BasisCut
```

and instead use only:

```text
explicit finite zero-origin coverage
+
correction-aware selected Event world
```

without losing a capability that the current household actually uses?

This is not a serialization rename. It is a capability and authority boundary decision.

## Prior qualified pressure

Observation 219 established, on real household data, that the five current pointwise-zero QuantityBasis rows contribute no quantity information. Their necessary contribution is finite evidence that those five coordinates have a known zero origin. Removing one coordinate from that finite domain must make the coordinate unknown rather than silently zero.

Observation 221 rejected a generic household `Coverage` ontology. Scheduled completeness and zero-origin quantity completeness share only a small information-order shape. Permission, visibility, presentation selection, accounting classification, and representation completeness must not be collapsed into world completeness.

Observation 222 established that BasisCut had real historical meaning. A starting-state observation can already contain a retained Event occurrence, and BasisCut prevents that occurrence from being counted twice. A one-time arithmetic fold into an origin value is not correction-stable. The current household reconstruction avoids this pressure by selecting a reconstructed origin and selected Event world that do not overlap.

Therefore the current question is narrower than whether these concepts were ever valid. It asks whether the current production operating mode still needs them.

## Current household data shape

The current `basis.loam` contains exactly five rows and every quantity is exactly zero:

```text
cash        / jpy = 0
paypay      / jpy = 0
smbc        / jpy = 0
yucho       / jpy = 0
all-country / jpy = 0
```

There is no current `basis-corrections.loam` and no current `basis-cut.tsv`.

There is also no current root `corrections.loam`; absent Event correction memory currently means the EventCorrection relation is empty. EventCorrection semantics remain a supported production capability and are not candidates for retirement here.

The selected Movement world is published by `movement-authority/CURRENT` and content-addressed selected objects. The root sidecar Event stream is not the current Movement authority.

The current `balance-view.tsv` happens to select the same five Locus/Measure coordinates as the zero bases. That coincidence is not authority for origin completeness. Presentation selection must not be used to infer zero-origin coverage.

## Latest-data requalification

The current household head is a direct child of the Observation 219 household revision `188319456d96fa24ac0af7b251ff612800ab6522`.

The selected Event object change from that parent adds only these three new records:

```text
record-21
  paypay +1000
  smbc   -1000

record-22
  paypay -1045
  food   +1045

record-23
  paypay -160
  coffee +160
```

For the five tracked balance coordinates, the exact delta is therefore:

```text
cash          0
paypay     -205
smbc      -1000
yucho         0
all-country   0
```

Using the already-qualified Observation 219 production values as the parent baseline gives the expected current values:

```text
cash          909
paypay        523
smbc        80575
yucho        5000
all-country  5600
```

This is a revision-delta requalification, not a claim that the production executable was rerun during Observation 223. The important structural fact is stronger and simpler: the basis rows are still all zero, no basis correction or cut was added, and the current revision only adds Event effects. The zero-origin factorization shape therefore remains intact.

## Production dependency inventory

### BalanceReview

`Loam/BalanceReview.lean` is the shared household balance reader used by production surfaces.

It currently loads:

```text
MovementManifestAuthority selected world
corrections.loam
basis.loam
basis-corrections.loam
basis-cut.tsv
balance-view.tsv
```

and projects selected coordinates through:

```text
admittedQuantityBasisFrontier?
inspectCurrentQuantityWithBasisCut?
```

The current failure vocabulary includes:

```text
basisMissing
basisFrontierRequired
basisCutInvalid
missingEventCorrectionEndpoint
eventFrontierRequired
```

The production cut must preserve the Event correction failures while replacing basis-frontier and basis-cut admission with explicit zero-origin membership.

### TUI

`Loam/Tui/Balances.lean` imports `Loam.BalanceReview` and stores a `BalanceReview.Snapshot`.

`Loam/Tui/Cli.lean` also imports `Loam.BalanceReview` as the shared balance read boundary.

There is no reason to add a TUI-local quantity projector. Changing the shared BalanceReview boundary is sufficient for the production TUI to consume the new semantics.

### Human-facing CLI writer

`Loam/Cli/DailyQuantityCli.lean` still implements:

```text
starting-quantity
correct-starting-quantity
balances
current
```

`starting-quantity` accepts an arbitrary integer JPY quantity for an arbitrary locus and persists a fresh QuantityBasis identity. It is not restricted to zero.

`tools/loam` exposes both starting-quantity operations directly and in the ordinary interactive menu:

```text
starting  Set a starting balance
basis     Correct a starting balance
```

This means the writer is not merely historical or test-only.

A reader-only cut is rejected. If BalanceReview stopped reading QuantityBasis while these commands remained writable, LOAM would have a human-facing ghost writer: a command could successfully persist evidence that the production current-balance path ignores.

More importantly, a new arbitrary nonzero snapshot can overlap retained historical Events. Keeping that writer without a corresponding overlap protocol would recreate the exact pressure for which BasisCut was valid.

### Lower-level current and balances commands

The existing `current` command derives candidate coordinates from both basis and Event activity. Event activity alone does not justify known origin completeness under the candidate semantics.

If `current` remains after the cut, its domain must come from explicit zero-origin coverage. An Event occurrence outside that domain must remain unknown rather than silently becoming known.

The existing `balances` command may remain as a presentation view, but every selected coordinate must be admitted independently by zero-origin coverage. `balance-view.tsv` must never create coverage.

### Core, application, and persistence modules

The practical dependency cluster includes:

```text
Loam/Core/QuantityBasisMemory.lean
Loam/Application/QuantityBasisFrontier.lean
Loam/Application/CurrentQuantity.lean
Loam/Application/BasisCut.lean
Loam/Persistence/QuantityBasisPersistence.lean
Loam/Persistence/QuantityBasisCorrectionPersistence.lean
Loam/Persistence/BasisCutPersistence.lean
Loam/Cli/QuantityBasisCorrectionCli.lean
Loam/Cli/DailyQuantityCli.lean
Loam/BalanceReview.lean
```

The candidate cut can remove the practical need for QuantityBasis identity, basis correction memory, basis frontier selection, and BasisCut from the current household path.

Historical observations that demonstrate why those concepts once existed are not production dependencies and must not be erased merely because the current operating mode no longer needs them.

## Tests and workflows affected

Current production tests and workflows still encode basis behavior, including:

```text
Loam/Tests/BalanceReview.lean
Loam/Tests/TuiBalances.lean
tests/test_record_review.py
.github/workflows/practical-starting-quantity.yml
.github/workflows/practical-basis-cut.yml
.github/workflows/practical-dogfood-session.yml
docs/TUI.md
```

The cut must replace production tests with tests for the new evidence boundary rather than merely deleting coverage.

Required negative controls include:

```text
duplicate zero-origin coordinate -> refuse
selected coordinate outside coverage -> unknown/refuse
Event activity outside coverage -> still unknown
malformed coverage persistence -> refuse
missing Event correction endpoint -> refuse
non-frontier Event corrections -> refuse
balance-view presence -> never creates coverage
```

Historical Observation 222 evidence and its dedicated executable witness should remain as research provenance even after BasisCut leaves production.

## Capability ledger

### Keep

```text
Event / EventMemory
EventCorrection / correction-aware Event frontier
MovementManifestAuthority selected world
explicit finite zero-origin evidence
missing != zero
balance-view as presentation selection
fail-closed malformed persistence
fail-closed correction relations
```

### Retire from the current practical household path

```text
QuantityBasisId
QuantityBasisMemory
QuantityBasisCorrection
QuantityBasisCorrectionMemory
QuantityBasisFrontier
BasisCut
basis.loam
basis-corrections.loam support
basis-cut.tsv support
starting-quantity
correct-starting-quantity
```

### Capability intentionally lost

The cut removes the ordinary ability to say:

```text
new-bank / jpy = 100000
```

as an arbitrary starting snapshot and then revise it append-only.

It also removes the practical overlap protocol that allows such a snapshot to coexist with retained Events already reflected in that snapshot.

That capability is real, but the current household does not use it: all current starting quantities are zero, there are no basis corrections, and there is no basis cut.

If a future household requirement genuinely needs a nonzero reconstructed origin, that pressure can earn a narrow `OriginSnapshot : EffectCoordinate ->? Quantity` or another explicit reconstruction mechanism at that time. Observation 223 does not generalize preemptively.

## Earned replacement

The narrow production replacement is:

```text
ZeroOriginCoverage
  finite set EffectCoordinate
```

with semantics:

```text
coordinate in ZeroOriginCoverage
  -> current quantity = correction-aware selected Event sum

coordinate not in ZeroOriginCoverage
  -> unknown / basisMissing-equivalent
```

There is no identity per coordinate, no quantity column, no correction graph, and no BasisCut relation.

The representation must reject duplicate coordinates rather than normalize them silently, preserving the negative control already qualified by Observation 219.

This is a domain-specific evidence boundary. It is not a generic `Coverage` framework and not a generic `Origin` framework.

## Cut order

The production change should be atomic at the semantic boundary even if implemented in more than one commit:

1. Add the narrow `ZeroOriginCoverage` type/persistence and its fail-closed tests.
2. Add one shared application projection that first requires coverage membership and then uses the existing correction-aware Event quantity semantics.
3. Switch `BalanceReview` to that projection while leaving `balance-view.tsv` presentation-only.
4. Make TUI balances continue consuming only `BalanceReview`; do not add TUI-local reconstruction.
5. Change or retire the lower-level `current` and `balances` paths so Event activity cannot create known origin completeness.
6. Remove `starting-quantity` and `correct-starting-quantity` from both the compiled dispatcher and `tools/loam` human-facing menu/help in the same production cut.
7. Replace obsolete practical tests/workflows/docs with zero-origin coverage tests and preserve Event correction tests.
8. In an explicit household reconstruction/cutover step, publish the five coordinates now represented by zero bases as the new coverage authority. Derive this migration input from the current zero-basis evidence, not from `balance-view.tsv`.
9. Only after the new reader and writer boundary is live, retire `basis.loam` from household canonical data.
10. Delete now-dead QuantityBasis/BasisCut production machinery once no production build path depends on it, while retaining historical research witnesses.

## Rejected cuts

### Reader-only cut

Rejected because it creates a ghost writer and permits arbitrary snapshots whose overlap semantics are no longer honored.

### Infer coverage from balance-view

Rejected because presentation selection is not historical completeness evidence.

### Event-activity-implies-known

Rejected because Event evidence does not prove that the retained history is complete from zero for that coordinate.

### Generic Coverage framework

Rejected by Observation 221. The shared shape is an information-order pattern, not one household ontology.

### Generic OriginSnapshot now

Rejected because current production data earns only zero-origin membership. Nonzero snapshot pressure is currently hypothetical.

### Delete BasisCut history

Rejected. Observation 222 established a real overlap problem. Retirement from the current practical path does not make the historical pressure false.

## Decision

**GO for the current household production retirement of QuantityBasis, QuantityBasisCorrection, QuantityBasisFrontier, and BasisCut, provided the read boundary and human-facing starting-quantity writers are cut together and explicit zero-origin coverage is installed as independent evidence.**

**NO-GO for a reader-only cut, balance-view-derived coverage, Event-derived knownness, or silent support for arbitrary nonzero starting snapshots.**

The current household capability set is preserved by the smaller shape:

```text
selected correction-aware Event world
+
explicit finite zero-origin coverage
+
independent presentation selection
```

The semantic reduction is therefore earned for the present production operating mode, not asserted as a universal accounting theorem.

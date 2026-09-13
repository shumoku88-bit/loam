# Observation 246 — Shared current-anchor root cut

Status: **PROBE — current household pressure**

Baseline:

```text
71b913446386c1ed86a2e43cc49e801ee330822f
feat(cli): expose balances report as plain text (#822)
```

Household pressure:

```text
loam-data 9aca13c98dd8a479b3817478d603976b9aa32ac4

RoleBalance quantity blockers:
  debt-mother
  debt-mother-wifi
```

The user has independently confirmed that current real-world balances are correct, while retained history does not justify zero-origin support for these two liabilities.

## Question

Can current balance observation be admitted without reviving the retired `QuantityBasis` / `BasisCut` subsystem, inventing synthetic Actual history, or overloading `OpeningSupport`?

Prior work already established the surrounding boundaries:

- Observation 201: retained reconstruction does not determine an independently observed physical/external quantity assertion;
- Observation 206: an external assertion does not by itself choose history completeness or a repair policy;
- Observation 243: current support and zero-origin historical support are independently observable;
- Observation 244: a later anchor needs boundary information; a bare scalar observation is too small;
- Observation 245: an already-retained opening Event can serve as a narrow opening witness, but this does not generalize arbitrary later observations;
- historical Application 011: avoiding double counting for an observed starting quantity requires explicit evidence about which Event correction roots are already reflected rather than chronology inferred from file order, Event order, date, or Git history.

The remaining compression question is therefore narrower:

> If several quantities are observed in one reconciliation session, can one shared set of already-reflected Event correction roots support all of those assertions, with ordinary correction-aware root contributions supplying only post-anchor deltas?

## Candidate information shape

Observation-local candidate:

```text
Current-anchor session
  reflected Event correction roots

Per-coordinate assertion
  EffectCoordinate
  Quantity
```

For an asserted coordinate:

```text
current
  = asserted quantity
  + current correction-selected contribution
      of roots not in the shared reflected set
```

The candidate deliberately has no:

- synthetic balancing Event;
- opening Event fabrication;
- generic Account or Balance ontology;
- per-coordinate anchor identity;
- anchor correction graph;
- second Event correction engine;
- inferred chronology from occurrence date, list order, EventId, or Git commit order;
- claim that the assertion establishes zero-origin history.

`effective(root, coordinate)` in the Alloy probe abstracts the quantity contributed by the current correction terminal of one stable Event correction root. This is not a second proposed quantity engine.

## Why roots, not current terminals

A pre-anchor Event may later be corrected or reclassified. The observation already reflected the real state at its boundary, so changing the current terminal of that old root must not add the occurrence again.

Therefore the cut is over stable correction roots:

```text
covered root
  old terminal -> corrected terminal
  still covered
```

A genuinely post-anchor root remains outside the cut and contributes normally.

This preserves the durable lesson of the retired BasisCut without reviving QuantityBasis identity or correction machinery.

## Selected probes

Expected Alloy matrix:

```text
sharedCutSupportsMultipleCoordinates       SAT
cutIsIndependentEvidence                   SAT
coveredRootCorrectionIsAbsorbed            SAT
uncoveredRootContributes                   SAT
sharedAndDuplicatedCutAgree                SAT
differentBoundariesNeedDistinctCuts        SAT
currentSupportWithoutOriginCompleteness    SAT

CoveredRootChangesDoNotChangeCurrent       UNSAT counterexample
SharedCutEqualsDuplicatedEqualCuts          UNSAT counterexample
MissingAssertionRemainsUnsupported         UNSAT counterexample
CurrentAssertionImpliesOriginCompleteness  SAT counterexample
```

### Shared cut for one reconciliation session

Two different coordinates may carry different asserted quantities while using the same reflected-root set. If coordinate-local cuts are merely copies of that same set, the shared representation must produce exactly the same answers.

This tests whether per-coordinate cut duplication is answer-relevant when the observation boundary is genuinely shared.

### Root cut is independently necessary

Two worlds may have identical assertions and identical correction-selected root contributions but different reflected-root sets, producing different current answers.

Therefore the cut cannot be derived from the asserted scalar or current Event quantities.

### Covered corrections remain absorbed

If only roots already reflected by the observation change their correction-selected contributions, the anchored current answer must stay fixed. This includes reclassification of an old root across coordinates.

### Uncovered roots contribute

A root outside the cut represents post-anchor retained activity for the selected query. A change in its effective quantity can therefore change the derived current balance.

### Shared cut is not universal

If two coordinates were observed at genuinely different boundaries, their reflected-root sets may differ. Forcing one coordinate's cut onto the other can change its answer.

So a shared cut is justified only for assertions from one reconciliation session. Observation 246 does not collapse all future anchors into one global household cut.

### Current support does not imply origin completeness

The model keeps `originComplete` independent. A current assertion can exist while origin history remains unsupported, preserving the distinction established by Observation 243.

## Late historical publication boundary

A later-discovered Event root whose real occurrence predates the observation may already be reflected by the observed quantity even though the root was not retained when the observation was first recorded.

Observation 246 does not infer this from occurrence date. Such a root would need explicit admission into the reflected set for the current anchor. This is the same semantic pressure historically handled by BasisCut and is intentionally explicit rather than chronological.

The probe therefore tests the information shape of the cut, not a policy for deciding whether a newly retained root belongs in it.

## Production gate

Even if the bounded model qualifies, do not immediately revive `QuantityBasis`.

A production candidate should first test whether current household use can remain as small as:

```text
one current reconciliation snapshot
  shared reflected-root cut
  per-coordinate asserted quantities
```

with no stable snapshot identity or correction family until revision/history pressure actually appears.

The production read path should reuse ordinary correction-root/frontier quantity mechanics rather than introduce anchor-specific arithmetic.

Exact household assertion values are not required for this observation. They are needed only if a later production data publication is justified.

## Stop rules

```text
OpeningSupport widened to arbitrary observation      NO
ZeroOriginCoverage weakened                           NO
synthetic Actual inserted to force a balance          NO
retired QuantityBasis subsystem restored wholesale    NO
occurrence date treated as total ordering              NO
Git history used as runtime semantic order             NO
shared cut used across different observation sessions NO
```

## Decision criterion

A positive result earns only this bounded claim:

> For quantities observed together at one reconciliation boundary, a shared explicit set of already-reflected Event correction roots plus per-coordinate asserted quantities is sufficient for the selected current-balance calculation, while origin-history support remains independent.

It does not yet earn persistence, publisher, CLI, TUI, or canonical household-data changes.

# Observation 246 — Shared current-anchor root cut

Status: **QUALIFIED — shared cut sufficient for one reconciliation session in the bounded model**

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

## Executed result

Observation 246 ran on:

```text
head:     d24175459f4246a6690c7472c15c80cbecc8fd5a
workflow: Observation 246
run:      34753442067
job:      103713722330
result:   SUCCESS
Alloy:    6.2.0 / Sat4j
```

Alloy produced exactly the selected matrix:

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

## Findings

### 1. One shared cut is sufficient inside one reconciliation session

Two different coordinates can carry different asserted quantities against one reflected-root set. When coordinate-local cuts are merely copies of that same set, Alloy found no counterexample to equality between the shared-cut answer and the duplicated-cut answer.

Therefore per-coordinate cut duplication carries no additional answer information when the observation boundary is genuinely shared.

### 2. The cut itself is independently necessary

Alloy found worlds with identical assertions and identical correction-selected root contributions but different reflected-root sets and different current answers.

Therefore the cut cannot be derived from the asserted scalar or the current Event quantities.

### 3. Corrections to reflected roots remain absorbed

The model found a witness where a reflected root changes its effective contribution while the current anchored answer stays fixed. The stronger assertion also had no counterexample: if assertions, the shared cut, and every uncovered-root contribution are fixed, changes confined to reflected roots cannot change the current answer.

This includes reclassification of an old root across coordinates.

### 4. Uncovered roots remain genuine deltas

Alloy found a witness where a root outside the cut changes its effective contribution and the current answer changes. The candidate therefore does not freeze the balance at the assertion; post-anchor retained activity still composes through the ordinary root contribution.

### 5. A shared cut is session-scoped, not universal

Alloy also found coordinates with genuinely different local cuts where forcing one coordinate's cut to be shared changes the other coordinate's answer.

So the compression is bounded:

```text
same reconciliation boundary
  -> one shared cut is sufficient

different reconciliation boundaries
  -> cut distinction may be observable
```

This prevents one household-global anchor from swallowing future independent observations.

### 6. Current support remains weaker than origin completeness

A supported current assertion can coexist with absent origin-completeness evidence, and the assertion that current support implies origin completeness has a counterexample.

The result therefore preserves the Observation 243 boundary rather than weakening `ZeroOriginCoverage`.

## Late historical publication boundary

A later-discovered Event root whose real occurrence predates the observation may already be reflected by the observed quantity even though the root was not retained when the observation was first recorded.

Observation 246 does not infer this from occurrence date. Such a root would need explicit admission into the reflected set for the current anchor. This is the same semantic pressure historically handled by BasisCut and is intentionally explicit rather than chronological.

The probe therefore qualifies the information shape of the cut, not a policy for deciding whether a newly retained root belongs in it.

## Architectural result

The bounded result supports a conservative extension rather than resurrection of the retired subsystem:

```text
shared reflected-root cut
+
per-coordinate asserted quantities
+
existing correction-root/frontier quantity semantics
    -> selected current quantities
```

The following are not required by the selected answer:

```text
per-coordinate duplicated cuts
per-anchor stable identities
anchor correction graph
synthetic Actual
arbitrary starting-balance writer
second quantity engine
```

The old `QuantityBasis` / `BasisCut` machinery remains correctly retired as a production subsystem. Observation 246 recovers only the independently necessary information that current dogfood has now re-earned.

## Production gate

The next production candidate should test whether current household use can remain as small as one current reconciliation snapshot:

```text
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

## Verdict

**QUALIFIED for the bounded information shape.**

For quantities observed together at one reconciliation boundary, one explicit shared set of already-reflected Event correction roots plus per-coordinate asserted quantities is sufficient for the selected current-balance calculation. The cut is independently necessary, covered-root corrections remain absorbed, uncovered roots remain deltas, and current support does not imply zero-origin historical support.

This result does not yet earn persistence, publisher, CLI, TUI, or canonical household-data changes. The next question is the smallest production reuse seam over current correction-root mechanics.


## 2026-09-27 follow-up — incremental reconciliation groups

Household setup auditing exposed the production consequence already latent in Finding 5.

The current production image has exactly one shared cut. Home `o` starts from an empty editor and publication replaces that complete image. That is safe for one reconciliation session, but awkward when a household later adds an independently observed bank account.

The new bounded pressure therefore compares:

```text
one global cut
vs
coordinate-local duplicated cuts
vs
several anonymous reconciliation groups
```

where each group contains:

```text
shared reflected-root cut
+ one or more asserted coordinates
```

and every currently supported coordinate belongs to at most one live group.

The extension asks only four new questions:

1. can several groups with different cuts coexist in one current-support image?
2. can a fresh coordinate be added under a later group without changing old answers?
3. does a current-only reader need stable group identity?
4. why must one coordinate not belong to two live groups simultaneously?

The intended compression boundary is:

```text
semantic minimum:
  coordinate -> (asserted quantity, reflected-root cut)

representation compression:
  coordinates with equal/shared observation cut
      -> one anonymous group carrying that cut once
```

A group is therefore not proposed as a new household entity. It is only a factoring of equal cut evidence.

The new Alloy cases are expected to distinguish the following:

```text
multipleSessionsSupportDifferentCuts          SAT
incrementalSessionPreservesExisting           SAT
differentSessionIdentitySameAnswer            SAT
duplicateSessionMembershipCanDisagree         SAT

GroupedSessionsEqualDuplicatedCuts             UNSAT counterexample
ExistingGroupedAnswerPreserved                 UNSAT counterexample
CoordinateCutsDetermineGroupedCurrent          UNSAT counterexample
OneSharedCutAlwaysRepresentsGroupedSessions    SAT counterexample
```

If qualified, the smallest production direction is not an append-only anchor history and not a stable AnchorId graph. It is a replaceable **current support image containing several anonymous reconciliation groups**, with global uniqueness of supported coordinates.

Re-observing a coordinate would move its current assertion to the newly observed group in the next replaceable image; the old group identity itself need not survive. Historical observation provenance remains a separate question and is not earned by this current-balance requirement.

This follow-up deliberately does not change the earlier stop rules:

- no chronology inferred from date or EventId;
- no per-coordinate duplicated cuts when one shared cut suffices;
- no stable group/session identity merely for current answers;
- no second correction engine;
- no claim of zero-origin or bounded historical completeness.

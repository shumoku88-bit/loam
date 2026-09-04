# Observation 157 — Actual authority topology does not have one universally smaller shape

Status: **OBSERVING** until the bounded Alloy matrix is qualified by CI. No production persistence topology changes here.

## Pressure

Observation 154 qualified one typed outer frame as representation-only transport for the existing EventMemory, ActualValidity, EventDescription, and EventCorrection wire representations.

Observation 155 then qualified one temporal publication property: if one complete image already exists as one authority unit, sibling staging plus one same-filesystem authority replace can prevent mixed-generation reader visibility.

PR #335 subsequently added a concrete versioned Actual-routing persistence stream. It can be loaded and published independently by sibling staging plus rename.

The resulting pressure is no longer merely aesthetic:

```text
more independent sidecars
    versus
one complete Actual authority image
```

The question is deliberately narrower than "which has fewer files?":

> Can one authority topology simultaneously give whole-Actual one-authority publication and preserve strict single-family rewrite locality, or are those two forms of simplicity structurally opposed?

## Why Alloy

Observation 155 was temporal and therefore used TLA+ / TLC.

Observation 157 is structural. It asks how fact families are partitioned into authority units and what other families become part of the publication scope when one family changes. Alloy is the primary instrument.

The bounded model names five currently concrete Actual-side persistence families:

```text
EventMemory
ActualValidity
EventDescription
EventCorrection
ActualRouting
```

It does not model their wire bytes or claim that every family is always changed together by one household operation.

## Candidate topology A — one complete authority

Every family belongs to one authority unit.

This gives the structural precondition needed by Observation 155 for one complete-image authority transition:

```text
all families
    -> one authority unit
```

But a publication caused by one changed family necessarily has the whole authority unit as its rewrite scope.

For an ActualRouting-only change, the bounded model therefore expects:

```text
rewrite scope = all five families
```

The other four families may remain semantically unchanged, but they are physically inside the same authority publication unit.

## Candidate topology B — one authority per family

Each family belongs to a distinct authority unit.

For an ActualRouting-only change, the expected rewrite scope is exactly:

```text
ActualRouting
```

This preserves strict single-family locality.

But the five families no longer form one authority unit, so a whole-Actual snapshot cannot be published by the single authority transition qualified by Observation 155 without adding coordination above the sidecars.

## Intermediate partitions

The model also permits an intermediate topology where some families share an authority and others remain independent.

Expected: SAT.

This matters because the design space is not binary. A future observed atomicity requirement may justify grouping a subset without implying that every Actual-side family belongs in one file.

## Expected Alloy matrix

```text
routingOnlyContrast                 SAT
intermediatePartitionWitness        SAT
RewriteScopeContainsChangedFamily   UNSAT counterexample
UnifiedWholeImageOneAuthority       UNSAT counterexample
SidecarsSingleFamilyLocality        UNSAT counterexample
UnifiedSingleFamilyLocality         SAT counterexample
SidecarsWholeImageOneAuthority      SAT counterexample
NoTopologyHasBothStrictProperties   UNSAT counterexample
```

For `check` commands, `UNSAT counterexample` means Alloy found no counterexample and the bounded assertion survived.

The two deliberately too-strong claims are:

```text
UnifiedSingleFamilyLocality
SidecarsWholeImageOneAuthority
```

Both are expected to fail.

## Interpretation boundary

If the matrix is qualified, the result is not "sidecars are better" and not "one file is better".

It is:

```text
whole-image one-authority publication
    and
strict single-family rewrite locality
```

are structurally competing properties once more than one independently named fact family exists.

Therefore a complete Actual authority should not be selected merely because Observation 155 showed that it *can* be published safely. Safe publication is not sufficient evidence that the stronger coupling is simpler.

The current concrete pressure from ActualRouting supports at least one independently publishable family. No observation currently requires ActualRouting to be atomically coupled with EventMemory, ActualValidity, EventDescription, and EventCorrection in one authority transition.

So the smallest decision supported by this observation, if qualified, is conservative:

```text
retain current family authority boundaries
until a concrete cross-family atomicity requirement earns a grouping
```

A future requirement may still justify a hybrid partition or a complete Actual authority. That decision must name the families that truly require one publication boundary rather than using file-count reduction as a proxy for semantic simplicity.

## Not claimed

This observation does not introduce or require:

- a production unified Actual parser, writer, loader, or file path;
- a migration of canonical household data;
- removal of any current sidecar;
- a cross-stream transaction protocol;
- byte-size or performance superiority;
- power-loss durability guarantees;
- a claim that all five families are equally optional or updated with equal frequency;
- a permanent prohibition on future authority grouping.

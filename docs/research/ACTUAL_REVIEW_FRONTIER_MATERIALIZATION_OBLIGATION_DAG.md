# G2-025 — Actual Review frontier materialization obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY CANDIDATE**

Primary instruments: **DRAKONview + obligation DAG + source reachability + focused regression**.

## Question

G2-024 removed the stored `ActualReview.Record.isCurrent` Boolean and made currentness an exact consequence of the retained outgoing correction edge.

That changed the dependency shape of `ActualReview.recordsFromActualEvidence?`.

Before G2-025 the read boundary still called:

```text
correctionFrontierMemory? evidence.events evidence.corrections
```

and then discarded the returned `EventMemory`:

```text
| some _ => ...
```

The question is therefore:

> Does Actual Review still need a materialized current Event frontier, or does it only need the correction relation to pass the same fail-closed topology admission?

## Existing ownership

`CorrectionFrontier.correctionFrontierAdmissible` owns the semantic graph obligations:

- every correction endpoint names a retained Event;
- one target has at most one successor;
- one replacement has at most one predecessor;
- replacement paths are acyclic.

These are the obligations that make the later target lookup functional and make

```text
Record.isCurrent := replacement.isNone
```

sound for the admitted review world.

`correctionFrontierMemory?` adds one more step after those obligations succeed:

```text
filter superseded Events
        |
        v
EventMemory.ofEvents?
        |
        v
materialized current Event frontier
```

That materialized frontier is necessary for callers that perform quantity projection on the current world.

## Why Actual Review is different after G2-024

Actual Review deliberately returns one transient `Record` for **every remembered Event**, including superseded historical Events needed by search and correction detail.

Its current-only day/week/undated filters do not consume a frontier `EventMemory`. They inspect:

```text
record.replacement.isNone
```

The frontier value therefore contributes no data after G2-024.

The dependency is now:

```text
ActualEvidence
    |
    v
correction topology admission
    |
    +-- invalid --> refuse review
    |
    v
ActualValidity admission
    |
    +-- invalid --> refuse review
    |
    v
project every remembered Event
    |
    +--> replacement target lookup
    |         |
    |         +--> derive currentness
    |
    +--> date / description / Event
    |
    v
transient review Records
```

No current-frontier Event collection appears in the answer path.

## Why direct admission is not weaker

The proposed production change is only:

```text
materialize current Event frontier and test Option success
```

becoming:

```text
test correctionFrontierAdmissible directly
```

It does **not** replace graph admission with `replacement.isNone`.

The same `ReplacementFrontier.structurallyAdmissible` obligations remain the gate before record projection.

`EventMemory` already carries a proof that retained EventIds are unique. `correctionFrontierMemory?` filters that valid collection before re-admitting it through `EventMemory.ofEvents?`; filtering cannot invent a duplicate EventId. The extra materialization is therefore defensive construction for consumers that need the frontier value, not an independent correction-topology distinction for Actual Review.

## Focused regression

G2-025 adds two direct `recordsFromActualEvidence?` cases.

### Accepted world

A valid EventMemory with no Correction edges must still produce one review Record per remembered Event.

### Refused world

Raw `EventCorrectionMemory` admits two distinct edges with the same target because it rejects only duplicate exact edges:

```text
root -> left
root -> right
```

This branching relation must still be rejected by Actual Review before record projection.

That regression pins the important distinction:

```text
raw correction storage admission
        !=
correction frontier topology admission
```

## KEEP boundaries

G2-025 keeps:

- `CorrectionFrontier.correctionFrontierAdmissible` as the whole-graph fail-closed gate;
- `correctionFrontierMemory?` for Balance, Budget, Role and other callers that actually consume the current Event frontier;
- exact replacement `EventId` in `ActualReview.Record`;
- ActualValidity admission as an independent read obligation;
- historical superseded Events in Actual Review;
- current-only presentation derived from replacement absence.

## Do not generalize

Do **not** replace repository-wide `correctionFrontierMemory?` calls with the predicate.

A caller that computes quantity, role balance, budget consumption, or another effective current-world projection needs the materialized frontier itself.

Do **not** add a new generic `CorrectionAdmission` wrapper. The existing predicate already names the exact semantic question.

Do **not** move topology admission into `EventCorrectionMemory`; raw fact retention intentionally allows unresolved topology for later Application-level interpretation.

## Stop point

The smallest earned simplification is local:

```text
ActualReview
    correctionFrontierMemory? + discard value
                |
                v
    correctionFrontierAdmissible
```

Everything else stays where it is.

## Qualification target

Qualification must preserve:

- correction-free Actual review projection;
- refusal of branching correction topology;
- correction-aware current day/week selection;
- historical corrected search visibility;
- Correction and Reversal TUI behavior;
- Stock-Flow and Transactions-Flow behavior downstream of Actual Review;
- malformed correction evidence failing before transient Record projection.

If the direct Record Review and integrated production workflows remain green, record:

**G2-025: SIMPLIFY QUALIFIED — Actual Review admits correction topology directly and no longer materializes a current Event frontier that it does not consume.**

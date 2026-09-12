# Normalized Actual wire qualification

This experiment follows the white-sheet model in `MINIMAL_ACTUAL_MODEL.md` and asks
a stronger implementation question:

> Can the proposed Actual shape stand on its own as admitted canonical meaning,
> without expanding back into today's Event / ActualValidity / EventDescription /
> RelationUnit / RelationDischarge families or introducing permanent `compat-*`
> vocabulary?

The answer for the synthetic qualification is **yes**.

## Candidate wire

```text
LOAM-NORMALIZED-ACTUAL  1
TX <event> <base-date> NODESC|DESC <text>
  [REPLACES <target-event>]
  [REVERSAL-OF <target-event>]

  EFFECT <locus> <measure> <quanta>
  KEYED-EFFECT <key> <locus> <measure> <quanta>

  DATE-REV <revision> <date> REPLACES ROOT
  DATE-REV <revision> <date> REPLACES REV <prior-revision>

  RELATION <relation> SOURCE <effect-key> <debtor> <creditor> <quantity>
  DISCHARGE <relation> <quantity>
ENDTX
```

Endpoint tokens are currently `household` or `external:<opaque-id>` in this research
codec. Syntax is provisional; semantic factorization is the subject of the experiment.

## Admission rules implemented directly on this shape

The Python research codec admits the candidate without translating through current
production families. It rejects:

- duplicate Event identity;
- open, branching, self, or cyclic Event correction edges;
- reversal edges with absent endpoints;
- reversal Effects that are not the exact physical inverse multiset of the target;
- duplicate or open date-revision identity;
- branching or cyclic date-correction paths;
- RelationUnit whose source stable EffectKey does not resolve in the same Event;
- duplicate RelationUnit identity;
- non-positive or source-magnitude-exceeding relation quantity;
- duplicate `(later Event, RelationUnit)` discharge rows;
- discharge to an absent relation;
- non-positive discharge quantity;
- aggregate discharge beyond the relation quantity.

Effect list order is deliberately absent from semantic observation. Duplicate Effects
at the same `(LocusId, MeasureId)` coordinate remain legal, and only an Effect actually
used as Relation source needs a stable key.

## Synthetic qualification

`tools/test_normalized_actual.py` exercises one admitted world containing all of:

- a two-edge Event correction chain;
- a two-edge occurrence-date revision chain;
- an explicit exact reversal;
- a RelationUnit anchored to one keyed Effect;
- another ordinary Effect at the same `bank/jpy` coordinate;
- two partial discharges of that relation;
- Events with and without descriptions;
- ordinary Effects whose order is permuted without changing semantic observation.

The same test also constructs invalid open/branching/cyclic correction shapes,
invalid date topology, non-inverse reversal, unresolved relation source, unknown
discharge target, and aggregate over-discharge. Each is rejected fail-closed.

At commit `b2c956ff39d3fe740260389e8fc38f197a84f8cc`, GitHub Actions reported:

```text
normalized Actual synthetic qualification PASS
fixture bytes: 1101
covered: correction/date-revision/reversal/relation/discharge/
         duplicate-coordinate/description/publication
```

## Single-generation publication prototype

The same research codec includes a deliberately small authority prototype:

```text
actual-authority/
  CURRENT
  generations/
    <sha256>/
      actual.loam
```

`stage_generation` first parses and admits complete candidate bytes, canonicalizes
them, and writes an immutable digest-addressed generation. Staging does not change
authority.

`select_generation` verifies the staged generation and then changes exactly one
`CURRENT` file with sibling temporary file + `os.replace`.

The qualification demonstrates:

1. Old is selected and readable;
2. New is completely staged;
3. readers still observe Old;
4. an unrelated malformed partial generation can exist and remains invisible;
5. one CURRENT replacement occurs;
6. readers then observe exactly New.

This concrete test complements the Alloy publication experiment from #747. It does
not claim filesystem power-loss durability, but it shows that the proposed semantic
model does not require family-wise authority transitions or relation-first dangling
sidecars.

## Important non-claim

This does **not** yet establish production observational equivalence.

The remaining decisive gate is differential qualification against today's real
production boundaries using synthetic worlds that exercise exactly the same rare
semantics:

```text
current production publishers/readers
              vs
normalized actual.loam admission/readers
```

Required comparisons:

1. Event correction history and current correction frontier;
2. complete date-revision provenance and current occurrence date;
3. explicit reversal target/reversal identity plus exact inverse validation;
4. RelationUnit source `(EventId, EffectKey)` and source payload;
5. partial discharge provenance and outstanding quantity;
6. duplicate same-coordinate Effect behavior;
7. description/no-description presentation;
8. physical balance/quantity projection;
9. current HOBS1 / CycleBudget observations where applicable.

A **test-only** bridge may be used to compare those observations. It must not become
production compatibility vocabulary or a second canonical engine.

## Current verdict

```text
white-sheet semantic factorization       QUALIFIED (Alloy, #747)
normalized standalone wire               QUALIFIED SYNTHETICALLY
sparse Effect identity                    QUALIFIED SYNTHETICALLY (#745/#746)
single selected-generation topology      QUALIFIED SYNTHETICALLY + Alloy
production observational equivalence     NOT YET QUALIFIED
production migration                     BLOCKED
```

The next work item should therefore be differential qualification, not another schema
feature and not a production migration.

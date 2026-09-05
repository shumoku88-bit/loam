# Observation 167: What do absence and correction mean for burden evidence?

Status: bounded Alloy observation following Observations 163–166.

Observation 163 separated physical movement from economic burden. Observation 166 showed that source meaning may need Effect precision and that LOAM already has the candidate reference coordinate `(EventId, EffectKey)`. Before any production burden fact is introduced, one authority question remains:

> What does it mean when burden evidence is absent, and how may later burden evidence correct an earlier interpretation without rewriting the source Event?

This observation deliberately isolates burden evidence. Directional open-relation evidence has additional debtor/creditor structure and is not assumed to inherit the same correction law until separately observed.

## Existing LOAM pressure

LOAM already uses an append-only correction pattern in several independent areas:

```text
retained original fact
+ retained replacement fact
+ explicit correction relation
-> fail-closed current frontier
```

Earlier observations also established that learned/storage order is not semantic winner authority when sibling corrections exist.

A burden overlay should therefore not casually introduce a mutable last-write-wins field unless the household case forces a different law.

## Observation-local quantity shape

The model retains:

```text
Event
Effect { Event, Key }
Unit { source Effect }
```

`Unit` is an observation-only indivisible quantity witness. It lets one Effect contain multiple quantity parts whose economic bearers differ. This does **not** propose a production `Unit` entity.

Burden evidence is represented observation-locally as:

```text
BurdenFact {
  unit
  bearer
}

BurdenCorrection {
  target
  replacement
}
```

Corrections must preserve the same source Unit. Thus changing burden interpretation does not implicitly replace the Event or Effect that carried the physical quantity.

The model also contains an observation-only latent `semanticBearer`. It is not proposed as storage. Its purpose is epistemic: current admitted evidence must remain compatible with the possible meaning, while **absence of evidence deliberately leaves multiple meanings possible**.

## Three current evidence states

For one source Unit:

```text
0 current burden facts -> unknown
1 current burden fact  -> known bearer
2+ current facts       -> unresolved candidates
```

This is intentionally different from:

```text
0 facts -> Household
```

or:

```text
last stored fact wins
```

Neither rule is granted automatically.

## Probe 1: absence supports different meanings

Two worlds contain the same source Event / Effect / Unit and no burden facts at all.

One possible meaning is household-borne; the other is outside-borne.

Expected: **SAT**.

Therefore physical evidence plus absence of burden evidence does not reconstruct the bearer.

This matters immediately for historical household data. Older shared-cost events may have valid movement evidence without retained burden-allocation evidence. A universal default of `Household` would silently reinterpret those records.

## Probe 2: explicit household evidence differs from absence

Two worlds both happen to be household-borne.

One has no burden evidence. The other has an explicit current Household burden fact.

Expected: **SAT**.

So even when a projection happens to produce the same practical answer, the epistemic state differs:

```text
unknown but possibly Household
!=
explicitly known Household
```

A UI may choose convenient presentation, but the Core should not erase this distinction if later questions depend on evidence provenance.

## Probe 3: correction changes burden without changing source

Start with:

```text
source Effect/Unit unchanged
old burden fact: Household
```

then append:

```text
replacement burden fact: Outside
correction: old -> replacement
```

Both facts remain retained. The current frontier changes to Outside while the source Event / Effect remains the same.

Expected: **SAT**.

Candidate consequence:

```text
wrong burden evidence
-/->
wrong physical Event
```

Correct the overlay unless the movement itself was also wrong.

## Probe 4: sibling burden corrections remain unresolved

From one prior burden fact, append two sibling corrections:

```text
base -> Household candidate
base -> Outside candidate
```

No learned-time or storage-order authority exists in the model.

Expected: **SAT** with both terminal candidates current.

This reuses an already-established LOAM principle rather than inventing burden-specific last-write-wins semantics.

## Probe 5: same current bearer can hide different history

Compare:

```text
A: direct Outside burden fact
```

with:

```text
B: old Household fact
   corrected to Outside
```

Both have the same current bearer. Their retained provenance differs.

Expected: **SAT**.

Therefore a flattened current bearer is not enough to reconstruct how the current interpretation was reached.

## Probe 6: one Effect can have split burden

One Effect supplies two exact quantity Units:

```text
Unit A -> Household
Unit B -> Outside
```

Expected: **SAT**.

So even after Observation 166 earned Effect-level anchoring pressure, a future production burden representation should not assume that one Effect necessarily maps to one scalar bearer label.

The likely shape is closer to:

```text
(EventId, EffectKey)
+ exact quantity partition
+ bearer evidence
```

but Observation 167 does not yet choose a production encoding for that partition.

## Deliberately too-strong check: absence determines bearer

The assertion says that identical absent evidence must imply the same semantic bearer.

Expected: **SAT counterexample**.

If Alloy finds the counterexample, `no burden evidence` cannot universally mean either Household or Outside.

## Check: one current fact determines bearer

When exactly one current burden fact exists, the observation-local semantic completion must agree with its bearer.

Expected: **UNSAT counterexample**.

This is the narrow authority rule being tested.

## Check: burden correction preserves source anchor

Every admitted burden correction connects facts about the same Unit, hence the same source Effect.

Expected: **UNSAT counterexample**.

This is a stop condition against turning burden correction into Event replacement by default.

## Candidate finding

If the matrix holds, the smallest current semantic shape is:

```text
physical Event / Effect evidence
        independent

burden evidence frontier
  0 facts -> unknown
  1 fact  -> known
  >1      -> conflict

append-only burden correction
  -> changes burden frontier
  -> does not mutate source Event / Effect
```

A practical writer may automatically publish explicit Household burden evidence for ordinary purchases when the user operation genuinely asserts that meaning. That would be **writer evidence**, not a Core theorem that missing evidence means Household.

This distinction allows old canonical movement history to remain valid without pretending it contains burden knowledge that was never recorded.

## What this does not earn

Observation 167 does **not** earn:

- production `BurdenFact` or `BurdenCorrection` types;
- observation-local `Unit` atoms as production identity;
- a mutable bearer field on Event or Effect;
- `no evidence = Household`;
- `no evidence = no outside claim`;
- last-write-wins correction;
- a generic RevisionGraph persistence layer;
- production Party / Person registry;
- directional open-relation correction semantics;
- automatic historical backfill;
- rewriting existing shared-cost settlement movements;
- persistence, CLI, TUI, or wire-format changes.

## Next pressure if qualified

The next distinct question is directional open-relation evidence:

> If burden says an outside party bears quantity, when is an `Outside -> Household` open relation known to exist, and does absence of relation evidence mean zero or unknown?

That question should be observed separately because burden ownership and debtor/creditor relation are independent semantic axes.

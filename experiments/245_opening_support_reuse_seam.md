# Observation 245 — Opening support production reuse seam

Status: **QUALIFIED — an opening Event witness can gate the existing correction-aware quantity engine without retaining a second quantity**

Baseline:

```text
4af076994a6948ff4af09078cf41a0d6747b339c
experiment: qualify temporal quantity anchor compression (#817)
```

Qualified CI:

```text
workflow: Observation 245
run:      34744194266
job:      103688928806
result:   SUCCESS
Lean:     4.33.1
```

## Trigger

Observation 243 separated current/as-of support from exact-zero historical support. Observation 244 then showed that a qualified temporal quantity anchor can represent both zero-origin and later non-zero support in the abstract, while a bare observation, a scalar basis without a boundary, or raw deltas without correction selection are insufficient.

The next production question is smaller:

> Does current household pressure actually require a new temporal quantity engine or a second retained quantity, or can an already-retained opening Event act as the support witness while current arithmetic remains owned by existing production quantity inspection?

The concrete pressure is the reconstructed liability opening entry already retained in canonical Actual. Its opening quantity is not missing from Event evidence. What is missing is typed permission to treat that retained opening entry as sufficient current-balance support.

## Existing production seam

Current production already factorizes the zero-origin path as:

```text
ZeroOriginCoverage
    -> gate
    -> inspectQuantity
         -> recorded Event quantity when no corrections exist
         -> correctionFrontierMemory? when corrections exist
```

`ZeroOriginQuantity` does not own a second quantity algorithm. It only gates the ordinary correction-aware projection.

Observation 245 asks whether non-zero opening support can preserve that same shape.

## Candidate

The experiment-local candidate is deliberately tiny:

```lean
structure OpeningSupport where
  coordinate : EffectCoordinate
  openingEvent : EventId
```

It does **not** retain:

- opening quantity;
- date;
- AccountingRole;
- description;
- source/provenance string;
- support identity;
- support correction memory;
- a second Event frontier;
- a second quantity algorithm.

The quantity already lives in the named Event's Effect. The support fact contributes only the independent meaning:

> this retained Event is admitted as the opening witness for this coordinate.

## Admission used by the probe

A candidate witness is usable only when:

1. the ordinary production correction frontier is admissible;
2. the named opening Event survives on that frontier;
3. that Event actually contains the named coordinate.

No opening meaning is inferred from:

- Event list position;
- EventId spelling;
- Locus spelling;
- sign;
- description text;
- AccountingRole;
- occurrence date.

Once admitted, the candidate delegates **exactly** to existing `inspectQuantity`.

The Lean probe includes a theorem making that delegation explicit:

```text
valid opening support
    -> inspectOpeningSupportedQuantity?
       = some (inspectQuantity ...)
```

## Qualified witnesses

The runtime probe passed all selected witnesses:

```text
opening Event reuses recorded quantity:                         PASS
ordinary Event correction remains authoritative:               PASS
zero net activity does not invent support:                     PASS
support must name the inspected coordinate:                    PASS
superseded opening witness fails closed:                       PASS
republished witness can follow ordinary correction frontier:   PASS
```

### 1. Opening Event plus retained activity reuses recorded quantity

The fixture contains:

```text
opening    -100
repayment   +20
```

With a valid opening witness, the answer is `-80` through ordinary `inspectQuantity`. The candidate performs no arithmetic itself.

### 2. Ordinary Event correction remains authoritative

The fixture then retains a correction:

```text
repayment      +20
repayment-v2   +30
repayment -> repayment-v2
```

The same opening witness yields `-70` because existing correction-frontier semantics select the effective Event. No opening-support correction engine is involved.

### 3. Numeric cancellation does not create support

A coordinate with:

```text
borrow  -5
repay   +5
```

remains unsupported when no opening witness is admitted, even though its recorded net quantity is zero.

Thus:

```text
net zero != supported zero
```

survives this seam.

### 4. Coordinate mismatch fails closed

A witness for another coordinate cannot authorize the inspected coordinate merely because the named Event exists.

### 5. A superseded opening Event fails closed

If ordinary EventCorrection supersedes the Event named by the support witness, the old witness is no longer accepted because its Event is absent from the current correction frontier.

This is conservative. The candidate does not silently chase or reinterpret the support relation.

### 6. A witness republished to the replacement Event composes normally

When the witness names the replacement opening Event, the ordinary correction frontier admits it and existing `inspectQuantity` supplies the current answer.

This shows that opening support does not require its own correction semantics. Whether production publication should automatically retarget, explicitly replace, or refuse stale support is a later authority question.

## Why this is smaller than retired QuantityBasis

Earlier QuantityBasis retained an independent scalar quantity per coordinate.
Observation 219 later found that current real-household balance answers no longer justified keeping that machinery, especially where reconstructed Event history already retained the opening quantity evidence that mattered.

Observation 245 follows that result rather than reviving QuantityBasis:

```text
retired shape
  coordinate -> independent quantity fact

qualified candidate
  coordinate -> retained opening EventId
  quantity   -> already in Actual Event
```

The candidate therefore adds support meaning without duplicating the numeric fact.

## Why this does not yet generalize arbitrary later temporal anchors

Observation 244's abstract temporal anchor remains broader than this production seam.

Current Actual occurrence time is day-grained, and current Core EventMemory deliberately gives Event list order no temporal meaning. Existing research also refuses intraday ordering without stronger evidence.

Therefore a generic production rule such as:

```text
anchor(date, quantity)
+ Events after date
```

would be under-specified when other relevant Events share that date.

Observation 245 avoids inventing an intraday cut. It qualifies only the narrower case where the opening quantity is already represented as an Event inside the retained stream and the independent fact needed is support/admission rather than another numeric snapshot.

## Production consequence

The experiment supports this architecture if real-data pressure is pursued:

```text
zero-origin current support
  ZeroOriginCoverage
      -> inspectQuantity

non-zero opening current support
  minimal opening-Event witness
      -> inspectQuantity
```

Both paths can share the same correction-aware quantity engine.

`ZeroOriginCoverage` must remain semantically strong for `StockFlowReview`; this experiment does not widen it.

## Production gate

Observation 245 does **not** yet authorize a new canonical file or writer.

Before production implementation, inspect whether an existing retained relation/evidence mechanism can carry only:

```text
EffectCoordinate -> EventId
```

without introducing a new identity family, correction family, or generic anchor subsystem.

If no existing mechanism fits, a new persistence surface is justified only if it remains smaller than the problem it solves.

A production candidate should preserve these stop rules:

```text
new quantity engine                    NO
new opening quantity fact              NO
infer support from Event activity      NO
infer support from description/sign    NO
weaken ZeroOriginCoverage              NO
anchor-specific correction semantics   NO
```

## Non-claims

This observation does not establish:

- arbitrary later temporal anchors in production;
- historical as-of support before the opening witness;
- conventional Balance Sheet completeness;
- Trial Balance completeness;
- retained earnings / closing semantics;
- accrual recognition;
- automatic support migration through EventCorrection;
- that every opening-looking Event deserves support;
- that a new persistent `OpeningSupport` type is required.

## Verdict

```text
non-zero opening support needs a second quantity engine     NO
opening quantity needs duplicate retained storage           NO
existing inspectQuantity can remain authoritative           YES
ordinary EventCorrection can remain authoritative           YES
missing / net-zero remains unsupported                      YES
stale superseded witness fails closed                       YES
arbitrary later date anchor already safe in production      NO
smallest surviving candidate                                coordinate -> opening EventId
next pressure                                                reuse existing relation/evidence machinery before adding persistence
```


## Live Lean witness retirement — 2026-09-26

The standalone research Lean witness and its dedicated workflow were retired
after the seam was promoted into production.

The live boundary is now carried by:

- `Loam/Core/OpeningSupport.lean`;
- `Loam/Persistence/OpeningSupportPersistence.lean`;
- `Loam/RoleBalanceReview.lean`;
- Role Balance / Four Voice / Counterpoint production tests covering current
  support, stale witnesses under correction, and explicit replacement support.

The research note and Git history remain the historical qualification record.

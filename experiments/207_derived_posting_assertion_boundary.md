# Observation 207 — Derived posting / assertion boundary

Status: **C-seeking bounded probe from Ledger/hledger capability reconstruction review**

## Question

The reviewed Ledger/hledger capability map exposed a stronger pressure than any single feature row:

```text
retained physical history
+ accounting-only / virtual contribution
+ query-generated contribution
+ balance assertion
+ correction-aware historical query
```

may coexist, while different consumers select different subsets of those layers.

The external trigger is concrete. In hledger 1.52:

- `--real` can exclude virtual postings from reports while balance assertions still consider virtual postings;
- `--auto` generates temporary postings and can change whether balance assertions pass;
- auto postings exist only for the report invocation and are not retained journal postings;
- `close` documentation warns that assertion results can depend on real/status filters, auto postings, costs, and dates.

Ledger likewise distinguishes real/virtual and actual/automated postings and applies automated transactions during parsing/report construction.

This observation does **not** attempt feature parity. It asks a smaller LOAM question:

> Does this composition force physical Event/Effect to grow, or can the selected answers remain determined by separate additive semantic planes, query policy, explicit assertion evidence, and the existing correction-aware horizon discipline?

## Relation to earlier observations

Observation 068 already established:

```text
policy-generated attribution
    !=
independently retained provenance
```

Observation 201 established:

```text
reconstructed quantity
    !=
external/physical quantity assertion
```

Observation 206 established:

```text
reconstruction + assertion
    !=
completeness / repair policy
```

Observation 207 is not a repeat of those distinctions. It asks whether **several contribution planes with different selection laws can safely compose with assertion validation and historical correction without being flattened into one authoritative balance scalar or pushed into Event/Effect fields.**

## Observation-local model

The bounded specimen uses four exact quantity atoms (`Q0`–`Q3`) and two knowledge horizons (`H0`, `H1`).

Each world carries:

```text
originalPhysical
correctedPhysical? + correctionKnownAt?
queryHorizon

accountingOnly

generatedByRule
autoMode = AutoOff | AutoOn

reportRealness = RealOnly | IncludeAccounting

asserted
```

These are observation-local names. They do not propose production `VirtualPosting`, `AutoPosting`, `Account`, or `BalanceAssertion` Core types.

### Bounded arithmetic guard

The observation deliberately uses a tiny explicit addition table over `Q0`–`Q3`. That relation is partial: sums such as `Q3 + Q1` are outside the represented bounded specimen rather than meaningful semantic failures.

The first exact-head CI run exposed that distinction. Positive determinism checks could otherwise obtain a counterexample only because a derived report or assertion balance did not exist in the tiny arithmetic table. The model therefore requires the compared derived balance(s) to be defined before treating a difference as semantic evidence.

This guard is observation-local. It does not propose a production overflow policy or make undefined arithmetic equal to a failed assertion.

### Physical selection

A correction learned at `H1` is visible only to the `H1` query. An `H0` query continues to select the original physical quantity.

### Report selection

A report can choose:

```text
RealOnly
    physical + generated contribution

IncludeAccounting
    physical + accounting-only + generated contribution
```

Generated contribution appears only when `AutoOn`.

### Assertion selection

Assertion validation deliberately has a different law:

```text
physical
+ accounting-only
+ generated contribution only when AutoOn
```

`reportRealness` does not alter assertion validation.

This is the key pressure. One universal `selected balance` knob would be too small if report and validation legitimately observe different planes.

## C-seeking attacks

### 1. Real-only report scalar determines assertion outcome

Hold selected physical quantity, report mode, auto mode, assertion, and visible report scalar fixed. Change only accounting-only evidence.

Expected: **counterexample exists**.

Representative worlds:

```text
Left
  physical       Q1
  accountingOnly Q0
  RealOnly report Q1
  assertion      Q2
  -> FAIL

Right
  physical       Q1
  accountingOnly Q1
  RealOnly report Q1
  assertion      Q2
  -> PASS
```

So the visible report scalar cannot stand in for assertion authority.

### 2. Selected scalar determines provenance

Two worlds can both report `Q2`:

```text
World A
  physical       Q2
  accountingOnly Q0

World B
  physical       Q1
  accountingOnly Q1
```

Expected: **SAT witness / provenance compression falsified**.

### 3. Physical selection + assertion determines validation

Keep the selected physical quantity and asserted quantity equal, but vary accounting-only evidence or generated-policy state.

Expected: **counterexample exists**.

So physical Event history plus an expected scalar is too small.

### 4. Auto policy changes assertion result

Keep retained evidence fixed. Toggle `AutoOff` / `AutoOn`.

Representative bounded world:

```text
physical       Q1
accountingOnly Q1
generated rule Q1
asserted       Q2

AutoOff -> assertion balance Q2 -> PASS
AutoOn  -> assertion balance Q3 -> FAIL
```

This demonstrates query-generated contribution as independently observable policy input. It does not establish that generated output is retained historical fact.

### 5. Correction horizon composes with derived assertion

Retain both original and corrected physical evidence, with the correction learned at `H1`:

```text
original  Q1
corrected Q2
generated Q1
asserted  Q2
```

Then:

```text
H0 query -> original Q1 + generated Q1 = Q2 -> PASS
H1 query -> corrected Q2 + generated Q1 = Q3 -> FAIL
```

The later correction must not rewrite the old `H0` answer.

## Positive candidate

The model also checks the conservative candidate:

```text
correction-aware physical history
+ accounting-only evidence
+ generated-rule quantity
+ AutoMode
+ report realness policy
+ explicit assertion
+ query horizon
    -> selected report scalar + assertion result
```

If that candidate is deterministic in the bounded model, the pressure is **B-level additive composition**, not demonstrated C-level Core-shape failure.

## Expected Alloy matrix

```text
representativeRealReportVsAssertion               SAT
sameRealReportDifferentAssertionOutcome            SAT
sameSelectedScalarDifferentProvenance              SAT
autoModeChangesAssertionOutcome                    SAT
correctionHorizonChangesDerivedAssertion            SAT

ReportScalarDeterminesAssertionOutcome             SAT counterexample
SelectedScalarDeterminesPlaneProvenance            SAT counterexample
PhysicalSelectionAndAssertionDetermineValidation   SAT counterexample
AssertionIndependentOfReportRealness               UNSAT counterexample
ExplicitLayersDetermineSelectedViews               UNSAT counterexample
LaterCorrectionDoesNotRewriteOldHorizon             UNSAT counterexample
```

## Interpretation gate

Do not call this a Core failure merely because the flat scalar attacks succeed.

Classification rule:

```text
flat scalar / one selected-balance authority fails
    -> missing semantic separation is real

separate additive planes + policy + assertion + horizon succeed
    -> B / CONSERVATIVE EXTENSION pressure

only if the additive candidate also fails because Event/Effect itself cannot
represent the legitimate selected answers
    -> C / CORE SHAPE PRESSURE
```

## Production boundary

Even if the expected matrix succeeds, Observation 207 does **not** earn:

- `VirtualPosting` as a production type;
- `AutoPosting` as a production type;
- a generic accounting-posting plane;
- a retained generated-Event stream;
- automatic materialization of policy output;
- a balance assertion writer;
- Ledger/hledger compatibility;
- a universal real/virtual flag on `Effect`;
- a new field on `Event` or `Effect`.

The narrow result would only be that contribution-plane provenance and selection policy cannot be erased into one scalar, while a conservative additive representation remains sufficient in this bounded composition.

## Tool choice

**Alloy first.**

The primary question is structural distinguishability and bounded compositional sufficiency. TLA+/SPIN would become appropriate only if later work asks about concurrent rule changes, assertion publication, or racing corrections rather than the static information boundary tested here.

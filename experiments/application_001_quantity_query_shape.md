# Application 001 — quantity inspection as a query-shaped boundary

## Why this experiment exists

LOAM has reached a point where a small read-only household-facing application layer is plausible, but choosing an implementation language first would reverse the development order used so far.

The question here is therefore not:

```text
Which language should implement the household application?
```

It is:

```text
What is the smallest named household-facing question
that the current semantic evidence can answer honestly?
```

The first candidate is quantity inspection.

## Do not call this `current quantity` yet

The current Practical Core already distinguishes two quantity projections:

- `EventMemory.quantityAtRecorded`, which sums all remembered Event facts at one Locus/Measure coordinate;
- `EventCorrection.quantityAtEffective?`, which applies exactly one explicit Correction when both endpoint Events can be projected.

The existing practical CLI also fails closed when two or more Corrections exist because no correction-frontier projection has yet been earned.

Therefore an application operation named merely `current quantity` would hide an unresolved semantic choice.

Application 001 instead asks:

> Given the retained Event and Correction evidence, which already-earned quantity projection, if any, may answer this query?

## Query result modes

The experiment models four outcomes:

```text
0 Corrections
    -> RecordedQuantity

1 Correction + both endpoint Events present
    -> SingleCorrectionEffectiveQuantity

1 Correction + missing endpoint Event
    -> MissingCorrectionEndpoint

2+ Corrections
    -> FrontierRequired
```

The last two are not exceptional implementation accidents. They are part of the application answer.

A household-facing layer must be able to say "I cannot answer this quantity question from the retained evidence yet" without manufacturing a correction frontier or silently falling back to the recorded aggregate.

## What this query observes

Application 001 observes only the evidence needed to choose the quantity projection boundary:

```text
remembered Event membership
Correction membership
Correction endpoint closure
```

The model also carries two deliberately unobserved evidence families:

```text
Event descriptive context
Plan evidence
```

Changing those while keeping the quantity evidence fixed must not change the inspection mode.

This is the application-layer form of context-relative sufficiency:

```text
named query
    -> distinctions the query may observe
    -> evidence sufficient for those distinctions
    -> answer or explicit refusal
```

It is not a claim that descriptive context or Plan evidence are globally irrelevant. A later query may require them.

## Alloy experiment

`application_001_quantity_query_shape.als` checks the result-mode boundary without modeling arithmetic already retained in Lean.

Expected witnesses:

- zero Corrections can produce the recorded mode;
- one closed Correction can produce the single-correction effective mode;
- one open Correction produces explicit refusal;
- multiple Corrections produce frontier-required refusal;
- descriptive and Plan evidence can vary while the quantity-inspection mode remains unchanged.

Expected safety checks:

- zero Corrections never select another mode;
- one closed Correction never selects another mode;
- one open Correction never pretends to be effective;
- multiple Corrections never pretend a correction frontier exists;
- evidence outside this query vocabulary cannot change its mode.

## Why Alloy here, rather than another quantity theorem

The exact arithmetic and storage-order invariance of the two currently earned quantity projections already live in Lean.

The new question is relational and application-shaped:

```text
which retained evidence state
    -> which application answer mode
```

Alloy is the smaller tool for checking this partition before adding an executable host.

No new quantity arithmetic is introduced.

## Executable-host question

Only after the query contract survives this experiment should LOAM ask which language should execute it.

Three candidates have different experimental value.

### Ada + SPARK

Ada/SPARK remains a strong candidate for a durable native application boundary. It can make admission/refusal states explicit and later place proof obligations close to imperative I/O and persistence code.

But LOAM already has substantial evidence from HRA that this combination works well. Using it first would teach less about whether the unusual LOAM development process changes the shape of the executable layer.

### Dafny

Dafny is especially interesting for the first host probe because specification, automated verification, and executable program can inhabit the same source artifact.

That makes it possible to test a new question:

```text
Can a query-shaped LOAM application operation
become executable without duplicating
its contract into a separate conventional application model?
```

If yes, Dafny may occupy part of the space that would otherwise be split between a Lean specification and an application implementation.

This does not make Dafny the new LOAM core language. It would be one executable-host experiment.

### PureScript

PureScript is interesting for a different reason. Its algebraic data types and effect discipline can represent narrow query results naturally, and it is well suited to a human-facing shell.

For example, a UI can be forced to handle all four result modes rather than treating refusal as an untyped error string.

PureScript would therefore test:

```text
Can the human-facing layer remain shaped by the formal query contract
without becoming another large household domain model?
```

PureScript is not being proposed here as a replacement for Alloy, Lean, or a verification-aware language.

## Proposed next probe

If this application contract qualifies, the highest-information next experiment is a **small Dafny implementation of Application 001**, not a full household application.

The Dafny probe should:

1. encode exactly the four result modes;
2. verify that every Correction-cardinality/closure case returns the required mode;
3. contain no Plan, Series, refund, category, merchant, budget, or descriptive-context vocabulary;
4. perform no canonical writes;
5. avoid inventing stable imported identity;
6. remain small enough that an Ada/SPARK or PureScript implementation can later be compared against the same contract.

PureScript can then become a useful second host probe if we want to test UI/application-shell ergonomics rather than proof ergonomics.

## What this does not earn

This experiment does not earn:

- a generic `Application` framework;
- a generic `Query` type in Practical Core;
- a generic `Result`/`Evidence` ontology;
- a `CurrentQuantity` semantic primitive;
- a correction-frontier algorithm;
- an Ada, Dafny, or PureScript dependency;
- a household TUI;
- canonical write authority.

It also does not introduce Observation 085.

## Practical Core impact

None.

```text
Observation 085:          not introduced
Practical Core additions: 0
Persistence additions:    0
CLI additions:            0
wire-format additions:    0
canonical writes:         0
new host language:        not yet selected
```

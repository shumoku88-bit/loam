# Observation 160: Can LOAM expose query and what-if projections without creating a second accounting authority?

Status: bounded Alloy observation prompted by the first practical `loamBudgetWindow` query against canonical household data and the desire to let ChatGPT, TUI, CLI, and later UI clients share the same Application boundary.

## Question

LOAM can now derive a real household Remaining value from canonical evidence over an explicit coordinate window.

The next pressure is to make that capability broadly callable. A query bridge is useful only if it does not accidentally create a second source of household truth or let a hypothetical answer masquerade as a canonical mutation.

This observation asks:

> What is the smallest contract that lets multiple clients ask the same question, lets a client explore a hypothetical overlay, and still keeps canonical evidence as the only accounting authority?

A second transport concern appears immediately: a response may outlive the exact instant at which it was computed. If canonical data changes later, a bare answer can become stale. Does the response therefore need provenance identifying the canonical snapshot from which it was derived?

## Observation-local abstraction

The bounded model intentionally uses unit-count Capacity and Actual facts rather than LOAM's exact quantity algebra. The observation is about authority, provenance, and projection boundaries, not arithmetic representation.

A canonical `Snapshot` contains only:

```text
Capacity facts
Actual facts
```

A `Query` selects a Purpose.

A `Hypothesis` is an overlay that may add Capacity or Actual facts for projection only.

A `BoundResponse` contains:

```text
source Snapshot
Query
optional Hypothesis
Surface
value
```

`Surface` is deliberately semantically irrelevant and has three witnesses: ChatGPT, TUI, and CLI.

A `BareResponse` omits the source Snapshot. It represents the tempting smaller transport shape in which a result is returned without saying which canonical revision produced it.

The eventual implementation need not retain a `Snapshot` domain entity. For a Git-backed query bridge, a source commit/revision can play this provenance role. The model is only asking whether some stable source binding is observable.

## Candidate contract

### Canonical query

```text
Remaining(snapshot, query)
```

is derived only from canonical facts in that snapshot.

### Hypothetical query

```text
HypotheticalRemaining(snapshot, query, overlay)
```

is derived from the snapshot plus the overlay without changing the snapshot.

### Explicit apply

Applying the same overlay as canonical evidence is a separate relation producing a different canonical snapshot.

The numerical result of a simulation may equal the result after explicit apply. That equality must not collapse the semantic distinction between "projected" and "admitted".

## Probes

### 1. Different surfaces can share one answer

Two bound responses may come from different surfaces while sharing source snapshot, query, and hypothesis. They can return the same value.

Expected: **SAT**.

This is the desired client architecture: ChatGPT, TUI, CLI, and future UI do not own separate budget semantics.

### 2. A hypothetical overlay can change the answer without changing canonical evidence

A fresh one-unit Capacity overlay changes the hypothetical Remaining by one while the base Snapshot remains the base Snapshot.

Expected: **SAT**.

This is the `"予備から食費へ2000円動かしたらどうなる？"` shape in miniature. Asking the question is not an accounting write.

### 3. Simulation can numerically match an explicit later apply

There can be a base Snapshot, a hypothetical overlay, and a distinct later Snapshot that explicitly contains that overlay. The simulation answer against the base can equal the canonical answer against the later Snapshot.

Expected: **SAT**.

The important result is not the numerical equality. It is that the two source states remain distinct. A matching number does not turn a hypothetical response into authority.

### 4. A source-less response can be stale

A bare response can be exactly correct for one Snapshot and wrong for another Snapshot using the same query.

Expected: **SAT**.

Therefore, once query results can cross a process/UI boundary or persist long enough for canonical data to advance, result provenance is independently observable. A response should identify the canonical source revision from which it was derived.

This provenance is transport/query metadata, not a new household financial fact.

### 5. Same source + same query + same hypothesis is surface-independent

No pair of bound responses with equal source, query, and hypothesis may disagree merely because one came through ChatGPT and another through TUI/CLI.

Expected check: **UNSAT counterexample**.

### 6. A read-only execution preserves every canonical query projection

If a query execution preserves canonical Capacity and Actual facts, every canonical Remaining query has the same answer before and after the execution.

Expected check: **UNSAT counterexample**.

This captures the intended non-authority of query transport.

### 7. A bound current response matches its bound snapshot

If a non-hypothetical bound response names the current Snapshot as its source, its value must equal the canonical projection from that Snapshot.

Expected check: **UNSAT counterexample**.

This is the property that a source revision lets a consumer check conceptually: "is this answer about the canonical revision I think it is about?"

## Candidate finding

If the expected matrix holds, the next query bridge does not need a second accounting state model.

The smallest useful boundary is approximately:

```text
canonical source revision
+ query parameters
+ optional hypothetical overlay
-> derived result
```

with these laws:

1. Query execution is read-only with respect to canonical household evidence.
2. Result semantics do not depend on presentation surface.
3. Hypothetical overlays affect only hypothetical projection until separately admitted through an authority-bearing write path.
4. Query responses that can outlive an execution instant should identify the canonical source revision that produced them.
5. Query responses and simulation results are not themselves canonical household evidence.

## What this does not earn

This observation does **not** earn:

- a retained `Query` household entity;
- a retained `Response` household entity;
- a `BudgetPeriod` entity;
- stored Remaining;
- an Envelope object;
- a generic command bus;
- a second database for UI state;
- an automatic path from simulation to canonical mutation;
- HRA compatibility machinery.

A GitHub Actions request/result artifact, HTTP response, CLI output, or future local IPC message may all satisfy the same boundary if they bind the result to the exact canonical source revision and do not acquire accounting authority.

## Stop condition

Do not make query transport canonical merely because external clients need a stable protocol.

Introduce additional retained query identity only if a real workflow needs properties that source revision + query parameters cannot reconstruct, such as durable audit identity for externally signed requests or an asynchronous approval protocol.

Until then, keep the river one-way:

```text
canonical evidence -> Application projection -> client response
```

and keep hypothetical water in a separate channel until an explicit authority-bearing action admits it.

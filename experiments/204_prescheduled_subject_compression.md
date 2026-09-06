# Observation 204 — Can F051 and F052 share one subject-attached pre-Scheduled carrier?

Status: **OBSERVING concept-pressure compression probe**

Sources:

```text
F051 / Observation 196
  known existence != exact quantity

F052 / Observation 202
  exact quantity != exact temporal placement
```

## Question

The two counterexamples could tempt LOAM to grow state-specific concepts such as:

```text
amount-unknown obligation
amount-known / due-unknown obligation
```

Observation 204 asks a smaller question first:

> For the selected F051/F052 queries, can both pressures be represented by one stable subject identity with independently attached exact amount and exact due evidence, without changing exact `ScheduledOccurrence` and without introducing separate state-specific nouns?

This is a packaging/compression question, not a product-design proposal.

## Candidate carrier

Observation-local vocabulary:

```text
Subject
Amount
Due
World
```

Each world retains only:

```text
known   : set Subject
amount  : Subject -> lone Amount
due     : Subject -> lone Due
```

Attachments require the subject to be known.

For this bounded probe, every `Subject` is already inside the selected pre-Scheduled/date-bearing pressure. Therefore absence of `due` means only that no exact temporal placement is retained yet. The model deliberately does **not** distinguish financial `no due date` from `due undetermined`; that remains outside this probe.

Likewise, absence of `amount` means no exact amount is retained yet. Approximate/range quantity is outside scope.

## Why this is smaller than state-specific concepts

The candidate does not introduce constructors such as:

```text
UnknownAmountObligation
KnownAmountUnknownDue
ExactScheduledObligation
```

Instead the same subject can be observed through selected snapshots:

```text
known only
known + exact amount
known + exact amount + exact due
```

The final state is only an observation-local exact-Scheduled-like view. Production `ScheduledOccurrence` remains unchanged.

## Selected attacks

### 1. Represent both adjacent pressures

Can one carrier represent an existence-only subject and an amount-known / due-not-yet-attached subject?

Expected: **SAT**.

### 2. Same amount, different due knowledge

Can equal subject identity and exact amount coexist with no exact due in one world and exact due in another?

Expected: **SAT**.

This should reproduce the F052 separation without a dedicated state-specific noun.

### 3. Attachments do not determine known existence

If amount and due attachments are identical, can known-subject membership still differ?

Expected assertion counterexample: **SAT**.

This is the F051 lower bound: attachment domains alone cannot replace explicit known existence.

### 4. Known + amount do not determine due placement

Expected assertion counterexample: **SAT**.

This is the F052 lower bound inside the candidate carrier.

### 5. Loose evidence pools lose correspondence

With two known subjects, can the same global amount set and due set support different subject-specific amount/due pairings?

Expected: **SAT**, and the corresponding assertion should have a counterexample.

This tests whether stable subject attachment matters, rather than keeping quantity/time evidence as uncorrelated global bags.

### 6. Full subject-attached evidence determines selected views

Once `known`, subject-attached `amount`, and subject-attached `due` are all fixed, can the selected amount pool, due pool, or complete subject/amount/due view still differ?

Expected assertion counterexample: **UNSAT**.

This is only bounded sufficiency for the selected F051/F052 views.

## Architectural interpretation under test

Possible result if the matrix holds:

```text
F051 + F052
  do not require two state-specific concept families

one stable subject-attached carrier
  can preserve the selected distinctions

but
  existence / quantity / time remain independent information dimensions
```

That would still be **B / CONSERVATIVE EXTENSION pressure**, not C. It would support keeping exact `ScheduledOccurrence` exact and, if dogfood later requires partial future knowledge, first considering one small additive family rather than weakening Scheduled or inventing several household-domain nouns.

It would not prove that the observation-local `Subject` is the right production concept.

## Deliberate boundaries

Observation 204 does not establish:

- a production `Expectation`, `Obligation`, `Claim`, `Bill`, or `Subject` type;
- a generic partial-record or entity-component framework;
- nullable fields inside `ScheduledOccurrence`;
- no-due-date semantics;
- approximate/range quantity;
- time-known / amount-unknown symmetry beyond existing bounded evidence;
- transitions or lifecycle from partial knowledge to Scheduled publication;
- recurrence generation;
- Commitment, Remaining, Headroom, Capacity, notification, persistence, CLI/TUI, or canonical-data behavior.

Runtime remains research-only.

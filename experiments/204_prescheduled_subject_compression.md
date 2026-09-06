# Observation 204 — Can F051 and F052 share one subject-attached pre-Scheduled carrier?

Status: **DONE — bounded compression candidate SURVIVED / RESEARCH_ONLY**

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

## Executed result

Dedicated Observation 204 CI completed SUCCESS on executable head:

```text
935fe5fc186c42d453adce52a090e5f9129deb63
```

workflow run:

```text
34008892319
```

job:

```text
101421066043
```

Alloy 6.2.0 + Sat4j produced exactly the selected matrix:

```text
representativeExistenceThenAmountBeforeDue    SAT
sameAmountDifferentDueKnowledge               SAT
sameLoosePoolsDifferentPairing                SAT
AttachmentsDetermineKnownSubjects             SAT counterexample
KnownAndAmountDetermineDuePlacement           SAT counterexample
LoosePoolsDetermineSubjectPairing             SAT counterexample
SubjectAttachedCarrierDeterminesSelectedViews UNSAT counterexample
```

## What the result says

### One carrier can represent both adjacent pressures

The representative witness uses the same subject identity across two selected snapshots:

```text
Left
  known S1
  no exact amount
  no exact due

Right
  known S1
  exact amount A1
  no exact due
```

So the selected F051 existence-before-quantity state and the F052 amount-before-placement state do not require separate state-specific subject types inside this bounded vocabulary.

A second witness keeps subject identity and exact amount equal while due evidence differs:

```text
Left
  S1 + A1
  no exact due

Right
  S1 + A1 + D1
```

This reproduces the F052 separation without introducing a `KnownAmountUnknownDue` constructor.

### Attachments alone are too small

`AttachmentsDetermineKnownSubjects` has a counterexample.

Two worlds can have identical empty amount/due attachments while one knows subjects to exist and the other does not.

Therefore:

```text
attachment domains
  -/->
known existence
```

The F051 existence distinction cannot be erased.

### Known existence + amount are still too small

`KnownAndAmountDetermineDuePlacement` has a counterexample.

Equal known-subject membership and equal amount attachment can coexist with different exact due evidence.

Therefore the F052 temporal distinction also survives inside the shared carrier.

### Loose amount/time pools are too small

The two-subject witness is:

```text
Left
  S1 -> A1, D1
  S2 -> A2, D2

Right
  S1 -> A1, D2
  S2 -> A2, D1
```

Both worlds have the same known-subject set, the same global amount set, and the same global due set. But the subject-specific complete triples differ.

Therefore:

```text
identity-free amount pool + due pool
  -/->
subject-specific future expectation
```

Stable attachment correspondence matters once more than one subject exists.

### Full subject-attached carrier closes the selected gap

`SubjectAttachedCarrierDeterminesSelectedViews` has no counterexample in the selected scope.

Once all three retained dimensions are equal:

```text
known subject identity
subject-attached exact amount
subject-attached exact due
```

the selected amount pool, due pool, and complete subject/amount/due view are fixed.

This is bounded sufficiency only. It does not prove a universal minimal representation.

## Compression interpretation

Observation 204 therefore gives a more precise answer than either "one new concept" or "two new concepts":

```text
state-specific nouns
  can be avoided for the selected F051/F052 states

but

stable subject identity
known existence
exact quantity evidence
exact temporal evidence
  remain separately observable dimensions
```

The candidate compresses **packaging**, not information.

This differs from Observation 203. There, flattening reservation provenance and operation-right provenance into one scalar usable-quantity envelope lost meaning. Here, one subject-centered carrier can retain the independent dimensions without inventing a separate type for every partial-knowledge state.

## Rebuild-pressure result

Current architectural reading remains:

```text
B / CONSERVATIVE EXTENSION PRESSURE
```

Nothing in Observation 204 requires changing the established exact meaning of `ScheduledOccurrence`.

If real dogfood later requires pre-Scheduled partial knowledge, the current evidence favors testing one small additive subject-attached family before either:

- weakening `ScheduledOccurrence` with nullable fields, or
- introducing several household-domain state nouns.

That is still only a future implementation candidate, not an earned product concept.

## Deliberate boundaries

Observation 204 does not establish:

- a production `Expectation`, `Obligation`, `Claim`, `Bill`, or `Subject` type;
- a generic partial-record or entity-component framework;
- nullable fields inside `ScheduledOccurrence`;
- no-due-date semantics;
- approximate/range quantity;
- unrestricted three-way independence of existence, quantity, and time;
- time-known / amount-unknown symmetry beyond existing bounded evidence;
- transitions or lifecycle from partial knowledge to Scheduled publication;
- recurrence generation;
- Commitment, Remaining, Headroom, Capacity, notification, persistence, CLI/TUI, or canonical-data behavior.

Runtime remains `RESEARCH_ONLY`.

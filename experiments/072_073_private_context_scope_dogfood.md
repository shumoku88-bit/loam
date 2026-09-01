# Observations 072–073 private dogfood — current descriptive-context scope boundary

## Purpose

Observation 072 established that a retained quantity-placement fact does not determine all human-facing context that may make an Event recognizable.

Observation 073 then established a bounded structural distinction:

```text
context attached to the whole Event
    !=
context attached to an individual Effect
```

This checkpoint asks what the current private canonical Actual source and its public parser boundary say about those observations today.

It does not introduce Observation 085.

## Existing boundary

Observation 072 deliberately did not name the missing context `Merchant`, `Place`, `Purpose`, `Category`, `Counterparty`, `Description`, or `Note`.

Observation 073 likewise did not require two concrete context fields. It only showed that Event-scope and Effect-scope attachments cannot be collapsed for free. A single Event-level attachment becomes sufficient only after adding an explicit semantic law that every Effect inherits the Event context.

The present dogfood keeps both restraints.

## Privacy-safe current source pressure

A read-only inspection of the current private canonical Actual source establishes only these structural categories:

```text
Transaction/Event header description channel:     present and used
Transaction-block metadata channel:                present and used
Event shape with three-or-more postings:           present
Posting-inline comment channel:                    not observed in the current snapshot
```

No private descriptions, dates, quantities, posting coordinates, account-like names, metadata keys or values, identities, counterparties, paths, or hashes are retained here.

The important point is not that the current source contains some particular description. It is that the canonical source actively carries human-facing description at whole-Transaction scope while also exercising Events with more than two physical Effects.

That makes the attachment-scope question non-vacuous without proving that Effect-local descriptive context is currently needed.

## Public parser retention boundary

The public h-kernel journal parser makes the current representation boundary explicit.

At Transaction scope it retains:

```text
Transaction description
JournalTransactionSource metadata
```

where generic indented `; key: value` lines are parsed as `JournalMetadata` attached to the Transaction source block.

At Posting scope, `JournalPostingSource` retains only source-line and quantity-column coordinates. The posting parser removes text beginning at an inline semicolon before parsing the posting body.

So the current parser boundary is structurally:

```text
Transaction header description
    -> retained Transaction meaning

standalone indented metadata comment
    -> retained Transaction-source metadata

Posting inline comment
    -> not retained as Posting semantic evidence

Posting-level metadata object
    -> absent from the current Journal source model
```

This is a representation fact, not a claim that h-kernel is defective. The current household vocabulary may simply not ask any question that requires Effect-local descriptive evidence.

## Finding A — Observation 072 remains operational

The current canonical source does not consist only of quantity-placement facts. It actively retains a separate whole-Transaction descriptive channel.

Therefore the practical design must continue to avoid overloading `Locus`, quantity, or identity tokens with human-facing recognizability.

The safe reading remains:

```text
quantity-placement fact
    !=
all human-facing descriptive evidence
```

This checkpoint still does not identify what domain noun the descriptive evidence should have in LOAM.

## Finding B — Observation 073 is a live representation boundary, not yet a demanded feature

The current private source contains multi-Effect Events, so there are real structures to which an Effect-local question could attach.

But the current canonical source/parser does not retain a semantic Effect-level descriptive channel.

That means:

```text
current canonical encoding
    preserves Event-scope descriptive evidence

but

current canonical encoding
    does not currently preserve Effect-scope descriptive evidence
```

The second statement must not be inverted into:

```text
Effect-scope descriptive evidence is unnecessary
```

Absence of a retained channel is not a proof that no future vocabulary will need it.

Likewise, it would be premature to add the channel merely because Observation 073 exhibited possible split-context worlds. A concrete later question must expose a distinction that the current Event-only descriptive representation collapses.

## No natural-language reconstruction

This checkpoint deliberately does not split a Transaction description into guessed sub-descriptions and attach them to Postings.

For example, punctuation, word order, account-like coordinates, amounts, or textual resemblance are not treated as evidence that one phrase belongs to one Effect.

Doing so would invent exactly the attachment relation that Observation 073 says must remain explicit if it matters.

So the current operational rule is:

```text
Event-level descriptive evidence present
    -> observe it at Event scope

Effect-level descriptive evidence not explicitly retained
    -> do not reconstruct it from prose or physical shape
```

## Executable observer

`tools/private-context-scope-shadow.py` makes the current lexical boundary repeatable without exposing private values.

It reports only structural counts for:

- Transaction records with non-empty header descriptions;
- Transaction-block metadata comment coverage;
- Posting-line coverage;
- Events with three or more Postings;
- Posting lines that lexically contain inline comments.

It does not classify any text as merchant, place, purpose, category, counterparty, note, or another ontology. It does not turn an inline Posting comment into Effect-level semantic context. It also does not infer Effect context from the Event description.

The dedicated synthetic workflow verifies that changing description values without changing structure does not change the summary, that private fixture values do not escape, that source bytes remain unchanged, and that malformed Transaction-without-Posting input fails closed.

## Relationship to later sufficiency observations

There is a useful resonance with the later context-relative sufficiency arc:

```text
future question
    -> distinctions that must survive
    -> sufficient retained evidence
```

Observation 073 tells us one distinction that *can* matter: Event scope versus Effect scope.

The current private snapshot has not yet supplied a later question that requires Effect-local descriptive evidence. Therefore no additional retained state is earned merely from the possibility.

## Practical Core impact

None.

```text
Practical Core additions: 0
Persistence additions:     0
CLI additions:             0
wire-format additions:     0
Observation 085:            not introduced
```

This checkpoint does not earn a generic `Context`, `Metadata`, `Merchant`, `Place`, `Purpose`, `Category`, `Counterparty`, `Description`, or `Note` primitive. It does not require an h-kernel source-format change. It only makes the current scope boundary observable and leaves the next semantic move to concrete future pressure.

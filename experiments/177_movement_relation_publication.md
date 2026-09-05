# Observation 177: Movement relation publication activation

## Question

Observation 176 promoted a small open-relation vocabulary. PR #360 introduces only that Core vocabulary, and stacked PR #361 introduces a fail-closed Application admission/frontier without choosing persistence.

The next step in the conservative sequence is now concrete enough to ask:

> Can the first practical Movement relation writer use one independently persisted positive-relation stream, with Event publication remaining the semantic activation edge, without introducing a multi-stream transaction bundle or a stored negative `NoRelation` receipt?

This observation is deliberately scoped to **fresh practical Movement publication**. It does not claim one protocol for Scheduled completion, correction replacement, date correction, or historical publication. Observation 171 already established that those operation kinds may share a qualification law while retaining distinct physical publication protocols.

## Existing production shape

Current `MovementCli` already publishes supporting evidence before Event authority:

```text
Actual validity
-> optional EventDescription
-> Event last
```

If Event publication fails, the CLI explicitly says the already-published supporting evidence remains inert until that `EventId` exists.

That shape matches earlier split-publication observations: raw relation-like evidence may safely appear before its referenced Event because fail-closed reference admission keeps it semantically inactive.

Open relation adds one important new pressure. Under a future completeness-covered region:

```text
covered source + no current positive relation -> known-none
```

So a reader must never observe a newly authoritative covered Event while still holding an older relation-stream snapshot that omits a positive relation belonging to that Event. That mixed snapshot would manufacture false known-none.

## Candidate Movement protocol

The operation-specific adapter first decides relation meaning for the new Event/Effect.

### Positive relation

```text
prepare Event + validity + optional description + RelationUnit
-> publish supporting validity/description
-> publish positive RelationUnit
-> Event last as authority commit
```

The relative order among supporting evidence is not the semantic claim here. The required edge is:

```text
required positive relation evidence
BEFORE
Event authority
```

If relation persistence fails, Event publication must not occur.

### No relation

For qualified no-edge meaning:

```text
prepare Event + validity + optional description
-> complete relation qualification
-> publish supporting validity/description
-> publish no relation row
-> Event last as authority commit
```

The apparent `publish no relation row` step is intentionally empty. The candidate relies on writer closure and Event authority instead of storing routine negative evidence.

Once a covered Event is visible, the writer contract says its relation decision was already completed. A later relation-stream read may therefore interpret clean absence as known-none.

This is the key compression under test:

```text
qualified writer path
+ Event authority visible
+ relation stream contains no positive row for source
-> known-none
```

without:

```text
NoRelation fact per Event/Effect
```

## Reader order

For this bounded fresh-Movement protocol, the candidate acquisition order is:

```text
Event stream
-> relation stream
```

If the reader sees the new Event, a single monotone writer must already have completed any required positive relation publication before the Event commit. Reading the relation stream afterward can therefore catch up to that supporting evidence.

The reverse order is unsafe. A reader can acquire an old empty relation snapshot, allow the writer to complete relation + Event publication, then acquire the new Event and falsely derive known-none.

This is the same ordering asymmetry observed for correction split publication in Observation 059, but the failure mode is now stronger: not merely a transient duplicate effective Event, but a false semantic negative produced by completeness compression.

## Why SPIN

The question is about concrete writer/reader interleavings and a crash prefix, not static relation shape. SPIN is therefore smaller and more direct than another Alloy ontology model.

Three bounded models are checked.

### Safe candidate

`177_movement_relation_publication_safe.pml`

The writer nondeterministically chooses positive-edge or no-edge meaning.

- positive edge publishes the relation row before Event;
- no-edge publishes no relation row;
- relation qualification completes before Event;
- the writer may stop before Event to model the important crash prefix;
- the reader acquires Event before relation.

Assertions require:

- visible Event implies relation qualification had completed;
- Event + positive row implies the retained meaning really has an edge;
- Event + relation absence implies the retained meaning really has no edge;
- relation-first crash residue with no Event remains semantically inert.

Expected result:

```text
0 errors
```

### Unsafe writer order

`177_movement_relation_publication_unsafe_writer.pml`

The meaning has a positive edge, but Event is published before the relation row.

Expected result:

```text
assertion violation exists
```

The counterexample is a reader observing Event authority plus old relation absence and therefore manufacturing known-none.

### Unsafe reader order

`177_movement_relation_publication_unsafe_reader.pml`

The writer uses relation-first / Event-last, but the reader acquires relation before Event.

Expected result:

```text
assertion violation exists
```

The reader can retain an old empty relation snapshot, then see the newly authoritative Event after the writer finishes.

## Candidate consequence if qualified

If the expected matrix holds, fresh Movement can earn a very small first physical persistence step:

```text
one independently typed positive RelationUnit stream
```

with:

```text
writer:
  relation qualification
  -> required positive relation append when any
  -> Event last

reader for this publication shape:
  Event
  -> relation
```

and **no routine negative relation row**.

The Event commit acts as the activation/completion edge only because Observation 170's writer-closure rule remains a prerequisite for any concrete completeness cutover. The Event does not intrinsically encode relation meaning.

A pre-Event relation row may survive a crash as orphan raw evidence. That is acceptable: PR #361's source-reference admission keeps it unresolved/inert until the source Event exists. This is preferable to inventing an atomic multi-file bundle merely to erase harmless orphan provenance.

## What this would earn

Only for fresh practical Movement, pressure would exist for:

- an independently persisted positive `RelationUnit` stream;
- operation-specific relation meaning collection/qualification before Event commit;
- aborting Event authority publication when required positive relation persistence fails;
- Event-first / relation-second acquisition for a relation-aware read of this bounded publication shape;
- retaining relation-first crash residue rather than requiring rollback;
- no routine persisted `NoRelation` receipt.

## What this does not earn

This observation does **not** yet earn:

- one global Relation transaction framework;
- a manifest/generation bundle across Event, validity, description, and relation streams;
- a physical `RelationRevision` stream;
- source-level `ExplicitNoneEvidence` persistence;
- a concrete relation completeness cutover date;
- qualification changes for Scheduled completion, correction replacement, date correction, or historical publication;
- automatic relation inheritance across EventCorrection;
- multi-writer concurrency;
- fsync/power-loss durability claims;
- compaction or rollback;
- a universal reader protocol across all canonical stream families;
- CLI/TUI wording or endpoint display-name registry.

If Movement later becomes the first practical writer, its implementation should earn only the persistence pieces it actually needs. Relation revision persistence should wait until an actual correction/retraction operation requires it.

## Stack

This observation is stacked on PR #361 `application/open-relation-frontier` at exact head:

`5f965ad9a3d5656b62147568ed7d35445c81068d`

PR #360 and PR #361 remain open and unmerged by this observation.

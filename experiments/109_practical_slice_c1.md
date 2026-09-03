# Practical Slice C1: Attention / Issue Core

Observation 109 already established the semantic boundary for household matters that need attention even when no financial occurrence exists yet. Slice C1 turns that qualified boundary into the first practical Lean ownership without copying the HRA Issue record.

## Implemented boundary

The user-facing capability may be called **Issue**. The neutral Practical Core family is `Attention`.

```text
Attention
  stable AttentionId
  opaque human context
  explicit due meaning
    DueOn Time
    NoDueDate
    DueUndetermined

AttentionClosure
  AttentionId
  knownOn Time
  kind
    Resolved
    Dropped

AttentionRelation
  source AttentionId
  target
    EventId
    AttentionId
  knownOn Time
```

Current lifecycle is projected from explicit closure evidence:

```text
no closure   -> Open
Resolved     -> Resolved knownOn
Dropped      -> Dropped knownOn
```

Relation provenance is not an input to that projection. A relation to an Actual Event or a later Attention identity therefore cannot silently close the source item.

## Deliberate compression

HRA's current Issue record carries fields such as category, title, optional amount, details, recorded date, mutable status, due state, and closure state. LOAM does not copy that structure merely because it exists.

Slice C1 retains only one opaque human `context` value. It does not claim that category, title, amount, or details are impossible future distinctions. It says only that the first admitted current open-Issue question does not yet require separate canonical fields.

Likewise, the Core stores no mutable `Open | Resolved | Dropped` status. Closure meaning remains evidence, and current lifecycle remains a projection.

## Fail-closed behavior

`AttentionMemory` rejects repeated Attention identity.

`AttentionClosureMemory` rejects two closure dispositions for one Attention identity. Mistaken-closure correction semantics are intentionally not invented here.

Application inspection also refuses a current view when retained closure evidence references an unknown Attention identity. A malformed relation graph therefore cannot be hidden by simply ignoring the dangling closure.

## Not implemented yet

Slice C1 deliberately does not add:

- persistence or CLI;
- a TUI Issue workspace;
- creation / recorded-on time;
- due edits or Attention correction identity;
- historical `knownThrough` queries;
- ordering by due date;
- category, amount, title/details split;
- relation persistence or relation correction;
- Plan/Scheduled/funding relation targets;
- recurrence or notification behavior.

Those are future pressure points, not fields to pre-install.

## Why this is enough to fix the architecture

The implementation boundary is now:

```text
Issue UI vocabulary
      ↓
Attention Core evidence
      ↓
current lifecycle projection
```

and not:

```text
mutable Issue object
  with embedded status + relation + accounting + notification state
```

This keeps the important Observation 109 distinctions while leaving later household evidence free to earn additional structure independently.

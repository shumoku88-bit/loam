# Observation 122 — Does a completed Scheduled occurrence need distinct continuation provenance?

## Household question

LOAM can already retain one Scheduled occurrence, later retain an Actual Event that realizes it, and keep those two facts connected by explicit completion evidence.

Daily use adds a different pressure:

```text
September Scheduled
    -> September Actual
    -> October Scheduled?
```

Sometimes the next occurrence should be added only after the current one is paid. Sometimes several future occurrences are already present. Sometimes there is no next occurrence at all. The question is therefore not whether LOAM should automatically generate recurrence.

The narrower question is:

> If a later Scheduled occurrence already exists, can LOAM know that it is the next occurrence of the completed one from date and movement similarity alone, or is distinct continuation provenance observable?

This observation also compares that relation with Observation 105's existing Scheduled -> Scheduled successor/replacement meaning.

## Competing meanings

Observation 105 earned a terminal successor/replacement relation:

```text
old Scheduled
    -> replacement Scheduled
```

The old occurrence is superseded rather than realized.

The new household pressure has a different shape:

```text
old Scheduled
    -> Actual

old Scheduled
    -> next Scheduled
```

Completion and next-occurrence provenance may therefore coexist for the same source.

The model calls the second relation `continuation` only as observation vocabulary. It is not a proposed Practical Core type or persistence record.

## Bounded questions

The Alloy model asks whether:

1. one Scheduled occurrence can be completed and still retain a linked next occurrence;
2. a chain of future occurrences can be linked before the current occurrence is completed;
3. that pre-created chain can remain after completion without generating another occurrence;
4. Observation 105's terminal replacement edge can be reused unchanged as next-occurrence provenance;
5. exactly one later Scheduled fact with the same movement shape is enough to reconstruct "this is the next one";
6. two worlds can have the same completion/replacement lifecycle and the same Scheduled facts while differing only in continuation provenance;
7. continuation alone leaves the source Scheduled live until independent terminal evidence exists.

## Expected interpretation

If the model behaves as expected, the useful boundary is:

```text
future Scheduled similarity
    !=
next-occurrence provenance

Observation-105 replacement
    !=
post-completion continuation
```

A future practical UI could then safely distinguish:

```text
linked next occurrence already exists
    -> show it after completion

no linked next occurrence
    -> optionally offer "Add next scheduled movement"
```

But absence of a linked next occurrence would not mean:

```text
recurrence ended
```

and would not require automatic generation.

## Deliberate boundary

This observation does **not** introduce:

- Recurrence;
- Series;
- frequency or monthly rules;
- automatic future generation;
- a retained "recurrence ended" state;
- copy-forward amount/date policy;
- UI layout or final user-facing wording;
- a Practical Core `ScheduledContinuation` type;
- persistence or CLI changes.

A relation type should be added only if the solver shows that the provenance distinction is independently observable and later dogfood actually needs to retain it.

## Tool choice

Alloy is sufficient because the immediate question is static distinguishability and information sufficiency: can the same retained Scheduled/Actual shapes support different answers about which future occurrence is "next"?

TLA+ or SPIN would become useful later if the pressure becomes operational, for example completion racing with another writer that adds or links a future occurrence. J is unnecessary until the question becomes about coverage shape across a larger calendar horizon.

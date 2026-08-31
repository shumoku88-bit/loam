# Observation 061: whole-frontier Resolution split publication

## Question

Observation 059 found a bounded single-Correction protocol for separately persisted Event and relation streams:

```text
writer: relation -> Event
reader: Event -> relation
```

Observation 060 then showed that the resulting torn intermediate state can be recovered across crash/restart by retrying publication.

LOAM also has `EventResolutionMemory`. A Resolution is stronger than one Correction: it names several parent candidate Events and offers one replacement Event, and semantic admission requires the relation to cover the whole current unresolved frontier.

The next question is therefore:

> If the unresolved frontier is already visible and stable, does a multi-parent Resolution require a stronger split-publication protocol than Correction, or is the Observation 059 order still sufficient?

This observation deliberately freezes the frontier. It does **not** model new Corrections arriving while the Resolution is being published.

## Why SPIN

The pressure is again an interleaving question between a writer and a reader sampling two separately published streams. The shape differs from Observation 059 because semantic admission now has several pre-existing parents, but the operational question is still concrete publication/acquisition order.

SPIN is therefore the smallest tool that adds a distinct answer.

## Bounded Resolution shape

The model fixes one existing unresolved frontier:

```text
parent A Event: already visible
parent B Event: already visible
```

One new Resolution names both parents and one new replacement Event.

The final semantic state requires all of:

```text
parent A visible
parent B visible
Resolution visible
replacement Event visible
```

The parent Events are not publication variables in this observation. They are prior facts. This isolates whether **multiple parent references by themselves** create another publication edge.

Fail-closed Resolution admission means:

- Resolution visible, replacement absent -> Resolution remains inert;
- replacement visible, Resolution absent -> replacement can be observed without the whole-frontier relation that gives it effective meaning.

The second mixed state is rejected by the model.

## Protocols compared

### Candidate protocol

Writer:

```text
Resolution -> Event
```

Reader:

```text
Event -> Resolution
```

The Resolution may appear physically before the replacement Event because its parent frontier already exists. Until the replacement appears, semantic admission fails closed.

If a reader sees the replacement Event under one monotone writer, the writer must already have published the Resolution. Reading the Resolution stream second can therefore recover the matching relation version.

### Boundary A: Event-first writer

Writer:

```text
Event -> Resolution
```

Reader:

```text
Event -> Resolution
```

SPIN should find an interleaving where the replacement is seen after the first writer step while the Resolution stream is still old.

### Boundary B: Resolution-first reader

Writer:

```text
Resolution -> Event
```

Reader:

```text
Resolution -> Event
```

SPIN should find an interleaving where the reader first sees the old Resolution stream, the writer completes both publications, and the reader then sees the new Event stream.

## Expected SPIN results

- `061_resolution_split_publication_safe.pml`: **0 errors**
- `061_resolution_split_publication_unsafe_writer.pml`: **assertion violation exists**
- `061_resolution_split_publication_unsafe_reader.pml`: **assertion violation exists**

The assertion rejects a completed reader snapshot in which the replacement Event is visible without an admitted Resolution.

## Finding if the expected results hold

For this bounded stable-frontier case, multi-parent Resolution does **not** require a stronger publication order than single-Correction publication.

The useful generalization would be narrower than “all relations use the same protocol”:

> When every non-replacement endpoint of a newly published relation is already visible and stable, relation-first publication can leave the relation inert until the one new replacement Event appears; opposite-order acquisition can then avoid exposing that replacement without its relation.

The extra parent identities affect semantic admission, but they do not add new publication edges when they are already present.

## Important boundary

This result would say nothing about a moving frontier.

If Corrections that define the unresolved frontier are themselves published concurrently with the Resolution, the reader may need to coordinate three semantic inputs:

```text
EventMemory
CorrectionMemory
ResolutionMemory
```

At that point the question is no longer merely “does Resolution reuse the Correction protocol?”. It becomes a multi-stream snapshot problem in which frontier identity can change while a Resolution is acquired.

That should be a separate observation rather than being smuggled into this one.

## Practical consequence

Do not add Resolution persistence merely by analogy yet. If the expected SPIN results hold, they justify reusing the **ordering shape** from Observation 059 only for publication over an already-existing stable conflict frontier.

A later practical step can then decide whether Resolution persistence is worth implementing, while a separate observation can pressure concurrent frontier change if such a workflow becomes concrete.

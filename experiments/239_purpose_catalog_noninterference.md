# Observation 239 — Purpose catalog noninterference

Status: **qualified candidate boundary**

## Question

Can LOAM separate a stable `PurposeId` from its human-facing label without creating
a second Purpose authority or changing Capacity semantics?

The practical pressure is small but real: a household may want to rename a display
label such as `一般生活` while preserving the identity referenced by retained
Capacity and routing evidence.

## Candidate

Keep the existing semantic coordinate unchanged:

```text
PurposeId(token)
```

Add replaceable presentation metadata only:

```text
PurposeId -> label / help
```

The catalog does not enumerate admitted Purpose identities. It only decorates
identities supplied by an existing semantic source. Missing metadata falls back to
the stable token.

## Lean result

`Loam.Observations.Observation239` checks the production-shaped Capacity boundary:

1. changing catalog metadata leaves the complete semantic Capacity row unchanged;
2. decorating a list of Capacity rows preserves exactly the same semantic rows in
   the same order;
3. catalog decoration cannot increase or decrease the number of semantic rows;
4. missing metadata preserves the stable Purpose token as recognition text.

The production candidate also carries direct laws in `Loam.PurposeCatalog` that
`entryFor` preserves `PurposeId` and `forPurposes` preserves the exact identity
list.

## Trust / scope boundary

This result deliberately does **not** establish a general Purpose registry,
retirement, merge, alias, or migration model. Those operations are not earned by a
display rename requirement.

It also does not claim that a label has household semantic meaning. Labels and help
remain replaceable presentation configuration.

## Decision

A display-only Purpose catalog is qualified as a small candidate boundary.

Next practical step, only after the proof/build is green:

```text
config/purpose-catalog.tsv
        -> load presentation metadata
        -> Capacity / Budget render labels
        -> PurposeId remains unchanged in publication and routing
```

Do not add a Purpose registry or canonical rename event for this requirement.

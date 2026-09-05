# Observation 188 — Description is not permission

## Pressure

A household budget can accidentally turn a descriptive label into a spending justification.

For example, `learning` or `books` may be useful descriptions of what money was spent on, while the same words can also sound like reasons that money ought to be allocated there. That mixes two different questions:

1. **What is this spending about?**
2. **What kind of decision is this use of finite capacity?**

The second question is where a small human-facing vocabulary such as the following may help:

- 必要 (`need`)
- 欲しい (`want`)
- 備える (`prepare`)
- 決まっている (`committed`)

These are candidate decision words, not moral ranks.

## Lean observation

The model keeps `DescriptionClass` and `DecisionRole` as separate finite types and records only a pair of them in `ConsideredUse`.

The checks establish three small facts:

- the same spending description can carry different decision roles;
- the same decision role can contain different spending descriptions;
- changing the decision role need not rewrite the spending description.

A concrete witness also records that `learning` can be framed as `want`; the descriptive label therefore does not imply `need` or create spending authority by itself.

## Finding

The observed shape is:

```text
spending description × decision role
```

not:

```text
spending description -> permission
```

and not:

```text
decision role -> spending category
```

This makes it possible to retain useful descriptive questions such as “how much went to books?” without silently creating a dedicated books budget or declaring book spending specially justified.

## Boundary

Observation 188 does **not** add these four decision words to LOAM Core, does not rename any current Capacity Purpose, and does not migrate household data.

It also does not claim:

- that every outlay must have exactly one decision role;
- that `need` is better than `want`;
- that the four Japanese labels are universal;
- that classification determines allocation;
- that a role is itself spending permission;
- that historical spending should be rewritten when the current decision framing changes.

A practical household migration, if desired, needs an explicit mapping and effective boundary rather than silently reinterpreting existing Capacity history.

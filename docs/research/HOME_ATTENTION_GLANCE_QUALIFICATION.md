# Home Attention glance qualification

Status: **PRESENTATION SLICE UNDER QUALIFICATION**

## Pressure

Issue #1053 requires a deliberately deferred Scheduled continuation to be
rediscoverable later.

PR #1224 makes that intent durable by publishing one ordinary Attention item.
The remaining presentation question is narrower:

> Can Home make current-open Attention visible without becoming a second
> Attention engine?

## Current boundary

```text
attention.loam
    |
    v
AttentionReview
    |
    +--> Attention / Manage
    |
    +--> Home glance
```

Home does not inspect Attention persistence, closure evidence, due semantics, or
Scheduled continuation context directly. It consumes only
`AttentionReview.Availability`.

## Home projection

The glance preserves four states:

```text
read refusal        -> Attention: unavailable
missing authority   -> Attention: not configured
configured empty    -> Attention: 0 open
one current-open    -> 1 open + qualified summary
multiple open       -> N open + [i] manage
```

For a single deferred Scheduled continuation, the qualified summary retains the
existing `due unknown` label and opaque human context.

When multiple Attention items are open, Home deliberately shows only the count
and the `[i] manage` affordance. `openItems` retains representation order only,
not priority, so Home must not single out the first retained item as though it
were more important.

Full navigation, resolve/drop, and new item creation remain in
`Attention / Manage`.

## Freshness

Before this slice, returning from Attention administration reused the pre-session
Home snapshot. That was harmless while Home did not display Attention.

Once Home projects Attention, the administration return path reloads the ordinary
root Snapshot before redrawing Home.

This is read freshness only. It creates no new Attention state and no
presentation-owned cache.

## Root Snapshot

The root TUI Snapshot gains an optional Attention read answer with a default
unavailable/error value, matching the existing optional Daily Pace pattern.

`loadSnapshot` records the result of `AttentionReview.loadEvidence` without
turning Attention refusal into failure of ordinary Home/Actual/Scheduled use.

## Non-goals

This slice adds no:

- Attention sorting or priority;
- selected-day Attention membership;
- parsing of Attention context;
- continuation relation;
- duplicate Attention suppression;
- Home mutation verbs;
- new canonical state.

## Qualification

The deferred-continuation regression now proves the practical chain:

```text
Defer
 -> AttentionPublisher
 -> AttentionReview reload
 -> root Snapshot
 -> Home glance
```

It also checks that Home keeps missing configuration distinct from configured
empty Attention.

## Stack relationship

This slice is intentionally stacked on PR #1224.

- #1224 owns explicit Defer and durable Attention publication.
- this slice owns only Home rediscovery and post-administration freshness.

If #1224 does not graduate, this Home slice has no independent reason to merge.

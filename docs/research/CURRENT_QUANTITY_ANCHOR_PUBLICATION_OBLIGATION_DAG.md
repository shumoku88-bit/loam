# G2-017 — CurrentQuantityAnchor publication obligation DAG

Status: **Generation-2 audit evidence — KEEP CURRENT BOUNDARY**

Primary instruments: **DRAKONview + obligation DAG + production-writer reachability + existing executable evidence**.

## Question

`CurrentQuantityAnchorPublisher.publish` builds one complete observed-present image from:

- current normalized Actual evidence;
- ZeroOriginCoverage;
- OpeningSupport;
- a fresh set of observed coordinate quantities.

Generation 2 asks whether the writer should widen its ownership interval to every input authority, or retain the smaller current boundary:

```text
Actual -> CurrentQuantityAnchor
```

It also asks whether replacing the current anchor should acquire a retained revision graph.

## Current production shape

The writer currently does this:

```text
acquire Actual ownership
        |
        v
acquire CurrentQuantityAnchor ownership
        |
        v
load current Actual
        |
        +------ load ZeroOriginCoverage snapshot
        |
        +------ load OpeningSupport snapshot
        |
        v
reject support-family overlap
        |
        v
derive all stable correction roots from locked Actual
        |
        v
construct one complete anchor image
        |
        v
atomically replace current-quantity-anchor.loam
```

The caller does not supply the reflected-root cut. It is derived from the locked Actual generation.

## O1 — Actual and anchor replacement require one coherent interval

The anchor meaning depends on the exact stable correction roots already reflected by the observation.

If Actual changed between root discovery and anchor publication, the retained cut could describe a different history generation than the asserted present. Therefore Actual ownership is semantic, not merely mechanical.

The anchor file itself is replaceable current evidence. Concurrent replacement must also be excluded.

Therefore:

```text
Actual ownership                         KEEP
CurrentQuantityAnchor ownership          KEEP
relative order Actual -> Anchor          KEEP
```

## O2 — ZeroOriginCoverage / OpeningSupport are overlap guards, but not current runtime writers

`propose?` refuses an assertion when its coordinate already has support in either:

```text
ZeroOriginCoverage
OpeningSupport
```

This is a real semantic guard: LOAM has not qualified precedence between independent support families.

But writer reachability matters before converting every read into a lock dependency.

Repository-wide search at the G2-017 checkpoint finds:

- `saveOpeningSupportMap?` has no LOAM production caller;
- `saveZeroOriginCoverage?` is used only by test fixtures inside LOAM;
- neither save API is called from `loam-data`;
- canonical household copies are explicit Git-managed evidence/policy files.

Therefore no current LOAM production writer can race a support-family mutation against anchor publication.

Adding locks now would preserve no reachable production interleaving. It would only enlarge ownership topology in anticipation of a future writer.

Verdict:

```text
load support snapshots                    KEEP
support overlap refusal                    KEEP
OpeningSupport writer lock                 DO NOT ADD YET
ZeroOriginCoverage writer lock              DO NOT ADD YET
new shared support ownership coordinator    DO NOT ADD
```

If a production writer is later added for either support family, this verdict must be reopened because the current reachability premise will no longer hold.

## O3 — Missing or malformed support evidence remains fail-closed

Publication requires both support files to exist and decode successfully.

This is intentionally stricter than treating missing evidence as empty support. Absence of an authority file is not proof that no support exists.

Therefore current load behavior remains:

```text
missing support authority   -> refuse
malformed support authority -> refuse
valid empty image            -> explicit absence of support
```

No optional fallback is earned by this audit.

## O4 — Fresh observation replaces the current image; it is not a retained anchor revision

The anchor writer atomically replaces one complete current reconciliation image.

This does not silently discard a qualified history model. Existing Four-Voice V4 evidence already establishes:

```text
fresh observation
    -> new complete reflected-root cut
    -> new complete asserted-current image
```

The old anchor is not mutated into a historical revision.

A retained revision graph would introduce new identity, chronology, correction, and selection semantics without a current product question requiring them.

Therefore:

```text
complete-image replacement                 KEEP
anchor identity family                     DO NOT ADD
anchor revision graph                      DO NOT ADD
implicit old/new reconciliation policy     DO NOT ADD
```

A caller may derive a residual between an earlier image and a fresh observation when both are available in an explicit comparison context. That does not make the residual or old image canonical history.

## O5 — Why this differs from G2-015

G2-015 added CurrentQuantityAnchor to AccountingRole virginity because a live production writer could otherwise publish a role after retained anchor quantity already existed. Both mutable authorities participated in one race-sensitive admission rule, so ownership was widened.

G2-017 finds a different topology:

```text
Actual                    mutable production authority
CurrentQuantityAnchor     mutable production authority
ZeroOriginCoverage        configured evidence; no production writer
OpeningSupport            configured evidence; no production writer
```

Similar semantic importance does not imply identical ownership obligations.

## Obligation DAG

```text
                    publish current observation
                              |
          +-------------------+-------------------+
          |                   |                   |
          v                   v                   v
     root-cut truth      support separation    image replacement
          |                   |                   |
          v                   v                   v
   locked Actual       Coverage snapshot      lock anchor image
          |            Opening snapshot             |
          |                   |                     |
          |          reject overlap                 |
          |                   |                     |
          +-------------------+---------------------+
                              |
                              v
                    one complete anchor image
                              |
                              v
                       atomic replacement
```

Ownership is earned only where a current production writer can invalidate the admission interval.

## Stop point

G2-017 does not earn:

- a generic `SupportAuthority`;
- a four-file ownership coordinator;
- ZeroOriginCoverage or OpeningSupport runtime publishers;
- anchor revision history;
- support-family precedence;
- optional missing-support semantics.

The smallest justified boundary remains the current one.

## Verdict

**G2-017: KEEP QUALIFIED — retain `Actual -> CurrentQuantityAnchor` ownership, read configured support families as fail-closed snapshots, and do not add speculative support locks or anchor revision history.**

Reopen this result only if a production writer is introduced for ZeroOriginCoverage or OpeningSupport, or if a product question independently requires historical anchor identity/revisions.

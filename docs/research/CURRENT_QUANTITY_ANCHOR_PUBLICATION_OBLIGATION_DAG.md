# G2-017 — CurrentQuantityAnchor publication obligation DAG

Status: **Generation-2 audit evidence — KEEP CURRENT BOUNDARY**

Primary instruments: **DRAKONview + obligation DAG + production-writer reachability + existing executable evidence**.

## Question

`CurrentQuantityAnchorPublisher.publish` updates one replaceable observed-present support image from:

- current normalized Actual evidence;
- ZeroOriginCoverage;
- OpeningSupport;
- the retained CurrentQuantityAnchor image, when present;
- one fresh set of coordinate quantities observed together now.

Generation 2 asks whether the writer should widen its ownership interval to every input authority, or retain the smaller current boundary:

```text
Actual -> CurrentQuantityAnchor
```

Observation 246's 2026-09-27 follow-up and PR #1386 later qualified several anonymous reconciliation groups inside that replaceable image. The writer therefore also asks how a fresh group composes with retained groups without inventing anchor identity or history.

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
        +------ load retained anchor image under anchor ownership
        |
        v
reject support-family overlap
        |
        v
derive all stable correction roots from locked Actual
        |
        v
construct one fresh anonymous reconciliation group
        |
        v
preserve unmentioned prior coordinates
move re-observed coordinates to the fresh group
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

## O4 — Fresh observation updates the replaceable current image; groups are not retained revisions

PR #1386 qualified the production pressure that the original one-cut image could not satisfy: a household may observe another coordinate later without re-observing every prior coordinate.

The smallest surviving current-support shape is:

```text
replaceable current-support image
  reconciliation group A
    reflected-root cut A
    assertions observed together at A

  reconciliation group B
    reflected-root cut B
    assertions observed together at B
```

A fresh publication therefore:

1. derives one new cut from the locked current Actual world;
2. preserves prior groups for coordinates not observed now;
3. removes any re-observed coordinate from its prior group;
4. appends the fresh coordinate assertions under the new cut;
5. drops a prior group if no assertions remain in it;
6. atomically replaces the complete current-support file.

The group is anonymous representation factoring. It is not a stable AnchorId, timestamp, historical observation record, or revision node.

Therefore:

```text
replaceable grouped current-support image          KEEP
unmentioned prior coordinate support               KEEP
re-observed coordinate moves to fresh group        KEEP
global one-coordinate/one-live-group uniqueness    KEEP
anchor/group identity family                       DO NOT ADD
anchor revision graph                              DO NOT ADD
historical observation provenance                  DO NOT INFER
```

The old file image is still not canonical history. Current support retains only the minimum coordinate-local quantity and reflected-root cut needed for today's answer.

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
     root-cut truth      support separation    grouped replacement
          |                   |                   |
          v                   v                   v
   locked Actual       Coverage snapshot      lock anchor image
          |            Opening snapshot             |
          |                   |              load retained groups
          |          reject overlap                 |
          |                   |                     |
          +-------------------+---------------------+
                              |
                              v
                    fresh anonymous group
                              |
                              v
               preserve unmentioned coordinates
                 move re-observed coordinates
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

**G2-017: KEEP QUALIFIED, UPDATED BY #1386/#1389 — retain `Actual -> CurrentQuantityAnchor` ownership, preserve a replaceable image of anonymous reconciliation groups, read configured support families as fail-closed snapshots, and do not add speculative support locks or anchor/group revision history.**

Reopen this result only if a production writer is introduced for ZeroOriginCoverage or OpeningSupport, or if a product question independently requires historical anchor identity/revisions.

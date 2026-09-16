# G2-016 — OpeningSupport / Actual correction obligation DAG

Status: **Generation-2 audit evidence — KEEP / DO NOT COUPLE**

Primary instruments: **DRAKONview + production-bound obligation DAG + existing executable compatibility witnesses**.

## Question

`OpeningSupport` is a narrow current-balance claim:

```text
EffectCoordinate -> opening EventId
```

The named Event must survive on the ordinary current correction frontier and must actually contain the supported coordinate.

That creates an apparent pressure on `CorrectionPublisher`:

> If an Event is named by OpeningSupport, should correction of that Event be refused, or should OpeningSupport be automatically retargeted to the replacement?

Generation 2 asks whether either coupling is justified by current production semantics.

## Existing independent boundaries

### Actual correction

`CorrectionPublisher` owns replacement of one current practical Actual Event. Its admission obligations are local to Actual and already-retained relations that explicitly constrain the target:

```text
current Event
  + practical balanced-JPY target
  + relation/discharge independence
  + reversal independence
  + current occurrence date
  + admitted replacement Loci
  -> append replacement Event + EventCorrection
```

It does not read `OpeningSupport`.

### OpeningSupport consumption

`RoleBalanceReview` treats OpeningSupport as usable only when:

```text
one admitted correction frontier
        |
        v
openingEvent survives on that frontier
        |
        v
openingEvent contains the supported coordinate
        |
        v
opening-supported current quantity may be projected
```

If correction supersedes the named opening Event, the old support claim becomes stale and the read fails closed.

This behavior is already executable in:

- Observation 245 (`experiments/245_opening_support_reuse_seam.*`);
- `Loam/Tests/FourVoiceCompatibilityV6.lean`;
- `Loam/Tests/CounterpointFiveWorlds.lean`.

## Why stale support is not a failed correction

OpeningSupport adds independent meaning:

> this specific retained Event is admitted as the opening witness for this coordinate.

An `EventCorrection` says something different:

> this Event has been superseded by this replacement for the current Actual frontier.

The correction relation does **not** state that every independent interpretation attached to the old Event transfers to the replacement.

Therefore:

```text
old Event corrected
```

is insufficient to derive:

```text
replacement Event inherits opening-witness meaning
```

Automatically chasing the correction would invent a semantic migration rule not retained by either relation.

## Why CorrectionPublisher must not refuse the correction

Adding a guard such as:

```text
if OpeningSupport names target then reject correction
```

would reverse the ownership relation.

A read-support claim would become authority over whether an otherwise valid Actual fact may be corrected. That would make a stale interpretation freeze the fact it interprets.

Current evidence supports the opposite direction:

```text
Actual changes independently
        |
        v
old OpeningSupport may become stale
        |
        v
RoleBalance retracts the answer
        |
        v
new explicit support may later restore it
```

The refusal is therefore informative: the retained facts remain available, but the prior current-balance claim is no longer justified.

## Explicit re-support is the earned repair

The existing executable witness shows:

```text
OpeningSupport(c -> old)
EventCorrection(old -> replacement)
```

makes the old opening-supported answer unavailable.

If a new support claim is explicitly published as:

```text
OpeningSupport(c -> replacement)
```

then the ordinary correction frontier admits the replacement and the answer is restored.

No OpeningSupport-specific correction history or migration engine is required.

## Contrast with CurrentQuantityAnchor

`CurrentQuantityAnchor` behaves differently under correction, and that difference is earned rather than inconsistent.

An anchor retains:

```text
reflectedRoots
+ exact current assertions observed at one reconciliation cut
```

Its projection explicitly interprets corrections *inside an already reflected root* as historical detail already absorbed by the observed present. The reflected-root cut is the semantic reason a correction can change ordinary frontier history while leaving the anchored present unchanged.

OpeningSupport has no such cut. It names one Event directly.

Therefore Generation 2 must not generalize:

```text
CurrentQuantityAnchor is correction-stable
```

into:

```text
all support evidence should follow corrections
```

The two evidence families answer different questions.

## Obligation DAG

```text
                          Actual correction
                                |
                                v
                    target is current / admissible
                                |
                                v
                   append replacement + correction
                                |
               +----------------+----------------+
               |                                 |
               v                                 v
      ordinary Actual frontier            independent support claims
               |                                 |
               |                        OpeningSupport(c -> old)
               |                                 |
               |                                 v
               |                     does old survive current frontier?
               |                         /                 \
               |                       yes                 no
               |                        |                   |
               |                        v                   v
               |                 support usable      support stale
               |                                            |
               |                                            v
               |                                    retract balance answer
               |                                            |
               |                                            v
               |                              explicit re-support may restore
               |
               v
      correction remains authoritative
```

No edge runs from `OpeningSupport` back into correction admission.

## Rejected alternatives

### Reject correction when support names the target

**REJECT.** This turns a read-support interpretation into mutation authority over Actual.

### Automatically retarget support to the replacement

**REJECT.** EventCorrection does not prove inheritance of opening-witness meaning.

### Add OpeningSupport correction history

**REJECT.** Existing explicit re-support plus ordinary correction-frontier validation already represents the required distinction.

### Generalize support migration from CurrentQuantityAnchor behavior

**REJECT.** Anchor stability is justified by its reflected-root cut, which OpeningSupport deliberately lacks.

## Stop point

Keep the current separation:

```text
CorrectionPublisher
    -> correct Actual independently

OpeningSupport
    -> remain one explicit Event witness

RoleBalanceReview
    -> validate witness against the current correction frontier
    -> fail closed when stale

explicit replacement support
    -> restore answer when independently asserted
```

No production code change is earned by G2-016.

## Verdict

```text
CorrectionPublisher reads OpeningSupport                 NO / KEEP
OpeningSupport blocks otherwise-valid correction        NO
correction auto-retargets OpeningSupport                 NO
OpeningSupport-specific correction history              NO
stale witness fails closed                              KEEP
explicit re-support restores answer                     KEEP
CurrentQuantityAnchor correction stability generalized  NO
```

**G2-016: KEEP QUALIFIED — Actual correction remains independent; stale OpeningSupport retracts the derived balance claim rather than constraining or silently following the correction.**

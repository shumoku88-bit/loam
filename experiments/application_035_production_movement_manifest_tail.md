# Application 035: Production Movement Manifest Tail

## Question

Can the practical production `loamMovement` entrance reuse the one production
`MovementAdmission` result and publish its five canonical fact families through
generation-manifest authority, with no sidecar mutation in that path and with
one `CURRENT` authority switch, before changing the default production
persistence mode?

This application is deliberately narrower than a default cutover. It asks
whether the replacement tail is production-capable and semantically equivalent,
not whether the legacy sidecar authority may already be removed.

## Starting boundary

Application 034 extracted the Movement-specific semantic boundary:

```text
MovementAdmission.Draft
MovementAdmission.World
MovementAdmission.Admitted
admit? : World -> Draft -> Except String Admitted
```

Both the existing sidecar publisher and the direct manifest probe could therefore
share one admission implementation. The remaining production Movement tail was
still the qualified sidecar protocol:

```text
ActualValidity
-> optional EventDescription
-> optional RelationUnit
-> optional RelationDischarge
-> Event last
```

That is at most five cross-family save calls and four partial-authority prefixes.

## Production-capable manifest authority

Application 035 adds `Loam.MovementManifestAuthority` as a Movement-specific
physical authority boundary for exactly these five existing typed families:

- `Event`
- `ActualValidity`
- `EventDescription`
- `RelationUnit`
- `RelationDischarge`

The families remain separately encoded and separately typed. The manifest is an
authority selector over five family images, not a new merged semantic fact.

The physical protocol is:

```text
selected CURRENT
-> verify five referenced content-addressed objects
-> production typed decode
-> MovementAdmission.admit?
-> production typed encode
-> prepare immutable content-addressed objects off authority
-> verify staged CURRENT
-> one CURRENT replacement
```

`prepareWorld?` and `commitPrepared?` are separate. Merely preparing an object
never gives it authority.

The module does not introduce a generic repository, CRUD layer, transaction
framework, or admission framework.

## Explicit experimental production mode

The real production `loamMovement` binary now has an explicit non-default gate:

```text
LOAM_EXPERIMENTAL_MOVEMENT_MANIFEST_ROOT=DIR
```

When the variable is absent, the existing sidecar publisher remains the default.

When it is present, `loamMovement` still performs the ordinary human-input
collection, but after writer ownership is acquired it re-reads only the selected
manifest world for canonical admission. The positional `MEMORY_FILE` is then
pre-input preflight/completion-hint material only; it is not mutation authority.

There is no selected-manifest -> legacy-sidecar fallback. Missing, malformed,
unsupported, missing-object, or digest-invalid selected authority fails closed.

## Real production entrance qualification

The dedicated Application 035 workflow built and ran the real production
`loamMovement` binary for two Movements through the experimental manifest mode:

1. `2026-09-05`, `paypay -100`, `travel +100`, one explicit `E2H friend 100`
   relation and description `manifest source movement`.
2. `2026-09-06`, `friend-in -40`, `paypay +40`, one explicit discharge of
   `relation-1` by `40` and description `manifest discharge movement`.

The manifest-mode mutation created none of the five legacy sidecar files. The
selected typed projection after the two real production entrance calls was:

```text
event_count=2
effect_count=4
recorded_paypay=-60
recorded_travel=100
recorded_friend_in=-40
relation_count=1
discharge_count=1
relation_outstanding=60
```

Observed production-tail surface:

```text
retained_sidecar_save_calls=5
manifest_tail_sidecar_save_calls=0
manifest_tail_selected_world_reads=1
manifest_tail_shared_admission_calls=1
manifest_tail_authority_publish_calls=1
manifest_authority_switches_per_mutation=1
manifest_partial_authority_prefixes=0
production_manifest_mode_default_off=1
semantic_family_count=5
```

## Exact canonical byte preservation

The selected manifest world was re-encoded with the same production family
encoders and compared with the pre-refactor Application 034 production baseline.
All five hashes and byte sizes matched exactly:

```text
Event
f1db19930ebce381589d55dcb6279031263465f088deaba3e7e68d5b83090992
177 bytes

ActualValidity
7a4d44b8a877386c70b91131f644e6e97e2a6ff8658989013e9958e1ef727f5f
81 bytes

EventDescription
77a98cf7921d12ee5da6757539d5e195410c8c3c0de971bc450689e0daedaa6a
113 bytes

RelationUnit
cd73e5303796be1e23711c7b9849190de4e61e4bd0672a5f2d6905552ff50f73
82 bytes

RelationDischarge
8e8626073f6e205950ab5287bee14372f0dd0e30a0b7d91076dc5faccba718ea
66 bytes
```

Thus the physical authority topology changed without changing the canonical
family bytes produced by the qualified two-Movement case.

## Interrupted preparation and retry

The workflow also stopped after production `prepareWorld?`, before any `CURRENT`
commit, and then retried from the still-selected old generation.

Observed:

```text
retry_reused_prepared_objects=5
interrupted_candidate_authority_changes=0
orphan_event_id_reservations=0
manifest_partial_authority_prefixes=0
```

The retry received the same fresh Event identity (`record-1`) because an
unselected prepared generation does not reserve semantic identity. All five
already-prepared byte-identical objects were reused.

This is the important topology change relative to the sidecar Event-last
protocol: interruption may leave inert immutable objects, but it does not leave a
prefix of canonical fact families authoritative.

## Fail-closed selected authority

A separate negative case retained a valid legacy sidecar world, selected a
manifest world, then corrupted the selected Event object. The next manifest-mode
Movement exited with status `2` on digest verification.

Observed:

```text
broken_selected_manifest_failed_closed=1
legacy_sidecar_fallbacks=0
frozen_sidecar_mutations_after_manifest_failure=0
```

The writer did not silently recover by treating the legacy sidecars as current
truth and did not mutate those frozen sidecars.

## Interpretation

Application 035 establishes a stronger result than the earlier scratch manifest
probes:

> The real practical production Movement entrance can already execute through a
> production manifest publication tail while reusing the same production
> admission seam.

For that explicit mode, one Movement mutation has:

```text
sidecar save calls          0
CURRENT authority switches  1
partial-authority prefixes  0
semantic family count       5
```

The improvement is not that five meanings became one. They did not. The
improvement is that five distinct canonical family images can become current as
one selected generation rather than as a temporally ordered cross-family save
protocol.

## What this application does not claim

Application 035 does **not** yet earn:

- changing the default production authority from sidecars to manifests;
- deleting the existing sidecar publisher;
- automatic migration of an existing household source;
- mixed-version fallback;
- removal of legacy readers or consumers;
- a generic persistence framework;
- a whole-program source-size reduction claim.

The default remains the previously qualified sidecar protocol.

## Remaining boundary

The next gate is no longer "can production Movement publish through manifest
authority?". Application 035 answers that yes for the qualified practical path.

The remaining question is cutover:

> Can an existing canonical household installation be explicitly migrated to
> selected manifest authority, with all required production consumers reading
> that authority, after which the Movement default can change without a
> mixed-version or rollback ambiguity?

That should remain a distinct migration/cutover application rather than being
folded into this production-tail qualification.

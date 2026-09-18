# Admitted Type Integrity Audit — 2026-09-19

Status: **qualified; no confirmed production semantic bypass**

Scope: production-facing Lean types whose names or comments imply admission,
resolution, or authority qualification.

Primary question:

> Does receiving a value whose type/name says "Admitted" mean Lean itself proves
> the relevant invariant, or does production safety still depend on the value
> having come through one specific admission function?

## Result matrix

| Type | Representation | Production construction | Canonical / user-visible bypass found? | Decision |
| --- | --- | --- | --- | --- |
| `Persistence.AdmittedActualImage` | proof-carrying for current Event and validity projections | `admitActualImage?`, normalized decode | no | KEEP |
| `Application.AdmittedRelationUnit` | plain structure | relation admission/frontier projection | no | KEEP, document trust boundary |
| `Application.AdmittedRelationDischarge` | plain structure | target-local discharge admission | no | KEEP, document trust boundary |
| `MovementAdmission.Admitted` | plain operation result | `MovementAdmission.admit?` | no | KEEP |
| `CapacityEvidence` | proof-carrying cross-family completeness | `CapacityEvidence.ofParts?` / normalized Capacity decode | no | KEEP |

## 1. AdmittedActualImage

`AdmittedActualImage` carries:

```lean
currentEvents_admitted :
  correctionFrontierMemory? evidence.events evidence.corrections =
    some currentEvents

currentValidities_admitted :
  admittedActualValidityMemory? evidence.validity =
    some currentValidities
```

Those two read projections therefore cannot drift from the retained evidence
without supplying false Lean proofs.

The structure does **not** carry a single proof field saying that every
normalized-Actual law over Relation, Discharge, Reversal, calendar dates and
movement balance holds. Those laws are established by the construction path in
`admitActualImage?`.

Repository reachability shows production read surfaces consume
`ActualAuthority.Image`, while production acquisition goes through
`ActualAuthority.loadImageFile?` / `loadImage?`, which decode via
`decodeNormalizedActualImage?` and hence `admitActualImage?`.

No production constructor bypass was found.

### Decision

Keep the current type.

Promoting every normalized-Actual law into one dependent proof payload would
increase proof surface substantially. It is not currently justified because the
authority loader already owns the complete admission boundary, while the two
derived views that downstream readers deliberately reuse are the parts whose
non-drift matters at the type boundary.

## 2. AdmittedRelationUnit

The type is intentionally small:

```lean
structure AdmittedRelationUnit where
  relation : RelationUnit
  source : Effect
```

It is therefore forgeable by ordinary Lean code. Its name alone is not a proof
that:

- the source Event belongs to a particular EventMemory;
- the exact EffectKey resolves in that Event;
- endpoints have the admitted Household/external shape;
- quantity is positive and bounded by source magnitude;
- whole-source aggregate coverage remains bounded.

Those properties are checked by `admitRelationUnit?` and the surrounding
frontier.

A repository-wide construction search found no production direct constructor
outside the admission implementation. Consumers receive these values through
`currentRelationState?`, `admittedRelationFrontier?`, or the discharge
frontier.

### Decision

Keep the plain read view for now.

An indexed proof-carrying alternative such as
`AdmittedRelationUnit (events : EventMemory)` could encode source membership
and the admission predicates statically, but it would propagate the EventMemory
index through `RelationSourceState`, discharge admission, tests and queries.
No downstream runtime check is currently removed by paying that cost.

Revisit only if a second independent production entrance begins accepting
`AdmittedRelationUnit` directly, or if downstream code starts trusting fields
that are not re-derived from an admitted frontier.

## 3. AdmittedRelationDischarge

This type is likewise an admission-produced read view:

```lean
structure AdmittedRelationDischarge where
  discharge : RelationDischarge
  event : Event
  target : AdmittedRelationUnit
```

Its constructor can be called directly, so the type by itself does not prove
event identity, target identity, non-self-discharge, positivity, per-row bound,
or aggregate target bound.

Production creation is contained in the private target-local admission path.
The public query `admittedRelationDischargesFor?` starts again from raw
Event/Relation/Discharge evidence and performs the checks before returning the
view.

No production bypass was found.

### Decision

Keep. Do not add proof fields merely to make the name stronger.

If discharge values ever cross module boundaries as durable capability tokens,
reopen this audit.

## 4. MovementAdmission.Admitted

`MovementAdmission.Admitted` is a plain operation-result structure containing
the updated semantic World plus allocated EventId.

Only `MovementAdmission.admit?` constructs it in production. The practical
publisher consumes it immediately and then calls
`ActualAuthority.publishActual?`.

That publication path encodes and re-admits normalized Actual evidence before
the authority switch. Therefore even a hypothetical forged operation result
does not establish a canonical-authority bypass through the production
publisher API.

### Decision

Keep. It is an operation result, not a proof-carrying authority.

## 5. Capacity contrast

`CapacityEvidence` is the useful counterexample:

```lean
complete : capacityReferencesComplete movements effective = true
```

Here the cross-family completeness fact is small, stable and broadly reused, so
carrying the proof removes repeated rediscovery downstream.

This is the criterion for future proof promotion:

> add a proof field when one stable semantic fact has multiple consumers and the
> carried proof deletes repeated checks or prevents projection drift.

Do not promote proof fields merely because a structure can otherwise be
constructed manually.

## 6. ActualEvidence naming correction

`ActualEvidence` contains proof-carrying memories together with raw retained
Relation/Discharge provenance. Calling the whole aggregate "admitted evidence"
overstates what the type itself guarantees.

The production comment is therefore changed to describe it as **retained Actual
evidence** and to state that cross-family admission belongs to Application or
persistence boundaries.

## Closure

No T3/T4 production semantic gap was confirmed in this focused audit.

The useful distinction is:

```text
proof-carrying type
  invariant follows from the value itself

admission-produced view
  invariant follows from the qualified construction path

raw retained provenance
  invariant is intentionally not claimed yet
```

Current LOAM uses all three deliberately. The next trigger for additional Lean
proof-carrying structure should be a concrete downstream simplification or a
real constructor bypass, not the word "Admitted" by itself.

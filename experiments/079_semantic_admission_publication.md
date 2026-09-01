# Observation 079 — Are semantic admission and external publication one stage?

## Question

LOAM now has two concrete pressures that use very different parts of the practical boundary.

Observation 078 allows a read-only stateless shadow run to assign fresh run-local identity only for a proved identity-renaming-invariant quantity query. The run observes a source snapshot, evaluates a checked projection, persists nothing, and deliberately earns no continuity-sensitive semantic admission.

The practical correction entrance has the opposite shape. It constructs a replacement Event plus an explicit EventCorrection, checks representability and closed references against an in-memory candidate world, then publishes the correction relation stream before the replacement Event stream. Until the replacement Event is physically present, referential relation admission keeps the published dangling relation semantically inactive.

That creates a smaller question than inventing a new runtime architecture:

> Are `ADMIT` and `PUBLISH` actually one ordered stage, or are they independent coordinates that only some operations happen to cross together?

This observation tests a temporary five-verb vocabulary:

```text
OBSERVE
PROPOSE
CHECK
ADMIT
PUBLISH
```

The verbs are experiment labels only. They are not new Core types, commands, persistence objects, or a required universal pipeline.

## Existing cases

### Case A — stateless quantity shadow

A useful description of Observation 078 is:

```text
OBSERVE
  one private journal snapshot

PROPOSE
  fresh run-local identity is sufficient for this query

CHECK
  Lean proof that the retained quantity answer is identity-renaming-invariant

ADMIT
  no continuity-sensitive retained semantic fact

PUBLISH
  no persistent source or LOAM mutation
```

The important pressure is negative: successful checking does not itself require semantic admission or external publication.

### Case B — append-only correction

The current practical correction entrance already separates physical and semantic coordinates.

Before filesystem publication it can construct an in-memory replacement Event and EventCorrection whose explicit references are closed in the supplied candidate EventMemory. That candidate can therefore satisfy referential admission without yet being durable external state.

For publication, the correction relation stream is intentionally saved first. If replacement Event publication then fails, the raw correction is externally present but referential admission against the durable EventMemory keeps it semantically inactive until the referenced replacement appears.

So the current implementation already supplies pressure for both shapes:

```text
admissible candidate
+ not yet published
```

and

```text
published raw relation
+ not currently admitted
```

Neither shape means that an unsafe fact became authoritative. `RelationAdmission` is explicitly world-relative and fail-closed: it knows only whether referenced Event identities are present in the supplied EventMemory, not files, arrival order, authority, or publication protocol.

## Tool choice

Alloy only.

The present question is structural: can checked, admitted, and published coordinates vary independently while retaining a small dependency discipline? We do not yet need to decide operation order over time.

TLA+ would become the right next tool only if a later observation asks which publication/admission orderings are safe across a concrete transition protocol. Lean would become appropriate only if a stable general law is earned and should be preserved in the Practical Core.

## Model

`experiments/079_semantic_admission_publication.als` gives each bounded world five sets over one neutral `Matter` vocabulary:

```text
observed
proposed
checked
admitted
published
```

It assumes only this candidate dependency discipline:

```text
proposed ⊆ observed
checked  ⊆ proposed
admitted ⊆ checked
published ⊆ checked
```

The model deliberately does **not** assume:

```text
checked  => admitted
checked  => published
admitted => published
published => admitted
```

Nor does it interpret set membership as a global state-machine phase. It asks whether those stronger implications are actually forced by the smaller structure.

## Alloy result

Alloy 6.2.0 with Sat4j produced every requested positive witness:

```text
shadowStopsAtCheck                       SAT
correctionAdmittedWithoutPublication     SAT
correctionPublishedWithoutAdmission      SAT
correctionCrossesBothBoundaries           SAT
sameCheckedDifferentBoundaryState         SAT
```

It also found counterexamples to every attempted collapse of the boundaries:

```text
CheckForcesAdmission                     SAT counterexample
CheckForcesPublication                   SAT counterexample
AdmissionForcesPublication               SAT counterexample
PublicationForcesAdmission               SAT counterexample
CheckedStateDeterminesBoundaryState       SAT counterexample
```

The two dependency guards remained unviolated in the bounded scope:

```text
UncheckedAdmissionImpossible             UNSAT
UncheckedPublicationImpossible           UNSAT
```

Those last two results validate the assumptions encoded in this model. They do not promote those assumptions into new general LOAM law.

## Result

The five verbs survive only in a weaker form than a pipeline:

- `CHECK` is not semantic commitment;
- `ADMIT` is semantic eligibility relative to a supplied world, not necessarily durable mutation;
- `PUBLISH` is an external effect coordinate, not proof of semantic admission;
- identical observed/proposed/checked information does not determine admitted/published state;
- no universal `OBSERVE -> PROPOSE -> CHECK -> ADMIT -> PUBLISH` pipeline has been earned.

The correction entrance makes the distinction practical rather than merely terminological. A candidate relation can be referentially closed against an in-memory candidate world before anything is durable, while a raw correction can be durably published and still remain outside the admitted view when its replacement Event is absent.

So `ADMIT` and `PUBLISH` are better treated as independent coordinates that an operation may cross in different ways. This observation does **not** establish which temporal ordering is safest for a general publication protocol.

That negative result is useful: the five-word sketch does not become a new framework merely because it is convenient vocabulary.

## Practical Core impact

None.

- no Core type change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no new authority or chronology rule;
- no claim that Alloy establishes temporal protocol safety.

This observation is only a structural audit of vocabulary against behavior LOAM already has.

## Next pressure

Do not add a generic five-stage runtime.

If a concrete operation later needs a claim about publication/admission order across reachable states, make that temporal protocol the question and use TLA+ only then. Otherwise keep `ADMIT` and `PUBLISH` as descriptive coordinates rather than mandatory architecture.

# Application 006: conservative fact extension

## Question

Before LOAM starts aiming at ordinary daily use, can a future fact family be added without forcing the existing canonical Event and Correction families to change shape or meaning?

This is deliberately narrower than designing Plans, budgets, accounts, classifications, or a universal metadata system. The future fact kind remains abstract.

## Existing evidence

Observation 054 already separated three concerns:

- logical canonical basis;
- physical storage topology;
- derived projections.

It also showed that explicit typed fact streams can preserve the same correction meaning as one unordered tagged fact set. A single global serialized order is not required.

Current production persistence follows that direction in a small, concrete way:

- Event memory has its own versioned `LOAM-EVENT-MEMORY\t1` format;
- Event-correction memory has its own versioned `LOAM-EVENT-CORRECTION-MEMORY\t1` format;
- each decoder fails closed on malformed or unsupported contents;
- each stream is published independently, while higher-level protocols decide when more than one stream must be coordinated.

The production persistence code does not yet define persistence for every Core fact family. That is useful pressure for this experiment: future growth should not require retrofitting a universal row format merely because another fact kind appears.

## Lean probe

`application_006_conservative_fact_extension.lean` models:

- an `ExistingImage Event Correction` with two independently typed families;
- an `ExtendedImage Event Correction LaterFact` with one arbitrary later family;
- `extend`, which adds the later family without changing the old memberships;
- `forgetLater`, which projects the extended image back to exactly the old image.

Lean proves by construction:

1. `forgetLater (extend base laterFacts) = base`;
2. Event membership is preserved exactly;
3. Correction membership is preserved exactly;
4. a representative projection that depends only on the old image is unchanged.

The proof is intentionally simple. The point is not theorem difficulty; it is to make the extension boundary explicit before production daily-use work starts.

## Interpretation

The useful requirement is **conservative extension**, not "predict every future feature".

A later fact family may be added without changing an existing family when:

- its identity is independently explicit;
- old facts are not rewritten to smuggle the new meaning inside them;
- old projections depend only on the old admitted image unless they explicitly opt into the new family;
- any cross-family invariant is introduced explicitly at the Application/Core boundary;
- physical publication coordination is added only when that invariant actually requires it.

This means LOAM does not need to enumerate every HRA feature before daily use begins.

## Persistence consequence

Do **not** weaken the current version-1 Event-memory decoder so that it silently skips unknown rows. Fail-closed decoding is valuable: an old reader should not accidentally claim to understand a changed Event-memory format.

When a genuinely new canonical fact family is earned, the smallest safe options remain open:

- give it an independently versioned typed stream;
- introduce a new version of an existing stream if the old fact itself truly changed;
- bundle streams later if operational pressure such as atomic cross-family publication earns that topology.

No universal `Fact`, metadata bag, manifest, database schema, or plugin registry is earned here.

## Daily-use consequence

LOAM can now move toward the first ordinary-use vertical slice without first designing every future Plan, allocation, classification, cancellation, supersession, or account-management feature.

The next practical question can therefore stay small:

> Can ordinary expense, income, and transfer recording produce the account/locus balances needed for daily use while preserving the current generic Event/Effect vocabulary?

Application 006 does not create a new Observation number because it confirms and operationalizes the extensibility consequence of existing canonical-topology observations rather than discovering a new domain law.

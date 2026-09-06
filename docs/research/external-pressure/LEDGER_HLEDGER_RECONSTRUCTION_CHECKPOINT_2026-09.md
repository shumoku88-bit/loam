# Ledger / hledger Reconstruction Checkpoint — September 2026

Status: **research checkpoint through Observation 210; selected semantic reconstruction, not compatibility or product parity**

Evidence baseline:

```text
64b8c203baaa531593c669ca46e1ad74af357be7
experiment: probe Ledger lot gain composition (#461)
```

Capability map:

- `LEDGER_HLEDGER_CAPABILITY_RECONSTRUCTION_MAP_2026-09.md`

## Question closed by this checkpoint

LOAM used Ledger 3 and hledger 1.52 as mature external pressure against a deliberately small neutral semantic Core.

The question was not:

> Can LOAM copy every Ledger/hledger feature?

It was:

> When selected mature accounting answers require more information than LOAM's physical Event/Effect history contains, does that information force a larger neutral Event/Effect shape, or can it remain explicit additive evidence, relations, policy, projection, generation, and admission over stable existing identities?

Through Observation 210, every directly attacked cluster took the additive branch.

## Baseline Core reading

The selected physical identity remains conceptually small:

```text
Event
  -> Effect identity
     -> Locus
     -> Measure
     -> exact signed Quantity
```

`EffectKey` provides a stable provenance endpoint where later semantic evidence needs to refer to a particular effect.

This checkpoint does not claim that the whole application contains only these concepts. It distinguishes neutral physical identity from the additional semantic planes that can attach to it.

## Evidence sequence

### Before the Ledger composition gates

Earlier observations had already separated several tempting compressions:

```text
physical Locus              != AccountingRole
recognition coordinate      != occurrence/payment coordinate
valuation coordinate        != physical occurrence
rate/source provenance      != one authoritative scalar
historical valuation        != acquisition basis
aggregate holding           != disposal-source provenance
valid allocation            != selected attribution
current policy              != retained historical attribution
```

Important earlier evidence includes Observations 031, 049, 062, 066–071, 140–143, 201, and 206.

Those results suggested additive composition, but several mature Ledger/hledger cross-feature interactions were still capable of exposing Core-shape pressure.

### Observation 207: derived postings + assertions + correction horizon

Pressure:

```text
retained physical history
+ accounting-only contribution
+ query-generated contribution
+ report realness policy
+ balance assertion
+ correction-aware query horizon
```

The probe showed that one flat selected-balance scalar cannot reconstruct assertion outcome or contribution provenance. But explicit separate planes plus policy, assertion evidence, and query horizon determined the selected report/assertion answers in the bounded model.

Classification:

```text
B / conservative additive composition
```

Production `VirtualPosting`, `AutoPosting`, or a universal real/virtual field on Effect was not earned.

### Observation 208: hierarchy + role + status + posting date

Pressure:

```text
Locus hierarchy
+ inherited / overridden AccountingRole
+ transaction / posting status
+ transaction / posting date
+ report selection
+ assertion selection
```

Hierarchy, posting-specific status, and posting-specific date all proved independently observable: flattening them loses legitimate selected answers. Keeping them as explicit relations over existing Event / Effect / Locus identities fixed the selected sets.

Classification:

```text
B / conservative additive composition
C / Core-shape pressure not demonstrated
```

No production Account tree, status field, or extra universal Event/Effect date field was earned.

### Observation 209: generation + assignment + finality/order

Pressure:

```text
close / open / retain generation
+ balance assignment
+ generated assertions
+ generation / validation selection context
+ Ledger-like parse order
+ hledger-like date-then-parse order
+ generated-vs-retained admission
```

The probe established:

```text
generated values  -/-> generation meaning
generation        -/-> retained history
final balance      -/-> prefix-sensitive assertion result
```

But explicit mode, target, context, ordering, and admission inputs determined the selected outputs.

Classification:

```text
B / conservative additive composition
```

This preserves a strong boundary between generating a candidate answer and admitting retained historical fact.

### Observation 210: acquisition basis + disposal provenance + gain/value

Pressure:

```text
acquisition-specific basis
+ disposal provenance
+ sale proceeds
+ remaining market valuation
+ cost / market report policy
    -> realised gain
     + unrealised gain
     + selected remaining value
```

The executed Alloy matrix showed that basis+proceeds alone, market value alone, and gain scalar alone all lose information. Once the explicit acquisition/provenance/valuation inputs were fixed, the selected gain/value answers were fixed.

Classification:

```text
B / conservative additive composition
```

No C-level need to change Event, Effect, or EffectKey was found.

## Qualified architectural result

For the selected mature Ledger/hledger semantic families directly attacked through Observation 210, the surviving architecture is:

```text
small neutral physical Core
+ independently observable typed evidence
+ explicit relations
+ policy / projection / generation
+ explicit admission boundary
    -> selected mature accounting answers
```

The research repeatedly discovered information that must **not be erased**. It did not discover that the information must become a field of neutral Event/Effect.

That is the central result of this checkpoint.

A stronger statement is now justified than at the original capability-map review:

> Across the selected mature Ledger/hledger semantics directly tested, no C-level pressure has yet required enlarging neutral Event/Effect/EffectKey shape.

The statement remains bounded. It is evidence from the attacked semantic families, not a theorem about all future accounting software.

## Semantic reconstruction is not production implementation

`R` in the capability map means the selected semantic question has a qualified reconstruction. It does **not** mean LOAM should immediately add production types, writers, persistence, commands, or UI for that vocabulary.

Dogfood still decides what product vocabulary is earned.

For example, the research can qualify that acquisition-specific basis and disposal provenance determine selected gain answers without earning a production `Lot` object today.

Likewise, it can qualify a separate accounting-only contribution plane without earning a universal `VirtualPosting` family.

## External-version boundary

The checkpoint deliberately does not flatten Ledger and hledger into one imaginary system.

In the selected source versions:

- hledger 1.52 distinguishes posting-attached cost from ambient valuation and preserves Ledger-style cost/lot annotations, while its automated lot/gain machinery is more limited;
- Ledger 3 exposes richer cost/lot/gain reporting semantics;
- their assertion ordering also differs in a way explicitly attacked by Observation 209.

The reconstruction target is therefore the selected semantic distinction, not accidental syntax or one product's object vocabulary.

## What remains outside this checkpoint

This work does not establish:

- Ledger parser or journal-syntax compatibility;
- hledger parser or journal-syntax compatibility;
- query/expression-language parity;
- option-for-option command parity;
- tax-basis correctness;
- FIFO, LIFO, average-cost, or specific-identification automation;
- fees, splits, mergers, spin-offs, or other corporate actions;
- short-position semantics;
- general recurring/rewrite rule engines;
- full reconciliation/import authority;
- complete ROI/investment-return methodology;
- production types or UI for every qualified semantic distinction.

These are residual frontiers, not evidence that Event/Effect must already grow.

## Stop rule

Do not continue Ledger/hledger research merely to fill remaining table cells.

This reconstruction line is considered **closed at the current checkpoint** until one of the following occurs:

```text
real dogfood requires an answer the current evidence cannot determine
product work exposes incompatible legitimate projections over current identities
a retained-provenance requirement cannot be represented additively
a generated/admitted-fact boundary fails under a concrete workflow
a rich valuation/corporate-action case exposes an indispensable relation that
cannot attach to existing stable identities
```

When reopened, seek the smallest falsifying specimen first. Do not import a conventional accounting object model by default.

## Checkpoint conclusion

```text
selected Ledger/hledger reconstruction breadth            SUBSTANTIAL
independent semantic information discovered                YES
that information can be erased into flat scalars           NO
additive composition survived Obs. 207                     YES
additive composition survived Obs. 208                     YES
additive composition survived Obs. 209                     YES
additive composition survived Obs. 210                     YES
C-level Event/Effect/EffectKey shape pressure found        NO
future C-level pressure proved impossible                   NO
production parity claimed                                   NO
research should now return to dogfood                       YES
```

The next useful pressure should come from actually using LOAM, not from making the Ledger/hledger catalog greener.

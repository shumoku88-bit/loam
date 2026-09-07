# Observation 221 — Is scoped completeness one shared household concept?

Status: **QUALIFIED INFORMATION-LAW / NO GENERIC COVERAGE ONTOLOGY**

Research starting point: LOAM `d9c8de9cd22f9b18c7ab9574f494621b6a42d972`

## Pressure

Observation 219 showed that the current zero-only household `QuantityBasis` can
factor into:

```text
explicit zero-origin coverage
+ correction-aware Event quantity
```

while preserving `missing != zero`.

Observation 211 independently showed that Scheduled absence can become safely
negative inside an explicit completeness horizon:

```text
explicit occurrence       -> Due
absent + complete scope    -> NotDue
absent + incomplete scope  -> Unknown
```

The repeated word `coverage` is tempting. LOAM should not create a universal
household `Coverage` concept merely because two observations use similar English.

The question is narrower:

> Is there a small information-law shared by zero-origin quantity coverage and
> Scheduled completeness, while their evidence and storage remain semantically
> distinct?

## First classification: similarly named things that are not the same

The current repository contains several unrelated uses of coverage-like
vocabulary.

### LocusAdmission

`LocusAdmissionVocabulary` is a finite current **permission** set for new quantity
writes.

```text
approved locus
    -> new write may use this identity
```

It does not claim that retained history for that Locus is complete. Therefore:

```text
new-write permission != origin completeness
```

### knownThrough

Historical/shadow `knownThrough` is a **visibility** boundary:

```text
which retained evidence is visible to this historical query?
```

Observation 211 explicitly distinguished this from Scheduled completeness:
visibility through a date does not mean every obligation through that date was
materialized.

```text
visibility != completeness
```

### balance-view / AccountingRole

Observation 219 already excluded both. Presentation selection and accounting
classification do not prove quantity-history completeness.

### graph / relation coverage

Older frontier-coverage observations concern graph reachability. Relation-plane
coverage concerns quantity allocation over a source Effect. Neither supplies
open-world completeness for a household query merely because the word
`coverage` appears.

## The smaller common shape

The shared structure is read-side and extensional.

For a query `q`, distinguish:

```text
direct(q)       : optional answer already justified by explicit evidence
complete(q)     : whether a closed-world reconstruction is justified at q
closedValue(q)  : domain-specific answer justified when complete(q)
```

Then:

```text
if direct(q) exists
    Known direct(q)
else if complete(q)
    Known closedValue(q)
else
    Unknown
```

This is intentionally not a claim that every domain has the same canonical
completeness record.

## Why Scheduled and Quantity are not identical

### Scheduled

One explicit current-open occurrence is already a direct positive witness.
Completeness is needed only to strengthen **absence**:

```text
explicit Due outside completeness scope -> still Due
absent inside completeness scope         -> NotDue
absent outside completeness scope        -> Unknown
```

The candidate `completeThrough` from Observation 211 is one possible way to
realize `complete(q)` for day/subject queries.

### Current quantity

An Event effect is a **change**, not a direct witness of current stock.
Therefore retained Event activity by itself does not justify a current quantity.
Origin completeness is required even when the retained aggregate is nonzero:

```text
Event aggregate + zero-origin completeness -> Known current quantity
Event aggregate without origin completeness -> Unknown current quantity
```

For current household dogfood, Observation 219's finite zero-origin coordinate
set realizes `complete(q)`.

So the two domains share an information gate, not an identical evidence meaning.

## Lean probe

`221_scoped_completeness_information_order.lean` introduces experiment-local:

```text
Knowledge A = Unknown | Known A
CompletenessScope Q = Q -> Bool
```

and one generic read-side operation:

```text
inspectWithCompleteness direct closedValue scope query
```

The probe checks the two domain-shaped instantiations and selected negative
controls.

### Scheduled witnesses

- explicit Due stays Known with no completeness claim;
- covered absence becomes Known false / NotDue;
- absence beyond completeness stays Unknown;
- substituting a broader visibility horizon for completeness changes Unknown into
  a negative answer and is therefore semantically observable.

### Quantity witnesses

- zero-origin-covered Event aggregate becomes Known current quantity;
- the same Event aggregate without origin completeness stays Unknown;
- substituting a Locus write-admission predicate for origin completeness can
  manufacture Known zero for a newly approved coordinate and is therefore wrong.

### Information order

The probe uses the tiny ordering:

```text
Unknown <= Known x
Known x <= Known x
Known x incomparable with Known y when x != y
```

Adding justified completeness may refine Unknown into Known. Adding completeness
does not override already-sufficient direct positive evidence.

This is a natural, narrow appearance of the earlier information-order / lattice
intuition without importing a general uncertainty framework.

## Executed result

The first CI attempt exposed only experiment-surface mistakes: generic type
parameters were left implicit while `autoImplicit` was disabled, and the probe
imported `Effect` rather than the module that defines `EffectCoordinate`.

After making the generic types explicit and importing `Loam.Core.Event`, the
Observation 221 job completed successfully:

```text
supporting production Event slice  SUCCESS
Scheduled-shaped witnesses         SUCCESS
Quantity-shaped witnesses          SUCCESS
permission != completeness         SUCCESS
visibility != completeness         SUCCESS
information-order witnesses        SUCCESS
```

No semantic expected result changed between attempts.

## Architectural interpretation

The smallest qualified boundary is:

```text
semantic family evidence
        |
        v
family-specific completeness claim
        |
        v
CompleteAt(query)  -- extensional predicate / read-side law
        |
        v
family-specific answer strengthening
```

The common layer, if production ever needs one, should therefore be no stronger
than a tiny Application-level structural helper around a `query -> Bool`
predicate and open-world answer refinement.

It should **not** own:

- what a query means;
- how completeness is earned;
- how completeness is persisted;
- chronology;
- Account/AccountingRole;
- Scheduled recurrence;
- Locus admission;
- source provenance.

## Persistence consequence

Observation 221 gives no reason for a universal `coverage.loam` file.

The two semantic claims have different natural shapes:

```text
zero-origin quantity coverage
    finite EffectCoordinate domain

Scheduled completeness
    possibly a temporal prefix, perhaps later scoped by subject/Series
```

Trying to serialize both through one generic record would enlarge the ontology
before any production duplication has been demonstrated.

## Important distinction: representation completeness vs world completeness

A whole-file authority may be a complete representation of **retained LOAM
facts** while still being incomplete about the real-world question being asked.

For example, `scheduled.loam` can contain every retained Scheduled row and still
omit a real future obligation that has not been materialized. Therefore:

```text
complete file publication
    !=
complete household evidence for every query
```

This distinction also prevents Git completeness, manifest completeness, or file
snapshot semantics from silently earning zero-origin or Scheduled completeness.

## Qualified finding

```text
SHARED
  completeness is a predicate over the query space
  completeness can refine open-world knowledge
  Unknown must not be strengthened without it
  adding justified completeness is information refinement

NOT SHARED
  evidence meaning
  scope representation
  persistence
  write policy
  domain-specific result vocabulary
```

Therefore **no production Core `Coverage` concept is earned**.

The preferred next production move is still to simplify the QuantityBasis path
using quantity-specific completeness/starting-state evidence. A generic
production helper should be extracted only if a second production family later
uses the same runtime mechanics and the helper demonstrably pays its rent, just
as Observation 218 required for replacement-frontier sharing.

## Consequence for QuantityBasis work

Observation 221 removes one architectural uncertainty from the next cut:

```text
Do not create:
  generic Coverage
  generic coverage persistence
  Scheduled completeness merely to share code

Do preserve:
  explicit quantity-history completeness scope
  missing != zero
  family-specific evidence meaning
```

Observation 220 has already shown that even non-zero starting state factors, for
current-value purposes, through a finite partial `EffectCoordinate -> Quantity`
origin snapshot. The next practical pressure is therefore whether the current
HRA-authority operating mode can replace QuantityBasis identity/correction
machinery with one atomically replaceable quantity-specific origin snapshot while
keeping coverage explicit and assessing BasisCut separately.

## Non-goals

Observation 221 does not authorize:

- a Core `Coverage` concept;
- a generic `coverage.loam` authority;
- production Scheduled completeness;
- treating `knownThrough` as completeness;
- treating LocusAdmission as completeness;
- treating balance-view or AccountingRole as completeness;
- a general uncertainty lattice in production;
- deleting QuantityBasis before its practical replacement is qualified.

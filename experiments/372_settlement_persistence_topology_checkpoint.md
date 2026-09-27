# Observation 372 — settlement persistence topology checkpoint

Status: **PERSISTENCE TOPOLOGY SELECTED — same Actual generation, document-level settlement rows**

Baseline:

```text
#1405  production settlement raw vocabulary
#1407  composed in-memory settlement admission
#1408  production-shaped settlement qualification
main   4da9caa95d38ea516d8a4f292a0104bdb7e1d3ce
```

## Trigger

Observation 371 deliberately stopped before persistence.

That stop condition mattered because the promoted settlement model now includes
facts that do not share one natural owning transaction:

- a commitment refers to a source Event / keyed Effect;
- direct settlement refers to a later physical Event / keyed Effect;
- one physical Effect may directly settle several commitments;
- one netting context may contain several opposite-direction commitments;
- exact zero-net settlement has no physical Effect at all;
- correspondence/member corrections retain old and replacement rows;
- optional future finality may refer to historical member versions.

The production semantic boundary is qualified. The remaining question is
physical topology:

> Where should retained settlement evidence live so that persistence does not
> distort the already-qualified meaning?

## Existing Actual authority

Current production `actual.loam` already has a strong single-generation
publication protocol:

```text
exclusive writer ownership
-> read current ActualEvidence
-> construct admitted candidate
-> encode complete generation
-> write .loam-stage
-> typed re-decode staged generation
-> atomic rename stage -> actual.loam
```

`ActualEvidence` is explicitly a persistence-neutral aggregate of co-published
Actual fact families.

`NormalizedActualAdmission.admitActualImage?` is the generation-wide
re-admission boundary.

This is valuable infrastructure. Settlement persistence should reuse it unless a
concrete semantic requirement proves that it cannot.

## Candidate A — force settlement rows inside TX blocks

### Shape

Examples would look conceptually like:

```text
TX source-event ...
  SETTLEMENT-COMMITMENT ...

TX later-payment ...
  SETTLEMENT-CORRESPONDENCE ...
```

and a netting context would need to be attached to some TX.

### Advantage

- smallest parser change;
- follows current per-TX normalized grammar;
- source/direct rows have obvious nearby Event references.

### Failure

The topology invents ownership that the semantic model does not have.

A `SettlementNettingContext` may span several source commitments and is not
owned by any one Event.

More decisively:

```text
NetSettlementOutcome.zero
```

has no physical Event by design.

Putting that context inside a TX therefore requires one of:

- arbitrarily choosing one member's Event as owner;
- inventing a synthetic settlement Event;
- inventing a zero-quantity physical Effect.

All three contradict qualified Observations 365–370.

The persistence grammar would become a hidden ontology.

### Decision

**REJECT.**

TX-local storage may still be used for facts whose semantic authority is truly
TX-local. It must not be used merely because the current parser is convenient.

## Candidate B — document-level settlement rows inside the same `actual.loam`

### Shape

Keep existing TX blocks unchanged, then allow settlement evidence at document
scope in the same normalized Actual generation.

Conceptually:

```text
LOAM-NORMALIZED-ACTUAL <version>

TX ...
...
ENDTX

TX ...
...
ENDTX

SETTLEMENT-COMMITMENT ...
SETTLEMENT-CORRESPONDENCE ...
SETTLEMENT-CORRESPONDENCE-REVISION ...
SETTLEMENT-NETTING ...
SETTLEMENT-MEMBER ...
SETTLEMENT-MEMBER-REVISION ...
```

The rows refer to Event / Effect identities rather than being physically nested
under them.

### Advantages

- preserves one Actual authority;
- preserves one writer lock;
- preserves one staging file;
- preserves one typed generation re-decode;
- preserves one atomic rename;
- supports cross-Event commitment / settlement relationships naturally;
- supports netting contexts spanning several commitments;
- supports zero-net contexts without a fake Event;
- supports append-only correction rows without rewriting TX blocks;
- lets unrelated Actual publishers preserve settlement evidence through ordinary
  `evidence with ...` updates;
- lets `NormalizedActualAdmission` validate Event closure and settlement
  conservation from one acquired generation.

### Cost

The current decoder is a TX-only state machine after the header.

It must gain one document-level parsing layer.

That is an implementation cost, not a semantic objection.

### Decision

**SELECT.**

This is the smallest topology that preserves the production semantics already
qualified.

## Candidate C — separate `settlement.loam` authority

### Shape

```text
actual.loam
settlement.loam
```

### Apparent advantage

- isolated grammar;
- minimal disturbance to normalized Actual parser;
- settlement-specific writers could operate on one small file.

### Failure

Settlement facts reference retained Actual Events / Effects.

Two independent files create a generation problem:

```text
actual generation A
settlement generation S
```

A crash or concurrent publication can expose:

```text
A_new + S_old
or
A_old + S_new
```

while settlement admission requires same-generation reference closure and
conservation.

Preserving the existing atomic guarantee would require new coordination such as:

- a shared generation manifest;
- generation directories plus atomic pointer switch;
- a multi-file transaction protocol;
- or an equivalent commit record.

None of that has been earned merely to avoid extending one parser.

It would also create a second authority-selection problem for every read-side
caller.

### Decision

**REJECT for the base production family.**

A separate stream may be reconsidered only if future scale or access-pattern
pressure makes the single file objectively insufficient and a generation
protocol is qualified first.

## Selected topology

### One authority generation

Settlement evidence becomes another retained fact family inside
`ActualEvidence`.

Prefer a grouped persistence-neutral raw aggregate rather than six unrelated
top-level fields:

```text
SettlementEvidence
  commitments
  correspondences
  correspondenceRevisions
  nettingContexts
  nettingMembers
  nettingMemberRevisions

ActualEvidence
  ...
  settlements : SettlementEvidence
```

This grouping is not a universal `Settlement` semantic supertype.

It is the raw-memory counterpart of the already-promoted settlement family and
prevents `ActualEvidence` from accumulating a flat pile of mechanically related
lists.

`SettlementEvidence.empty` should exist for migration and empty authority.

### One admitted generation image

`NormalizedActualAdmission.admitActualImage?` should call the existing
production:

```text
admitSettlementImage?
```

against the same retained `EventMemory`.

The resulting admitted settlement projection should be retained in
`AdmittedActualImage` rather than silently re-derived by each caller.

Conceptually:

```text
AdmittedActualImage
  evidence
  currentEvents
  currentValidities
  settlement
  ...proof/qualification link...
```

This keeps one acquired read image coherent across:

- current Event correction frontier;
- current occurrence validity;
- current settlement correspondence/member frontiers;
- settlement reference closure;
- composed target conservation;
- composed physical-Effect conservation.

Settlement does not become a second read authority.

## Document grammar

### Keep TX grammar semantically unchanged

Existing rows such as:

```text
EFFECT
KEYED-EFFECT
RELATION
DISCHARGE
EXCHANGE
...
```

retain their present TX-local meaning.

Do not move existing relation/discharge rows merely for symmetry.

### Add document-level settlement row families

Selected candidate grammar:

```text
SETTLEMENT-COMMITMENT
  <commitment-id>
  SOURCE <event-id> <effect-key>
  <debtor-endpoint>
  <creditor-endpoint>
  <measure-id>
  <quantity>

SETTLEMENT-CORRESPONDENCE
  <correspondence-id>
  TARGET <commitment-id>
  PHYSICAL <event-id> <effect-key>
  <quantity>

SETTLEMENT-CORRESPONDENCE-REVISION
  <target-correspondence-id>
  REPLACEMENT <replacement-correspondence-id>

SETTLEMENT-NETTING
  <context-id>
  <measure-id>
  ZERO

SETTLEMENT-NETTING
  <context-id>
  <measure-id>
  PHYSICAL <event-id> <effect-key>

SETTLEMENT-MEMBER
  <member-id>
  CONTEXT <context-id>
  TARGET <commitment-id>
  <quantity>

SETTLEMENT-MEMBER-REVISION
  <target-member-id>
  REPLACEMENT <replacement-member-id>
```

Exact spelling remains an implementation detail until the first persistence PR,
but these semantic coordinates are fixed by this checkpoint.

### Canonical physical order

Encoder should emit:

```text
all TX blocks in existing retained Event order
then
all document-level settlement rows
```

Within the settlement region, use a fixed family order:

```text
commitments
correspondences
correspondence revisions
netting contexts
netting members
netting member revisions
```

Retained list order inside each family should be preserved.

Decoder should collect raw rows first and run generation-wide admission only
after all Event and settlement facts are constructed.

Reference order therefore does not become semantic order.

### Do not require BEGIN/END fake containers

A separate `BEGIN-SETTLEMENT` owning block is not required for meaning.

Distinct document-level row prefixes already identify the family and avoid
creating another synthetic container identity.

A parser may internally use a settlement-region state for clarity, but that
state is grammar mechanics only.

## Wire-version decision

The current header is:

```text
LOAM-NORMALIZED-ACTUAL    1
```

Old v1 decoders reject unknown top-level rows.

Therefore writing settlement rows under the same v1 header would falsely claim
wire compatibility.

### Selected migration rule

Introduce a settlement-capable **v2** document grammar.

New decoder:

```text
v1
  -> decode current TX-only grammar
  -> SettlementEvidence.empty

v2
  -> decode current TX grammar
  -> decode document-level settlement rows
  -> generation-wide Actual + settlement admission
```

Encoder:

```text
if SettlementEvidence is empty
  -> emit v1

if SettlementEvidence is nonempty
  -> emit v2
```

This has useful operational properties:

- households that never use settlement keep byte-level v1 capability;
- unrelated writes do not force an immediate format migration;
- the first retained settlement fact makes the capability transition explicit;
- new code reads both generations;
- old binaries fail clearly on v2 rather than seeing a v1 header and then an
  unexplained unknown row.

Do not emit settlement rows under v1.

Do not require a one-time global migration command merely to install new code.

## Admission and decoding order

For v2:

```text
parse complete document
-> construct EventMemory and existing Actual evidence
-> construct SettlementEvidence
-> existing correction / validity / exchange / relation admission
-> admitSettlementImage? using the same EventMemory generation
-> construct AdmittedActualImage
```

Important: settlement correspondence/member revisions select current rows before
current semantic admission, exactly as qualified in #1407/#1408.

Superseded malformed historical payload may remain retained if the replacement
frontier itself is structurally valid and the current row is admissible.

Persistence must not accidentally re-impose admission on superseded payload and
undo the production correction semantics.

## Atomic publication consequence

No new filesystem transaction mechanism is required.

Existing `ActualAuthority.publishActualFile?` remains the physical commit
boundary:

```text
encode complete ActualEvidence including SettlementEvidence
-> stage
-> typed decode staged v1/v2 document
-> atomic rename
```

This makes a candidate containing:

```text
new Event
+ new settlement commitment
+ new correspondence/member evidence
```

visible all at once or not at all.

Zero-net publication is also atomic even though it adds no physical settlement
Event.

## Publisher preservation obligation

Adding a retained family creates one important repository-wide obligation:

> every unrelated Actual publisher must preserve existing SettlementEvidence.

Publishers that use:

```text
{ evidence with ... }
```

naturally preserve it.

Any code that reconstructs `ActualEvidence` from a field list must be audited.

Do not rely only on a default `.empty` field to keep old constructors compiling,
because silent loss of settlement evidence would be worse than a compile error.

The persistence implementation should add a qualification proving that at least
the major independent publishers preserve a nonempty settlement fixture across
an unrelated write.

Representative publishers:

- Movement;
- Exchange;
- Correction / reversal;
- validity/date;
- merchant / description;
- relation/discharge writers.

The exact coverage can be compressed into shared preservation helpers rather
than one bespoke test per UI route.

## Crash and stale-writer obligation

Existing Actual writer ownership remains the only lock.

Settlement publication should follow the same pattern:

```text
withActualOwnership
-> re-read full current ActualEvidence
-> construct candidate
-> admit whole candidate
-> publish whole generation
```

Do not create a settlement-only lock.

Do not load Actual outside ownership and later append settlement rows to a newer
generation.

The first writer qualification must include:

- interruption before rename leaves old generation readable;
- staged malformed settlement is rejected before authority switch;
- stale candidate cannot silently overwrite newer Actual evidence;
- unrelated retained families survive the write.

## What this checkpoint does not select

Still deferred:

- finality-publication persistence;
- complete-allocation publication persistence;
- automatic matching;
- securities statement import;
- credit-card statement import;
- FX valuation;
- fee/tax/basis decomposition;
- TUI shape;
- identifiers generated by a specific UI;
- batch writer semantics;
- legal settlement state.

Those can be additive rows/extensions later if concrete workflows require them.

## Implementation sequence

### Slice D1 — raw retained aggregate

Add:

```text
SettlementEvidence
SettlementEvidence.empty
ActualEvidence.settlements
```

No wire changes yet if useful to keep this PR compile-only.

### Slice D2 — Actual admitted image

Extend normalized Actual admission so one generation constructs and retains an
`AdmittedSettlementImage`.

Empty settlement evidence must preserve all current v1 behavior.

### Slice D3 — v2 parser / encoder

Add dual-version decode and conditional v1/v2 encode.

Pin round trips for:

- empty settlement v1;
- direct settlement v2;
- zero-net v2;
- correspondence revision v2;
- netting-member revision v2;
- malformed/missing references fail closed;
- unknown v2 row fails closed;
- settlement row under v1 is rejected.

### Slice D4 — generation preservation and crash qualification

Extend production persistence/crash tests to prove:

- one generation contains Event + settlement evidence atomically;
- unrelated writer round trips preserve settlement rows;
- staged invalid settlement never replaces authority.

### Slice E — first narrow settlement publisher

Only after D1–D4, add a writer.

The first writer should publish explicit user/AI-confirmed evidence.

Do not add canonical automatic matching in the first writer.

## Stop condition

After the selected document-level v2 topology round-trips and survives unrelated
publishers/crash qualification, stop persistence expansion.

Then add one narrow practical entrance and read/query surface.

Do not use persistence work as an excuse to promote optional finality,
allocation, brokerage, or valuation semantics.

## Decision

**SELECT**

```text
one actual.loam authority
one atomic Actual generation
TX blocks unchanged
document-level settlement rows
SettlementEvidence grouped raw aggregate
AdmittedSettlementImage retained inside admitted Actual image
v1 read compatibility
v1 encode while settlement empty
v2 when settlement evidence exists
```

**REJECT**

```text
settlement forced into owning TX
synthetic zero settlement Event
synthetic zero physical Effect
separate settlement.loam base authority
multi-file settlement commit protocol
settlement-only writer lock
silent v1 grammar widening
```

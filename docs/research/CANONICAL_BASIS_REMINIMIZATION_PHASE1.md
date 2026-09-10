# Canonical basis re-minimization — Phase 1

Status: **working checkpoint, no canonical-data mutation authorized**

Baseline main: `9d11b5413bc353d1e596aa7e839ee281cd28e613`

Tracking issue: #693

## 1. Question

Re-run the early LOAM minimization discipline against the current operational
system:

> What is the smallest independently retained household information from which
> every currently admitted observable operation can still produce the same
> semantic result?

This is deliberately stronger than source-line or file-count cleanup.

The working suspicion is that later LOAM continued to make many locally sound
minimality decisions while the combined current basis was not periodically
re-minimized as one whole system. That suspicion is not yet a conclusion.

## 2. Observable vocabulary, not read queries alone

The early observations minimized state relative to a future **operation
vocabulary**. The current audit must do the same.

Let `Q` contain currently admitted externally observable operations, including
reads and writes/administration.

For household worlds `h1` and `h2`:

```text
h1 ~Q h2
iff
for every q in Q and admitted input x,
semanticResult(q, x, h1) = semanticResult(q, x, h2)
```

This matters because some retained information changes whether a future write is
admitted even when no current read value changes. `LocusAdmission` is the clearest
example.

Likewise, an unavailable authority may be observably different from an explicit
empty authority at a writer boundary. Current Correction publication, for
example, refuses when Reversal evidence is unavailable because it cannot establish
independence from reversal semantics.

Therefore the audit must preserve independently earned differences in:

```text
values
availability / refusal
unresolved / unknown state
admission
publication result
```

### Q must be physical-topology neutral

Current filesystem behavior is evidence for semantic/authority distinctions. It
is not itself the vocabulary to preserve.

Do not automatically put observations such as these into `Q`:

```text
file X exists
file X has this sibling filename
this exact path is missing
this exact error string mentions a file
```

Normalize them to the independently meaningful result when one exists:

```text
Reversal evidence unavailable
Capacity effective evidence incomplete
known-empty Scheduled retirement evidence
malformed selected authority
```

Otherwise the current physical layout would prove its own necessity and the
audit could never discover that file topology had pulled the design.

## 3. Current `Q` — first production inventory

This is an operation inventory, not a Core-type inventory. It will be refined as
remaining production readers/writers are traced.

### Actual / quantity

Current observable distinctions include at least:

- correction-aware recorded/current quantity;
- zero-origin-gated current quantity;
- `coverageMissing`;
- missing correction endpoint;
- correction frontier required / unavailable;
- dated Actual review and date-unknown records;
- human Event description/search visibility;
- correction publication;
- occurrence-date correction publication;
- Actual reversal publication;
- Movement publication admission/refusal.

### Scheduled

Current observable distinctions include at least:

- current-open Scheduled occurrences;
- completion;
- retirement/cancellation;
- replacement;
- unknown completion Scheduled endpoint;
- unknown retirement Scheduled endpoint;
- unknown replacement Scheduled endpoint;
- invalid replacement graph;
- conflicting terminal evidence;
- Scheduled creation;
- Scheduled routing publication.

The current open-world result vocabulary means that known-empty lifecycle
evidence cannot be collapsed into unavailable evidence merely because both happen
to produce no rows on one household snapshot.

### Capacity / Purpose

Current observable distinctions include at least:

- entitlement from Capacity movement;
- historical/windowed Capacity using effective evidence;
- Actual consumption by historical routing;
- Remaining as a projection;
- Scheduled Commitment partitioned into managed / unmanaged / unrouted /
  unresolved eligibility;
- Headroom as a projection;
- Capacity transfer / rebalance publication;
- Actual routing administration;
- unresolved Scheduled pressure caused by missing AccountingRole evidence.

`Consumption`, `Remaining`, `Commitment`, and `Headroom` are result vocabulary,
not automatically retained canonical state.

### Relation / Attention / reporting

Open-relation and relation-discharge evidence remain part of the explicit
scriptable Movement entrance, so their production operations stay inside `Q` even
though the current selected household images are empty.

Attention support exists in Core/Application/TUI, but the current `loam-data`
snapshot has no `attention.loam`. The production review therefore observes source
unavailability rather than selected retained Attention evidence. Attention should
not be counted as part of the **current retained household basis** merely because
the executable can consume it if configured later.

Report surfaces remain projections unless a retained distinction is separately
earned by one of their underlying questions.

### Replaceable configuration / presentation metadata

Current configuration and presentation inputs include:

- balance-view selection;
- cycle-funding selection;
- boundary presets;
- Locus catalog metadata;
- Purpose catalog metadata.

These affect current interaction or query selection, but are not thereby
historical household facts. They belong in `Q` as current inputs where relevant,
while their **past values** are retained only if some admitted operation can
observe those past values.

## 4. Retained-family audit rule

For each independently retained semantic family `f`, seek one of four results:

```text
WITNESS
  same retained basis without f
  + two richer worlds
  + some operation in Q has a different semantic result

DERIVABLE
  reconstruct f's entire Q-visible contribution from the other retained basis
  under an explicit checked law

QUERY-IRRELEVANT
  no operation in current Q can observe the distinction

UNRESOLVED
  current evidence is insufficient to remove or retain f safely
```

Existing code, files, codecs, manifests, workflows, or historical observations do
not count as indispensability witnesses by themselves.

Current real data also does not prove dispensability merely because one selected
family is empty today.

## 5. Initial semantic-family table

`WITNESS TARGET` means the current code already exposes a likely distinguishing
operation, but a minimal synthetic witness still needs to be recorded before the
audit closes that row.

| Retained meaning / policy | Current audit status | Distinguishing pressure |
| --- | --- | --- |
| Event + signed Effects | WITNESS TARGET | recorded quantity, journal, every Movement-derived projection |
| Actual validity / occurrence coordinate | WITNESS TARGET | dated review, windowed consumption/reporting, date correction |
| Event description | WITNESS TARGET | human review/search result differs while quantities agree |
| RelationUnit | WITNESS TARGET | explicit open-relation Movement operation |
| RelationDischarge | WITNESS TARGET | explicit relation-discharge Movement operation/frontier |
| Locus admission policy | WITNESS TARGET | same household facts, different Movement admission outcome |
| Event correction | WITNESS TARGET | same raw Events, different effective/current quantity |
| Actual reversal | WITNESS TARGET | reversal result and Correction independence/refusal boundary |
| Actual routing | WITNESS TARGET | same Actual facts, different Purpose consumption/history answer |
| Zero-origin coverage | **WITNESS — Observation 242** | same Event/Correction world, exact current zero vs `coverageMissing` |
| Capacity movement | WITNESS TARGET | same Actual facts, different entitlement/remaining/headroom |
| Capacity effective coordinate | **WITNESS — Observation 243** | same Capacity movement, different windowed Entitlement |
| AccountingRole classification | WITNESS TARGET | same Scheduled/routing, pressure vs non-pressure vs unresolved |
| Scheduled occurrence | WITNESS TARGET | current-open / commitment / future answer |
| Scheduled completion | WITNESS TARGET | same occurrence and Actual, open vs completed |
| Scheduled retirement | WITNESS TARGET | same occurrence, open vs retired |
| Scheduled replacement | WITNESS TARGET | same occurrences, different current replacement frontier |
| Scheduled routing | WITNESS TARGET | same Scheduled facts, different managed/unmanaged commitment |
| Attention item / closure | **NOT CURRENTLY RETAINED** | current production source is unavailable in `loam-data` |
| presentation/config metadata | NOT COUNTED AS HOUSEHOLD FACT YET | current query/UI input; historical retention still unearned |

This is not a claim that every listed row deserves an independent physical file,
manifest member, writer, or package.

## 6. First closed global witnesses

### Observation 242 — ZeroOriginCoverage

Two worlds retain identical empty Event and Correction evidence and differ only in
whether `cash/jpy` has explicit zero-origin coverage.

```text
covered   -> current 0
uncovered -> coverageMissing
```

Therefore coverage remains independently Q-observable. This earns **KEEP
MEANING**, not the current coverage filename or wire shape.

### Observation 243 — Capacity effective coordinate

Two worlds retain one identical Capacity movement and differ only in its effective
coordinate. One effective coordinate falls inside `[0, 2)`, the other outside.

```text
inside  -> Entitlement 100
outside -> Entitlement 0
```

Therefore effective-time evidence remains independently Q-observable. This earns
**KEEP MEANING**, not a separate `.effective` companion file.

Both witnesses use current production types and projections rather than inventing
a parallel audit ontology.

## 7. Derived vocabulary already showing the desired compression shape

Several useful household nouns are already intentionally absent from retained
state:

```text
Consumption
Remaining
Commitment
Headroom
report sections
current-open views
```

Their existence demonstrates the desired direction:

```text
small retained evidence
        ↓
strong query-specific projection
        ↓
rich household answer
```

The global audit asks whether the same treatment can be pushed further into the
currently retained basis itself.

## 8. Semantic basis and physical topology are separate search spaces

The audit must not let current filenames answer semantic questions.

Use three explicit layers:

```text
A. retained meaning
   independently observable fact / policy distinctions

B. authority state
   which retained meanings are available, known empty, unavailable, malformed,
   or selected together atomically

C. physical topology
   files, directories, manifests, sections, object blobs, commit points
```

The mapping is not one-to-one:

```text
many semantic families may share one physical image
one semantic family may use more than one physical artifact for safety
known-empty evidence is not the same as a missing file
same record shape is not the same semantic authority
```

### Physical-topology hypothesis to test

A current file boundary is earned only if removing or moving that boundary loses
an observable safety/operational property after semantic meaning and authority
state are held fixed.

Candidate properties include:

- atomic publication;
- crash-prefix closure;
- unavailable vs explicit-empty distinction;
- stale-writer rejection;
- independent update lifecycle;
- corruption/failure blast radius;
- reconstruction/migration ability;
- human-operable recovery.

If a physical boundary cannot produce such a witness, it is representation
pressure rather than semantic authority.

Conversely, reducing the file count is not valid if the reduction silently merges
one of those observable properties.

A historical physical split may have acquired types, codecs, publishers, tests,
and vocabulary that look semantic only because the file existed. The audit must
test that possibility rather than assume it.

## 9. First concrete topology pressure

Observation 241 establishes only the factorization needed for this phase:

```text
known-empty Reversal authority != unavailable Reversal authority
```

for the selected Correction-like operation, while a representative physical
container change is invisible when decoded authority state is preserved.

Production tracing then found stronger concrete pressure:

- `CorrectionPublisher` derives `actual-reversals.loam` from the Correction
  filename instead of receiving a topology-neutral Reversal authority;
- Capacity derives `.effective` from the Capacity filename;
- Capacity movement and effective evidence already share one writer-ownership
  domain and a dependent-evidence-before-activation publication order;
- file/path assumptions are visible in review and TUI wiring above persistence;
- physical absence has different meanings across families and even across
  operations.

The detailed census is in
`docs/research/PHYSICAL_TOPOLOGY_PRESSURE_2026-09-10.md`.

## 10. Next formal steps

### Step A — continue semantic witnesses without duplicating old research

Prefer reusing existing qualified observations when they already provide the exact
global collision. Add a new small proof only where the combined current basis
needs a new witness.

Next high-leverage rows:

1. AccountingRole fallback for Scheduled pressure;
2. Scheduled terminal evidence as one combined lifecycle witness set;
3. ActualRouting versus derived Consumption;
4. LocusAdmission as a write-vocabulary witness;
5. ActualReversal semantics separately from its current file representation.

### Step B — authority-state factorization

Continue separating:

```text
family meaning
family availability / explicit emptiness
physical container presence
```

The missing-file census already shows that `pathExists` cannot serve as one
universal semantic bottom value.

### Step C — physical-topology invariance

After enough semantic rows close, model mappings from semantic families/atomic
groups to physical containers. A topology change is representation-only when
every topology-neutral `Q` result and required publication/failure property is
invariant under that mapping.

### Step D — real-data shadow

Against one exact `loam-data` snapshot, materialize candidate semantic bases and
physical layouts in scratch only. Compare the complete selected semantic-result
vector. Real-data equality supplements, but never replaces, synthetic
counterexample pressure.

## 11. Stop rule

Do not optimize this directly:

```text
number of files
number of types
number of modules
```

Optimize this:

```text
number of independent distinctions that must be retained
+ number of independent safety laws required to publish them correctly
```

Then let the file structure fall out of those answers.

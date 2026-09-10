# Canonical basis re-minimization — Phase 1

Status: **working checkpoint, no canonical-data mutation authorized**

Baseline main: `9d11b5413bc353d1e596aa7e839ee281cd28e613`

Tracking issue: #693

## 1. Question

Re-run the early LOAM minimization discipline against the current operational
system:

> What is the smallest independently retained household information from which
> every currently admitted observable operation can still produce the same
> result?

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
observableResult(q, x, h1) = observableResult(q, x, h2)
```

This matters because some retained information changes whether a future write is
admitted even when no current read value changes. `LocusAdmission` is the clearest
example.

Likewise, a missing authority may be observably different from an explicit empty
authority at a writer boundary. Current Correction publication treats missing
Actual Reversal authority as unavailable, not as an empty reversal relation.

Therefore the audit must preserve all currently observable:

```text
value differences
availability / refusal differences
unresolved / unknown differences
admission differences
publication result differences
```

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

Production code still contains observable relation-frontier and discharge
operations and Attention/report surfaces. These must be traced to their selected
operational authorities before the retained-family table is considered complete.

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
  + some operation in Q has a different observable result

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

This table is intentionally preliminary. `WITNESS TARGET` means the current code
already exposes a likely distinguishing operation, but a minimal synthetic witness
still needs to be recorded before the audit closes that row.

| Retained meaning / policy | Initial status | Distinguishing pressure to formalize |
| --- | --- | --- |
| Event + signed Effects | WITNESS TARGET | recorded quantity, journal, every Movement-derived projection |
| Actual validity / occurrence coordinate | WITNESS TARGET | dated review, windowed consumption/reporting, date correction |
| Event description | WITNESS TARGET | human review/search result differs while quantities agree |
| RelationUnit | WITNESS TARGET | open relation operation if production surface remains admitted |
| RelationDischarge | WITNESS TARGET | discharge/open-frontier answer if production surface remains admitted |
| Locus admission policy | WITNESS TARGET | same household facts, different Movement admission outcome |
| Event correction | WITNESS TARGET | same raw Events, different effective/current quantity |
| Actual reversal | WITNESS TARGET | reversal result and Correction independence/refusal boundary |
| Actual routing | WITNESS TARGET | same Actual facts, different Purpose consumption/history answer |
| Zero-origin coverage | WITNESS TARGET | same Event history, `current q` vs `coverageMissing` |
| Capacity movement | WITNESS TARGET | same Actual facts, different entitlement/remaining/headroom |
| Capacity effective coordinate | WITNESS TARGET | same Capacity movements, different windowed answer |
| AccountingRole classification | WITNESS TARGET | same Scheduled/routing, pressure vs non-pressure vs unresolved |
| Scheduled occurrence | WITNESS TARGET | current-open / commitment / future answer |
| Scheduled completion | WITNESS TARGET | same occurrence and Actual, open vs completed |
| Scheduled retirement | WITNESS TARGET | same occurrence, open vs retired |
| Scheduled replacement | WITNESS TARGET | same occurrences, different current replacement frontier |
| Scheduled routing | WITNESS TARGET | same Scheduled facts, different managed/unmanaged commitment |
| Attention item / closure | UNRESOLVED | confirm current selected production authority and admitted operations |
| presentation/config metadata | NOT COUNTED AS HOUSEHOLD FACT YET | current query/UI input; historical retention still unearned |

This is not a claim that every listed row deserves an independent physical file,
manifest member, writer, or package.

## 6. Derived vocabulary already showing the desired compression shape

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

## 7. Semantic basis and physical topology are separate search spaces

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

### Physical-topology hypothesis to test later

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

This is the point where file topology may be found to have pulled the design: a
historical physical split may have acquired types, codecs, publishers, tests, and
vocabulary that look semantic only because the file existed. The audit must test
that possibility rather than assume it.

## 8. First concrete boundary: Actual Reversal empty authority

The current household `actual-reversals.loam` is explicitly empty.

That does **not** make Actual Reversal semantics dispensable. Current Correction
publication intentionally distinguishes:

```text
explicit complete empty reversal authority
    -> Correction may prove there is no reversal conflict

missing reversal authority
    -> Correction refuses: independence cannot be proved
```

So the immediate question is not:

> Can we delete the empty file?

It is:

> What is the minimum retained/authority state needed to preserve the distinction
> between known-empty Reversal evidence and unavailable Reversal evidence, and
> does that distinction require its own physical file?

This is the model for later topology work: preserve meaning first, then challenge
the file.

## 9. Next formal steps

### Step A — minimal semantic witnesses

Start with small bounded worlds for high-leverage rows:

1. ZeroOriginCoverage;
2. Actual Reversal availability;
3. Capacity effective evidence;
4. Scheduled terminal evidence;
5. AccountingRole fallback for Scheduled pressure.

For each row, ask Alloy for a collision after erasure/quotienting.

### Step B — authority-state factorization

Separate:

```text
family meaning
family availability / explicit emptiness
physical container presence
```

Search for counterexamples to any representation that identifies two currently
observable authority states.

### Step C — physical-topology invariance

Only after A and B, model a mapping from semantic families/atomic groups to
physical containers. A topology change is representation-only when every `Q`
answer and required publication/failure property is invariant under that mapping.

### Step D — real-data shadow

Against one exact `loam-data` snapshot, materialize candidate semantic bases and
physical layouts in scratch only. Compare the complete selected observable-result
vector. Real-data equality supplements, but never replaces, the bounded synthetic
counterexample search.

## 10. Stop rule

Do not optimize this:

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

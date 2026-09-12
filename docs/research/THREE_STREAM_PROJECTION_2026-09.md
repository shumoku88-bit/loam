# Three-stream projection experiment — 2026-09

Status: **read-only representation experiment**

This experiment asks a deliberately narrow question:

> Can the currently selected LOAM household evidence be represented as three
> physical streams without deleting an independently observable distinction?

It does **not** propose a new production persistence format and it does not
change canonical household authority.

## Why this experiment exists

HRA-N demonstrates that a small physical authority topology and strong retained
semantics are compatible. Its logical authority is three streams while keeping
correction, reversal, Scheduled lifecycle, versioned policy, Capacity history,
routing, relations, Attention, fail-closed admission, and atomic generation
publication.

LOAM currently maps more semantic families directly onto persistence families.
The data-shape audit already found pressure around that topology: selected
Movement families, root sidecars, and historical content-addressed objects are
not automatically the same thing as independently observable household facts.

The first safe test is therefore not to redesign codecs. It is to remove file
boundaries while preserving selected bytes exactly.

## Experimental projection

`tools/three-stream-projection.py` reads the **CURRENT-selected** Movement world
and current root-side evidence and emits exactly three files:

```text
actual.stream
policy.stream
scheduled.stream
```

The mapping is currently:

```text
actual.stream
  selected Event
  selected ActualValidity
  selected EventDescription
  selected RelationUnit
  selected RelationDischarge
  selected LocusAdmission
  actual-reversals.loam, when present

policy.stream
  accounting-role.loam, when present
  zero-origin-coverage.loam, when present
  actual-routing.loam, when present
  capacity.loam, when present
  capacity.loam.effective, when present
  scheduled-routing.loam, when present

scheduled.stream
  scheduled.loam, when present
```

`scheduled-routing.loam` remains independent **meaning** even though this
experiment places it in the physical policy stream. LOAM CurrentCoverage needs
that evidence to distinguish remaining Capacity from future managed Scheduled
commitment and Headroom. The experiment must never infer it from Scheduled
Locus names or Actual routing.

Likewise AccountingRole, ActualRouting, Capacity effective dates, zero-origin
coverage, and reversal evidence remain distinct facts. Three streams means three
physical containers, not three semantic concepts.

## What is deliberately outside the three streams

`config/` is passed through only when an observation comparison needs it. In
particular `balance-view.tsv`, `cycle-funding.tsv`, boundary presets, and UI
catalogs are not silently promoted to household fact merely because a current
query consumes them.

The projection also does not copy old unselected Movement objects or recovery
manifests. Git already retains committed history; the experiment is about the
currently selected household state.

## Wire framing

Each stream uses a temporary length-delimited framing:

```text
LOAM-THREE-STREAM<TAB>1
SECTION<TAB>NAME<TAB>BYTE_LENGTH<TAB>SHA256
<exact original bytes>
```

The framing exists only to make the experiment unambiguous and reversible.
Section payloads are not normalized or reparsed. `unpack` verifies the SHA-256,
reconstructs a minimal Movement object store plus `CURRENT`, and restores current
side files.

This deliberately proves less than a final compact codec. It proves that the
current persistence **boundaries** are not required to preserve the selected
bytes.

## Checks

Three levels are kept separate.

### 1. Exact selected-byte round trip

```sh
python3 tools/three-stream-projection.py check DATA_ROOT WORK_DIR
```

This compares SHA-256 fingerprints for every selected semantic section before
and after:

```text
current LOAM layout
  -> three streams
  -> minimal current LOAM layout
```

No old unselected content-addressed object is required for the round trip.

### 2. Shared HOBS1 observation parity

The Practical Budget Window CI fixture packs and rehydrates its data, then runs
`loamHouseholdObservation` against both layouts. The HOBS1 documents must be
byte-for-byte equal.

That covers the currently shared differential surface:

- Balance;
- explicit Budget/Envelope window;
- Capacity entitlement.

A mismatch is a hard failure for this experiment.

### 3. LOAM-specific dogfood parity

Against the real household data, run the existing read-only
`Loam/Tests/CycleBudgetDogfood.lean` before and after the projection.

That checkpoint exercises distinctions not yet covered by HOBS1, including:

- explicit Cycle Funding backing;
- CurrentCoverage;
- Scheduled commitment;
- ScheduledRouting;
- unresolved future pressure;
- current physical balances.

The experiment should not claim semantic compression beyond the observations
actually compared.

## What success means

Success means:

1. selected current evidence can be reduced to three physical containers;
2. the old current layout can be reconstructed without old object generations;
3. HOBS1 observations are unchanged;
4. LOAM-specific CurrentCoverage dogfood remains unchanged on real data.

It does **not** yet mean that Event, ActualValidity, and EventDescription should
be encoded on one line. That is the next experiment. This phase only removes
unearned physical boundaries.

## Next compression question

If this projection remains green, the next experiment should replace the
byte-preserving sections with a semantic compact codec, beginning with the
strongest candidate:

```text
Event + base occurrence date + description
  -> one Actual transaction record

later correction
  -> sparse replacement fact
```

The acceptance rule should be observational equivalence rather than structural
identity:

```text
Obs(current LOAM) = Obs(compact LOAM)
```

Counterexamples that distinguish the two states are reasons to keep a fact, not
reasons to keep the old file topology.

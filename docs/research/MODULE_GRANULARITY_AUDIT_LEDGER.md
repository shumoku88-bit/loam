# Module Granularity Audit Ledger

Checkpoint base: `cc53d11cde8a1d5a43c96e79e076fb69093d6201`

Status: **FIRST INVENTORY RUN COMPLETE — implementation changes remain separate**

## Inventory result

The focused CI inventory completed successfully on PR #957.

```text
Lean modules: 331
Modules <= 80 lines: 87
Modules with exactly one local consumer: 50
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 1
  unreachable: Loam.Sha256
Recent commit change sets observed: 181
```

The important result is not that LOAM has 87 small modules or 50 one-consumer
modules. Those are candidate selectors only. The first reachability pass found
exactly one production-like Lean module outside every declared library/executable
import path.

## MGA-001 — `Loam.Sha256`

Classification: **RETIRE_CANDIDATE**

Evidence:

- dependency inventory: `fan_in = 0`, `fan_out = 0`;
- production-root reachability: unreachable from every one of the 17 declared
  Lake library/executable roots;
- current repository code search for `Loam.Sha256` finds only the module itself;
- the module comment says it exists for the historical-admission prepare/verify
  boundary;
- its introduction was PR #308, which added `HistoricalPrepare` / historical
  candidate qualification using this SHA-256 implementation;
- current code search for `HistoricalPrepare` finds no production Lean caller.

Interpretation:

This is not a file-granularity merge candidate. It is stronger: a formerly real
mechanical dependency appears to have outlived the production boundary that
needed it.

Stop point:

Do **not** delete it in PR #957. A separate narrow retirement PR should prove:

1. no workflow/tool/source path still names `Loam.Sha256`;
2. deleting the file preserves `lake build` and relevant qualification;
3. no historical experiment is being treated as a production dependency merely
   because its documentation still mentions the old boundary.

## MGA-002 — `Loam.Persistence.ScheduledPersistence`

Classification: **KEEP_BOUNDARY**

Candidate signal:

- exactly one local consumer:
  `Loam.Persistence.ScheduledLifecyclePersistence`;
- 107 lines;
- current source explicitly says the standalone Scheduled stream was retired as
  an authority boundary and this module now supplies only the typed inner codec
  embedded in the complete lifecycle image.

Why the boundary still earns its keep:

- it owns one coherent pure responsibility: encode/decode of
  `ScheduledMemory String`;
- the lifecycle module separately owns the complete multi-section envelope,
  terminal projection, staging, rename, and authority-file I/O;
- after the complete lifecycle cutover in PR #533, the child codec received a
  later independent dependency-narrowing change in PR #680.

That is concrete evidence of a separate change reason after the old standalone
authority disappeared. A single consumer is therefore not sufficient evidence
for collapse.

## MGA-003 — `Loam.CycleFundingConfig`

Classification: **KEEP_BOUNDARY**

Candidate signal:

- 29 lines;
- exactly one local consumer: `Loam.CycleBudgetReview`.

Why the boundary still earns its keep:

- it owns replaceable config parsing/load policy, including the current JPY-only
  admission rule and missing-file behavior;
- `CycleBudgetReview` owns query orchestration, Actual ownership, balance evidence,
  coverage, and funding composition;
- the config module was introduced with the Cycle Budget surface, while later
  Cycle Budget observation/refactoring changes occurred in the consumer without
  requiring this config module to change.

The split is small but corresponds to an independently stable policy/representation
boundary rather than an arbitrary intermediate step.

## MGA-004 — small shared controls

Classification: **KEEP_BOUNDARY**

The following intentionally remain false-positive controls for size-based
heuristics:

- `Loam.Core.Purpose`;
- `Loam.FreshNumberedToken`;
- `Loam.ScheduledActualOwnership`;
- `Loam.SparseEffectIdentity`.

Each is small, but each has multiple independent production consumers or owns a
shared law/order that would otherwise be duplicated or hidden inside one caller.

## MGA-005 — `Loam.Tui.CompletionPrompt`

Classification: **KEEP_BOUNDARY (for now)**

Candidate signal:

- 25 lines;
- exactly one local consumer: `Loam.Tui.Cli`.

Counter-evidence:

- PR #622 deliberately moved completion recognition under `Tui/`, making the
  presentation-local ownership explicit;
- the module is a small pure recognition projection over Event memory;
- the sole consumer `Tui.Cli` is already a very large orchestration module, so
  collapsing a coherent helper into it would reduce file count while increasing
  local navigation density.

This case should be revisited only if a broader TUI decomposition changes the
consumer topology.

## First-pass verdict

The new lens is already useful, but the first data does **not** support a general
"LOAM is split into too many tiny files" conclusion.

The strongest machine signals split into two very different classes:

```text
small / one-consumer + independent responsibility  -> KEEP_BOUNDARY
unreachable + historical caller retired            -> RETIRE_CANDIDATE
```

The first concrete subtraction exposed by this audit is therefore not a merge.
It is the likely retirement of `Loam.Sha256`.

## Next pass

Continue with candidate discovery in this order:

1. root production helpers with one consumer or zero incoming edges;
2. CLI executable roots, separating required executable boundaries from obsolete
   command surfaces;
3. TUI `Foo` / `FooSession` pairs, using pure-state vs effect-session separation
   as an explicit KEEP criterion;
4. only then inspect larger modules for the opposite problem: files that may be
   too coarse and own multiple independent reasons to change.

Add `RETIRE_CANDIDATE` to the audit vocabulary alongside:

```text
KEEP_BOUNDARY
COLLAPSE_CANDIDATE
RETIRE_CANDIDATE
MOVE_LAYER_CANDIDATE
SPLIT_CANDIDATE
NEEDS_DRAKON
NEEDS_HISTORY
```

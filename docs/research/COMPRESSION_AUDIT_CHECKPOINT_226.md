# Compression audit checkpoint at Observation 226

Status: **AUDIT BASELINE — OPEN**

Repository baseline: `18386a843612874c6258aeb9251835c4cc7f2a30`

This checkpoint freezes the compression concerns identified before further architectural expansion. It is not a conclusion that LOAM has failed to remain coherent, nor a defense that the current production implementation is already small. Its purpose is to make both claims falsifiable.

## Why this audit exists

LOAM's design philosophy aims for minimal canonical evidence, semantic clarity, reconstructability, strong checking laws, human-operable simplicity, and increasingly fewer pieces with stronger relationships.

Recent review exposed two distinct forms of compression debt.

First, research generation has outrun integrated synthesis. Numbered observations have reached Observation 226 while the root `OBSERVATION_MAP.md` remains detailed only through Observation 084. Local observations can remain individually disciplined while their accumulated result becomes difficult to survey, absorb, retire, or falsify as a whole.

Second, excluding tests and historical Lean observation proofs does not make the production implementation obviously small. A recent line/file inventory reported approximately:

| Surface | Lines | Files |
| --- | ---: | ---: |
| Core | 4,171 | 38 |
| Application | 2,876 | 20 |
| Persistence | 2,290 | 19 |
| top-level / publisher write paths | 5,246 | 32 |
| CLI | 5,978 | 24 |
| TUI | 4,753 | 23 |
| Core + Application + Persistence + write paths | ~14,600 | 109 |
| full practical runtime including CLI/TUI | ~25,300 | 156 |

These counts are an audit input, not yet a repository-owned reproduced measurement. The audit must independently reproduce or correct them before using them as a metric.

The important distinction is therefore:

```text
small semantic information basis
    does not imply
small production implementation surface
```

LOAM may still have a compact semantic basis while carrying accidental implementation, authority, persistence, writer, or historical complexity around it. That is now an open question rather than an assumed success.

## What current evidence already says

### 1. Historical proof volume is not the whole explanation

The practical runtime itself is materially larger than the historical `Loam.Observations` proof archive. Any defense of compactness must therefore inspect production-reachable code rather than subtracting tests and observations and stopping there.

### 2. File count is not concept count

A module split can be representational only. Thirty modules do not prove thirty independent semantic primitives. Conversely, a single file can hide several independent mechanisms. The audit must count semantic obligations and independently retained facts, not merely files.

### 3. Local design discipline can coexist with global accumulation

The current repository contains many individually narrow boundaries: Core memories, frontiers, inspections, persistence codecs, publishers, CLI adapters, and TUI presentation modules. Many are well motivated in isolation. The audit question is whether the same laws and mechanics are being paid for repeatedly under different names.

### 4. Deletion does happen, but integration lags

Recent work has retired obsolete migration runtimes, compatibility paths, private observers, and starting-balance machinery. Therefore the problem is not an absence of deletion culture. The concern is that local retirement and replacement have not yet produced a comprehensively compressed production and research map.

### 5. TUI duplication is not currently the primary suspicion

The production TUI intentionally delegates canonical reads and writes to shared boundaries and publishers rather than implementing a second semantic engine. TUI size may still contain presentation duplication, but the first audit target is the production semantic/write/persistence closure beneath it.

## Audit hypotheses

The audit should try to falsify all of these, rather than protect any one of them.

### H1 — compact semantic basis, inflated implementation

LOAM retains only a small number of independently observable household facts, but implements them through too many specialized histories, frontiers, codecs, publishers, and adapters.

### H2 — semantic basis itself has grown

Some concepts currently presented as necessary independent evidence no longer earn independent status after later observations and production cutovers.

### H3 — dead production surface remains after semantic retirement

Concepts removed from current practical entry points may still leave reachable or buildable application, persistence, CLI, executable, or workflow surfaces. `QuantityBasis` is a concrete audit candidate because zero-origin work has already displaced part of its former production role while related modules remain in the repository.

### H4 — safety laws are encoded repeatedly rather than factored

Writer ownership, fail-closed loading, atomic replacement, correction/replacement frontier behavior, identity admission, and current-world re-read rules may be repeated across domain-specific publishers. Some repetition may be semantically necessary; some may be mechanical duplication.

### H5 — research/CI history is retained as active machinery longer than necessary

An observation can remain valuable historical evidence without keeping a dedicated workflow or active build path forever. The current one-observation/one-workflow tendency may be preserving verification history as operational surface.

## Audit order

Do not begin by deleting files or inventing a generic framework. Proceed in this order.

### Phase 1 — reproduce the production surface

Build a repository-owned inventory of production-reachable Lean modules and executable targets. Separate:

- Core
- Application
- persistence
- publishers / writer ownership / authority publication
- CLI
- TUI
- tests
- historical observation proofs
- research-only formal models and tools

Record lines, files, direct imports, executable roots, and whether each module is reachable from a current production entrance.

**Exit condition:** the ~25.3k / 156-file claim is reproduced, corrected, and made mechanically repeatable.

### Phase 2 — inventory independently retained meaning

For every production semantic unit, classify it as one of:

- primitive retained fact
- authority / memory of retained facts
- pure projection
- generic mechanical law
- writer protocol
- persistence representation
- UI-local state
- compatibility / migration / historical residue

For every primitive or authority, answer:

1. Which household answer becomes impossible without it?
2. Can later evidence reconstruct it?
3. Does removing it merge meanings that remain independently observable?
4. Is the distinction semantic, or only an implementation convenience?

**Exit condition:** a finite current semantic basis can be stated without referring to file names.

### Phase 3 — audit mechanics multiplication

Group same-shaped mechanisms across domains, especially:

- replacement / correction histories and frontiers
- current/effective selection
- identity admission
- complete-image persistence
- fail-closed decode/load
- stage-and-rename publication
- writer ownership
- current-world re-read before publication
- relation-first or other cross-authority publication laws

For each family choose one result:

- genuinely shared mechanics and safe to factor
- intentionally duplicated because semantic authority differs
- obsolete duplicate to retire
- unresolved, requiring one focused observation

Do not generalize merely because two types look alike.

**Exit condition:** every repeated mechanism has an explicit reason to remain repeated or a concrete compression change.

### Phase 4 — retire dead production surface

Start with already-qualified or already-displaced concepts. Audit candidates include old QuantityBasis-era paths, completed migration/cutover helpers, obsolete low-level CLI entrances, superseded Scheduled sidecar paths after the lifecycle authority cut, and any executable target no longer used by household operation or qualification.

Deletion is preferred over compatibility shims when current household meaning is preserved.

**Exit condition:** production-reachable code contains no known implementation whose only justification is historical LOAM shape.

### Phase 5 — compress research and CI history

Classify Observation 085–226, and then earlier observations as needed, into:

- `LIVE LAW` — still carries a distinct current constraint
- `ABSORBED` — result is embodied by a later law, test, type, or production boundary
- `HISTORICAL EVIDENCE` — useful record, not active qualification machinery
- `RETIRED` — superseded or falsified
- `OPEN` — unresolved question

Update the integrated observation map to the current frontier.

Then determine whether dedicated formal-model workflows must remain individually active. Prefer a small number of shared qualification lanes when that preserves the distinct checks.

**Exit condition:** the project has a current map from surviving laws to active checks, with historical evidence distinguishable from active machinery.

### Phase 6 — compare before/after complexity

After the above work, report at least:

- production LOC and file count
- number of production-reachable modules
- number of retained semantic primitives
- number of independently persisted authorities
- number of writer protocols
- number of executable targets
- number of active CI workflows
- number of observations classified LIVE LAW / ABSORBED / HISTORICAL / RETIRED / OPEN

A successful audit does **not** require an arbitrary LOC target. It requires explaining why each surviving independent piece earns its cost.

## Guardrails

During this audit:

- do not compress semantic distinctions merely to improve metrics;
- do not introduce a generic history/publisher/framework unless at least two real current domains demonstrate identical mechanics and preserved independent authority;
- do not move complexity from Core into Application, Persistence, CLI, or TUI and call the result smaller;
- do not count historical proof/archive files as production complexity, but do count active historical machinery that remains on normal qualification paths;
- do not use file count or LOC as a substitute for semantic analysis;
- do use file count and LOC as smoke alarms for implementation multiplication;
- preserve fail-closed behavior, provenance, exact quantity semantics, correction/replacement meaning, and writer ownership unless a stronger qualified model replaces them.

## Current audit judgment

The defensible statement at this checkpoint is:

> LOAM may have a relatively small semantic information basis, but the repository has not yet demonstrated that this basis yields a small production implementation. The active implementation surface is large enough, relative to LOAM's own compression goals, that compactness must now be treated as an audit question rather than an established property.

This is not a request to make the code superficially shorter. The target is a stronger correspondence:

```text
few independently necessary facts
        +
few genuinely distinct mechanisms
        ->
rich household behavior
```

The audit should stop adding architectural vocabulary while that correspondence is unclear. Focused work that directly removes or clarifies existing production complexity may continue.

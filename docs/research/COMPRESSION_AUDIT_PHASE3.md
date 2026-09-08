# Compression audit Phase 3 — mechanics multiplication

Status: **IN PROGRESS — MECHANICAL SMOKE SCAN**

Phase 2 closed with this current audit basis:

```text
18 retained fact/policy families
~9 physical authority instances
134 executable-reachable practical Lean files
21,226 executable-reachable practical lines
```

Phase 3 asks why the implementation surface is much larger than the retained information basis.

This phase does **not** assume that repeated code is accidental. Different semantic authorities may legitimately need separate codecs, publication protocols, recovery behavior, or failure boundaries. Conversely, giving every fact family a narrowly named helper does not prove those mechanisms are distinct.

## Audit families

The first mechanics pass groups pressure into these questions.

### M1 — collection / identity admission

How many semantic families independently implement:

- unique stable identity;
- `List`-backed memory;
- `of... ?` admission;
- append with duplicate rejection;
- lookup by identity;
- permutation-independence laws?

Repeated proof text may be harmless local explicitness, or it may indicate a reusable finite-map/set boundary already earned by several real domains.

### M2 — text codec admission

How many persistence modules repeat:

- version header;
- token validation;
- row encode/decode;
- trailing-empty handling;
- full collection re-admission;
- malformed => `none` fail-closed behavior?

Wire syntax may need to remain domain-specific even if mechanical parsing/publication support is shared.

### M3 — stage + rename publication

How many executable-reachable persistence/authority modules create a sibling `.loam-stage`, write the complete candidate, then `IO.FS.rename` it into authority?

The law is valuable. Repetition is not automatically valuable.

### M4 — missing-storage semantics

Audit every `pathExists` / `OrEmpty?` boundary. Missing storage sometimes means:

- unavailable evidence;
- empty evidence;
- malformed/missing authority and therefore refusal.

These are semantic distinctions. A generic loader must not erase them.

### M5 — writer ownership and current-world re-read

Audit publishers for repeated implementation of:

- acquire one ownership anchor;
- re-read current authority inside ownership;
- validate a stale frontend intent against current evidence;
- prepare candidate state;
- publish relation/policy evidence in an observed order;
- commit authority;
- return a small receipt.

The sequence may admit a shared transaction-shaped skeleton while publication order and semantic admission remain domain-specific.

### M6 — fresh identity allocation

Several practical writers generate `record-N`, `replacement-N`, `correction-N`, `validity-N`, relation ids, and other identities by scanning all relevant retained namespaces.

The audit must distinguish:

- genuinely different collision domains;
- one shared opaque-id allocation mechanic specialized to different namespaces;
- compatibility-era identity logic that current manifest authority may have displaced.

### M7 — replacement / correction frontier mechanics

Event correction, Actual-validity correction, Scheduled replacement, and other revision-like domains may share directed-edge mechanics while preserving different semantic endpoints and authority.

`ReplacementFrontier` already exists for part of this pressure. Phase 3 must determine where reuse stops and domain-specific logic starts, instead of creating a larger generic history framework by reflex.

### M8 — historical routing mechanics

Actual and Scheduled routing already share `RoutingHistory` while retaining separate subject types and authorities. This is a positive control for the audit: a demonstrated example of mechanical factoring without semantic collapse.

### M9 — complete-image / multi-family authority

Movement manifest, Scheduled lifecycle, and Attention show different ways to package several meanings into one physical authority image. The audit must ask whether these differences are driven by required atomicity and recovery behavior or simply by implementation chronology.

## Mechanical smoke scan

`tools/audit-mechanics-patterns` scans only executable-reachable practical Lean modules for textual pressure indicators such as:

- `.loam-stage`;
- `IO.FS.rename`;
- `pathExists`;
- `WriterOwnership`;
- Movement selected-world load/prepare/commit calls;
- `OrEmpty?` loaders;
- `fresh...` identity helpers;
- `ReplacementFrontier`;
- `RoutingHistory`;
- `Nodup` collection laws;
- executable-reachable `*Publisher.lean` modules.

These counts are smoke alarms only. A textual match is not a duplication finding, and absence of a match is not proof of factoring.

## Decision labels

Every mechanics family that survives detailed inspection will receive exactly one label:

- `SHARE` — same mechanism can be factored while semantic authority stays explicit;
- `SEPARATE` — repetition is justified by different semantic/atomicity/recovery requirements;
- `RETIRE` — implementation mechanism belongs to obsolete or unreachable production surface;
- `OPEN` — evidence is insufficient; one focused observation/test may be warranted.

Do not add a generic abstraction merely to reduce line count. `SHARE` requires at least two current production domains with genuinely identical mechanical obligations.

## Exit rule

Phase 3 completes only when each mechanics family M1–M9 has a concrete `SHARE / SEPARATE / RETIRE / OPEN` result and any proposed sharing boundary is smaller than the mechanisms it replaces without weakening fail-closed behavior, provenance, or authority separation.

# Lean 4-aware design and runtime review

**Role:** small, maintained review card for humans and AI. Not a performance mandate,
second semantic authority, compulsory PR checklist, or new CI gate.
See [Issue #1946](https://github.com/shumoku88-bit/loam/issues/1946),
[`AGENTS.md`](../AGENTS.md), [design philosophy](../DESIGN_PHILOSOPHY.md),
and the [AI Workbench](AI_WORKBENCH.md) for current policy and available instruments.

## When to use

- During development **only** when modifying a meaningful algorithm, data
  representation, parse/load path, cache, or event/render loop.
- Roughly every two weeks **while development is active**, inspect changes since
  the most recent recorded review and 1–2 existing, relevant measurements.
  A broader sweep needs a reproducible regression or milestone.
- No mandatory profiling, fresh benchmark harness, per-PR report, scheduled
  workflow, dependency upgrade, or speculative optimization. **No findings is a
  successful outcome.** Reviews are read-only unless an implementation task is
  explicitly approved.

## Questions to answer, only where relevant

1. **Algorithm and reuse first:** Is there repeated decoding, qualification,
   sorting, linear `List.find?` within loops, whole-image reconstruction, or
   duplicated representation/authority? Can already-admitted, same-generation
   information be reused without introducing a new cache? Compare `List`,
   `Array`, and `HashMap` on the actual access pattern.
2. **Lean allocation and ownership:** Is there evidence of costly allocation,
   copying, or accidental sharing on a measured hot path? Reason about RC/FBIP
   with ownership in mind; a pure `Array` update is not automatically in-place.
   Inspect compiler IR / emitted C only if measured cost motivates it.
3. **TUI lifecycle:** Distinguish perceived response time, queued-input tail,
   idle CPU/output, startup time, memory/RSS, terminal I/O, and snapshot rebuild.
   Does state or cache outlive the admitted snapshot it represents? Specify its
   owner, invalidation, and reconstruction before proposing one.
4. **Compilation and FFI:** Consider `-O3`, LTO, PGO or C FFI only for a
   demonstrable bottleneck, and compare end-to-end cost. Lean-to-C compilation
   does not eliminate Lean allocation and call overhead.
5. **Safety and simplicity:** Preserve fail-closed admission, corrections,
   temporal/Measure distinctions, unknown-versus-zero, household generation,
   recovery, and explicit Publish. A faster path must not create a second source
   of truth or a complex invalidation protocol.

Consult existing evidence *before* running a new probe:
`docs/research/TUI_YEAR_SCROLL_2026-10-10.md`,
`docs/research/INCREMENTAL_DELTA_COST_PROBE_2026-10.md`,
`tools/benchmark-home-scroll.py`, `tools/benchmark-actual-read.py`, and
`tools/benchmark-tui-resources.py`. Use synthetic fixtures, not operational
`loam-data` or private household details. A microbenchmark, test duration,
and real TUI latency are different observations.

## Compact checkpoint (e.g. a comment on #1946)

Record the **date, base/head commit or reviewed PR range, and chosen evidence**.
For each *material* finding, note:

| File / function | Observation and evidence | Correctness / maintenance trade-off | Smallest action | Classification |
| --- | --- | --- | --- | --- |
| `path:function` | Code fact or measured workload; state uncertainty | Ownership, semantics, invalidation, tests | Remove / reuse / measure / defer | Demonstrated issue / hypothesis / acceptable trade-off / no action |

If nothing earns action, record **“no findings; no change”** with the inspected
scope. Keep one brief checkpoint in #1946 or an existing owning record; do not
create a document or PR merely because another fortnight elapsed.

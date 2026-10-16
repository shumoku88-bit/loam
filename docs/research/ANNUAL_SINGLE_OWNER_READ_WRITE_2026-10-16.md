# Native annual single-owner session: pinned Home read and CAS write

Date: 2026-10-16
Issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)
Predecessor: merged [#2052](https://github.com/shumoku88-bit/loam/pull/2052)

**This PR does not enable annual storage in production or change normal LOAM's TUI/CLI, `household.loam` or `loam-data`. The entire adapter remains marked disposable-root research.**

## What this removes from the uncertainty list

A Home read against one annual HEAD worked in #2052, but the next write could still be developed as a separate second owner if we were careless. The new `AnnualSingleOwnerSandbox` presents an explicit *one-root, one-pinned-HEAD session*:

- `open? annualRoot expectedHeadWire` requires the existing marker and **no competing `household.loam`** in the annual root. Under the HEAD writer lock, it replays the whole selected native source closure. The caller must supply the exact expected HEAD; it never infers "latest" by listing year directories or silently falls back to old source. The pin is **test-provided, not a secure monotonic freshness witness**.
- `pin.readHome? configRoot today` delegates to the same existing Home composition as #2052 with the same pinned annual native Actual + Scheduled generation. The original ordinary synthetic household serves only as a **read-only configuration and parity fixture**. This is not a second writer or a dual-authority production root.
- `pin.append? admittedDay operation changedFamilies candidateImage` invokes the *existing* native Lean `appendWithOutcome?` with the **same** `pin.selected.headWire` as its compare-and-swap expectation. The writer's cross-process HEAD lock and before/after file+parent sync barriers remain unchanged. On macOS/APFS the barrier requires `F_FULLFSYNC`; Linux uses `fsync`. A competing valid HEAD is refused before its publication, no branch/fork. No file in the original ordinary household is published.
- `AppendOutcome.committed` returns a new selected HEAD; reopening requires explicitly pinning that new exact HEAD. `refusedBeforeHead` and `outcomeUnknown` retain their distinct earlier meanings. Never automatically retry an `outcomeUnknown`.

## CI: real synthetic 2026–2029 continuity

Reuse exactly the prior Jan 1 installed synthetic fixture and year-source migration from #2051, and prior native Home parity from #2052. After the copied 2027 baseline and 2028 native admission:

1. Explicitly pin and read the 2028 selected HEAD. Simulate entering **2029-01-01 without an operation**; no 2029 directory, no new HEAD or modified Actual/Scheduled balances.
2. Admit the first 2029 LocusAdmission operation through `Pinned.append?` and check the new same-authority `journal/2029/2.full.loam`, fully synchronized HEAD and reopen.
3. Read Home from the newly pinned 2029 HEAD, using exactly the same existing Home composer; verify Actual identities/currentness, Scheduled, supported/unsupported quantities, and source view remain coherent.
4. A reader and a concurrent writer holding the **old 2028 HEAD** must both refuse after the new 2029 HEAD is selected. A duplicate operation ID must refuse even after reopening. No orphan ordinal 3 from the rejected stale attempt.
5. A root with both annual HEAD and a competing `household.loam` is refused for opening and append. An externally expected newer HEAD refuses a complete, valid-but-old HEAD. Reinstating the original selected HEAD should permit a read again. The synthetic ordinary household and `.prev` remain byte-identical.

Use the existing Linux, macOS-15 Intel and Apple Silicon CI lanes. This tests the actual native Lean publication and Home read functions, not a new accounting implementation.

## What's still not done

- **Not a selectable production authority**, no TUI menu, no backend toggle, no auto migration or regular accounting command pipeline to this reader/writer session. We do not treat a research `LocusAdmission` change as a replacement for a complete semantic `Movement`, `Correction`, `Scheduled` or other product command.
- **No trusted HEAD freshness anchor**: a valid old HEAD together with an equally old supplied expected pin can still be selected, so the test's external expected-head comparison is not rollback protection in general.
- Product-ready native filesystem integration, real power-loss proof, historical external config versioning, explicit restore version choice, and user-controlled cutover remain separate gates.
- The disposable marker and same-root absence check are **not adversarial filesystem security**; symlink/path races and hostile roots are out of scope. No physical durability guarantees from CI SIGKILL.

**Next:** prototype an explicitly chosen, fail-closed single-authority normal-command dispatcher on **synthetic disposable roots**, with no call paths that publish to both `household.loam` and annual HEAD. Prefer a small command family at first, then continue widening only if real UI simplicity merits annual storage.

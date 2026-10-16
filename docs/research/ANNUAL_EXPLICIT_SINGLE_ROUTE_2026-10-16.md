# Explicit one-owner ordinary Movement routing rehearsal (disposable roots)

Date: 2026-10-16  
Delivery: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
Depends on merged [#2055](https://github.com/shumoku88-bit/loam/pull/2055)

**Research-only. No production source selection, household migration or TUI/CLI changes. No `loam-data` access.**

## Why the existing write engine is reused

The ordinary `HouseholdCommand.recordIdempotent` already owns Actual Movement semantics and normal household publication. #2054 introduced a native annual HEAD writer backed by precisely the same admission machinery; #2055 preserved post-HEAD uncertainty with retained Event identity. The next useful step is not a new movement parser or a second home, but a **single explicit choice at the command boundary** so a selected operation can never be sent to both physical owners.

The new `AnnualExplicitCommandSandbox` has an intentionally tiny contract:
- `Target.ordinary root`: requires an **already marked synthetic** root with an existing `household.loam` and no annual HEAD; delegates to the **existing** `HouseholdCommand.recordIdempotent`. The full ordinary `Except String IdempotentResult` is returned unchanged. A legacy IO error is **not** presented as a definite pre-commit refusal.
- `Target.annual root expectedHeadWire`: requires an already marked synthetic root with one qualified selected HEAD, no competing `household.loam`, and an exact caller-provided HEAD pin; delegates to the existing `Pinned.recordMovement?`. It returns the existing `MovementOutcome` unchanged, including the **Event ID** on uncertain post-HEAD results.
- Selection failures return `refusedSelection` **before** either writer is invoked. There is no fallback from failed annual to ordinary, no automatic detection of the most recent year, no dual write, and no implicit creation of a new source root or new annual baseline.

The explicit caller-provided admission day is used only on the annual route, not silently substituted for ordinary `MovementAdmission.Draft.validOn`. This interface is not a trusted current-clock protocol.

## CI proof by a *single* test over three independent disposable roots

The native Linux and macOS Intel/Apple Silicon CI suites reuse the ordinary Jan 1 fixture and annual journal lineage from #2051–#2055. The new `NativeAnnualExplicitCommandProbe` then creates a **second** fresh synthetic ordinary root, distinct from the original read-only parity root and the preselected annual root.

The test first routes a real balanced 60 JPY bank-to-food Movement into the second ordinary root via `HouseholdCommand.recordIdempotent`: bank 7850→7790; annual HEAD unchanged. It repeats the same operation ID with a different draft and requires `alreadyApplied` with the original Event, no second publication. Invalid ordinary Movement retains its original `Except.error` contract, not `refusedSelection`.

Then an explicit annual target (the still-unmodified HEAD from before the ordinary write) publishes a separate 55 JPY Movement via annual CAS; bank 7745→7690; annual journal gains one source object and retains the operation→Event identity. The ordinary-root bytes remain unchanged during the annual operation.

Negative cases refuse before writing: stale HEAD pin, ordinary target pointed at an annual root, annual target pointed at a legacy root, unmarked original ordinary root, and mixed ordinary+annual owner evidence inside one root. The original parity household and `.prev` remain identical to their starting bytes.

## This is NOT yet production cutover

These controls use a temporary marker and path/existence checks, so they are **not race-safe against hostile filesystem modification**. Ordinary household errors retain their native semantics rather than promising universal three-way certainty. A caller-supplied old valid HEAD could be paired with its equally stale expected pin: no authenticated monotonic source freshness is supplied. Likewise there is no qualified publication-day clock, multi-family normal command dispatch, complete migration wizard, durable restore promotion, power-cut proof, or user-facing source switch. The operational source remains `household.loam`.

The point of this PR is to close one architectural loophole without touching real data: **once explicitly selected, only one physical authority can receive a normal idempotent Movement**. It is not permission to select the annual backend for actual household data.

Next slice should make the admission-day and freshness authority decisions explicit, and test configuration/restore coordination, rather than expanding duplicated backend glue without a clear product requirement.

# Reobserving an uncertain native annual Movement without double-posting

Date: 2026-10-16  
Tracking: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
Predecessor: merged [#2054](https://github.com/shumoku88-bit/loam/pull/2054)

**Disposable synthetic journals only.** No TUI/CLI operational route change, no real `household.loam` migration or `loam-data` mutation. No claim of physical power-loss durability.

## The missing semantic distinction

PR #2047 already modeled source publication results as committed, refused-before-HEAD, or outcome-unknown, and could reread the HEAD and source chain after a post-rename fsync failure. PR #2054 then admitted a real practical Movement into that one HEAD, retaining an Actual `MovementOperationId` -> `EventId` mapping. But the Movement-specific `outcomeUnknown` variant did not retain the expected EventId, and simply seeing a HEAD with matching operation metadata is **insufficient** to confirm the correct Event identity was admitted.

## Change

- Extend `MovementOutcome.outcomeUnknown` with the already-admitted **expected EventId**. It is not a success receipt; the EventId is only a proposed identity to check on reobservation.
- Extract the **pure existing HEAD classification** into `AnnualSourceHeadSandbox.classifyUnknownSelected`. The generic `reobserveUnknown?` continues to use the same logic and retains its public statuses, no new publication protocol.
- Add `Pinned.observeMovement?` to the synthetic annual adapter. It takes the original pin, admission day, operation ID and expected EventId; it reads a complete qualified annual source, rechecks the root via the existing locked `open?` and uses the shared classifier. It returns three deliberately process-visible possibilities:
  - `priorHeadVisible` only when the original HEAD is selected and the operation ID is absent in its Actual mapping;
  - `requestedMovementVisible event` only when the requested HEAD, year, publication day and operation ID match **and** the *same native selected generation* retains the exact `MovementOperationId -> EventId` mapping and referenced Event evidence;
  - `cannotClassify reason` for mismatched/other HEAD, wrong day, wrong Event, corrupt/absent chain, competing `household.loam` owner or source-race refusal.
- Neither a visible prior nor requested HEAD is a durable commit receipt, explicit restore approval, or permission to blind retry. Historical valid-old HEAD with a matching old expected pin remains a known unresolved freshness risk.

## Real failpoint test, not just simulated uncertainty

`NativeAnnualMovementUnknownProbe.lean` runs after #2054's real Movement test in the **same existing native Lean CI fixture**. It prepares another *valid* balanced bank-to-food Movement using the same typed admission code, then installs the annual source but injects an error at the HEAD-parent synchronization **after HEAD rename**.

Checks: `AppendOutcome.outcomeUnknown`; the new visible HEAD contains the correct operation and native Event identity; prior-pin and newly selected-source retry both refuse; no ordinal-five duplicate source. An unattempted request observes the prior HEAD, a wrong expected Event/day/operation refuses, malformed HEAD refuses, an old-but-valid HEAD can only be classified as old and does NOT prove durability, and a second physical `household.loam` owner is refused. Reopening Home from the selected annual generation shows the two synthetic real Movements (75+30 JPY) reflected in exact bank balance (7850 -> **7745**); the old household and its previous file are unchanged.

This test uses the existing real Linux `fsync` and Darwin/APFS `F_FULLFSYNC` barrier adapters except for the **single explicitly injected HEAD-parent failure**. It does not test physical power interruption.

## Release blockers retained

Normal TUI command routing, real recovery UX, verified wall-clock admission dates, authenticated monotonic HEAD freshness, user-chosen version on restore and stable native filesystem adapter are still missing. An uncertain result must remain uncertain even if requested bytes were process-visible, because a later power failure or old valid HEAD substitution is outside this evidence.

Successful Linux/macOS CI only qualifies this disposable prototype and must not silently enable annual source cutover.

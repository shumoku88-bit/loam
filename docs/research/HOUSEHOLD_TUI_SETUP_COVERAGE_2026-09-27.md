# Household TUI setup coverage checkpoint — 2026-09-27

Status: **AUDIT CHECKPOINT / NO NEW SEMANTICS PROMOTED**

## Trigger

Issue #1372 exposed a production-shape question larger than one historical-support relation.

If LOAM is to remain usable when a household adds a new bank account, wallet, expense category, liability, or Measure later, ordinary setup must not require knowing canonical filenames or editing several evidence/config files by hand.

The same pressure applies to a new user adopting LOAM for the first time.

This checkpoint asks:

> Can an ordinary user extend one household from the production TUI without becoming a LOAM persistence maintainer?

The answer is currently **partly**.

LOAM already has good presentation-neutral writer boundaries for several setup actions, but some user-visible setup still depends on manual configuration or complete-image replacement semantics that are awkward for incremental adoption.

## Product rule

For an ordinary household fact or policy that users may legitimately add or change during normal use:

1. semantic admission remains owned by the existing Review/Publisher/Authority boundary;
2. a shared high-level household entrance should exist;
3. at least one normal human surface should expose the operation;
4. that surface must not require the user to know canonical filenames;
5. the surface must preview replacement/destructive scope before publication;
6. after publication, the TUI reloads canonical state rather than treating local editor state as authority.

Exceptional reconstruction, migration, repair, or one-time cutover evidence may remain operator-only when that restriction is part of its meaning.

This is an interaction requirement, not a reason to add an Account primitive or merge independent authorities.

## Current setup coverage

| User intention | Current semantic / policy owner | Shared high-level entrance | Production TUI | Current disposition |
| --- | --- | --- | --- | --- |
| Admit a new account/category identity | LocusAdmission | HouseholdCommand.admitLocus | Home `m` | **Covered** |
| Assign its first accounting role | AccountingRole | HouseholdCommand.assignInitialAccountingRole | Home `m` -> Tab | **Covered for initial assignment** |
| Give a stable Locus a friendly display label | replaceable Locus catalog | no ordinary typed household editor found | none | **Gap** |
| Route an Expense or other admitted Locus to a Purpose | ActualRouting | shared publisher / household entrance | Home `p` | **Covered** |
| Include a coordinate in ordinary balance presentation | `config/balance-view.tsv` | no normal household editor | read-only Balances only | **Gap** |
| Observe exact current quantities | CurrentQuantityAnchor | HouseholdCommand.observeCurrentQuantities | Home `o` | **Covered, but whole-image replacement is hostile to incremental setup** |
| State bounded historical completeness after a start boundary | research under #1372 | not yet promoted | none | **Must not be promoted without an ordinary TUI path** |
| Establish zero-origin historical support | ZeroOriginCoverage | reconstruction/cutover-only | none | **Acceptable as exceptional evidence** |
| Establish OpeningSupport | OpeningSupport | no ordinary production caller | none | **Keep special until an ordinary workflow earns it** |
| Add/change a Measure decimal scale | MeasurePresentationAuthority | HouseholdCommand.setMeasureScale | CLI only | **Gap for ordinary multi-currency setup** |
| Create a completely fresh household authority set | production initializer not found in this audit | none found | none found | **First-run gap; separate from #1372 but same usability principle** |

## Important CurrentQuantityAnchor finding

The current quantity TUI starts from an empty editor:

```text
Home o
  -> CurrentQuantityAnchor.initial
  -> collect assertions
  -> publish one complete image
```

The publisher then replaces `current-quantity-anchor.loam` with that complete image.

This is semantically intentional: one CurrentQuantityAnchor image is a set of quantities observed together at one shared reconciliation cut.

It creates a real incremental-adoption problem, however.

Suppose a household already has:

```text
cash / jpy
yucho / jpy
```

in the current anchor and later adopts another existing bank account.

Entering only:

```text
new-bank / jpy
```

is not an additive update. It replaces the complete image and removes the earlier anchor assertions.

Blindly preloading the old rows and carrying them forward is also not automatically sound, because those old quantities were observed at an older reconciliation cut. Presenting them as if they were re-observed together with the new account would change the evidence meaning.

Therefore the UI problem cannot be fixed merely by "merge old rows before save".

The next design question is:

> What is the smallest sound interaction for adding independently observed current quantity support later?

Candidates include:

1. explicitly re-observe every anchor-backed coordinate at the new shared cut;
2. qualify multiple retained reconciliation cuts / coordinate groups;
3. avoid CurrentQuantityAnchor for genuinely new zero-start coordinates when stronger start evidence is available;
4. another smaller representation that preserves the existing reflected-root semantics.

Do not choose among these from convenience alone.

## Historical support consequence

The proposed bounded historical support from #1372 must obey the same product rule.

If the surviving semantic fact is approximately:

```text
coordinate -> complete since start-day
```

then production promotion is incomplete unless an ordinary user can state, preview, publish, inspect, and later correct that claim without editing a `.loam` file.

The TUI wording should remain human-facing, for example:

```text
How much history do you know for this account?

- I started this account at zero in LOAM
- This existing account is complete from YYYY-MM-DD onward
- I only know the current balance
- I do not know yet
```

Those choices may map to different independent evidence families internally. The TUI must not collapse them into one generic "account setup" semantic record.

## Candidate user journey

A future maintenance/setup surface may compose existing operations without owning their semantics:

```text
Add household identity
  |
  +-- stable identity / label
  |
  +-- AccountingRole
  |
  +-- optional Purpose routing
  |
  +-- quantity-history question
  |     +-- zero from a qualified boundary
  |     +-- complete since a qualified day
  |     +-- current quantity only
  |     +-- unknown
  |
  +-- optional balance-view inclusion
  |
  +-- preview exact publications
        |
        +-- publish through existing household boundaries
        +-- reload
```

The UI may orchestrate these steps, but each durable fact keeps its own qualified authority and failure semantics.

Partial success must remain visible. A successful Locus admission must not be silently rolled back or disguised if a later optional role, routing, or presentation step is refused.

## Priority gaps

### P0 — incremental current quantity support

Before treating account addition as self-service, determine how later independently observed accounts coexist with the current complete-image anchor semantics.

This is the most important newly exposed gap because a superficially convenient editor could silently weaken evidence meaning.

### P0 — #1372 promotion must include a writer + TUI path

Do not land a new normal-use historical-support file and defer its human publication path.

Research can remain file-free. Production normal-use evidence must be operable from a standard frontend.

### P1 — balance-view administration

A newly admitted account can be valid and current yet remain absent from the ordinary Balances selection until `config/balance-view.tsv` is edited externally.

A small typed editor is enough. It must remain replaceable presentation/query policy and must not create quantity support.

### P1 — friendly Locus labels

Locus admission deliberately creates only a stable token. That semantic separation is good, but an ordinary user should not need to edit `config/locus-catalog.tsv` to give a new identity a readable label.

### P1 — Measure scale administration

The presentation-neutral write boundary already exists:

```text
HouseholdCommand.setMeasureScale
```

but the ordinary human path is currently CLI-only. Adding a currency from the TUI should reuse this boundary rather than inventing currency semantics in presentation code.

### P2 — first-run household bootstrap

Repository search in this checkpoint found test-only world initialization but no normal production household initializer.

This does not block existing dogfood, but it is a separate requirement before "download LOAM and start from zero" is a realistic product path.

## Non-goals

This checkpoint does not authorize:

- an Account Core primitive;
- a generic Setup authority;
- one giant account record containing role, routing, support, and presentation;
- automatic inference of AccountingRole from names or signs;
- automatic historical completeness from endpoint equality;
- merging old CurrentQuantityAnchor rows across different observation cuts;
- weakening ZeroOriginCoverage;
- a new TLA+ model;
- production persistence for #1372 yet.

## Next implementation order

1. Keep #1372 research semantics separate from UI convenience.
2. Resolve the incremental CurrentQuantityAnchor question first, because new-account onboarding depends on it.
3. Promote bounded historical support only together with its household writer and TUI administration path.
4. Add the small replaceable balance-view editor.
5. Add friendly Locus-label administration.
6. Expose existing Measure-scale administration in the TUI.
7. Treat first-run household bootstrap as its own later slice.

The desired end state is simple:

> A user may understand "account", "category", "current balance", and "history from this date" without understanding LOAM's file topology, while LOAM continues to retain those meanings as separate explicit evidence.

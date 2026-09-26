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
| Observe exact current quantities | CurrentQuantityAnchor | HouseholdCommand.observeCurrentQuantities | Home `o` | **Covered incrementally by anonymous reconciliation groups (#1386/#1389)** |
| State bounded historical completeness after a start boundary | research under #1372 | not yet promoted | none | **Must not be promoted without an ordinary TUI path** |
| Establish zero-origin historical support | ZeroOriginCoverage | reconstruction/cutover-only | none | **Acceptable as exceptional evidence** |
| Establish OpeningSupport | OpeningSupport | no ordinary production caller | none | **Keep special until an ordinary workflow earns it** |
| Add/change a Measure decimal scale | MeasurePresentationAuthority | HouseholdCommand.setMeasureScale | CLI only | **Gap for ordinary multi-currency setup** |
| Create a completely fresh household authority set | production initializer not found in this audit | none found | none found | **First-run gap; separate from #1372 but same usability principle** |

## CurrentQuantityAnchor follow-up — incremental gap qualified

PR #1386 extended Observation 246 and qualified the missing interaction law.

The current quantity TUI still starts from an empty local editor, but that editor now means **only the quantities observed together now**:

```text
Home o
  -> CurrentQuantityAnchor.initial
  -> collect this observation group
  -> publish one fresh reconciliation group
```

The publisher owns composition with retained support. A canonical image may contain several anonymous groups:

```text
older group
  cash / jpy
  yucho / jpy
  cut A

later group
  new-bank / jpy
  cut B
```

Entering only `new-bank / jpy` therefore preserves `cash / jpy` and `yucho / jpy` under their prior cut. It does not pretend that those older values were re-observed at the newer boundary.

If one coordinate is explicitly re-observed, only that coordinate moves to the fresh group. One coordinate cannot belong to two live groups simultaneously.

The semantic minimum remains approximately:

```text
coordinate -> (asserted current quantity, reflected-root cut)
```

Anonymous groups only factor coordinates that genuinely share one cut. They do not create stable anchor identity, chronology, or historical observation provenance.

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

### Graduated — incremental current quantity support

Observation 246's follow-up / PR #1386 qualified anonymous reconciliation groups, and PR #1389 promotes that shape into production persistence, publication, and TUI wording.

The remaining onboarding gaps no longer require re-observing every previously anchored account merely to add one later account.

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

1. Keep #1372 historical-support semantics separate from current-support UI convenience.
2. Promote bounded historical support only together with its household writer and TUI administration path.
3. Add the small replaceable balance-view editor.
4. Add friendly Locus-label administration.
5. Expose existing Measure-scale administration in the TUI.
6. Treat first-run household bootstrap as its own later slice.

The desired end state is simple:

> A user may understand "account", "category", "current balance", and "history from this date" without understanding LOAM's file topology, while LOAM continues to retain those meanings as separate explicit evidence.

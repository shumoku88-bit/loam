# Start or resume a household (first small continuity slice)

This documents the **fresh-household CLI** introduced for [#2020](https://github.com/shumoku88-bit/loam/issues/2020).
It is not a claim that the full ordinary TUI restart journey is complete.

## Data lost or genuinely starting from scratch

Only when you deliberately choose a **new directory that does not exist yet**:

```sh
./tools/loam init /path/to/new-household
./tools/loam doctor /path/to/new-household
./tools/loam tui /path/to/new-household
```

- `init` creates an independent, qualified HouseholdImage with all thirteen known structural sections explicitly empty.
- A destination that already exists, even if empty or malformed, is refused. No `--force`, deletion, copying over old data, automatic restore, or silent fallback to a parent household.
- No old transactions, bank balances, outstanding plans, historical completeness, zero-origin claims, or Daily Pace values are invented. Unknown is not zero.
- The normal TUI can then admit accounts/categories (Loci), assign roles, observe **today's** real balances, create future Scheduled items, and record new purchases. Configuration of visible balances, the Daily Pace pool, and cycle boundaries is still a separate step, with some existing manual setup gaps.
- The guarded startup TUI selector is now available. Friendly labels, full TUI-led account/plan/reopen acceptance and current-forward Daily Pace evidence remain to be delivered under #2020.

Do **not** point `init` at a damaged or dormant existing household. Keep its bytes for diagnosis or a separate qualified recovery attempt.

## TUI entry when the selected household will not open

`./tools/loam tui [LOAM_DATA_DIR]` keeps the existing Home entrance whenever
the selected household is readable.

If startup cannot verify the selected household **and both input/output are
interactive terminals**, it instead shows a bounded first-run screen:

1. Confirm an unused destination directory. When the selected directory is
   absent it is suggested as the destination; when the selected directory
   already exists (including malformed households), the destination starts
   **blank** and you must type a different one.
2. **Enter** reviews that independent destination. This does not write.
3. **Enter again** explicitly creates the new household using the *same*
   guarded `loam init` installer, then opens ordinary Home at that root.
   **Esc** from review goes back to editing; **Esc** while editing cancels
   without a write.

An existing destination, including an empty folder, is refused by the canonical
installer; the editor stays open with the refusal visible. A damaged selected
household is never silently restored, reset or replaced. A successful fresh root
contains unknown current balances, not asserted zero balances. Use the ordinary
Home `m` (Loci and initial roles), `o` (current observations), `s` (future
Scheduled), and `r` (ordinary Record), in whichever order makes sense.

If stdin/stdout are noninteractive, there is no prompt or implicit initialization:
use `loam init NEW_DATA_DIR` explicitly. A malformed source remains intact.

This closes only the TUI **entry** part of #2020. Friendly presentation labels,
ordinary balance/Daily Pace configuration and full acceptance of incremental
setup and hiatus recovery remain independent checks, not hidden assumptions.

## Real-terminal first-run acceptance

`tests/test_continuity_full_first_run_pty.py` is a separate isolated
**real PTY** acceptance, rather than a publisher-level synthetic fixture.
It starts `loamTui` against a nonexistent temporary root, explicitly
confirms independent creation, and uses terminal keystrokes to admit bank and
food Loci, optionally name the bank, observe a present bank balance, choose
display and Daily Pace pool, enter two known cycle boundaries, record a
purchase and add one future unpaid Scheduled occurrence. It exits and opens
the resulting household again in a **new process** to inspect the ordinary
Balances, Daily Pace and Scheduled views.

The test checks absence of writes during start/review, conservation of
canonical bytes for presentation-only config changes, Actual and Scheduled
publication only after confirmation, and no canonical mutations on read-only
reopen. The real-time dates are computed only for disposable test data; the
production UI still never infers pension payment dates or historical balances.

This test complements the existing pure-form, publisher, calendar, read-model
and corruption/hiatus checks. It does **not** claim to prove usability with a
real person's household, exact future-date recurrence, full IME composition,
or recovery of missing history. Those remain separate observations under #2020.

## Qualified daily-life restart (synthetic acceptance)

`Loam/Tests/FreshHouseholdDailyLife.lean` uses a disposable independently
initialized household and the same `HouseholdCommand` publishers as the
normal TUI: admit an asset and an expense, assign their roles, observe the
asset's present amount, add a future unpaid Scheduled item, record a purchase,
reopen Current Balances/Scheduled and next-day Home, then add another asset
after initial setup. No history, zero origin or bounded historical coverage is
fabricated. Before the observation, selecting an unknown current balance must
fail, **not** return a manufactured zero.

A current-forward Daily Pace result requires *explicit* chosen pool and cycle
configuration. The test first checks that fresh startup cannot invent this,
then provides disposable `config/daily-pace.tsv` and
`config/boundary-presets.tsv` and checks that the current answer protects
future Scheduled outflow and retains the post-purchase observed balance.

This synthetic command-to-review test is **not** a claim that all these settings
are easy to reach through the TUI. In particular, balance display selection,
Daily Pace pool and pension-cycle presets still need a user-friendly ordinary
setup route, and friendly account labels are still separate presentation work.
#2020 remains open until those steps and real TUI editing are accepted.

## Optional friendly account and category names

After adding an admitted stable Locus through Manage Loci, choose
**Space > Household setup > Account / category display names**. Select an
existing account/category, type an optional name such as `ゆうちょ`, review,
and confirm. Existing display help and older/historical-only labels remain
unchanged. Missing labels retain stable-token fallback.

These are just replaceable presentation labels, not renamed accounts. Neither
the canonical household nor the balance support, Scheduled identities,
AccountingRoles or Daily Pace inputs are modified. A malformed/stale
`config/locus-catalog.tsv` is never silently reset. Names can be added
incrementally, even after recording has already begun.

## Select which balances appear

After admitting bank/cash Loci, use **Space > Household setup >
Balances / visible accounts**. Select the exact `Locus × Measure` rows to
show in Balances, even before entering their amount. Those rows correctly say
`?` until observation or other qualified current support is available.
Unlike the separate Daily Pace spending pool, the **display selection is not
eligibility evidence**. It may be empty, supports incremental later setup and
preserves visible selections of other currencies.

This changes only replaceable `config/balance-view.tsv`. No canonical
`household.loam` write, fabricated zero, or pension-cycle change occurs.
Malformed config, stale edits, or residual publishing stages refuse edits.

## Choose Daily Pace spendable accounts from TUI

After observing exact current balances, open **Space > Household setup >
Daily Pace / spendable accounts**. Only currently exact balances of the
configured Measure are shown. Use j/k or the arrows to focus, Space to
include/exclude a balance, Enter to review the selected pool, and Enter
again to save. Esc in review goes back to selection; Esc in selection
cancels without saving.

The selection is replaceable `config/daily-pace.tsv` query configuration,
**not** a financial fact, role assignment, balance rewrite, or complete
historical assertion. Missing/unknown balances cannot be automatically
assumed eligible, and the screen refuses empty pools, malformed existing
configurations, and a configuration changed while editing. It does not
touch `household.loam`.

**Pension-cycle dates can now be entered from TUI** under Space >
Household setup > Daily Pace / cycle dates. Enter a preset name and explicit
comma-separated real YYYY-MM-DD boundaries (at least two, oldest first,
including today). For example `pension` and
`2026-10-15, 2026-12-15, 2027-02-15`. These are explicitly known
report boundaries, **not** an automatically repeated pension schedule.
Tab moves between fields; Enter reviews the proposed replacement and
another Enter saves it. Esc cancels or returns to editing.

The editor reuses the canonical `BoundaryPresetConfig.decode?` validation,
retains other named presets, refuses ambiguous overlapping current cycles,
refuses stale/malformed configuration and does not touch the household ledger.
Change only the current named preset, not previous accounting transactions.
When new boundary dates become known, reopen the same editor to extend them.
No annual reset, retrospective backfill or recurrence inference is required.

## Returning after months or years off

Use the read-only review against the existing directory:

```sh
./tools/loam resume /path/to/existing-household
./tools/loam tui /path/to/existing-household
```

`resume` uses a single qualified HouseholdImage generation to report the explicit current-open and overdue Scheduled list, current exact-anchor coordinates and retained bounded historical-completeness claims. It does **not** infer a missed interval from the last transaction date, assert that Scheduled items were paid, retire any old plan, assume balances, update a completeness claim, or write a single byte of canonical data.

**If a previously certified complete-since date crosses an unrecorded period, first remove or correct that coordinate's bounded-history claim via Home > Manage Loci > Shift-Tab.** Only then re-observe its real current balance; the existing publisher correctly refuses to replace a differing anchored amount while an incompatible complete-history claim remains. Do not remove valid coverage for accounts whose history really is complete.

If the old household still exists, **do not create a new root**. Keep the older records, use `doctor` if the start read is refused, re-observe balances you actually know, inspect old unpaid Scheduled items, and resume recording today.

LOAM must never require retroactive transaction reconstruction. Current balance observations do not prove that missing months were completely recorded. The remaining TUI-integrated resume guidance, complete restart journey and explicit hiatus test across household launch are still tracked in #2020. The separate CLI review is a small operational step, not a new recovery engine.

## Jan 1 ordinary household preflight (Issue #2030)

`Loam/Tests/JanuaryFirstHousehold.lean` exercises one **disposable**
household before and after **2026-12-31 / 2027-01-01** without changing
the host system clock: unchanged Home generation and no new year's invented
opening entries, known bank amounts vs unknown cash, retained Jan-3 Scheduled,
an explicit December-to-February pension Daily Pace cycle, a January Actual,
a correction to a December-effective Event, and one same-generation
Scheduled+Actual completion. This uses real current qualified HouseholdImage
read/write publishers and the normal Home read model. A calendar-year switch
does **not** reset the current household or the pension cycle.

**Important limit:** these checks qualify the *existing single installed
`household.loam` authority* and synthetic date-parameterized views, **not**
automatic physical `journal/2027/` creation, source-year-at-admission,
Git-head coordination, selective year replays, or a simulated system-clock
midnight TUI session. Research under #1969 has shown Git+Household dual-head
crash mismatches and test-injected source admission times. #2030 remains open;
there is no authorized production annual source-journal cutover yet.

## January 1 is not household reset

The planned January-1 Tackler/Git source-journal rollover is separate storage work tracked in [#1969](https://github.com/shumoku88-bit/loam/issues/1969). A calendar year boundary must not create a new household identity, reset balances, or fabricate opening entries. Pension-cycle boundaries remain independent.

## Qualification of this first slice

`Loam/Tests/NewHousehold.lean` and the existing Operational Continuity workflow cover first qualified installation, startup diagnosis, Movement-world admission, refusal to repeat on an existing root, byte-preservation of damaged source, and safe creation alongside that source. These are disposable fixtures. They do not modify `loam-data`.

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
- The first-run wizard, friendly labels, full TUI-led recovery, and an end-to-end new-household/actual-balance/plan/reopen acceptance specimen remain to be delivered under #2020.

Do **not** point `init` at a damaged or dormant existing household. Keep its bytes for diagnosis or a separate qualified recovery attempt.

## Returning after months or years off

If the old household still exists, **do not create a new root**. Keep the older records, use `doctor` if the start read is refused, re-observe balances you actually know, inspect old unpaid Scheduled items, and resume recording today.

LOAM must never require retroactive transaction reconstruction. Current balance observations do not prove that missing months were completely recorded. A dedicated, simple TUI resume workflow with fail-closed gap handling is still planned in #2020.

## January 1 is not household reset

The planned January-1 Tackler/Git source-journal rollover is separate storage work tracked in [#1969](https://github.com/shumoku88-bit/loam/issues/1969). A calendar year boundary must not create a new household identity, reset balances, or fabricate opening entries. Pension-cycle boundaries remain independent.

## Qualification of this first slice

`Loam/Tests/NewHousehold.lean` and the existing Operational Continuity workflow cover first qualified installation, startup diagnosis, Movement-world admission, refusal to repeat on an existing root, byte-preservation of damaged source, and safe creation alongside that source. These are disposable fixtures. They do not modify `loam-data`.

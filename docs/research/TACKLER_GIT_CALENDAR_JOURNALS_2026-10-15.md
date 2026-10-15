# Tackler + Git calendar-year journal: first native LOAM bridge

Date: 2026-10-15  
Status: **disposable research; no production authority conversion**  
Tracking: storage [Issue #1969](https://github.com/shumoku88-bit/loam/issues/1969)

## Decision from the user

- **January 1** is the start of every LOAM journal year. Use `2026`,
  `2027`, not an April-boundary `FY2026`.
- Preserve **human-readable canonical financial evidence**.
- Borrow Tackler's idea of calendar-organized plain-text journals
  and Git's immutable revisions before designing more bespoke
  per-year manifest or snapshot infrastructure.
- **No manual yearly closure, no required user daily confirmation.**
  An inactive calendar year produces no empty source event.
- Pension-day two-month cycles remain independent of calendar years.
  Calendar-year reporting is a query horizon, **not an instruction to
  reset balances or invent generated opening/closing entries**.

## First reversible integration test

The existing LOAM code already has a **conservative hledger/Ledger PTA
export**, which exposes a valuable boundary: simple balanced Actual
Events may be rendered to ordinary PTA, but Scheduled, unknown
support and other retained provenance cannot be reconstructed from
that projection.

This PR adds a similarly scoped **Tackler journal *read model***,
intentionally not converting Tackler's journal format into the
household source of truth:

1. Start with the real `ScheduledBatchReplacement setup` fixture.
2. Use real native `MovementPublisher`, `CorrectionPublisher` and
   `ActualValidityPublisher` to capture four qualified
   `household.loam` versions via `NativeHouseholdSectionBridge.lean`.
3. `tools/NativeTacklerProjection.lean` enters the **real admitted**
   `ActualAuthority` and `ActualJournalProjection` and checks
   same-generation Scheduled completion/remaining obligations.
4. For this **narrow bank/wifi JPY-only fixture**, the Python driver
   `tools/research-tackler-git-calendar-journals.py` maps the
   qualified current-Actual postings to readable Tackler-style
   journal entries, one per current Event, under
   `txns/YYYY/event-<sha256-of-EventId>.txn`.
   `# ext-id:` contains the LOAM EventId; the file name is path-safe.
   Unbalanced, effect-free, unknown-role, zero, mixed-measure or
   malformed postings are **refused**, never silently inferred.
5. Every synthetic admitted generation causes an isolated **local Git
   commit** of the resulting annual *read model*. Git commit IDs
   select exactly reproducible sets of files; the test checks
   `git ls-tree` and `git show COMMIT:PATH` against the disk view.
6. The 2025-effective original is present in the prior read-model
   Git commit; after correction and move of its effective date to
   2027, the latest projection has only the corrected Event under
   `txns/2027`. Git's old pinned view remains reproducible.
   The **actual superseded original** is still retained in LOAM's
   complete canonical evidence even if omitted from Tackler's
   current-Actual projection.

**Important:** these are *effective-date directories* used by the
derived Tackler view. They are **not** an approved strategy for
physical LOAM admitted-source journals.

## Demonstrated filesystem shape

```text
tackler-git-read-model/            # synthetic, disposable Git repository
  .git/
  txns/
    2025/
      event-<stable-hash>.txn
    2026/
      event-<stable-hash>.txn
    2027/
      event-<stable-hash>.txn
```

Each Git snapshot includes only years with current visible
transactions. In the final version 2025 files can disappear because
the corrected Event's effective date moves into 2027. The initial
Git state and earlier revisions retain their earlier derived view.

For an eventual **canonical admitted-source** layout, the critical
difference is:

```text
journal/2026/   source entries actually admitted during 2026
journal/2027/   later source events or corrections admitted during 2027
```

A 2027-**admitted** change with a 2025-*valid* date must **stay in the
2027 source journal**, while an up-to-date tax-year report may project
its impact into 2025. Source admission/knowledge time is distinct
from transaction effective date and distinct from Git commit time.
Current LOAM writers do **not** yet retain a complete qualified
knowledge time for every source family, so the prototype must
not infer it from `validOn`, current clock or a Git commit timestamp.

The source file layout cannot be promoted until **full Actual,
Scheduled, Current Quantity, policy, unknown-vs-zero and correction
graph** support is preservable, including operation-level atomicity.

## Runtime

```sh
python3 tools/research-tackler-git-calendar-journals.py --check
```

Needs Git CLI and built Lean dependencies. The test uses only private
temporary synthetic fixtures; does not read or write `loam-data`.

It proves **Git-pinned text projection reproducibility and
LOAM-qualified read-model input**, not that Tackler has parsed the
output yet. A follow-up Tackler 26.10.1 CLI compatibility trial
is a separate gate. It must compare FS vs Git backends on an actual
Tackler process before claiming integrated Tackler reporting.

## The two different Git roles

- **Git-managed canonical journal** (future): user-editable evidence
  and admission-year organization, potentially versioning whole
  groups of retained LOAM facts. Only a qualified LOAM publication
  may advance the ledger. Git can back up and audit, but is not an
  independent semantic admission checker.
- **Git-managed Tackler projection** (this trial): a derived,
  disposable, *currently effective* accounting view. It can be
  rebuilt from qualified LOAM source. Old Git commits preserve
  what each generated report saw, but they are not sufficient to
  reconstruct full LOAM correction and Scheduled history.

Do not interpret ordinary Tackler `# ext-id` or Git's commit time
as permission to discard LOAM Event IDs, validity revisions,
CurrentQuantityPresence, Scheduled completion source endpoints or
historical-knowledge ordering.

## Next gates

1. Verify generated .txn files with the **real Tackler 26.10.1**
   binary, in both filesystem and Git-backed reader modes, without
   adding a heavy cargo compilation to every existing LOAM CI run.
2. Build a *native admitted-source* journal with **publication-year**
   membership at the one-Household semantic publication boundary.
   Prove that a real cross-Jan-1 correction does not rewrite an old
   year, and that source replay exactly reproduces all admitted
   families and omitted/missing-is-not-zero distinctions.
3. Qualify Git commit and on-disk canonical publication order,
   crash recovery, partial restore and rollback detection. A
   completed local transaction should not require user to run Git
   commands manually.
4. Reuse Tackler's subset-directory/Git-ref approach where it
   earns a read-time advantage. For balance/Daily Pace, load the
   complete necessary support prefix until qualified checkpoints
   make a narrower selection provably complete.
5. Compare native 1/5/10/20-year actual use cases before migrating
   production data; avoid fabricated year-end opening transactions.

**No real household data, canonical schema, runtime writer/TUI,
annual user workflow or git repository in `loam-data` is changed.**

## References

- [Tackler journal format](https://tackler.fi/docs/tackler/latest/journal/format/)
- [Tackler Git storage](https://tackler.fi/docs/tackler/latest/journal/git-storage/)
- [Tackler production setup](https://tackler.fi/docs/tackler/latest/examples/production-setups/)
- Existing native conservative PTA exporter:
  `Loam/Export/PlainTextAccountingExport.lean`.

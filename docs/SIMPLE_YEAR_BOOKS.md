# Start a separate household each calendar year

Use **one normal LOAM household per year**. Nothing is split or migrated.

```sh
# Source household remains unchanged
loam year new 2027 /path/to/loam-data

# Open the new, ordinary, independent household
loam tui /path/to/loam-data/books/2027

# Next year, do the same
loam year new 2028 /path/to/loam-data
loam tui /path/to/loam-data/books/2028
```

This is just the existing `loam init` installer with a predictable
`books/YYYY` directory. The new year has its own `household.loam`.
The `journal/YYYY` paths remain reserved for read-only archives, not
independent working households. Passing a path to `loam tui` selects the
book you want. The regular default LOAM path is not switched implicitly.

**Trade-off, intentionally accepted:** no records, balances, Scheduled
payments, account/category admission, roles, Daily Pace config or other
household facts are copied. You set up what you need in the new book.
Unknown is unknown, never an invented zero; correcting a prior-year record
never updates another independent book. There is no automatic annual reset,
pointer, opening transaction, annual migration, cross-file transaction or
unbounded history replay.

Existing year book directories are never overwritten. The prior
`loam-data/household.loam` is never edited by this operation.

## Compatibility warning

A previous experimental mode (PR #2068) could create
`journal/active-year`. If that file exists, the simplified runtime refuses
to open or publish to the stale root `household.loam`. Preserve all files
and open the data with a compatible version first. Never delete the pointer
to force a fallback. The simple `year new` mode does not convert that layout.

See `loam init NEW_DATA_DIR` for fresh independent households that do not
use year-named directories.

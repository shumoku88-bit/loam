# Real Tackler v26.10.1 filesystem/Git backend parity

Date: 2026-10-15
Status: **research-only, disposable, native Tackler runtime gate**
Related: storage Issue #1969; merged PR #2014.

## Question

PR #2014 established that the **real Lean-qualified, correction-aware LOAM
Actual projection** could be serialized into readable, calendar-year
Tackler-shaped `txns/YYYY/*.txn` files and preserved under four Git commits.
It verified all committed files via Git objects, but **did not run Tackler**.
This next gate uses the actual pinned Tackler CLI, not a home-grown text parser,
to make sure the formatted files are acceptable to the external engine.

## Run and reproducibility

The test adds an opt-in flag to the same isolated fixture runner:

```sh
# Requires a Git CLI, Lean build, Python 3, and Tackler v26.10.1 on PATH.
python3 tools/research-tackler-git-calendar-journals.py --check --tackler
```

It invokes Tackler's **actual parser/accounting computation** on each of
four derived states, in two independent backend configurations:

1. `--input.storage fs` reads the working tree under `txns`.
2. `--input.storage git --input.git.commit <sha>` reads the *exact
   committed snapshot* of that same tree.

Both use the same minimal Tackler config, disable strict chart requirement
for the tiny JPY fixture, and request a balance report. Only account rows
are compared, not Git provenance metadata/console banners. The test
requires that both named `Assets:Bank` and `Expenses:Wifi` survive
parsing, then compares their report rows across FS and Git input modes.
Earlier pinned Git views remain available after subsequent corrections.

The separate path-scoped
`.github/workflows/research-tackler-real-cli.yml` installs **exactly
26.10.1** from crates.io with `cargo install --locked --version 26.10.1
tackler`. It does not require installing Rust/Cargo/Tackler on the
user's Mac and is deliberately **not** added to every existing native
research run, because first-build compilation of Tackler and
dependencies is relatively expensive.

## Scope restrictions

This checks the *current-effective-year PTA read projection* of
one synthetic family, **not the canonical LOAM source journal**.
Its `txns/YYYY` grouping is by Event effective date; a 2027
admitted correction to an Event effective in 2025 belongs in
**2027's canonical publication-year source journal** if that design
is eventually adopted. It must not mutate 2025's sealed journal.
Tackler's Git commit timestamp is not qualified learned time.

Nor is this a complete Tackler/LOAM semantic equivalence test: the
projection deliberately omits superseded Actual source Events,
Actual validity revision evidence, nonrepresentable mixed-Measure
events, full Scheduled source/completion evidence, explicit
CurrentQuantityPresence, unclassified identities and coverage/policy
information. The complete admitted HouseholdImage still owns all
financial semantics; only generated read models go into the
experimental Git repository.

A successful CLI check **does not** mean production filesystem/Git
publication is crash-safe, that all balances/Daily Pace can be computed
from year-only journals, that financial facts should be converted into
Tackler syntax, or that a Mac installation is required.

## Official external sources

- [Tackler installation](https://tackler.fi/docs/tackler/latest/installation/)
- [Journal format, including ext-id](https://tackler.fi/docs/tackler/latest/journal/format/)
- [CLI backend selectors](https://tackler.fi/docs/tackler/latest/reference/command-line/)
- [Git storage support](https://tackler.fi/docs/tackler/latest/journal/git-storage/)
- [Tackler v26.10.1 release](https://github.com/tackler-ng/tackler/releases/tag/v26.10.1)

**No LOAM production authority, canonical schema, user data,
`loam-data` or day/year confirmation workflow changes.**

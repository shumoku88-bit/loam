# Observation 385 — Plain-text accounting migration admission matrix

Status: **EXECUTABLE ADAPTER BOUNDARY — hledger-backed one-shot migration probe; no production importer or authority change**

Baseline:

```text
LOAM main 9e4277a3985a9837cacb75b6e2d7157c65590cfa
```

External references inspected:

- hledger 1.52 manual and journal specification:
  - https://hledger.org/1.52/hledger.html
  - https://hledger.org/SPEC-journal.html
  - https://hledger.org/SPEC-print.html
- hledger's current Ledger compatibility notes:
  - https://hledger.org/ledger.html
- Ledger 3 manual:
  - https://ledger-cli.org/doc/ledger3.html

## Trigger

LOAM can already export a conservative common Plain Text Accounting view, and
its production write boundaries now cover ordinary single-Measure Movement and
explicit cross-Measure Exchange.

The adoption pressure is the opposite direction:

> Can a Ledger/hledger user bring an existing journal into LOAM once, then use
> LOAM's current reports and Trend without re-entering years of history?

This is deliberately **not** a bidirectional-sync question. Observation 075
already showed that mutable external text does not in general provide enough
stable occurrence identity for safe continuing synchronization.

The smallest useful target is therefore:

```text
external Ledger/hledger journal
        |
        v
source parser / normalizer
        |
        v
LOAM migration preview
        |
        +-> Direct
        +-> Normalize
        +-> Review
        `-> Refuse
        |
        v
fresh migration household
```

## Four dispositions

### Direct

The source already contains explicit accounting quantity facts that fit one
current LOAM admission boundary without dropping a source distinction claimed
by this importer.

### Normalize

Source syntax contains reversible shorthand or file-composition mechanics.
A source-native parser can make the relevant accounting facts explicit before
LOAM sees them.

Normalization must not guess household meaning.

### Review

The quantity history can plausibly be admitted, but the source also contains a
distinction LOAM does not currently retain. Automatic import stops and shows
exactly what would be omitted or mapped. The user may explicitly choose a
migration policy.

### Refuse

Current LOAM cannot represent the source meaning honestly enough for the v1
migration contract. The importer must not silently materialize, flatten, or
reinterpret it.

## Existing LOAM receiving boundaries

The present production model gives two useful target shapes.

### Ordinary Movement

`MovementAdmission.validateDraft` accepts:

```text
one real calendar date
nonempty nonzero Effects
one Measure
exact signed total = 0
currently admitted Loci
```

The sign has no built-in debit/credit meaning. Accounting role remains separate.

### Cross-Measure Exchange

`ExchangeAdmission` plus `ExchangeEvidenceFrontier` accepts one neutral Event
with:

```text
selected negative source Effect
selected positive destination Effect
distinct source/destination Measures
no third Measure
negative net source-Measure quantity
positive net destination-Measure quantity
```

Additional Effects in either selected Measure are allowed. The retained Exchange
fact does not itself claim FX rate, valuation, tax basis, gain/loss, home
currency, or travel direction.

That makes exact two-Measure quantity exchange much closer to current LOAM than
the older completion checkpoint suggested.

## Representative migration fixtures

These are synthetic fixtures chosen to exercise documented Ledger/hledger
semantics. They are a design matrix, not copied user data.

### 1. Basic expense — Direct

```ledger
2026-09-01 Coffee
    Assets:Cash        -300 JPY
    Expenses:Coffee     300 JPY
```

One Measure, explicit quantities, exact balance.

Target: one Movement Event.

### 2. Split expense — Direct

```ledger
2026-09-02 Supermarket
    Assets:Cash        -900 JPY
    Expenses:Food       600 JPY
    Expenses:Supplies   300 JPY
```

Multiple postings do not create a problem. LOAM Movement already admits an
arbitrary balanced same-Measure Effect list.

### 3. Same-Measure transfer — Direct

```ledger
2026-09-03 Transfer
    Assets:Bank       -5000 JPY
    Assets:Cash        5000 JPY
```

No special Transfer primitive is required.

### 4. Income — Direct

```ledger
2026-09-04 Pension
    Assets:Bank       80000 JPY
    Income:Pension   -80000 JPY
```

The importer need not interpret signs as income semantics. AccountingRole is a
separate LOAM classification.

### 5. Explicit opening transaction — Direct

```ledger
2026-01-01 Opening
    Assets:Bank      120000 JPY
    Equity:Opening  -120000 JPY
```

As quantity history this is an ordinary balanced Movement.

Whether the imported household should additionally mark an opening witness is a
separate LOAM support decision; the importer must not infer OpeningSupport from
the account spelling.

### 6. Elided balancing amount — Normalize

```ledger
2026-09-05 Lunch
    Expenses:Food     850 JPY
    Assets:Cash
```

Both Ledger-family tools support omitted balancing amounts. hledger `print -x`
can expose inferred amounts explicitly.

Candidate route:

```text
source text
  -> source parser
  -> explicit postings
  -> ordinary Movement
```

LOAM should not implement amount inference merely to import this syntax.

### 7. Include / alias composition — Normalize

A journal may obtain transactions through `include` files or rewrite account
names through aliasing.

Those are source composition/name-resolution mechanics. A source-native parser
can present the resolved transactions to LOAM.

The v1 importer should consume the normalized transaction image, not attempt to
be a Ledger/hledger directive engine.

### 8. Decimal commodity presentation — Review once per Measure

```ledger
2026-09-06 Snack
    Assets:USD       -12.34 USD
    Expenses:Food     12.34 USD
```

LOAM stores exact integral quanta and keeps decimal scale in
`MeasurePresentation`.

A proposed mapping such as:

```text
USD -> Measure usd, scale 2
```

must therefore be visible and confirmed. Once the Measure mapping/scale exists,
the transaction itself is Direct.

This is setup review, not transaction-by-transaction semantic review.

### 9. Exact two-commodity exchange — Direct after shape check

```ledger
2026-09-07 Exchange
    Assets:JPY      -15000 JPY
    Assets:USD         100 USD
```

The exact source and destination quantities fit current Exchange admission.

The importer may use the negative and positive physical legs as an Exchange
candidate only after confirming that exactly the current Exchange shape is
present. It must not invent a market rate or valuation record.

### 10. Explicit `@` / `@@` posting cost — Review

```ledger
2026-09-08 Buy shares
    Assets:Broker       2 ABC @ 500 JPY
    Assets:Bank      -1000 JPY
```

Ledger-family cost syntax carries more meaning than two naked quantities. It can
participate in cost, lot, price, and later valuation behavior.

Even when the arithmetic agrees with the other leg, v1 must not silently erase
the source cost annotation and call the result lossless.

A future explicit policy may distinguish a simple redundant conversion cost
from investment basis semantics.

### 11. Cleared / pending status — Review

```ledger
2026-09-09 * Cleared purchase
    Assets:Cash        -500 JPY
    Expenses:Food       500 JPY
```

and:

```ledger
2026-09-10 ! Pending purchase
    Assets:Bank        -700 JPY
    Expenses:Food       700 JPY
```

The quantities fit Movement, but LOAM does not currently retain the same
transaction-status meaning.

Automatic migration stops unless the user explicitly accepts dropping that
status distinction.

### 12. Code / tags / metadata — Review

```ledger
2026-09-11 (CHK42) Hardware
    Assets:Bank       -2000 JPY
    Expenses:Tools     2000 JPY
    ; project: balloon
```

Description can be retained directly, but source code/tag metadata is not the
same thing as LOAM EventDescription.

Do not concatenate arbitrary metadata into description silently. Preview the
loss or a future explicit mapping.

### 13. Posting-specific / secondary dates — Refuse in v1

Ledger-family syntax can attach posting/effective dates distinct from the
transaction date.

LOAM ActualValidity is Event-scoped. Choosing one date changes historical
placement; splitting one source transaction into several Events changes grouping
and identity.

That is not a harmless normalization, so v1 refuses the transaction until an
explicit migration policy is designed.

### 14. Balance assertion — Review

```ledger
2026-09-12 ATM
    Assets:Cash       1000 JPY = 5000 JPY
    Assets:Bank      -1000 JPY
```

The transaction quantity may fit Movement, but the assertion is independent
verification evidence.

LOAM has current quantity support and other explicit history-support families,
but a Ledger/hledger assertion is not automatically equivalent to any one of
them. In particular, source parse/order semantics matter.

The importer may offer "import quantities, omit assertion" only as an explicit
review choice.

### 15. Balance assignment — Review after source materialization

```ledger
2026-09-13 Reconcile
    Assets:Cash            = 4200 JPY
    Equity:Adjustments
```

A source parser can calculate the posting amount from prior state, and hledger
`print -x` can display assignment amounts explicitly.

That makes the realized quantity history available, but the original
"set/verify this balance" intent is additional evidence. Importing only the
materialized postings is therefore Review, not silent Normalize.

### 16. Unbalanced virtual posting — Refuse

```ledger
2026-09-14 Dinner
    Assets:Cash          -900 JPY
    Expenses:Food         900 JPY
    (Budget:Food)        -900 JPY
```

The virtual posting is deliberately outside ordinary double-entry balance and
can be excluded from reports as non-real.

Turning it into a real LOAM Effect would change its meaning; dropping it without
review would lose source data. v1 refuses this transaction shape.

### 17. Balanced virtual posting — Refuse

```ledger
2026-09-15 Dinner
    Assets:Cash          -900 JPY
    Expenses:Food         900 JPY
    [Budget:Food]        -900 JPY
    [Equity:Budget]       900 JPY
```

The bracketed virtual subsystem balances internally but remains explicitly
virtual in Ledger-family semantics.

It should not become ordinary LOAM Actual quantity merely because its arithmetic
balances.

### 18. Automated transaction rule — Refuse rule semantics

```ledger
= expr account =~ /Expenses:Food/
    (Tracking:Food)  1
```

Automated transactions modify/generate postings when other transactions match.

A one-shot migration could someday offer an explicit "materialize generated
history" mode using the source engine, but that is a different contract. v1
does not import the rule or silently expand it.

### 19. Periodic transaction rule — Refuse rule semantics

```ledger
~ monthly
    Expenses:Rent   50000 JPY
    Assets:Bank    -50000 JPY
```

This is a generator/forecast rule, not an observed historical occurrence.

LOAM Scheduled has its own retained lifecycle semantics, so translating the rule
by syntax alone would claim more correspondence than is justified.

### 20. Price / lot / investment identity — Refuse in v1

Representative Ledger-family features include:

```ledger
P 2026-09-16 ABC 550 JPY
```

and posting-attached lot cost/date/note information.

LOAM deliberately separates exact occurrence quantity from valuation and has no
generic market-price or investment-lot authority. Importing these as ordinary
Actual would either discard material meaning or invent valuation/basis meaning.

They remain outside the v1 migration boundary.

## Matrix result

```text
Direct       1 basic expense
             2 split expense
             3 same-Measure transfer
             4 income
             5 explicit opening transaction
             9 exact two-commodity Exchange

Normalize    6 elided balancing amount
             7 include / alias source composition

Review       8 Measure decimal scale setup
            10 explicit @ / @@ cost
            11 cleared / pending status
            12 code / tags / metadata
            14 balance assertion
            15 balance assignment after materialization

Refuse      13 posting-specific / secondary dates
            16 unbalanced virtual posting
            17 balanced virtual posting
            18 automated transaction rule
            19 periodic transaction rule
            20 price / lot / investment identity
```

The common core is therefore not tiny. Six ordinary transaction families are
already direct, and two common source conveniences can be normalized outside
LOAM.

The important boundary is not syntax complexity. It is source meaning that
would change time, reality/status, retained verification, generation, cost
basis, or valuation.

## Candidate normalized import image

Do not make Ledger syntax part of LOAM Core. A future adapter needs only a small
temporary shape approximately like:

```text
NormalizedTransaction
  sourcePosition
  date
  description
  postings[]
    account
    exact signed quantity text
    commodity
  sourceFeatures[]
```

`sourceFeatures` is essential. It prevents normalization from erasing the fact
that a transaction carried status, assertion, cost, metadata, virtuality, or a
posting-specific date.

The classifier can then route:

```text
one Measure + exact zero
    -> Movement candidate

qualified two-Measure source/destination shape
    -> Exchange candidate

known review-only source feature
    -> stop for review

meaning-changing/unsupported feature
    -> refuse
```

## Account and role boundary

A source account name can be proposed as a LOAM Locus identity, including
hierarchical names such as:

```text
Assets:Bank
Expenses:Coffee
```

But the importer must **not** infer:

```text
Assets:      -> AccountingRole.asset
Expenses:    -> AccountingRole.expense
```

from spelling alone.

Ledger account names are user vocabulary, and current LOAM intentionally owns
AccountingRole as separate explicit evidence. A later onboarding screen can
offer role proposals, but acceptance must remain explicit.

The same rule applies to commodity names. A symbol is a candidate Measure
mapping, not proof that the Measure is a currency or that a particular decimal
scale is semantically required.

## Historical-support consequence

Successfully importing Events does not by itself prove that every imported
coordinate has history from zero.

Three common source situations differ:

```text
explicit opening transaction
    -> import the Event
    -> opening support remains an explicit LOAM decision

journal truly complete from zero
    -> zero-origin/bounded support must be justified separately

journal starts mid-history / source only knows current balance
    -> use LOAM's existing current quantity / bounded-history support paths
```

This is useful rather than inconvenient: the importer should not convert
"there are transactions in a file" into a false completeness claim.

## Identity and retry boundary

Observation 075 remains decisive.

The v1 contract should be:

```text
one-shot migration
not ongoing synchronization
```

Content hashes and line numbers may be diagnostics, but neither may become the
semantic identity of a continuing external occurrence.

There is also an operational consequence: importing hundreds of Events directly
into an already-active household one at a time creates an awkward interrupted
migration/retry problem.

The smallest safe first target is therefore:

```text
fresh / disposable migration household
        |
        +-> parse all source data
        +-> classify every source feature
        +-> preview Locus / Measure setup
        +-> refuse unresolved semantics
        +-> publish migration
        +-> canonical re-read / reports
```

Appending an external journal repeatedly into an existing authority is outside
v1.

## Source-parser boundary

hledger `print -x` is a promising normalizer because current hledger documents
that it makes inferred balancing amounts, inferred costs, and balance-assignment
amounts explicit while keeping print output parseable.

This does **not** mean that `print -x` alone is a safe importer.

The adapter must still detect or retain evidence of:

- virtual postings;
- transaction/posting status;
- balance assertions/assignments;
- posting-specific dates;
- costs and lot annotations;
- generated/modified transactions when source options enable them;
- metadata whose omission would be user-visible.

The first implementation experiment should therefore use hledger as a
source-native parser/normalizer, but keep LOAM's own small classifier and
fail-closed preview.

Ledger-native normalization can be a later adapter if real Ledger-only files
fail the hledger-compatible entrance.

## What this observation does not authorize

Do not add yet:

- a general Ledger parser in Lean;
- bidirectional synchronization;
- source-line or content-hash Event identity;
- automatic AccountingRole inference from account prefixes;
- automatic zero-origin claims;
- market-price or lot authority;
- transaction-status Core vocabulary;
- periodic-rule translation to Scheduled;
- virtual posting semantics;
- generic import plugin architecture.

## Finding

A useful importer is substantially smaller than "support Ledger".

The strongest first product slice is:

```text
hledger-normalized common-core migration
        +
fail-closed source-feature classifier
        +
human preview of Locus / Measure setup
        +
fresh-household one-shot publication
```

This would let a large class of ordinary Ledger/hledger journals reach LOAM
Trend without weakening LOAM's semantic boundaries.

The next gate should be executable, not another broad survey:

1. choose a tiny normalized transaction representation;
2. encode these 20 fixtures as classifier tests;
3. prove/test that every Direct case reaches either Movement or Exchange;
4. prove/test that every Review/Refuse feature cannot silently reach publication;
5. only then decide whether a production `loam import hledger` command is earned.


## Executable classifier gate

The design matrix now has one deliberately test-only Lean instrument:

```text
Loam/Tests/PtaMigrationClassifier.lean
```

It does not parse Ledger syntax and it is not imported by the product library.
Instead it represents the narrow boundary a future source adapter must reach:

```text
Transaction
  validOn
  description
  exact mapped postings
  retained sourceFeatures
```

The executable classifier enforces the disposition precedence:

```text
Refuse > Review > Normalize > Direct
```

so a transaction that is mechanically normalizable but also carries retained
review/refusal semantics cannot expose a publication candidate.

The 20 matrix fixtures are encoded directly. For every Direct fixture the test
constructs either a current `MovementAdmission.Draft` or
`ExchangeAdmission.Draft` and then exercises the corresponding production
`admit?` boundary against an isolated admitted-Locus world.

For every Normalize, Review, and Refuse fixture, the classifier must expose no
Movement/Exchange candidate at all.

Three extra guards cover pressure not represented by a single matrix row:

- Review dominates Normalize when both source-feature classes are present;
- Refuse dominates Review;
- a fee-bearing/multi-posting two-Measure shape is Review until source and
  destination selection is explicit, even though current LOAM Exchange can
  represent such an occurrence once that selection is known.

This is intentionally the last research-only shape before considering a real
adapter. If it qualifies, the next question becomes operational:

> Can a source-native hledger normalization step produce this small input image
> while preserving enough feature metadata for the fail-closed classifier?

A production `loam import hledger` command is still not authorized by this
gate alone.


## hledger-backed adapter boundary

The next executable probe now puts a real hledger process in front of the
classifier instead of constructing every normalized transaction directly in
Lean.

The bounded path is:

```text
synthetic hledger journal
        |
        v
hledger 1.52.3 print -x -O csv
        |
        +-- exact normalized posting amounts
        |
source-feature inventory
        |
        +-- omitted amount
        +-- transaction status
        +-- balance assertion
        `-- virtual posting
        |
        v
narrow TSV adapter wire
        |
        v
existing Lean classifier
        |
        v
Direct / Normalize / Review / Refuse
        |
        v
production Movement/Exchange admission for Direct only
```

The source-feature pass is intentional. hledger's tabular `print` output is a
useful exact-amount transport, but normalization can flatten distinctions that
Observation 385 says must still block publication. The experiment therefore
does not treat normalized CSV alone as semantic authority.

The checked-in fixture contains five source transactions:

```text
1 explicit balanced expense        -> Direct
2 omitted balancing amount         -> Normalize
3 cleared transaction status       -> Review
4 balance assertion                -> Review
5 unbalanced virtual posting       -> Refuse
```

Transaction 2 specifically verifies the useful hledger boundary: the source has
no amount on one posting, while `print -x` supplies an explicit amount. The
adapter still retains `inferredAmount`, so the classifier sees Normalize
rather than silently treating the source as originally explicit.

The experiment also uses an explicit Measure-scale fixture. Decimal text is
converted to LOAM quanta only when multiplication by that confirmed scale is
exact. Any required rounding is refused.

### Why CSV here

Current hledger documents `print -O csv` as one row per posting with transaction
index, dates, status, account, amount, and commodity. It also documents that
`print -x` makes inferred amounts explicit.

hledger JSON is richer, but current documentation notes that JSON numeric output
is rounded to at most ten decimal places. That makes it unsuitable as the sole
exact-quantity transport for LOAM's migration boundary.

### CI scope

This does not add another workflow file. The existing Lean Proof Surfaces scope
detects changes to the adapter experiment and only then:

1. installs the pinned official hledger 1.52.3 Linux binary;
2. normalizes the synthetic journal;
3. feeds the resulting wire image into the existing Lean classifier.

Ordinary unrelated LOAM pull requests do not download or execute hledger because
the adapter step is path-scoped inside the existing workflow.

### Remaining gate

This probe deliberately aligns normalized hledger transactions with the
synthetic source transactions by finite fixture order. That is enough to test
the parser/normalizer boundary, but it is not yet a production provenance
protocol for arbitrary include trees, generated postings, reordering, or source
editing.

If this executable boundary qualifies, the next production-oriented question is
smaller and clearer:

> What preview/batch format should carry normalized transactions, source-feature
> evidence, Locus/Measure mappings, and user review decisions into one fresh
> migration household without relying on source order as identity?

Until that is answered, this remains an adapter experiment rather than
`loam import hledger`.

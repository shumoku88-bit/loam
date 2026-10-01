# LOAM text / SQLite persistence study — 2026-10

Status: **research checkpoint — no production persistence change authorized**

Baseline:

~~~text
main: eab0888cb85d78a04cfa0cd05166239ed8f946e7
fix(tui): expand Actual workspace and show newest first (#1683)
~~~

## Question

LOAM currently keeps normalized Actual evidence in a human-inspectable canonical
actual.loam file and reconstructs current household answers through typed
decoding, semantic admission, and projection.

SQLite is widely used as an application file format, including by personal
finance applications, because it combines a single portable file with atomic
transactions, indexed queries, incremental updates, and a mature recovery
protocol.

The research question is not:

> Is SQLite better than text?

It is:

> Which persistence responsibilities, if any, should LOAM delegate to SQLite
> without weakening its authority, admission, correction, uncertainty, or
> reconstructability semantics?

A second question is deliberately stronger:

> Can LOAM retain plain-text canonical authority while gaining most database
> advantages from a disposable, rebuildable SQLite read model?

This study treats those as competing hypotheses rather than selecting SQLite in
advance.

## Current LOAM baseline

Current production Actual persistence already owns more than a simple text-file
save:

~~~text
ActualEvidence
    -> encode normalized image
    -> write sibling stage
    -> read stage back
    -> compare bytes
    -> typed decode / semantic re-admission
    -> atomic rename
~~~

The write path also uses cross-process writer ownership so a stale whole-image
writer cannot silently replace a newer generation.

Relevant owners:

- Loam/Persistence/NormalizedActualPersistence.lean
- Loam/Authority/ActualAuthority.lean
- Loam/Persistence/WriterOwnership.lean
- docs/SEMANTIC_BLUEPRINT.md

This means "SQLite gives us atomicity" is not by itself a sufficient migration
argument. A useful SQLite design must either remove meaningful LOAM-owned
mechanics, enable a needed capability, or improve measured operation enough to
justify the new dependency and schema boundary.

## External evidence

### SQLite as an application file format

SQLite's own application-file-format guidance explicitly emphasizes:

- single-file storage;
- atomic transactions;
- incremental updates;
- indexed relational queries;
- cross-platform portability;
- long-lived file-format compatibility.

Sources:

- https://www.sqlite.org/appfileformat.html
- https://www.sqlite.org/fileformat.html

This explains why local desktop finance software frequently selects SQLite:
many storage-engine responsibilities are delegated to a mature embedded
database rather than recreated in application code.

A detail that matters for LOAM experiments is that journal state is part of
recovery. Rollback-journal mode may temporarily create a -journal file; WAL
mode uses -wal and -shm side files. A "single file" operational story must
therefore distinguish steady-state portability from in-flight recovery state.

### hledger: plain-text authority plus relational projection

hledger provides an explicit SQLite workflow:

~~~text
journal text
    -> hledger print -O sql
    -> sqlite3
    -> relational queries
~~~

It also demonstrates querying a freshly generated SQL stream without retaining
a database file at all.

Sources:

- https://hledger.org/sqlite.html
- https://hledger.org/export.html

This is direct precedent for a LOAM experiment where SQLite is a disposable
projection rather than household authority.

### Beancount: text authority, growing query pressure

Beancount's Vnext design notes say its SQL query engine began as a prototype and
grew into a primary way to retrieve data.

Source:

- https://beancount.github.io/docs/beancount_v3/

This is useful pressure evidence: plain-text authority does not remove demand
for richer relational-style querying. Query machinery tends to reappear either
inside the accounting tool or through an external database projection.

### GnuCash: multiple storage backends do not collapse into one obvious winner

GnuCash supports XML, SQLite, MySQL, and PostgreSQL storage. Its current guide
still describes XML as the most established format for most users while noting
that SQLite supplies SQL storage without running a separate DBMS. It also warns
that selecting a SQL backend does not automatically make the application
multi-user or fully incremental.

Source:

- https://www.gnucash.org/docs/v5/C/gnucash-guide/basics-files1.html

The useful lesson for LOAM is architectural: a database backend provides
storage mechanisms, not product semantics by itself.

### Lean integration feasibility

The Lean organization maintains SQLite bindings:

- https://github.com/leanprover/leansqlite

Therefore an eventual experiment does not require abandoning Lean for a
separate service merely to access SQLite.

## Three candidate architectures

### A — current text authority

~~~text
actual.loam
    -> typed decode
    -> admitted Actual image
    -> Reviews / reports
~~~

Properties:

- direct human inspection;
- ordinary Git diff and history;
- easy archival copy;
- current whole-image publication and custom qualification remain LOAM-owned;
- arbitrary indexed queries require LOAM-side computation.

### B — text authority + disposable SQLite projection

~~~text
actual.loam
    -> typed decode
    -> admitted Actual image
    -> SQLite projection
    -> indexed queries / analytics
~~~

The SQLite file has **no authority**.

Required law:

~~~text
delete sqlite projection
    -> rebuild from admitted LOAM authority
    -> same query-visible projection
~~~

A corrupt, stale, missing, or schema-incompatible projection must be disposable,
not a reason to reinterpret household facts.

This is the closest analogue to hledger's existing SQLite workflow, but LOAM can
place semantic admission before projection generation.

### C — SQLite canonical authority

~~~text
SQLite
    -> typed rows / reconstruction
    -> semantic admission
    -> admitted Actual image
    -> Reviews / reports
~~~

Potential benefits:

- indexed partial reads;
- incremental writes;
- transactions across multiple related rows;
- storage-engine crash recovery;
- no need to rewrite the complete Actual image for every change.

New obligations:

- schema authority and schema-version policy;
- migration qualification;
- mapping relational rows back to LOAM semantic aggregates;
- backup / restore qualification;
- decision about foreign keys and database constraints versus Lean admission;
- diagnosis when SQL-valid state is semantically invalid;
- loss of ordinary text diff as the direct authority view.

SQLite constraints must not silently become a second, weaker or stronger
household ontology.

## Research hypotheses

### H1 — household-scale text authority remains operationally sufficient

For realistic household history sizes, whole-image decode and publication may
remain cheap enough that replacing canonical storage has no practical benefit.

This hypothesis is falsified by measured latency, memory, write amplification,
or operational failure that materially affects normal use.

### H2 — a disposable SQLite projection captures most database value

Indexed search, joins, period aggregation, and exploratory analysis may become
much faster without changing canonical authority.

This hypothesis is falsified if projection rebuild cost, semantic duplication,
or synchronization complexity becomes large enough that the cache is no longer
obviously disposable.

### H3 — SQLite authority is justified only if it simplifies the whole system

SQLite authority should not be promoted merely because SQLite is mature.

Promotion requires evidence that it removes more persistence complexity than it
adds while preserving LOAM's semantic boundaries and long-term household
continuity.

## Experiment sequence

### E0 — responsibility inventory

Before adding SQLite, record the exact responsibilities currently owned by:

- normalized Actual parser / encoder;
- semantic admission;
- whole-image staging and verification;
- writer ownership;
- correction / validity / relation provenance;
- current projections.

Classify each responsibility as:

~~~text
semantic LOAM law
physical persistence mechanic
query/read optimization
migration/recovery policy
~~~

Only the latter three are candidates for delegation.

### E1 — disposable projection prototype

Build a non-authoritative SQLite projection from an already admitted Actual
image.

Initial schema should be intentionally narrow and relational, for example:

~~~text
events
effects
date_revisions
relations
discharges
merchant_evidence
exchange_evidence
original_amount_evidence
~~~

The schema is a read model, not a new Core vocabulary. Tables may be shaped for
queries and need not mirror one Lean structure per table.

Initial rules:

1. production writes still go only through LOAM authority;
2. SQLite projection creation starts from admitted evidence;
3. no SQLite mutation writes back to LOAM;
4. deleting the DB must be safe;
5. projection schema changes need no household-data migration because rebuild is
   authoritative.

### E2 — semantic equivalence checks

For generated fixture worlds and selected real-shape fixtures, compare:

~~~text
LOAM Review answer
        ==
SQLite projection query answer
~~~

Candidate checks:

- current event count;
- Effects by Locus and Measure;
- latest-N Actual records;
- date-range Actuals;
- merchant filtering;
- period quantity totals;
- correction/currentness-sensitive result sets;
- exchange / relation linkage where projected.

The SQLite query is not allowed to invent an answer that LOAM would refuse.

### E3 — scale benchmark

Use synthetic data so private household data is unnecessary.

Suggested sizes:

~~~text
1,000 events
10,000 events
100,000 events
1,000,000 events
~~~

Measure separately:

- full startup / decode;
- latest 30-day query;
- one-Locus history;
- one-Merchant history;
- date-range aggregation;
- trend-style grouped aggregation;
- one new movement publication;
- projection rebuild;
- peak memory;
- authority bytes and projection bytes.

The million-event case is an adversarial scale boundary, not an expected
household size.

### E4 — failure and recovery comparison

Test concrete failure shapes:

~~~text
projection deleted
projection truncated/corrupt
projection schema version unknown
process killed during projection rebuild
process killed during canonical publication
two readers during one writer
stale projection after newer authority generation
~~~

For architecture B, the expected recovery for projection-only failures is
usually "discard and rebuild".

For architecture C, the same failure may affect household authority and therefore
requires a stronger qualified recovery story.

### E5 — bounded SQLite-authority prototype

Only after E1-E4, create a separate experimental SQLite authority adapter.

It must reconstruct the same admitted Actual semantic image used by current
Reviews. Do not rewrite Reviews to SQL merely to make the prototype look good.

Compare:

~~~text
text authority -> Actual image
SQLite authority -> Actual image
~~~

before comparing UI or report performance.

## Evaluation matrix

Record evidence under these axes:

| Axis | Text authority | Text + SQLite projection | SQLite authority |
| --- | --- | --- | --- |
| semantic transparency | baseline | should preserve baseline | must be demonstrated |
| human inspection | strong | strong authority + SQL tooling | SQL/tool mediated |
| Git diff of authority | direct | direct | indirect/export needed |
| indexed query | application-owned | strong | strong |
| incremental write | whole-image Actual | authority still whole-image | strong candidate |
| crash protocol | LOAM-owned staged image | same authority + disposable DB | SQLite-owned plus adapter policy |
| cache deletion safety | n/a | required | not applicable |
| schema migration risk | wire migration | projection rebuild | authority migration |
| portability | plain text + documented grammar | text authority preserved | SQLite file format |
| implementation size | baseline | extra read model | may delete and add different machinery |

Do not pre-fill performance or code-size conclusions.

## Decision gates

### Keep text-only authority if

- measured household-scale performance is already negligible;
- SQLite projection does not materially improve a real query;
- or the projection adds more moving pieces than it removes.

### Keep text authority + SQLite projection if

- query/analysis performance improves materially;
- the DB is demonstrably rebuildable and disposable;
- production write semantics remain simpler as file authority;
- and no needed write capability requires relational storage.

### Consider SQLite canonical authority only if all are true

1. a concrete production problem remains after trying a disposable projection;
2. the SQLite adapter reconstructs the same admitted semantic image;
3. migration and recovery can be qualified without inventing household facts;
4. the new design deletes or materially simplifies existing persistence
   mechanisms rather than merely duplicating them;
5. long-term escape/export remains explicit and independently usable.

## Important non-goals

This study does **not** assume:

- SQL tables should become LOAM Core concepts;
- SQLite constraints replace Lean semantic admission;
- WAL is automatically preferable;
- database storage implies cloud sync or multi-user operation;
- a performance win alone justifies changing household authority;
- Plain Text Accounting conventions should dictate LOAM semantics.

## First provisional result

Existing systems support the experiment but do not decide it for LOAM.

The strongest prior evidence is:

~~~text
SQLite:
    mature embedded application storage

hledger:
    plain-text journal + SQLite projection is practical

Beancount:
    text authority still develops strong query-engine pressure

GnuCash:
    XML and SQL backends can coexist; SQL is not automatically superior
~~~

LOAM adds a distinct question because its persistence boundary already includes
typed semantic re-admission, fail-closed authority, retained correction /
provenance evidence, and explicit projection non-authority.

Therefore the first implementation experiment should be **B: disposable SQLite
projection**, not a canonical migration.

That experiment is intentionally reversible and can provide the evidence needed
to decide whether architecture C deserves implementation at all.


## First executable result — E1 / narrow E2 passed

The first bounded implementation is now retained under
`experiments/sqlite_projection/`.

It deliberately does not read private household data. The fixture contains five
balanced Actual Events, including one correction pair. It is first published
through the real normalized Actual authority, then reloaded as an admitted
image. Only after that admission does the experiment derive Actual Review
records and materialize them into SQLite.

The SQLite read model currently owns two tables:

~~~text
actual_records
effects
~~~

and indexes for date ordering and Locus/Measure lookup. It has no write-back
path.

CI result on the first executable checkpoint:

~~~text
Build completed successfully (130 jobs).

[ok] admitted Actual records: 5
[ok] current records: 4
[ok] newest-first current ids:
     event-book, event-topup, event-coffee-new, event-grocery
[ok] wallet/jpy current quantity: 3060
[ok] two independently rebuilt SQLite projections equal LOAM answers
[result] SQLite remained a disposable read model; actual.loam remained authority
~~~

The fixture checks four initial semantic correspondences:

1. retained review-record count;
2. correction-aware current record count;
3. newest-first current Event identity order;
4. correction-aware current quantity for one Locus / Measure coordinate.

A second SQLite database is independently rebuilt from the same admitted image
and must produce the same query-visible answer. This is a small but concrete
witness for the rebuildability requirement in H2.

### What this result does not show

This checkpoint does **not** establish that SQLite should become production
infrastructure.

It does not yet measure:

- realistic or adversarial scale;
- projection rebuild time;
- indexed-query speed against current Lean review paths;
- memory use;
- stale projection detection;
- interrupted rebuild recovery;
- database-authority migration or recovery.

The next useful experiment is therefore E3-style scale/query measurement, while
keeping the SQLite database disposable. Canonical SQLite authority remains
premature.

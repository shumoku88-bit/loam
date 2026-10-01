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


## E3 / E3.1 result — the first scale wall is encoder mechanics, not text I/O

The first E3 run reached 100,000 synthetic Events and exposed a steep canonical
publication curve. E3.1 then decomposed the publication path and corrected the
pure-LOAM query benchmark so results are forced before the timer stops.

Representative GitHub Actions measurements from the E3.1 runner:

| Events | admission | encode incl. re-admission | stage write | staged decode | reconstructed publication | forced LOAM latest-window | SQLite latest-window | forced LOAM food sum | SQLite food sum |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 1.086 ms | 54.388 ms | 0.136 ms | 4.506 ms | 59.274 ms | 0.008 ms | 0.025 ms | 0.007 ms | 0.168 ms |
| 10,000 | 12.218 ms | 6,063.211 ms | 0.312 ms | 52.608 ms | 6,118.281 ms | 0.101 ms | 0.111 ms | 0.132 ms | 1.718 ms |

At 10,000 Events, encoding with its ordinary re-admission consumed about 99% of
the reconstructed publication time. The raw stage write was about 0.3 ms and
stage read about 2.1 ms for an approximately 1.04 MB canonical text file.

The 10x increase from 1,000 to 10,000 Events produced roughly:

~~~text
semantic admission:       11.3x
staged typed decode:      11.7x
encode with re-admission: 111.5x
~~~

That is strong evidence against "plain text I/O is the first wall". The wall is
inside the current encoder path.

Code inspection gives a concrete mechanism consistent with the measurement.
The production encoder currently:

- grows the output list repeatedly with `rows := rows ++ [row]`, making row
  accumulation increasingly expensive;
- searches the full validity fact list to find each Event's base date;
- scans the full validity fact list again for every Event to discover date
  revisions;
- performs additional per-Event linear lookups for descriptions and selected
  evidence families.

The E3 synthetic world has no date revisions, yet the complete validity list is
still traversed once per Event by the revision loop. This supplies a direct
quadratic pressure independent of filesystem performance.

This is not yet a proof that every production encoder cost is quadratic, but it
is now a falsifiable implementation hypothesis with a precise next experiment:
replace repeated scans/append growth with transient indexes and reverse/linear
row accumulation, then require byte-for-byte wire equivalence and rerun the same
scale benchmark.

### Query-side result

Once the admitted image is already in memory, the simple LOAM scans are not
losing to SQLite at household-like scales in this experiment.

At 10,000 Events:

~~~text
latest-window:
  forced LOAM scan  101 us
  SQLite indexed    111 us

food/jpy aggregate:
  forced LOAM scan  132 us
  SQLite indexed   1718 us

SQLite open + first latest-window query:
  274 us
~~~

These are workload-specific observations, not a general SQL verdict. They do
show that the first measured reason to adopt SQLite is **not** these two simple
queries.

### Updated provisional conclusion

E3.1 weakens the case for SQLite canonical authority.

The immediate engineering question is now:

> Can the normalized text encoder be made near-linear while preserving the exact
> canonical wire and semantic admission laws?

If yes, plain-text authority survives the first measured scale attack. SQLite
can remain a disposable relational projection for query shapes that actually
benefit from indexing.

Only if publication remains a practical wall after fixing the identified
encoder mechanics does SQLite canonical authority regain force as a storage
candidate.


## E3.2 result — indexed byte-identical candidate removes the observed encoder wall

E3.2 tested the concrete implementation hypothesis from E3.1 without changing
production persistence.

The experimental candidate supports only the synthetic V1 benchmark shape. It
still performs ordinary LOAM semantic admission, but replaces repeated per-Event
linear scans with transient HashMaps and replaces growing List append with
Array.push row assembly.

A benchmark run is accepted only when:

~~~text
production encoder bytes == candidate encoder bytes
~~~

exactly. Both the 1,000-Event and 10,000-Event CI cases passed that byte equality
gate.

Representative GitHub Actions measurements:

| Events | production encode | indexed candidate | speedup | semantic admission |
| ---: | ---: | ---: | ---: | ---: |
| 1,000 | 58.721 ms | 2.373 ms | 24.7x | 1.369 ms |
| 10,000 | 7,889.193 ms | 26.981 ms | 292.4x | 15.422 ms |

The scale curve is more important than the absolute runner timings.

For a 10x increase in retained Events:

~~~text
semantic admission:  ~11.3x
indexed candidate:   ~11.4x
production encoder: ~134.4x
~~~

The candidate therefore tracks the near-linear admission curve while the current
production encoder grows superlinearly on the same evidence and emits the same
canonical bytes.

This is strong falsification of the first "plain text is the storage wall"
hypothesis. On this workload, the measured wall is implementation mechanics in
the production encoder, not the normalized text representation or filesystem
write.

### Consequence

The next production experiment should no longer be "replace text with SQLite".

It should be:

> Generalize the E3.2 mechanics across the complete normalized Actual vocabulary
> while preserving byte-for-byte canonical output and all existing semantic
> admission tests.

That production refactor must cover, rather than silently omit:

- Merchant, Exchange, OriginalAmount, and MovementOperation evidence;
- correction and reversal lookup;
- validity revisions;
- Relation and Discharge grouping;
- settlement row families;
- every current normalized Actual wire version.

Only after that full encoder is qualified should 100,000-Event publication be
rerun. If the full encoder becomes near-linear, the first measured justification
for SQLite canonical authority disappears. SQLite may still be useful as a
disposable query projection for workloads that actually benefit from relational
indexes.


## E3.3 result — production text authority survives the first scale attack

E3.3 moved the indexed / linear mechanics from the narrow research candidate
into the complete production `encodeNormalizedActual?` path.

The production encoder now builds transient indexes for Event-scoped retained
evidence, groups validity revisions / Relations / Discharges once, and
accumulates output rows through an Array rather than repeatedly copying a
growing List. Semantic admission still occurs before encoding and normalized
wire spelling / ordering remains unchanged.

Qualification includes exact canonical byte checks for the established V1
fixture and qualified Exchange fixture, while the E3.2 synthetic benchmark still
requires:

~~~text
production wire == narrow candidate wire
~~~

before timing is accepted.

Representative GitHub Actions measurements after the production change:

| Events | production encode | narrow candidate | staged decode | reconstructed publication |
| ---: | ---: | ---: | ---: | ---: |
| 1,000 | 3.003 ms | 2.336 ms | 5.664 ms | 9.089 ms |
| 10,000 | 26.883 ms | 26.198 ms | 62.654 ms | 92.454 ms |
| 100,000 | 538.381 ms | 538.519 ms | 1,377.071 ms | 1,945.896 ms |

At 100,000 Events the canonical text file is about 10.6 MB. Raw stage write is
about 2.6 ms and stage read about 27.8 ms. The previous E3 checkpoint measured
roughly 875 seconds for the 100,000-Event publication path on CI; the new
representative run is about 1.95 seconds. Runner variation prevents treating the
ratio as a product guarantee, but the order-of-magnitude change is decisive.

The production encoder and the narrow E3.2 candidate now have effectively the
same timing at 10,000 and 100,000 Events. The original superlinear encoder wall
has therefore been removed rather than hidden by a different storage format.

### New dominant boundary

After encoder linearization, staged typed decoding / semantic reconstruction is
the largest measured publication component at 100,000 Events:

~~~text
production encode incl. admission:  ~0.54 s
stage write + read:                  ~0.03 s
staged typed decode:                 ~1.38 s
total reconstructed publication:    ~1.95 s
~~~

This shifts any future persistence-performance work away from text output and
toward decode / reconstruction / admission only if real household operation ever
needs it.

### Query-side scale observation

At 100,000 Events:

~~~text
latest-window:
  forced LOAM scan   ~5.4 ms
  SQLite indexed     ~1.4 ms

food/jpy aggregate:
  forced LOAM scan  ~10.9 ms
  SQLite indexed    ~35.3 ms

SQLite projection rebuild:
  ~1.85 s
~~~

SQLite wins the selective date-window query in this synthetic workload, while
the in-memory LOAM scan remains substantially faster for the simple aggregate.
This supports workload-specific projection rather than database-first migration.

### Updated conclusion

The first measured case for SQLite canonical authority is now falsified.

Plain-text canonical authority is no longer the observed publication bottleneck
at even the 100,000-Event adversarial scale. SQLite remains technically useful
as a disposable relational projection when a query shape earns indexing, but
there is currently no measured persistence-performance reason to replace
`actual.loam` as household authority.

Future database work should therefore be demand-driven by concrete query or
operational requirements, not by the former encoder scale curve.

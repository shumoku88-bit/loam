# Investment semantic kernel comparison — 2026-09-27

Status: external-pressure synthesis after Observations 345–347

This note asks a narrower question than how LOAM should implement stocks:

> What is the smallest durable semantic boundary that can support investment accounting without distorting the neutral household Core?

The comparison uses four external designs for different reasons:

- TigerBeetle: minimal immutable transfer mechanics and same-ledger invariants;
- hledger 2 preview: current lot / basis / reduction-policy design;
- Beancount Vnext: inventory / booking separation and trading design pressure;
- GnuCash: explicit durable Lot object and capital-gain workflow.

The objective is not compatibility with any one system. It is to find which distinctions survive across several mature designs, then test whether LOAM can retain those distinctions with a smaller kernel.

## 1. TigerBeetle: strong mechanics, thin semantics

Primary sources:

- https://docs.tigerbeetle.com/coding/data-modeling/
- https://docs.tigerbeetle.com/coding/recipes/currency-exchange/
- https://docs.tigerbeetle.com/reference/transfer/
- https://docs.tigerbeetle.com/single-page/

TigerBeetle keeps its physical vocabulary intentionally small: Account, Transfer, ledger. One Transfer moves one amount between one debit account and one credit account on the same ledger. Cross-ledger exchange is composed from two same-ledger Transfers executed atomically.

Important distinction:

    linked execution != durable semantic relationship

TigerBeetle explicitly says linked execution metadata is not retained after the chain executes; a separate user-data identifier is needed if several Transfers must remain associated.

This is useful pressure for LOAM: keep mechanical consistency laws small, do not confuse execution mechanics with durable business meaning, and let domain meaning live above physical transfer mechanics.

But TigerBeetle is not a direct household observation model. Its currency-exchange recipe introduces liquidity-provider accounts on both ledgers. LOAM deliberately avoids inventing unobserved outside-household balances merely to force per-Measure closure. The lesson is architectural, not representational.

## 2. hledger 2 preview: transacted cost, basis, identity, and policy are separate

Primary sources:

- https://hledger.org/SPEC-lots.html
- https://hledger.org/DECISIONS.html
- https://hledger.org/relnotes.html

As of the 1.99.x previews for hledger 2, the lot design explicitly separates transacted cost or price from cost basis. A posting may carry either, both, or neither.

The current specification also separates LotId from cost. CostBasis contains date, optional label, and cost; LotId contains acquisition date plus optional label. This matters because AVERAGE pooling can change basis without changing lot identity.

Reduction method is also separate policy: SPECID, FIFO, LIFO, HIFO, and AVERAGE select or compress lot state rather than redefining physical transaction history.

This supports LOAM's earlier results: acquisition basis is not valuation, retained provenance is not today's booking policy, and historical attribution must not be reconstructed from current policy.

## 3. Beancount: inventory and booking are computation boundaries

Primary sources:

- https://beancount.github.io/docs/
- https://beancount.github.io/docs/beancount_v3/

Beancount places substantial meaning in Inventory and booking. Vnext distinguishes parsed/unbooked directives from resolved/booked directives and aims to expose booking as a reusable operation.

For LOAM the useful lesson is not to copy a mutable Inventory object. The useful separation is:

    physical Effects
      + acquisition provenance and basis
      + disposal attribution
      + selected booking policy
      -> derived position and gain answers

Beancount also leaves stock splits as a difficult design edge, reinforcing that acquisition identity and current quantity identity are not always the same thing.

## 4. GnuCash: durable Lot is a stronger user-visible promise

Primary sources:

- https://code.gnucash.org/docs/STABLE/group__Lot.html
- https://www.gnucash.org/docs/v5/C/gnucash-manual/tool-lots.html
- https://www.gnucash.org/docs/v5/C/gnucash-guide/invest-sell1.html

GnuCash uses a first-class GUID-backed Lot. A Lot groups Splits, may be created before membership exists, has title and notes, and can later gain or lose members. Security buys and sells are linked through Lots, and scrubbing may generate gain/loss transactions.

This proves a durable Lot object is useful. It does not prove every accounting kernel needs one. LOAM Observation 294 reaches the same stable-identity requirement only when the product promises an independently created durable subject whose identity survives payload changes.

## 5. The new pressure: cross-Measure mechanics

Observations 345–347 compare three independently meaningful occurrences:

    currency exchange
      -15000 jpy
        +100 usd

    security acquisition
       -1000 jpy
          +3 acme-share

    stock split
          -3 pre-share
          +6 post-share

All three can satisfy the same narrow mechanical checks: selected negative source Effect, selected positive destination Effect, distinct Measures, support restricted to those Measures, negative source residual and positive destination residual.

But they answer different domain questions: Exchange, SecurityTrade, SplitTransformation.

Observation 347 therefore qualifies:

    equal two-Measure mechanics != equal semantic authority

The clean shared abstraction, if promoted later, is a private or pure Application validation mechanic, not a universal CrossMeasureTransaction semantic type.

## 6. Why not copy TigerBeetle literally?

A TigerBeetle-like household representation could force every Measure to balance by adding external counterparties. For example, a stock purchase could contain an external cash Locus and an external security Locus.

That removes the mixed-Measure exception but may invent facts LOAM does not observe: the external party's balances and an artificial clearing or liquidity Locus.

For an operational transfer database this is appropriate. For a household evidence system it may be epistemically stronger than the evidence.

So LOAM should borrow TigerBeetle's small immutable mechanics without automatically borrowing its external balancing accounts.

## 7. Why not allow arbitrary mixed-Measure Events?

The opposite extreme is also unattractive. If normalized Actual simply stopped checking per-Measure closure, a malformed unexplained Event could enter persistence without any retained semantic authority.

The useful target is:

    nonzero per-Measure residuals require an admitted semantic authority
    which owns why those residuals may coexist in one Event

not:

    any sparse mixed-Measure vector is automatically valid

## 8. Candidate: residual obligations plus semantic qualification

For one Event, derive the nonzero entries of Effect.measureTotals. Ordinary balanced Movement has no residual obligation.

A mixed-Measure Event has residual support and must be qualified by a domain frontier. ExchangeEvidence may qualify exchange residuals. A future SecurityTradeEvidence may qualify security/settlement residuals. A future SplitTransformationEvidence may qualify old/new-unit residuals.

The word residual is a mechanical description only. The persisted generic bypass token should remain absent.

The partition is:

    mechanical residual calculation: shared
    domain proof that the residual is legitimate: separate authority
    generic user-writable cross-Measure bypass: absent

Persistence may consume the result of domain admission without turning the shared helper into canonical evidence.

## 9. Investment stack above that boundary

Once a SecurityTrade is legitimately admitted, the investment stack can remain:

    Event / Effect / Measure
        -> exact physical cash and security quantities

    Effect anchors + provenance
        -> acquisition continuity

    acquisition basis evidence
        -> carried basis

    quantity-bearing disposal attribution
        -> consumed origin

    booking policy
        -> FIFO / LIFO / HIFO / SPECID / AVERAGE selection

    valuation evidence and policy
        -> current value / unrealised answer

    disposal settlement + consumed basis
        -> realised gain

No universal LotId, base currency, Rate, TransactionKind, or mutable Inventory object is currently required in neutral Core.

## 10. What would falsify this candidate?

Reopen the Core boundary if a practical case shows one of these:

1. domain evidence cannot qualify a real mixed-Measure Event without duplicating large mechanics;
2. several semantic families need one independently observable durable transform identity which EventId cannot supply;
3. correction/reversal requires one shared cross-domain transform lifecycle;
4. corporate actions require information not representable as additive provenance plus domain evidence;
5. average-cost policy cannot preserve required historical answers without changing retained provenance semantics;
6. a user workflow requires an independently created durable lot-like subject;
7. settlement timing introduces identity that cannot attach to existing Event, Effect, or relation anchors.

## 11. Provisional result

External systems converge on distinctions even though they materialize them differently:

    physical movement != transaction meaning
    transaction price != acquisition basis
    acquisition/basis state != disposal selection policy
    aggregate holding != acquisition provenance
    current payload != independently created durable subject identity

The current LOAM candidate is the least committal representation that preserves all of these:

> retain exact physical facts and independently observable evidence; share only pure mechanics; derive policy-selected accounting answers; promote durable nouns only after a user-visible identity promise requires them.

This is currently a cleaner fit for LOAM than copying TigerBeetle's external balancing accounts, hledger's LotId, Beancount's Inventory object, or GnuCash's mandatory Lot object wholesale.

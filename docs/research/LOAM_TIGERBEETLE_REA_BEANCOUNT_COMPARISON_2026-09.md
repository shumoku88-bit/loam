# LOAM / TigerBeetle / REA / Beancount semantic comparison — 2026-09-20

Status: **research checkpoint**

This comparison is not a feature ranking. The four systems solve overlapping but
different problems.

The question is:

> What does each system treat as primitive retained reality, what does it derive,
> and what kinds of uncertainty or incompleteness can it represent without
> inventing an answer?

## Sources and scope

LOAM side:

- `docs/SEMANTIC_BLUEPRINT.md`
- `docs/research/LOAM_COMPLETION_BOUNDARY_2026-09.md`
- current production Movement / Actual / Measure / export boundaries

External comparison:

- TigerBeetle current documentation:
  - https://docs.tigerbeetle.com/reference/account/
  - https://docs.tigerbeetle.com/reference/transfer/
  - https://docs.tigerbeetle.com/coding/data-modeling/
  - https://docs.tigerbeetle.com/coding/recipes/currency-exchange/
  - https://docs.tigerbeetle.com/coding/recipes/correcting-transfers/
- Beancount current documentation:
  - https://beancount.github.io/docs/
  - https://beancount.github.io/docs/getting_started_with_beancount/
  - https://beancount.github.io/docs/beancount_v3/
- REA:
  - William E. McCarthy, “The REA Accounting Model: A Generalized Framework
    for Accounting Systems in a Shared Data Environment”, 1982
  - Geerts & McCarthy, “An ontological analysis of the economic primitives of
    the extended-REA enterprise information architecture”, 2002
  - ISO/IEC 15944-4 background
  - Vandenbossche & Wortmann, “Why accounting data models from research are not
    incorporated in ERP systems”, 2006

## First-pass map

| Question | LOAM | TigerBeetle | REA | Beancount |
| --- | --- | --- | --- | --- |
| Primary purpose | household facts + justified answers | financial ledger kernel | enterprise economic ontology | explicit double-entry text ledger |
| Main retained vocabulary | Event, Effect, Locus, Measure, Quantity, explicit evidence | Account, Transfer, ledger | Resource, Event, Agent + relationships | Account, Transaction, Posting, Amount, Cost/Price directives |
| Account primitive? | no | yes | generally no conventional GL account as base ontology | yes |
| Transaction primitive? | no familiar transaction kind; Event is neutral | Transfer is central primitive | Economic Event is central | Transaction is central |
| Unit separation | Measure | ledger denotes asset/currency kind | Resource kind / economic resource | currency/commodity on Amount/Posting |
| Ordinary balance law | same-Measure signed Effects balance | debit/credit Transfer on same ledger | stock-flow / duality semantics | double-entry transaction balance |
| Correction style | retained correction/currentness evidence | Transfer immutable; correct with new Transfer | implementation-dependent event history | source text may simply be edited |
| Reports | projections over authority | application/read side | derived views/accounting applications | derived directly from ledger |
| Missing evidence | may make answer unavailable | not a core epistemic state | ontology can model commitments, not normally “history incomplete” | validation/assertions detect inconsistencies; missing history often padded or edited |
| Cross-currency exchange | deliberately separate from ordinary Movement | two atomically linked same-ledger transfers | duality between economic events/resources | multi-currency transaction/cost/price machinery |
| Human-readable escape format | explicit PTA/Beancount projections | not the kernel’s role | conceptual ontology, not a ledger file | the source is already plain text |

## 1. What is “the world” in each model?

### LOAM — retained observation before familiar accounting nouns

LOAM deliberately does not begin with Account, Transaction, Budget, Envelope,
Month, or Report as canonical facts.

Its small practical vocabulary is closer to:

```text
Event
  -> Effect
       -> Locus
       -> Measure
       -> exact Quantity

+ separately retained evidence
  -> validity
  -> correction
  -> relations
  -> lifecycle
  -> completeness / zero-origin support where needed
```

The familiar accounting world is reconstructed only where enough evidence exists.

That makes LOAM a model not only of quantities, but of **what the household is
entitled to claim from the retained evidence**.

### TigerBeetle — a minimal financial transfer machine

TigerBeetle begins after a major semantic decision has already been made.

The application has identified:

```text
Account A
Account B
ledger L
Transfer amount Q
```

TigerBeetle then guarantees strong mechanical properties around that financial
movement.

An Account and a Transfer are domain primitives. A Transfer debits one Account
and credits another on the same ledger. Transfers are immutable.

TigerBeetle therefore asks:

> Given a financial transfer we intend to record, how do we store and execute it
> with extremely strong ledger invariants?

LOAM asks an earlier question:

> What retained household evidence justifies describing this observation as a
> particular current quantity or accounting movement at all?

### REA — model the economic reality, not the bookkeeping artifact

REA is the closest conceptual ancestor to LOAM’s refusal to treat familiar
accounting objects as physical reality.

The original model centers:

```text
Resource
Event
Agent
```

and relationships such as stock-flow, duality, control and responsibility.

Extended REA adds constructs such as commitments and types.

The important philosophical move is that debits, credits, receivables, and many
general-ledger categories need not be the stored reality. They can be accounting
views over a richer economic model.

That resembles LOAM’s:

```text
retain small underlying evidence
        ↓
derive accounting-shaped answers
```

But LOAM is intentionally much less ontologically ambitious. It does not try to
encode a complete enterprise ontology.

### Beancount — accounting text is the source

Beancount starts much closer to conventional double entry:

```text
Transaction
  -> Posting
       -> Account
       -> Amount / commodity
       -> optional cost / price
```

The text file itself is intended to be readable, editable and authoritative.
Reports and inventories are computed from it.

This gives Beancount an enormous practical advantage:

> the durable representation is already a portable accounting document.

LOAM deliberately chooses a richer canonical model and therefore needs explicit
exporters to gain the same portability.

## 2. The important TigerBeetle resemblance

The strongest resemblance is not syntax. It is **where invariants live**.

TigerBeetle does not let application convenience weaken the ledger law:

```text
Transfer
    debit Account A
    credit Account B
    both on one ledger
```

LOAM similarly refuses:

```text
15000 jpy + 100 usd = balanced
```

Different Measures do not cancel merely because a human knows they were one
exchange.

TigerBeetle’s currency exchange recipe uses:

```text
currency A transfer
        +
currency B transfer
        +
atomic linkage
```

rather than one cross-ledger Transfer.

LOAM Observation 282 independently arrived near:

```text
cross-Measure exact Event facts
        +
explicit ExchangeEvidence(EventId)
```

The implementations need not converge. The shared design lesson is:

> Preserve conservation inside one quantity domain. Represent the relationship
> between different quantity domains separately.

That is strong evidence that LOAM’s multi-Measure boundary is not merely an
idiosyncratic restriction.

## 3. The important REA resemblance

REA’s original motivation included criticism of conventional accounting data for
being too aggregated, too classification-driven, too monetary, and insufficiently
integrated with the underlying economic phenomena.

LOAM shares the pressure but chooses a narrower response.

REA tends toward:

```text
rich economic ontology
  resources
  events
  agents
  commitments
  relationships
  policies / types / business process structure
```

LOAM tends toward:

```text
minimal retained evidence
  +
only the semantic family earned by a concrete household question
```

This is a significant difference.

LOAM should therefore resist a tempting conclusion:

> “REA is similar, so LOAM should add Agent, Resource, Commitment, Contract,
> Exchange, etc. as a complete ontology.”

The better lesson is methodological:

> Do not mistake an accounting presentation category for the underlying fact.

REA is evidence that this principle is old and serious. It is not evidence that
LOAM should copy the full REA ontology.

## 4. The important Beancount resemblance

Beancount and LOAM agree strongly on a different idea:

> reports should be derived from durable data rather than becoming separate
> hand-maintained authorities.

Beancount is especially strong at making this practical because the retained
ledger is already plain text and report-oriented.

LOAM takes the separation further:

```text
LOAM authority
      |
      +-> LOAM-specific Review
      |
      +-> PTA projection
      |
      +-> Beancount / Fava projection
```

The Beancount projection is disposable. It does not become household authority
merely because Fava is convenient.

This gives LOAM two layers:

1. richer semantic authority;
2. conservative ordinary accounting escape format.

That asymmetry is useful. A perfect round trip is not required.

## 5. Where LOAM is currently most unusual: epistemic state

This comparison found the clearest LOAM-specific distinction here.

LOAM explicitly keeps rules such as:

```text
unknown != zero
missing != false
insufficient evidence -> refusal is an answer
```

TigerBeetle’s pending Transfers are operational state, not a statement that the
database may lack the historical evidence required to know an Account balance.

REA’s commitments represent promised/future economic phenomena. They are not, by
themselves, a general semantics of incomplete observation.

Beancount has strong validation and balance assertions. It can expose a mismatch.
It also provides practical mechanisms such as padding when historical opening
detail is unavailable. But its central question is still:

> Is this accounting ledger internally usable and balanced?

LOAM additionally asks:

> Does this retained evidence justify answering the selected household question?

That is a different axis from ordinary double-entry correctness.

Example:

```text
There are some Events touching cash.
```

A conventional ledger may compute their sum.

LOAM may still refuse:

```text
current cash balance unavailable
```

if the required origin completeness has not been established.

That property deserves preservation because it is easy for UI convenience,
imports or migration code to erase accidentally.

## 6. Correction and history reveal another major split

### TigerBeetle

Transfers are immutable. Correction happens by recording additional Transfers.
This naturally preserves an audit trail.

### LOAM

The selected current answer is derived from retained correction / validity /
lifecycle evidence rather than casually erasing provenance.

This is close in spirit to TigerBeetle but richer in semantics: LOAM must also
decide which retained fact is current for a household question.

### Beancount

The text ledger can simply be edited.

Git can preserve file history, but Beancount itself does not require every
historical correction to remain as an immutable accounting event.

This is easier for a human-maintained ledger and is one reason plain-text
accounting stays pleasantly small.

### REA

REA says much about what an economic event *is*, but concrete correction,
versioning and operational currentness policies belong to an implementation.

This is one place where LOAM is not simply “REA implemented in Lean”.

## 7. Known walls that matter to LOAM

### Wall A — purpose-neutral models need more detail when reality becomes specific

Research on REA adoption in ERP systems found an important pressure.

A purpose-neutral semantic model can be attractive, but actual enterprise
operation needs details such as terms, fulfillment, business-process conditions,
and many other facts.

If those are not modeled, the supposedly general model is insufficient.
If all are modeled pre-emptively, it becomes enormous.

LOAM’s current answer is preferable for its household scale:

```text
do not complete the ontology in advance

real question cannot be answered
        ↓
identify the smallest missing evidence
        ↓
qualify only that semantic addition
```

That is probably one of LOAM’s most important defenses against REA-style
ontology expansion.

### Wall B — clean semantic redesign is expensive to retrofit

The REA/ERP literature also notes that richer relationships embedded at the data
level can conflict with relationships already encoded in legacy application
logic. Retrofitting them can require major rewrites.

LOAM has an unusual advantage here because it is a new, small household system.
It is not trying to replace SAP’s decades of application behavior in place.

This may explain why a design that is awkward for existing ERP can still be
reasonable for a new personal-accounting authority.

### Wall C — dates and transfers are more complicated than one “transaction date”

Beancount’s own design notes call out transfers whose two institutional postings
settle on different dates as a core modeling difficulty.

That validates LOAM’s general instinct not to collapse:

```text
human story
institutional observations
settlement timing
currentness
```

merely because ordinary accounting UI wants one row.

### Wall D — multi-currency accounting is not merely “allow another commodity”

Beancount’s design discussions also document complications around currency
conversion and residual imbalances.

TigerBeetle solves a narrower operational problem by prohibiting cross-ledger
Transfers and composing exchange from linked same-ledger Transfers.

LOAM should keep its current discipline:

```text
multiple Measures
    !=
cross-Measure arithmetic
    !=
exchange identity
    !=
valuation
    !=
cost basis
```

## 8. A useful layered interpretation

The four systems can be placed on different layers rather than treated as
competitors:

```text
                 What happened in the world?
                           |
                    REA-like question
                           |
                           v
               What did we actually observe,
             retain, and have evidence to claim?
                           |
                       LOAM
                           |
                           v
               Which admitted value movement
                 must obey ledger invariants?
                           |
                TigerBeetle-like kernel
                           |
                           v
               How can ordinary accounting
              be written, queried and viewed?
                           |
                 Beancount / Fava
```

This is conceptual, not a proposed dependency graph.

LOAM does not need to import REA, run TigerBeetle, or make Beancount authoritative.

But the layering helps explain why LOAM can resemble all three without being a
clone of any one of them.

## 9. What LOAM appears to inherit from each

### From the REA family

- accounting categories need not be underlying reality;
- retain lower-level economic facts where useful;
- derive purpose-specific views rather than forcing one chart of accounts to be
  the universal ontology.

### From TigerBeetle-like ledger design

- make conservation rules structural;
- do not mix different asset / Measure domains just to satisfy a balance check;
- immutable or append-oriented correction is safer than silent history rewrite;
- a small kernel can support a much larger application without owning all
  business semantics.

### From Beancount / PTA

- text accounting is a powerful survival / interchange format;
- reports and rich presentation can remain derived;
- mature external viewers are often better than rebuilding every report surface;
- explicit syntax and external parser qualification are useful interoperability
  tests.

## 10. What LOAM should *not* copy automatically

### Do not become TigerBeetle

LOAM should not promote Account and Transfer to universal household ontology only
because they work extremely well inside a financial ledger kernel.

### Do not become full REA

LOAM should not add every plausible Resource / Agent / Commitment / Contract
family before a household question earns it.

### Do not become Beancount authority

LOAM should not flatten its richer provenance, unknown/completeness semantics,
Scheduled evidence or other qualified distinctions merely to make the canonical
format look like a familiar journal.

## 11. Falsification questions for the next years

The comparison suggests more useful tests than adding generic features.

LOAM’s architecture would gain strong evidence if it survives:

1. repeated schema migrations without changing household meaning;
2. a real cross-Measure exchange with fees;
3. institutional transfers whose two sides become observable on different dates;
4. incomplete imported history where “sum of known entries” must not masquerade
   as a known balance;
5. investment lots / acquisition basis without forcing valuation into Quantity;
6. a long history large enough that projections need acceleration without
   turning a cache into authority;
7. permanent retirement of LOAM while ordinary accounting history remains usable
   through PTA / Beancount export.

If these pressures require additive evidence or replaceable projections while the
small Core remains largely stable, that is meaningful evidence for the
architecture.

If they repeatedly force fundamental reinterpretation of Event / Effect / Locus /
Measure / Quantity, the current minimal ontology may be too weak.

## Conclusion

The comparison does **not** support the claim that LOAM discovered an entirely
new accounting architecture.

It supports a more interesting and more defensible description:

> LOAM sits at the intersection of several independently serious traditions.

REA supplies the pressure toward underlying economic facts and purpose-neutral
data.

TigerBeetle demonstrates the strength of a tiny financial kernel with hard
invariants and strict asset-domain separation.

Beancount demonstrates the durability and usefulness of explicit plain-text
double-entry data and derived reports.

LOAM’s distinctive combination is currently:

```text
minimal retained household evidence
        +
strong same-Measure movement invariants
        +
explicit provenance/currentness
        +
epistemic refusal when evidence is insufficient
        +
replaceable accounting/report projections
        +
a conservative plain-text escape route
```

The least common part of that combination is not double entry, immutability, or
event modeling individually.

It is the attempt to make **evidence sufficiency itself part of household
accounting semantics** while still preserving an escape into ordinary accounting
formats.

That is the property most worth falsifying and protecting in future LOAM work.

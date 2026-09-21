# Lot continuity: object identity vs provenance graph — 2026-09

Status: external comparison + LOAM pressure synthesis

This note asks a narrower question than "how should LOAM implement investments?":

> What is the durable thing being tracked when an acquisition is partially disposed, transferred, split, merged, or spun off?

The current LOAM pressure sequence is:

- Observation 287 — one acquisition source selected for one disposal;
- Observation 288 — one disposal consumes exact quantities from several sources;
- Observation 289 — a stock split makes acquisition Effect identity differ from the current quantity-bearing Effect identity;
- Observation 290 — a spin-off branches one acquisition origin into several current Effects;
- Observation 291 — two acquisition origins merge into one current physical Effect while origin-specific basis remains observable.

The sequence suggests a candidate reading:

    lot continuity
        may be
    provenance over changing quantity-bearing nodes
        rather than
    one physical Event/Effect identity

## 1. GnuCash: Lot is an explicit durable object

Primary documentation:

- https://cvs.gnucash.org/docs/STABLE/group__Lot.html
- https://code.gnucash.org/docs/STABLE/lotsoverview.html

GnuCash has a first-class GNCLot object with its own GUID.

The lot groups account Splits that belong to the same tracked item / quantity. A lot is normally opened by an acquisition and closes when its quantity balance reaches zero.

For investment gains, an acquisition opens a lot and a later sale Split is assigned into one or several existing lots. A single conceptual sale may therefore be represented as several lot-specific sale pieces.

This is the strongest durable-object design in this comparison:

    Lot GUID
       |
       +-- acquisition Split
       +-- partial-disposal Split
       +-- later partial-disposal Split

The object exists independently of any single Split.

## 2. hledger: lot identity survives relational transformations

Primary specification:

- https://hledger.org/SPEC-lots.html

hledger's current lot specification describes lot state using acquisition basis/date/optional label and retained lot state.

Several details are especially relevant to LOAM.

### Transfers preserve lot identity

A transfer-to recreates the source lot under the destination account. The specification explicitly says transfers preserve source lot identity and cannot rename the lot.

### Transfer topology is not one-to-one

hledger permits one source posting to feed several destinations and several source postings to feed one destination, as long as commodity totals match.

Selected lots are distributed across destination boundaries and may be split into fragments while lot identity is preserved.

### Average pooling intentionally destroys some identity

Under AVERAGE methods, incoming basis is merged into a running pool. The specification notes that original lot cost identity is lossy: after pooling, the old cost cannot necessarily be reconstructed on transfer back out; only some provenance such as date/label survives.

This gives a useful distinction:

    identity preserved by operation
        vs
    identity intentionally compressed by policy

That resembles LOAM's migration discipline: preserve, translate, or explicitly retire / leave unresolved.

## 3. Beancount: position/cost identity and an unresolved split edge

Primary documentation:

- https://beancount.github.io/docs/
- https://beancount.github.io/docs/beancount_v3/

Beancount positions combine units with cost information. Booking machinery matches reductions against existing positions/lots and carries cost/date/label information used for selection.

The Vnext design discusses recording references from booked reductions back to augmenting postings for trade-pair reporting.

But the same Vnext document says stock splits still need a strategy. That matters because stock split is precisely where the simple interpretation 'acquisition posting = current lot quantity' stops working.

## 4. External comparison

| System | Main continuity mechanism | Transformation behavior |
| --- | --- | --- |
| GnuCash | explicit Lot object / GUID | Splits are assigned to one durable Lot |
| hledger | retained lot state identified by basis/date/label | lots may be split/distributed across transfer topology; some policies intentionally merge identity |
| Beancount | booked Position / cost identity | reductions select positions; stock split remains a design edge |
| LOAM observations | Effect anchors + additive provenance evidence | physical identity may change while origin continuity is carried by relations |

There is no external evidence that a first-class Lot object is the one settled answer.

There is strong evidence that a serious system must retain information that survives aggregate balance projection: acquisition origin, basis, partial quantity consumption, transfer/corporate-action continuity, and booking/selection policy where required.

## 5. LOAM pressure sequence

Observation 287: one complete acquisition is disposed. EventId + EffectKey plus acquisition basis and disposal source attribution is sufficient for the selected gain answer.

Observation 288: one disposal consumes several acquisitions. Source identity set is insufficient; exact quantity per source is independently observable.

Observation 289: a stock split transforms one acquisition quantity into a new quantity-bearing Effect. Acquisition Effect identity is not current quantity-bearing Effect identity. A narrow lineage relation bridges them.

Observation 290: a spin-off branches one acquisition origin into parent and child current Effects. Physical quantity transformation, acquisition lineage, and basis allocation remain distinct.

## 6. Candidate interpretation

The strongest current LOAM reading is not:

    Lot = acquisition Event

and not yet:

    Lot = mandatory new durable object

It is closer to:

    physical node
        EventId + EffectKey

    provenance edges
        origin/current Effect relation
        optionally exact quantity-bearing

    basis evidence
        attached to acquisition origin
        or allocated across provenance branches

    policy
        selects / merges / transforms provenance where required

A lot could then be a derived connected provenance component for a selected query, rather than a primitive household noun.

## 7. But the graph hypothesis can still fail

The provenance-graph interpretation should not be promoted yet.

A durable LotId becomes independently pressured if a selected real query needs one stable identity that cannot be reconstructed from the retained graph.

The strongest candidate pressures are:

### Many-to-one merger

    origin A --\
               -> current merged Effect
    origin B --/

If A and B must remain separately observable for basis or holding-period rules, the current Effect clearly cannot be the lot identity. Graph edges may still suffice.

### Repeated transformations

    acquire -> split -> transfer -> merger -> spin-off

If the selected query is transitive (what acquisition origin does this current quantity descend from?), graph traversal may suffice.

If users or external authorities need a stable identity independent of that path, a durable Lot identity may be earned.

### Identity-preserving merge vs identity-destroying pooling

hledger's AVERAGE behavior is especially useful pressure. Some policies intentionally collapse distinctions.

LOAM would then need to distinguish lineage remains separately observable from policy explicitly retires separate origin identity.

## 8. Provisional conclusion

External systems support both sides:

- GnuCash demonstrates that a durable Lot object is workable and useful.
- hledger demonstrates that lot continuity already behaves relationally through split/merge transfer topology, and that some policies intentionally erase identity.
- Beancount demonstrates that cost-position booking can go far without one obvious universal lot object, while corporate actions remain a difficult boundary.

LOAM's current observations therefore support the research hypothesis:

> lot continuity may be best understood first as retained provenance over changing quantity-bearing Effects.

But they do not yet justify:

> LOAM should never have a LotId.

Observation 291 then applied the many-to-one merger pressure.

Two independently acquired origins feed one current physical Effect, with exact current quantity carried on separate provenance edges. A later one-unit disposal can be attributed to either origin, and the two attributions produce different realised-gain answers because the origin bases differ.

So the graph hypothesis now survives one-to-one, one-to-many, and many-to-one selected transformations.

That substantially strengthens the research hypothesis, but it still does not prove that a LotId is never useful.

The next evidence that would genuinely earn a first-class Lot identity should be a selected query requiring one stable reference that is not equivalent to an acquisition origin, a current physical Effect, or a reconstructable provenance component/path. Examples include an externally supplied stable lot identifier, annotations that must survive graph rewrites, or correction semantics that replace provenance edges while preserving one referenced lot identity.


## 9. External stable lot references

The strongest new pressure is not another corporate-action topology.

A current brokerage API exposes a lot identifier as independently observed,
operational data.

Public.com's July 2026 tax-lot API adds:

- endpoints that return unrealized tax lots;
- a provider-supplied `lotSelectionId` on each returned lot;
- sell-order tax-lot matching instructions that let the caller specify which
  lots are sold.

Primary sources:

- https://public.com/api/docs/resources/tax-lot-selling/get-unrealized-tax-lots-for-symbol
- https://public.com/api/docs/resources/order-placement/place-order
- https://public.com/api/docs/changelog

The important point is not the spelling of Public's field.

It is that the external brokerage boundary has its own lot reference that can be
observed and used in a later operation.

This creates two worlds with identical:

```text
physical Effects
provenance graph
basis
quantity
acquisition date
```

but different externally reported lot identifiers.

Therefore:

```text
complete internal provenance graph
    -/->
external lot identifier
```

Observation 292 captures this information boundary.

This is the first selected pressure where a stable lot-like reference is
independently observable even after the internal graph is fully retained.

However the minimum earned representation is still not necessarily a universal
LOAM `LotId`.

A source-scoped external identity is smaller:

```text
(provenance subject)
+
(provider / account namespace, external lot id)
```

The namespace matters because an external identifier is meaningful under the
authority that issued it; LOAM must not silently reinterpret one provider's
identifier as a universal household identity.

IRS specific-share rules reinforce the semantic need for distinguishable shares
without prescribing one universal lot-id scheme. Publication 550 says that a
taxpayer using specific-share identification must specify the particular shares
to the broker/agent at sale or transfer and receive confirmation; if the shares
cannot be identified, FIFO applies. The tax rule therefore requires an adequate
identification relation, not one globally standardized LotId.

Primary source:

- https://www.irs.gov/publications/p550

So the new result is:

```text
stable external lot reference is real
    !=
universal internal LotId is already earned
```

## 10. Updated falsification target

The graph hypothesis is now qualified rather than absolute:

```text
internal lot-like continuity
    may be reconstructed from provenance graph

external lot identity
    must be retained as separate evidence when observed
```

A first-class LOAM-owned `LotId` becomes independently pressured only when
LOAM itself needs one stable referent that is not reducible to:

- one acquisition origin;
- one current physical Effect;
- a provenance component/path;
- or one external authority's identifier.

The most useful next examples would be:

- a user annotation intended to follow one lot through transformations;
- a correction that replaces provenance edges but must preserve the referenced
  lot subject;
- several external custodians assigning different IDs to what LOAM judges to be
  one continuing lot-like subject.

Those cases test whether LOAM needs a stable semantic subject *above* both the
graph and external identifiers.

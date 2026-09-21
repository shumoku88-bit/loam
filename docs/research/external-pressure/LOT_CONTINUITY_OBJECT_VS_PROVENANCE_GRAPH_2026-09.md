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


## 11. User annotation and several external aliases still do not force LotId

The first post-Observation-292 candidate was durable user annotation.

This is a real product requirement rather than a synthetic one. GnuCash gives a
Lot its own GUID and exposes editable Lot Title and Notes:

- https://cvs.gnucash.org/docs/STABLE/group__Lot.html
- https://code.gnucash.org/website/docs/v5/C/gnucash-manual/tool-lots.html

That demonstrates the usefulness of a stable lot-local place to attach human
meaning.

However LOAM already has two pieces that make this pressure weaker than it first
appears.

First, retained provenance gives historical Effect anchors that do not disappear
merely because current quantity moves to a later Effect.

Second, production correction semantics already derive a stable Event root via
correctionRootTerminalEvents?.

Observation 293 combines those facts with:

- a retained historical Effect anchor;
- a provenance edge to the current Effect;
- an Event correction whose current terminal changes;
- two custodians assigning different source-scoped external lot ids;
- one user annotation.

The annotation is independently observable evidence. Two worlds can have the
same provenance and the same external lot aliases while only one contains the
annotation.

But the annotation can still target the retained historical provenance anchor.
The two provider ids can target that same anchor as well.

So neither user notes alone nor multiple provider lot ids alone require a new
LotId.

The stronger current boundary is:

LotId becomes independently pressured only if a stable internal subject is
required and no retained Effect anchor, canonical provenance component/key, or
existing correction root can serve as that referent.

This also raises a naming caution. If that boundary is eventually crossed, the
earned abstraction may be a generic stable semantic subject / annotation target
rather than an investment-specific LotId.

Observation 293 therefore narrows rather than expands the Core.

### External transfer evidence still points the same way

Current IRS transfer-statement rules require separate transfer information for
the same security when acquisitions differ by date or price, and require
adjusted basis / original acquisition information to cross the broker boundary.
DTCC CBRS likewise transfers associated Tax Lot records between firms and
supports correction/rejection workflows.

Those systems demonstrate that acquisition distinctions and corrections must be
retained operationally. They still do not establish one cross-provider universal
lot identifier that LOAM must adopt.

Primary sources:

- https://www.irs.gov/instructions/i1099b
- https://www.dtcc.com/products-and-services/clearing-settlement-services/equities-clearing/cost-basis-reporting-service


## 12. The boundary finally moves: independently created durable subjects

Observation 293 eliminated two tempting reasons for a new LotId: user notes
alone and several provider aliases alone. Both can still attach to a retained
provenance anchor.

A stronger real design exists.

The current GnuCash Lots Editor can create a new Lot before it is linked to any
split. The new Lot has a title and notes; free splits can later be linked into
it or unlinked from it. The engine representation gives the Lot its own GUID.

Primary sources:

- https://www.gnucash.org/docs/v5/C/gnucash-manual/tool-lots.html
- https://cvs.gnucash.org/docs/STABLE/group__Lot.html

That changes the identity question fundamentally.

A subject that can exist while its member set is empty cannot be identified by
an acquisition Effect or provenance component at creation time.

If the product also permits:

- title / note edits;
- membership changes;
- provider alias changes;
- two separately created subjects with otherwise identical current payloads;

then current payload is not the object identity.

Observation 294 models exactly that case. Two snapshots can retain identical:

- members;
- complete lineage;
- provider-scoped external lot ids;
- title;
- note;

while still representing two independently created internal subjects.

A single subject can also persist from an empty pre-provenance state through a
populated state and then through a different membership state.

This is the first selected pressure in the sequence that earns some
LOAM-owned stable subject identity, conditional on supporting this user-created
durable-object workflow.

### But this still does not uniquely earn Core.LotId

The representation question remains open.

GnuCash chooses an opaque GUID-backed Lot object.

hledger's current 2026 lot specification chooses a semantic LotId made from
acquisition date plus optional label:

- https://hledger.org/SPEC-lots.html

hledger also states that transfers preserve source lot identity and cannot
rename the lot. Under average pooling, some original cost identity is lossy but
date and label remain.

So external designs show at least two viable families:

1. opaque durable object identity;
2. semantic/content-keyed lot identity.

For LOAM there is a third question as well: whether this identity should be
investment-specific at all. A generic stable semantic subject could also support
other user-created named groupings.

The refined boundary is therefore:

stable LOAM-owned identity is earned
only if LOAM promises independently created durable subjects whose identity
survives changes to all derivable/current payload.

That does not yet imply:

Core.LotId is earned unconditionally.


## 13. Cross-domain convergence: Observation 204 already found stable subject pressure

Observation 294 is not the first place in LOAM research where a stable semantic
subject has appeared.

Earlier Observation 204 asked whether two pre-Scheduled partial-knowledge
pressures could share one subject-attached carrier. Its bounded result retained
four separately observable dimensions:

- stable subject identity;
- known existence;
- exact quantity evidence;
- exact temporal evidence.

It also showed that loose identity-free amount and due pools cannot reconstruct
which values belong to which subject once several subjects exist.

Observation 204 deliberately stopped short of introducing a production Subject
type. It classified the idea as a research-only conservative-extension
candidate.

The investment sequence now reaches the same architectural shape from a
different direction.

Observation 294 starts from a user-created durable lot-like object whose
membership, aliases, title, and note may all change. If independently created
objects with identical current payload must remain distinguishable, some stable
subject identity is required.

The convergence is therefore:

pre-Scheduled partial knowledge
    -> stable subject needed for attachment correspondence

user-created durable lot-like object
    -> stable subject needed across changing payload

This weakens the case for an investment-specific Core.LotId and strengthens the
case for keeping the next research question generic.

There is still no production StableSubjectId or SubjectId on current main, and
SA-010 explicitly rejected adding a generic Identity ontology without an earned
semantic reason. That discipline should remain in force.

The next falsification question is therefore not "should LOAM add LotId?" but:

Can one small typed stable-subject abstraction satisfy both the Observation 204
partial-knowledge pressure and the Observation 294 user-created durable-object
pressure without collapsing their domain-specific evidence?

Until that question is qualified and dogfood requires such a subject, the
production Core should remain unchanged.


## 14. Observation 295 — share the identity shape, not one global identity space

Observation 295 tests the cross-domain convergence directly.

The candidate is intentionally smaller than a production Subject object:

```text
StableSubjectId Domain
Attached Domain Value
```

The same typed schema is used for both selected pressures while their evidence
remains domain-specific.

For the pre-Scheduled case, subject-attached amount/due evidence preserves the
pairing that identity-free value pools lose.

For the user-created lot-like case, subject identity still distinguishes two
independently created subjects with identical complete current payload and
survives a transition from no members to populated membership.

The important negative result is domain erasure.

The raw token `subject-1` can legitimately exist in both the pre-Scheduled and
lot domains. If a generic implementation erased the semantic domain and kept
only one global token space, unrelated subjects would become accidentally
joinable.

So the bounded compression result is:

```text
shared identity implementation shape
    YES

shared untyped global identity namespace
    NO

shared domain-specific evidence payload
    NO
```

This is a better fit with SA-010 than either extreme.

An investment-specific `LotId` is not forced by the cross-domain evidence, but
a universal untyped `SubjectId` would also overstate semantic commonality.

The smallest successful research shape is a domain-indexed stable identity
schema. Production remains unchanged until two real production domains need the
lifecycle strongly enough for shared mechanics to pay for themselves.

# Observation 265 — description / party derivation boundary

Status: **QUALIFIED by Alloy 6.2.0 / Sat4j**

Baseline:

```text
shumoku88-bit/loam
main: 0e6621a105e881773c61cef88299c434366410d6
stacked on Observation 264 branch head: adf4549b4a6386602408517177a5d55d0c634147
```

Exact qualified branch head before this documentation commit:

```text
c6b1c51d1d769caeed23cb92bce42adcf4a9b691
```

GitHub Actions qualification:

```text
workflow: Observation 265
run:      35175007436
job:      105054659695
result:   SUCCESS
solver:   Alloy 6.2.0 / Sat4j
warnings: none
```

Observed matrix:

```text
sameDescriptionCanCoverDifferentParties               SAT
samePartyCanHaveDifferentDescriptions                  SAT
exactMerchantTextCanAgreeWithStableParty               SAT
descriptionMayNameThingsWithoutSelectingParty          SAT
sameDescriptionAllowsDifferentPartyInterpretations     SAT

EqualDescriptionDeterminesParty                        SAT counterexample
PartyDeterminesDescription                             SAT counterexample
DescriptionDeterminesPartyAcrossWorlds                 SAT counterexample
DescriptionPresenceImpliesParty                        SAT counterexample
ExplicitPartyEvidenceDeterminesSelectedPartyQuery      UNSAT counterexample
```

## Trigger

Observations 263–264 established two boundaries:

```text
shared external identity can span semantic uses

Party identity
  != obligation identity
  != creditor role
  != payment-recipient relation
  != Locus
```

They deliberately did not earn a production Party relation.

The next question is empirical and narrower:

> Can retained `EventDescription` already serve as semantic authority for stable
> external-party identity, or does exact cross-Event Party aggregation require
> independent evidence?

This revisits Observation 130 without weakening it.

Observation 130 examined 558 admitted historical transactions and correctly found
that one unqualified Event-scoped string was the minimal evidence needed for human
recognition. Its audit showed that description text mixed several intents:

```text
merchant/category/channel    コンビニ (147)
specific merchant            三和 (18)
item                          缶コーヒー / タバコ / 食品
transfer memo                 smbc→paypay
obligation/purpose            健康保険料(6月分) / 健康保険料(滞納分)
counterparty/context          友人kから交通費精算
opening evidence              Opening Balance
```

The current canonical data keeps the same mixture. Representative retained rows
include:

```text
DESC 三和
DESC セブンイレブン
DESC グランベリーモールモンベルコアスパンウォッシュアウトパーカ
DESC smbc→paypay
DESC 家賃
DESC 健康保険料
```

Meanwhile current selected `RelationUnit` / `RelationDischarge` household data are
explicit empty memories. Therefore the immediate production pressure is not a
creditor query. It is the narrower question of stable outside-actor identity for
queries such as:

```text
how much did I spend with Sanwa?
how many Events involved the same merchant/person?
```

## Observation 130 remains valid

This observation does **not** claim that EventDescription was a mistake.

Its authority remains:

```text
EventId -> unqualified human recognizer text
```

That is enough to distinguish and display household Events. It deliberately does
not mean:

```text
EventId -> MerchantId
EventId -> PartyId
EventId -> PurposeId
```

The new pressure appears only when a query requires stable identity equivalence
across Events rather than human-readable recognition of one Event.

## Why text is not identity authority

Three directions fail independently.

### 1. Equal description need not mean equal Party

Historical `コンビニ` is explicitly a merchant category/channel phrase rather than
one named merchant. Two Events can therefore retain identical human text while
referring to different outside actors.

So this implication is too strong:

```text
same description -> same Party
```

### 2. Equal Party need not mean equal description

Current data already demonstrates heterogeneous recognizer style. One Event may
contain only a merchant name while another embeds place + merchant + item, such as:

```text
三和
グランベリーモールモンベルコアスパンウォッシュアウトパーカ
```

If future Events refer to the same merchant with different item/place phrases,
Party identity must survive description variation. Therefore this implication is
also too strong:

```text
same Party -> same description
```

### 3. Description presence need not imply any external Party

The self-transfer negative control remains decisive:

```text
DESC smbc→paypay
```

can name real-world providers while the household Event is fully represented as a
Locus-to-Locus transfer and needs no external Party relation.

Likewise:

```text
DESC 家賃
```

states an obligation/purpose but does not identify which landlord is involved.

Therefore text token extraction cannot be semantic authority for Party identity.

## Observation-local model

The Alloy model fixes:

```text
Event -> one Description
```

and varies only a shadow:

```text
World.selectedParty : Event -> lone ExternalParty
```

The model includes witness shapes for:

- identical generic description with different Parties;
- one Party across different descriptions;
- repeated exact merchant text agreeing with one Party;
- self-transfer description with no Party;
- identical rent description with different possible Party interpretations.

The shadow is not a proposed production type. It is only enough to test whether
Description determines identity.

## Qualified interpretation

The qualified matrix establishes only this information boundary:

```text
EventDescription
  = human recognition evidence
  != stable external identity authority
```

For exact cross-Event identity queries, an AI or parser may propose an
interpretation from description text, but that interpretation is not derivable
semantic authority.

This matters directly for the future AI boundary:

```text
AI inference from Description
    -> candidate Party interpretation
    != retained Party evidence
```

An AI must not silently turn string extraction into canonical identity.

The positive control also matters: once independent Party evidence itself is held
equal, the selected Party query is determined. The missing information is identity
evidence, not another richer description format.

## Does this earn production Party persistence?

Not by itself.

The current household can still use descriptions for ordinary recognition, and
selected relation memories are empty. Observation 265 therefore does **not** add:

```text
PartyId
EventParty
EventMerchant
EventCounterparty
PartyRole
```

Instead it establishes the condition under which one of those relations becomes
earned:

> A household query requires exact aggregation or reference by the same outside
> actor across Events, and text matching / AI interpretation is not acceptable as
> the semantic authority for that answer.

At that point the smallest query-specific Party relation should be admitted. The
relation name must state its meaning rather than recreating a generic `Who` bag.

## Practical pressure ordering

Current evidence suggests this order:

```text
1. merchant / selected-counterparty identity aggregation
   current pressure exists in descriptions

2. creditor / discharge Party query
   semantic machinery exists, but canonical RelationUnit data are currently empty

3. direct payment-recipient identity
   O264 proves independence, but no retained household evidence currently demands it
```

This is not a permanent ontology ordering. It is only current production pressure.

## Stop condition

Do not add production Party persistence merely because description cannot derive
Party identity.

Keep `EventDescription` unchanged.

When the first exact cross-Event external-identity query becomes a real household
requirement, introduce only the independent relation needed by that query and keep
it separate from creditor, recipient, Locus, and generic Event participation.

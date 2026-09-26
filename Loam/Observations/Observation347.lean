import Loam.Core.Event

namespace Loam.Observation347

open Loam.Core

set_option autoImplicit false

/-!
# Observation 347 — shared two-Measure mechanics do not imply shared semantics

External comparison sharpened the question opened by Observations 345–346.

TigerBeetle keeps each Transfer inside one ledger / asset type and composes
cross-ledger activity with linked Transfers. hledger 2 separates transacted
cost, cost basis, lot identity, and reduction policy. Beancount similarly keeps
booking/inventory semantics above its basic posting representation.

LOAM deliberately does not fabricate outside-household balancing Loci merely to
make unlike Measures close independently. Its neutral Event can therefore carry
an observed mixed-Measure occurrence directly.

The remaining question is architectural:

> When several domains need the same two-Measure sign / support checks, what is
> actually shared?

This observation compares three independently meaningful occurrences:

1. currency exchange
     -15000 jpy
       +100 usd

2. security acquisition
      -1000 jpy
         +3 acme-share

3. stock split representation change
         -3 pre-share
         +6 post-share

All three have the same narrow mechanical shape:

- one explicitly selected negative source Effect;
- one explicitly selected positive destination Effect;
- distinct source / destination Measures;
- every Effect belongs to one of those two Measures;
- total source-Measure residual is negative;
- total destination-Measure residual is positive.

Their semantics are nevertheless independent:

- Exchange
- SecurityTrade
- SplitTransformation

The candidate result is therefore not a generic transaction type. It is a
smaller reusable validation mechanic below distinct semantic authorities.
-/

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def measureTotal?
    (event : Event)
    (measure : MeasureId) : Option Int := do
  let row ← (Effect.measureTotals event.effects).find? fun item =>
    item.1 = measure
  pure row.2

/--
Observation-local candidate for the mechanical part currently embedded in
Exchange admission.

It says nothing about *why* the source and destination quantities belong to one
occurrence.
-/
private def twoMeasureTransformMechanics?
    (event : Event)
    (sourceKey destinationKey : EffectKey) : Bool :=
  match findEffectByKey? event sourceKey,
        findEffectByKey? event destinationKey with
  | some source, some destination =>
      if source.measure = destination.measure then
        false
      else if source.quantity.quanta >= 0 then
        false
      else if destination.quantity.quanta <= 0 then
        false
      else if !event.effects.all (fun effect =>
          decide (effect.measure = source.measure) ||
            decide (effect.measure = destination.measure)) then
        false
      else
        match measureTotal? event source.measure,
              measureTotal? event destination.measure with
        | some sourceTotal, some destinationTotal =>
            decide (sourceTotal < 0) && decide (destinationTotal > 0)
        | _, _ => false
  | _, _ => false

private def yen : MeasureId := ⟨"jpy"⟩
private def usd : MeasureId := ⟨"usd"⟩
private def acme : MeasureId := ⟨"acme-share"⟩
private def preShare : MeasureId := ⟨"pre-share"⟩
private def postShare : MeasureId := ⟨"post-share"⟩

private def cashJpy : LocusId := ⟨"cash-jpy"⟩
private def cashUsd : LocusId := ⟨"cash-usd"⟩
private def bank : LocusId := ⟨"bank"⟩
private def broker : LocusId := ⟨"broker"⟩

private def exchangeSource : EffectKey := ⟨"exchange-source"⟩
private def exchangeDestination : EffectKey := ⟨"exchange-destination"⟩
private def securityCash : EffectKey := ⟨"security-cash"⟩
private def securityUnits : EffectKey := ⟨"security-units"⟩
private def splitOld : EffectKey := ⟨"split-old"⟩
private def splitNew : EffectKey := ⟨"split-new"⟩

private def exchangeEvent? : Option Event :=
  Event.ofEffects? ⟨"o347-exchange"⟩ [
    Effect.ofQuantity exchangeSource cashJpy yen (Quantity.ofQuanta (-15000)),
    Effect.ofQuantity exchangeDestination cashUsd usd (Quantity.ofQuanta 100)
  ]

private def securityEvent? : Option Event :=
  Event.ofEffects? ⟨"o347-security-acquisition"⟩ [
    Effect.ofQuantity securityCash bank yen (Quantity.ofQuanta (-1000)),
    Effect.ofQuantity securityUnits broker acme (Quantity.ofQuanta 3)
  ]

private def splitEvent? : Option Event :=
  Event.ofEffects? ⟨"o347-stock-split"⟩ [
    Effect.ofQuantity splitOld broker preShare (Quantity.ofQuanta (-3)),
    Effect.ofQuantity splitNew broker postShare (Quantity.ofQuanta 6)
  ]

/--
Three unrelated semantic domains satisfy the same small mechanical predicate.
That is repeated pressure for implementation reuse, not semantic unification.
-/
theorem exchange_security_and_split_share_two_measure_mechanics :
    (do
      let exchange ← exchangeEvent?
      let security ← securityEvent?
      let split ← splitEvent?
      pure (
        twoMeasureTransformMechanics?
          exchange exchangeSource exchangeDestination,
        twoMeasureTransformMechanics?
          security securityCash securityUnits,
        twoMeasureTransformMechanics?
          split splitOld splitNew)) =
      some (true, true, true) := by
  native_decide

inductive SemanticMeaning where
  | exchange
  | securityTrade
  | splitTransformation
deriving Repr, DecidableEq

structure InterpretedOccurrence where
  event : Event
  source : EffectKey
  destination : EffectKey
  meaning : SemanticMeaning

private def exchangeOccurrence? : Option InterpretedOccurrence := do
  let event ← exchangeEvent?
  pure {
    event := event
    source := exchangeSource
    destination := exchangeDestination
    meaning := .exchange
  }

private def securityOccurrence? : Option InterpretedOccurrence := do
  let event ← securityEvent?
  pure {
    event := event
    source := securityCash
    destination := securityUnits
    meaning := .securityTrade
  }

private def splitOccurrence? : Option InterpretedOccurrence := do
  let event ← splitEvent?
  pure {
    event := event
    source := splitOld
    destination := splitNew
    meaning := .splitTransformation
  }

private def mechanicallyQualified
    (occurrence : InterpretedOccurrence) : Bool :=
  twoMeasureTransformMechanics?
    occurrence.event occurrence.source occurrence.destination

/--
Fixing the mechanical qualification does not fix semantic meaning.

All three occurrences project to the same mechanical answer, while their
semantic answers remain pairwise distinct.
-/
theorem mechanical_qualification_does_not_determine_semantic_authority :
    (do
      let exchange ← exchangeOccurrence?
      let security ← securityOccurrence?
      let split ← splitOccurrence?
      pure (
        mechanicallyQualified exchange,
        mechanicallyQualified security,
        mechanicallyQualified split,
        exchange.meaning,
        security.meaning,
        split.meaning)) =
      some (
        true, true, true,
        .exchange, .securityTrade, .splitTransformation) := by
  native_decide

/--
A generic persisted "two-Measure transform" tag would be insufficient to answer
domain queries. The semantic evidence must remain separately retained when the
domain answer is observable.
-/
private def isExchange
    (occurrence : InterpretedOccurrence) : Bool :=
  occurrence.meaning = .exchange

private def isSecurityTrade
    (occurrence : InterpretedOccurrence) : Bool :=
  occurrence.meaning = .securityTrade

private def isSplitTransformation
    (occurrence : InterpretedOccurrence) : Bool :=
  occurrence.meaning = .splitTransformation

theorem equal_mechanical_acceptance_coexists_with_different_domain_queries :
    (do
      let exchange ← exchangeOccurrence?
      let security ← securityOccurrence?
      let split ← splitOccurrence?
      pure (
        (mechanicallyQualified exchange, isExchange exchange,
          isSecurityTrade exchange, isSplitTransformation exchange),
        (mechanicallyQualified security, isExchange security,
          isSecurityTrade security, isSplitTransformation security),
        (mechanicallyQualified split, isExchange split,
          isSecurityTrade split, isSplitTransformation split))) =
      some (
        (true, true, false, false),
        (true, false, true, false),
        (true, false, false, true)) := by
  native_decide

/-!
## Finding

The repeated commonality is now narrow enough to name without collapsing
authority:

    two-Measure transformation mechanics
        selected negative source Effect
        selected positive destination Effect
        distinct Measures
        support limited to those Measures
        source residual < 0
        destination residual > 0

This commonality appears in at least three independent meanings:

    Exchange
    SecurityTrade
    SplitTransformation

Therefore a future implementation may reasonably share a pure validator or a
proof-producing Application helper for this shape.

But the observation argues *against* persisting a generic semantic
`CrossMeasureTransaction` / `TransformKind` as the only authority:

    same mechanics
        does not determine
    same meaning

The smaller architecture is:

    neutral Event / Effect / Measure
        +
    shared private/pure mechanics
        +
    distinct semantic evidence families

Persistence may consume the proofs produced by those semantic frontiers without
turning the helper itself into user-writable canonical evidence.

This matches the existing architecture law:

    share mechanics, preserve semantic authority

and avoids two opposite distortions:

1. TigerBeetle-style fabricated counterparty / liquidity Loci merely to force
   per-Measure closure inside a household observation model;
2. one generic cross-Measure escape-hatch fact that admits arbitrary mixed
   Measures without saying which semantic authority justified them.

The result does not yet earn a production helper. SecurityTrade and
SplitTransformation are still research-only consumers.

Not earned here:

- Core transaction variants;
- generic persisted TransformationEvidence;
- a public arbitrary cross-Measure bypass;
- production SecurityTradeEvidence;
- production SplitTransformationEvidence;
- investment basis / disposal writers;
- any valuation or exchange-rate law.
-/

end Loam.Observation347

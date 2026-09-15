module experiments/observation_252_rea_ledger_commutation

-- Observation 252 asks whether the LOAM -> Ledger denotation qualified by
-- Observation 250 agrees with an REA-mediated route, and what extra evidence is
-- needed on the REA -> Ledger edge.
--
-- The key distinction is deliberate:
--
--   REA economic interpretation
--     !=
--   accounting-view policy that chooses Ledger coordinates.
--
-- The model is observation-local. It is not a complete REA ontology and does
-- not formalize ledger-semantics itself.

abstract sig Locus {}
one sig CashLocus, GoodsLocus extends Locus {}

abstract sig Measure {}
one sig JPY extends Measure {}

abstract sig SignedQuantity {}
one sig Minus100, Plus100 extends SignedQuantity {}

abstract sig Event {}
one sig Payment, DeliveryA, DeliveryB extends Event {}

abstract sig Effect {
  event: one Event,
  locus: one Locus,
  measure: one Measure,
  quantity: one SignedQuantity
}
one sig CashEffect, GoodsEffect extends Effect {}

fact StableLoamEvidence {
  CashEffect.event = Payment
  CashEffect.locus = CashLocus
  CashEffect.measure = JPY
  CashEffect.quantity = Minus100

  GoodsEffect.event = Payment
  GoodsEffect.locus = GoodsLocus
  GoodsEffect.measure = JPY
  GoodsEffect.quantity = Plus100
}

-- Selected REA shadow vocabulary, as in Observation 251.
abstract sig Resource {}
one sig MoneyResource, GoodsResource, AlternativeResource extends Resource {}

abstract sig Agent {}
one sig HouseholdAgent, MerchantAgent extends Agent {}

-- Ledger/Pacioli-shaped coordinate vocabulary. Each atom stands for one
-- AccountName x Commodity coordinate. Observation 250's direct route preserves
-- the LOAM Locus x Measure distinction without claiming that Locus is
-- intrinsically an Account.
abstract sig AccountName {}
one sig CashAccount, GoodsAccount, AlternativeAccount extends AccountName {}

abstract sig Commodity {}
one sig JPYCommodity extends Commodity {}

abstract sig LedgerCoordinate {
  accountName: one AccountName,
  commodity: one Commodity
}
one sig CashJPY, GoodsJPY, AlternativeJPY extends LedgerCoordinate {}

fact LedgerCoordinateShape {
  CashJPY.accountName = CashAccount
  GoodsJPY.accountName = GoodsAccount
  AlternativeJPY.accountName = AlternativeAccount
  all c: LedgerCoordinate | c.commodity = JPYCommodity
}

-- Observation 250's direct additive route, represented here as a fixed shadow
-- coordinate map. It preserves the two distinct LOAM Loci and the JPY Measure.
one sig DirectLedgerView {
  locusCoordinate: Locus -> one LedgerCoordinate,
  measureCommodity: Measure -> one Commodity
}

fact DirectLedgerViewShape {
  CashLocus.(DirectLedgerView.locusCoordinate) = CashJPY
  GoodsLocus.(DirectLedgerView.locusCoordinate) = GoodsJPY
  JPY.(DirectLedgerView.measureCommodity) = JPYCommodity
}

-- Candidate economic interpretation plus the additional accounting-view policy
-- needed to materialize a Ledger coordinate from an REA Resource.
abstract sig World {
  resourceOf: Locus -> one Resource,
  participant: Event -> set Agent,
  duality: Event -> lone Event,

  -- This relation is intentionally NOT part of the selected REA shadow.
  -- It is the extra accounting-view policy on the REA -> Ledger edge.
  ledgerCoordinateOfResource: Resource -> one LedgerCoordinate
}
one sig Left, Right extends World {}

pred reaCandidate[w: World] {
  all l: Effect.locus | one l.(w.resourceOf)
  some Payment.(w.participant)
  one Payment.(w.duality)
  Payment not in Payment.(w.duality)
}

fun directCoordinate[e: Effect]: one LedgerCoordinate {
  e.locus.(DirectLedgerView.locusCoordinate)
}

fun mediatedCoordinate[w: World, e: Effect]: one LedgerCoordinate {
  (e.locus.(w.resourceOf)).(w.ledgerCoordinateOfResource)
}

-- The bridge condition is intentionally stated one level above Effects: every
-- observed Locus, after REA Resource interpretation and accounting-view policy,
-- must land on the same Ledger coordinate used by the direct LOAM route.
pred accountingViewAgreesWithDirect[w: World] {
  all l: Effect.locus |
    (l.(w.resourceOf)).(w.ledgerCoordinateOfResource) =
      l.(DirectLedgerView.locusCoordinate)
}

-- REA interpretation can exist together with a compatible accounting view.
pred compatibleTriangleExists {
  reaCandidate[Left]
  accountingViewAgreesWithDirect[Left]
}

-- Hold the selected REA interpretation fixed while changing only the accounting
-- view. If SAT, REA itself does not uniquely determine Ledger coordinates.
pred sameReaDifferentLedgerView {
  reaCandidate[Left]
  reaCandidate[Right]
  Left.resourceOf = Right.resourceOf
  Left.participant = Right.participant
  Left.duality = Right.duality
  Left.ledgerCoordinateOfResource != Right.ledgerCoordinateOfResource
  some e: Effect | mediatedCoordinate[Left, e] != mediatedCoordinate[Right, e]
}

-- A deliberately misaligned accounting view should be able to break the
-- triangle even though the REA interpretation is well formed.
pred misalignedAccountingViewBreaksCommutation {
  reaCandidate[Left]
  not accountingViewAgreesWithDirect[Left]
  some e: Effect | mediatedCoordinate[Left, e] != directCoordinate[e]
}

-- Agent participation and duality can vary while the balance-level accounting
-- image remains unchanged when Resource interpretation and accounting view stay
-- fixed. This witnesses information forgotten by the Ledger projection.
pred differentReaSemanticsSameLedgerImage {
  reaCandidate[Left]
  reaCandidate[Right]
  Left.resourceOf = Right.resourceOf
  Left.ledgerCoordinateOfResource = Right.ledgerCoordinateOfResource
  (Left.participant != Right.participant or Left.duality != Right.duality)
  all e: Effect | mediatedCoordinate[Left, e] = mediatedCoordinate[Right, e]
}

-- If two distinct direct LOAM coordinates are collapsed to one REA Resource, a
-- Resource-only accounting-view function cannot preserve both coordinates.
pred resourceCollapseBlocksCommutation {
  reaCandidate[Left]
  CashLocus.(Left.resourceOf) = GoodsLocus.(Left.resourceOf)
  directCoordinate[CashEffect] != directCoordinate[GoodsEffect]
  not accountingViewAgreesWithDirect[Left]
}

-- Deliberately too strong. Equal selected REA interpretation does not determine
-- one accounting view or one resulting Ledger image.
assert ReaInterpretationDeterminesLedgerImage {
  (reaCandidate[Left] and reaCandidate[Right] and
   Left.resourceOf = Right.resourceOf and
   Left.participant = Right.participant and
   Left.duality = Right.duality) implies
    all e: Effect | mediatedCoordinate[Left, e] = mediatedCoordinate[Right, e]
}

-- Positive commutation theorem for the bounded model: once the accounting-view
-- policy agrees with the direct Locus-based shadow on every observed Locus, the
-- two routes choose the same Ledger coordinate for every retained Effect.
assert CompatibleAccountingViewCommutes {
  all w: World |
    (reaCandidate[w] and accountingViewAgreesWithDirect[w]) implies
      all e: Effect | mediatedCoordinate[w, e] = directCoordinate[e]
}

-- A compatible Resource-only accounting view cannot collapse two observed Loci
-- that the direct LOAM route keeps at distinct Ledger coordinates.
assert CompatibleViewCannotHideDistinctDirectCoordinates {
  all w: World |
    (reaCandidate[w] and accountingViewAgreesWithDirect[w] and
     directCoordinate[CashEffect] != directCoordinate[GoodsEffect]) implies
      CashLocus.(w.resourceOf) != GoodsLocus.(w.resourceOf)
}

run compatibleTriangleExists for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent, exactly 3 AccountName, exactly 1 Commodity, exactly 3 LedgerCoordinate
run sameReaDifferentLedgerView for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent, exactly 3 AccountName, exactly 1 Commodity, exactly 3 LedgerCoordinate
run misalignedAccountingViewBreaksCommutation for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent, exactly 3 AccountName, exactly 1 Commodity, exactly 3 LedgerCoordinate
run differentReaSemanticsSameLedgerImage for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent, exactly 3 AccountName, exactly 1 Commodity, exactly 3 LedgerCoordinate
run resourceCollapseBlocksCommutation for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent, exactly 3 AccountName, exactly 1 Commodity, exactly 3 LedgerCoordinate
check ReaInterpretationDeterminesLedgerImage for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent, exactly 3 AccountName, exactly 1 Commodity, exactly 3 LedgerCoordinate
check CompatibleAccountingViewCommutes for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent, exactly 3 AccountName, exactly 1 Commodity, exactly 3 LedgerCoordinate
check CompatibleViewCannotHideDistinctDirectCoordinates for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent, exactly 3 AccountName, exactly 1 Commodity, exactly 3 LedgerCoordinate

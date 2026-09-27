import Loam.Application.SettlementFrontier

namespace Loam.Tests.SettlementFrontier

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩
private def usd : MeasureId := ⟨"usd"⟩
private def shares : MeasureId := ⟨"shares"⟩

private def sourceLocus : LocusId := ⟨"source"⟩
private def bank : LocusId := ⟨"bank"⟩
private def brokerLocus : LocusId := ⟨"broker"⟩

private def cardIssuer : ExternalPartyId := ⟨"card-issuer"⟩
private def broker : ExternalPartyId := ⟨"broker-counterparty"⟩

private def keyedEffect
    (key : String)
    (locus : LocusId)
    (measure : MeasureId)
    (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ locus measure (Quantity.ofQuanta quanta)

private def event?
    (id : String)
    (effects : List Effect) : Option Event :=
  Event.ofEffects? ⟨id⟩ effects

private def memory? (events : List Event) : Option EventMemory :=
  EventMemory.ofEvents? events

private def commitment
    (id sourceEvent sourceEffect : String)
    (debtor creditor : RelationEndpoint)
    (measure : MeasureId)
    (quanta : Int) : SettlementCommitment := {
  id := ⟨id⟩
  sourceEvent := ⟨sourceEvent⟩
  sourceEffect := ⟨sourceEffect⟩
  debtor := debtor
  creditor := creditor
  measure := measure
  quantity := Quantity.ofQuanta quanta
}

private def commitmentRevision
    (target : String)
    (replacement : Option String) : SettlementCommitmentRevision := {
  target := ⟨target⟩
  replacement := replacement.map fun token => ⟨token⟩
}

private def extinguishment
    (id target : String)
    (quanta : Int)
    (effectiveOn : Option String := none) :
    SettlementCommitmentExtinguishment := {
  id := ⟨id⟩
  target := ⟨target⟩
  quantity := Quantity.ofQuanta quanta
  effectiveOn := effectiveOn
}

private def extinguishmentRevision
    (target : String)
    (replacement : Option String) : SettlementExtinguishmentRevision := {
  target := ⟨target⟩
  replacement := replacement.map fun token => ⟨token⟩
}

private def correspondence
    (id target event effect : String)
    (quanta : Int) : SettlementEffectCorrespondence := {
  id := ⟨id⟩
  target := ⟨target⟩
  event := ⟨event⟩
  effect := ⟨effect⟩
  quantity := Quantity.ofQuanta quanta
}

private def netContext
    (id : String)
    (measure : MeasureId)
    (outcome : NetSettlementOutcome) : SettlementNettingContext := {
  id := ⟨id⟩
  measure := measure
  outcome := outcome
}

private def netMember
    (id context target : String)
    (quanta : Int) : SettlementNettingMember := {
  id := ⟨id⟩
  context := ⟨context⟩
  target := ⟨target⟩
  quantity := Quantity.ofQuanta quanta
}

private def image?
    (events : EventMemory)
    (commitments : List SettlementCommitment)
    (correspondences : List SettlementEffectCorrespondence := [])
    (correspondenceRevisions : List SettlementCorrespondenceRevision := [])
    (contexts : List SettlementNettingContext := [])
    (members : List SettlementNettingMember := [])
    (memberRevisions : List SettlementNettingMemberRevision := [])
    (commitmentRevisions : List SettlementCommitmentRevision := [])
    (extinguishments : List SettlementCommitmentExtinguishment := [])
    (extinguishmentRevisions : List SettlementExtinguishmentRevision := []) :
    Option AdmittedSettlementImage :=
  admitSettlementImage?
    events
    commitments
    commitmentRevisions
    extinguishments
    extinguishmentRevisions
    correspondences
    correspondenceRevisions
    contexts
    members
    memberRevisions

private def expectOutstanding
    (image : AdmittedSettlementImage)
    (target : String)
    (expected : Int)
    (message : String) : IO Unit := do
  let amount ← requireSome (image.outstanding? ⟨target⟩)
    s!"{message}: commitment missing from admitted image"
  expect (amount.quanta == expected)
    s!"{message}: expected outstanding {expected}, got {amount.quanta}"

private def crossMeasureCard : IO Unit := do
  let source ← requireSome
    (event? "card-purchase" [
      keyedEffect "purchase-usd" sourceLocus usd 30
    ])
    "cross-measure card source Event fixture failed"
  let paid ← requireSome
    (event? "card-payment" [
      keyedEffect "card-jpy" bank yen (-4700)
    ])
    "cross-measure card payment Event fixture failed"
  let events ← requireSome (memory? [source, paid])
    "cross-measure card EventMemory failed"

  let c := commitment
    "card-commitment" "card-purchase" "purchase-usd"
    .household (.external cardIssuer) yen 4700
  let row := correspondence
    "card-direct" "card-commitment" "card-payment" "card-jpy" 4700

  let image ← requireSome (image? events [c] [row])
    "cross-Measure card settlement was rejected"
  expectOutstanding image "card-commitment" 0
    "cross-Measure card settlement"

private def securityBuyAndSell : IO Unit := do
  let buyTrade ← requireSome
    (event? "buy-trade" [
      keyedEffect "buy-shares" brokerLocus shares 3
    ])
    "buy trade Event fixture failed"
  let buyCash ← requireSome
    (event? "buy-cash" [
      keyedEffect "buy-jpy" bank yen (-1012)
    ])
    "buy cash Event fixture failed"
  let sellTrade ← requireSome
    (event? "sell-trade" [
      keyedEffect "sell-shares" brokerLocus shares (-1)
    ])
    "sell trade Event fixture failed"
  let sellCash ← requireSome
    (event? "sell-cash" [
      keyedEffect "sell-jpy" bank yen 490
    ])
    "sell cash Event fixture failed"
  let events ← requireSome
    (memory? [buyTrade, buyCash, sellTrade, sellCash])
    "security EventMemory failed"

  let buy := commitment
    "buy-commitment" "buy-trade" "buy-shares"
    .household (.external broker) yen 1012
  let sell := commitment
    "sell-commitment" "sell-trade" "sell-shares"
    (.external broker) .household yen 490

  let image ← requireSome
    (image?
      events
      [buy, sell]
      [correspondence "buy-direct" "buy-commitment" "buy-cash" "buy-jpy" 1012,
       correspondence "sell-direct" "sell-commitment" "sell-cash" "sell-jpy" 490])
    "buy/sell bidirectional settlement was rejected"

  expectOutstanding image "buy-commitment" 0
    "security buy settlement"
  expectOutstanding image "sell-commitment" 0
    "security sell settlement"

private def partialMultiEventDirect : IO Unit := do
  let source ← requireSome
    (event? "partial-source" [
      keyedEffect "partial-origin" sourceLocus usd 1
    ])
    "partial source Event fixture failed"
  let first ← requireSome
    (event? "partial-first" [
      keyedEffect "partial-first-jpy" bank yen (-400)
    ])
    "partial first Event fixture failed"
  let second ← requireSome
    (event? "partial-second" [
      keyedEffect "partial-second-jpy" bank yen (-600)
    ])
    "partial second Event fixture failed"
  let events ← requireSome (memory? [source, first, second])
    "partial direct EventMemory failed"

  let c := commitment
    "partial-commitment" "partial-source" "partial-origin"
    .household (.external broker) yen 1000

  let image ← requireSome
    (image?
      events
      [c]
      [correspondence
        "partial-direct-a"
        "partial-commitment"
        "partial-first"
        "partial-first-jpy"
        400,
       correspondence
        "partial-direct-b"
        "partial-commitment"
        "partial-second"
        "partial-second-jpy"
        600])
    "partial multi-Event direct settlement was rejected"

  expectOutstanding image "partial-commitment" 0
    "partial multi-Event direct settlement"

private def oneEffectSeveralCommitments : IO Unit := do
  let sourceA ← requireSome
    (event? "split-source-a" [
      keyedEffect "split-origin-a" sourceLocus usd 1
    ])
    "split source A failed"
  let sourceB ← requireSome
    (event? "split-source-b" [
      keyedEffect "split-origin-b" sourceLocus usd 1
    ])
    "split source B failed"
  let physical ← requireSome
    (event? "split-payment" [
      keyedEffect "split-jpy" bank yen (-1000)
    ])
    "split physical Event failed"
  let events ← requireSome (memory? [sourceA, sourceB, physical])
    "split EventMemory failed"

  let a := commitment
    "split-a" "split-source-a" "split-origin-a"
    .household (.external broker) yen 700
  let b := commitment
    "split-b" "split-source-b" "split-origin-b"
    .household (.external broker) yen 300

  let image ← requireSome
    (image?
      events
      [a, b]
      [correspondence "split-row-a" "split-a" "split-payment" "split-jpy" 700,
       correspondence "split-row-b" "split-b" "split-payment" "split-jpy" 300])
    "one Effect -> several commitments was rejected"

  expectOutstanding image "split-a" 0
    "split commitment A"
  expectOutstanding image "split-b" 0
    "split commitment B"

private def oppositeDirectionNetting : IO Unit := do
  let source ← requireSome
    (event? "net-source" [
      keyedEffect "net-origin" sourceLocus usd 1
    ])
    "netting source Event failed"
  let physical ← requireSome
    (event? "net-payment" [
      keyedEffect "net-jpy" bank yen (-270)
    ])
    "netting physical Event failed"
  let events ← requireSome (memory? [source, physical])
    "netting EventMemory failed"

  let out1000 := commitment
    "net-out-1000" "net-source" "net-origin"
    .household (.external broker) yen 1000
  let in700 := commitment
    "net-in-700" "net-source" "net-origin"
    (.external broker) .household yen 700
  let fee20 := commitment
    "net-fee-20" "net-source" "net-origin"
    .household (.external broker) yen 20
  let credit50 := commitment
    "net-credit-50" "net-source" "net-origin"
    (.external broker) .household yen 50
  let context := netContext
    "net-context"
    yen
    (.physical ⟨"net-payment"⟩ ⟨"net-jpy"⟩)

  let image ← requireSome
    (image?
      events
      [out1000, in700, fee20, credit50]
      []
      []
      [context]
      [netMember "net-m-out" "net-context" "net-out-1000" 1000,
       netMember "net-m-in" "net-context" "net-in-700" 700,
       netMember "net-m-fee" "net-context" "net-fee-20" 20,
       netMember "net-m-credit" "net-context" "net-credit-50" 50])
    "opposite-direction netting was rejected"

  expectOutstanding image "net-out-1000" 0
    "netting outgoing"
  expectOutstanding image "net-in-700" 0
    "netting incoming"

private def zeroNet : IO Unit := do
  let source ← requireSome
    (event? "zero-source" [
      keyedEffect "zero-origin" sourceLocus usd 1
    ])
    "zero-net source Event failed"
  let events ← requireSome (memory? [source])
    "zero-net EventMemory failed"

  let outgoing := commitment
    "zero-out" "zero-source" "zero-origin"
    .household (.external broker) yen 1000
  let incoming := commitment
    "zero-in" "zero-source" "zero-origin"
    (.external broker) .household yen 1000
  let context := netContext "zero-context" yen .zero

  let image ← requireSome
    (image?
      events
      [outgoing, incoming]
      []
      []
      [context]
      [netMember "zero-m-out" "zero-context" "zero-out" 1000,
       netMember "zero-m-in" "zero-context" "zero-in" 1000])
    "zero-net settlement required a synthetic physical Effect"

  expectOutstanding image "zero-out" 0 "zero-net outgoing"
  expectOutstanding image "zero-in" 0 "zero-net incoming"

private def mixedDirectAndNet : IO Unit := do
  let source ← requireSome
    (event? "mixed-source" [
      keyedEffect "mixed-origin" sourceLocus usd 1
    ])
    "mixed source Event failed"
  let directPhysical ← requireSome
    (event? "mixed-direct" [
      keyedEffect "mixed-direct-jpy" bank yen (-400)
    ])
    "mixed direct Event failed"
  let netPhysical ← requireSome
    (event? "mixed-net" [
      keyedEffect "mixed-net-jpy" bank yen (-300)
    ])
    "mixed net Event failed"
  let events ← requireSome
    (memory? [source, directPhysical, netPhysical])
    "mixed EventMemory failed"

  let outgoing := commitment
    "mixed-out" "mixed-source" "mixed-origin"
    .household (.external broker) yen 1000
  let incoming := commitment
    "mixed-in" "mixed-source" "mixed-origin"
    (.external broker) .household yen 300
  let context := netContext
    "mixed-context"
    yen
    (.physical ⟨"mixed-net"⟩ ⟨"mixed-net-jpy"⟩)

  let image ← requireSome
    (image?
      events
      [outgoing, incoming]
      [correspondence
        "mixed-direct-row"
        "mixed-out"
        "mixed-direct"
        "mixed-direct-jpy"
        400]
      []
      [context]
      [netMember "mixed-m-out" "mixed-context" "mixed-out" 600,
       netMember "mixed-m-in" "mixed-context" "mixed-in" 300])
    "valid mixed direct + net settlement was rejected"

  expectOutstanding image "mixed-out" 0
    "mixed outgoing commitment"
  expectOutstanding image "mixed-in" 0
    "mixed incoming commitment"

private def rejectsCrossModeTargetOveruse : IO Unit := do
  let source ← requireSome
    (event? "overuse-source" [
      keyedEffect "overuse-origin" sourceLocus usd 1
    ])
    "overuse source Event failed"
  let directPhysical ← requireSome
    (event? "overuse-direct" [
      keyedEffect "overuse-direct-jpy" bank yen (-700)
    ])
    "overuse direct Event failed"
  let netPhysical ← requireSome
    (event? "overuse-net" [
      keyedEffect "overuse-net-jpy" bank yen (-300)
    ])
    "overuse net Event failed"
  let events ← requireSome
    (memory? [source, directPhysical, netPhysical])
    "overuse EventMemory failed"

  let outgoing := commitment
    "overuse-out" "overuse-source" "overuse-origin"
    .household (.external broker) yen 1000
  let incoming := commitment
    "overuse-in" "overuse-source" "overuse-origin"
    (.external broker) .household yen 300
  let context := netContext
    "overuse-context"
    yen
    (.physical ⟨"overuse-net"⟩ ⟨"overuse-net-jpy"⟩)

  let result := image?
    events
    [outgoing, incoming]
    [correspondence
      "overuse-direct-row"
      "overuse-out"
      "overuse-direct"
      "overuse-direct-jpy"
      700]
    []
    [context]
    [netMember "overuse-m-out" "overuse-context" "overuse-out" 600,
     netMember "overuse-m-in" "overuse-context" "overuse-in" 300]

  expect result.isNone
    "cross-mode target overuse 700 + 600 against commitment 1000 was admitted"

private def rejectsCrossModePhysicalReuse : IO Unit := do
  let source ← requireSome
    (event? "physical-reuse-source" [
      keyedEffect "physical-reuse-origin" sourceLocus usd 1
    ])
    "physical-reuse source Event failed"
  let physical ← requireSome
    (event? "physical-reuse-net" [
      keyedEffect "physical-reuse-jpy" bank yen (-300)
    ])
    "physical-reuse Effect failed"
  let events ← requireSome (memory? [source, physical])
    "physical-reuse EventMemory failed"

  let netOutgoing := commitment
    "physical-net-out" "physical-reuse-source" "physical-reuse-origin"
    .household (.external broker) yen 600
  let netIncoming := commitment
    "physical-net-in" "physical-reuse-source" "physical-reuse-origin"
    (.external broker) .household yen 300
  let directCommitment := commitment
    "physical-direct" "physical-reuse-source" "physical-reuse-origin"
    .household (.external broker) yen 100
  let context := netContext
    "physical-context"
    yen
    (.physical ⟨"physical-reuse-net"⟩ ⟨"physical-reuse-jpy"⟩)

  let result := image?
    events
    [netOutgoing, netIncoming, directCommitment]
    [correspondence
      "physical-direct-row"
      "physical-direct"
      "physical-reuse-net"
      "physical-reuse-jpy"
      100]
    []
    [context]
    [netMember "physical-m-out" "physical-context" "physical-net-out" 600,
     netMember "physical-m-in" "physical-context" "physical-net-in" 300]

  expect result.isNone
    "one physical Effect was admitted simultaneously as net and direct settlement"

private def correspondenceCorrection : IO Unit := do
  let source ← requireSome
    (event? "corr-source" [
      keyedEffect "corr-origin" sourceLocus usd 1
    ])
    "correspondence correction source Event failed"
  let physical ← requireSome
    (event? "corr-payment" [
      keyedEffect "corr-jpy" bank yen (-600)
    ])
    "correspondence correction physical Event failed"
  let events ← requireSome (memory? [source, physical])
    "correspondence correction EventMemory failed"

  let c := commitment
    "corr-target" "corr-source" "corr-origin"
    .household (.external broker) yen 1000

  -- The superseded row deliberately points at missing physical provenance.
  -- Current admission must follow the replacement frontier rather than
  -- re-admitting historical payload as present settlement state.
  let old := correspondence
    "corr-old"
    "corr-target"
    "missing-event"
    "missing-effect"
    700
  let replacement := correspondence
    "corr-new"
    "corr-target"
    "corr-payment"
    "corr-jpy"
    600
  let revision : SettlementCorrespondenceRevision := {
    target := ⟨"corr-old"⟩
    replacement := ⟨"corr-new"⟩
  }

  let image ← requireSome
    (image? events [c] [old, replacement] [revision])
    "superseded malformed correspondence poisoned current admission"

  expect (image.settledQuanta ⟨"corr-target"⟩ == 600)
    "correspondence correction did not select replacement quantity"
  expectOutstanding image "corr-target" 400
    "correspondence correction outstanding"

private def memberCorrection : IO Unit := do
  let source ← requireSome
    (event? "member-corr-source" [
      keyedEffect "member-corr-origin" sourceLocus usd 1
    ])
    "member correction source Event failed"
  let physical ← requireSome
    (event? "member-corr-net" [
      keyedEffect "member-corr-jpy" bank yen (-300)
    ])
    "member correction physical Event failed"
  let events ← requireSome (memory? [source, physical])
    "member correction EventMemory failed"

  let outgoing := commitment
    "member-corr-out" "member-corr-source" "member-corr-origin"
    .household (.external broker) yen 1000
  let incoming := commitment
    "member-corr-in" "member-corr-source" "member-corr-origin"
    (.external broker) .household yen 700
  let context := netContext
    "member-corr-context"
    yen
    (.physical ⟨"member-corr-net"⟩ ⟨"member-corr-jpy"⟩)

  let old := netMember
    "member-old"
    "member-corr-context"
    "member-corr-out"
    900
  let replacement := netMember
    "member-new"
    "member-corr-context"
    "member-corr-out"
    1000
  let incomingMember := netMember
    "member-in"
    "member-corr-context"
    "member-corr-in"
    700
  let revision : SettlementNettingMemberRevision := {
    target := ⟨"member-old"⟩
    replacement := ⟨"member-new"⟩
  }

  let image ← requireSome
    (image?
      events
      [outgoing, incoming]
      []
      []
      [context]
      [old, replacement, incomingMember]
      [revision])
    "superseded netting member poisoned current netting admission"

  expect (image.settledQuanta ⟨"member-corr-out"⟩ == 1000)
    "member correction did not select replacement quantity"
  expectOutstanding image "member-corr-out" 0
    "member correction outgoing"

private def replacementConflictsFailClosed : IO Unit := do
  let source ← requireSome
    (event? "conflict-source" [
      keyedEffect "conflict-origin" sourceLocus usd 1
    ])
    "replacement conflict source Event failed"
  let physical ← requireSome
    (event? "conflict-payment" [
      keyedEffect "conflict-jpy" bank yen (-500)
    ])
    "replacement conflict physical Event failed"
  let events ← requireSome (memory? [source, physical])
    "replacement conflict EventMemory failed"

  let c := commitment
    "conflict-target" "conflict-source" "conflict-origin"
    .household (.external broker) yen 500
  let old := correspondence
    "conflict-old" "conflict-target" "conflict-payment" "conflict-jpy" 500
  let a := correspondence
    "conflict-a" "conflict-target" "conflict-payment" "conflict-jpy" 500
  let b := correspondence
    "conflict-b" "conflict-target" "conflict-payment" "conflict-jpy" 500

  let result := image?
    events
    [c]
    [old, a, b]
    [
      { target := ⟨"conflict-old"⟩, replacement := ⟨"conflict-a"⟩ },
      { target := ⟨"conflict-old"⟩, replacement := ⟨"conflict-b"⟩ }
    ]

  expect result.isNone
    "competing correspondence replacements were not refused"

private def commitmentCorrectionCarriesHistoricalTarget : IO Unit := do
  let source ← requireSome
    (event? "commitment-current-source" [
      keyedEffect "commitment-current-origin" sourceLocus usd 1
    ])
    "commitment correction current source Event failed"
  let payment ← requireSome
    (event? "commitment-current-payment" [
      keyedEffect "commitment-current-jpy" bank yen (-300)
    ])
    "commitment correction payment Event failed"
  let events ← requireSome (memory? [source, payment])
    "commitment correction EventMemory failed"

  -- The superseded row deliberately names missing provenance. Only the corrected
  -- current payload is semantically admitted.
  let old := commitment
    "commitment-old" "missing-old-source" "missing-old-effect"
    .household (.external broker) yen 1000
  let current := commitment
    "commitment-current" "commitment-current-source" "commitment-current-origin"
    .household (.external broker) yen 700
  let row := correspondence
    "commitment-old-payment" "commitment-old"
    "commitment-current-payment" "commitment-current-jpy" 300
  let revision := commitmentRevision "commitment-old" (some "commitment-current")

  let image ← requireSome
    (image? events [old, current] [row]
      (commitmentRevisions := [revision]))
    "compatible commitment correction did not preserve historical target attribution"

  expect (image.commitments.length == 1)
    "commitment correction did not select one current commitment"
  expect (image.commitments[0]?.map (fun admitted => admitted.commitment.id) ==
      some ⟨"commitment-current"⟩)
    "commitment correction selected the wrong current commitment"
  expectOutstanding image "commitment-current" 400
    "commitment correction historical target"

private def incompatibleCommitmentCorrectionFailsClosed : IO Unit := do
  let source ← requireSome
    (event? "commitment-incompatible-source" [
      keyedEffect "commitment-incompatible-origin" sourceLocus usd 1
    ])
    "incompatible correction source Event failed"
  let payment ← requireSome
    (event? "commitment-incompatible-payment" [
      keyedEffect "commitment-incompatible-jpy" bank yen (-300)
    ])
    "incompatible correction payment Event failed"
  let events ← requireSome (memory? [source, payment])
    "incompatible correction EventMemory failed"

  let old := commitment
    "commitment-incompatible-old"
    "commitment-incompatible-source" "commitment-incompatible-origin"
    .household (.external broker) yen 1000
  let current := commitment
    "commitment-incompatible-current"
    "commitment-incompatible-source" "commitment-incompatible-origin"
    .household (.external broker) usd 700
  let row := correspondence
    "commitment-incompatible-row" "commitment-incompatible-old"
    "commitment-incompatible-payment" "commitment-incompatible-jpy" 300
  let revision :=
    commitmentRevision "commitment-incompatible-old"
      (some "commitment-incompatible-current")

  expect
    (image? events [old, current] [row]
      (commitmentRevisions := [revision])).isNone
    "Measure-changing commitment correction silently retargeted old settlement evidence"

private def commitmentRetractionBoundary : IO Unit := do
  let source ← requireSome
    (event? "commitment-retract-source" [
      keyedEffect "commitment-retract-origin" sourceLocus usd 1
    ])
    "commitment retraction source Event failed"
  let payment ← requireSome
    (event? "commitment-retract-payment" [
      keyedEffect "commitment-retract-jpy" bank yen (-300)
    ])
    "commitment retraction payment Event failed"
  let events ← requireSome (memory? [source, payment])
    "commitment retraction EventMemory failed"

  let c := commitment
    "commitment-retracted"
    "commitment-retract-source" "commitment-retract-origin"
    .household (.external broker) yen 1000
  let revision := commitmentRevision "commitment-retracted" none

  let emptyImage ← requireSome
    (image? events [c] (commitmentRevisions := [revision]))
    "standalone commitment retraction was rejected"
  expect emptyImage.commitments.isEmpty
    "retracted commitment remained current"

  let row := correspondence
    "commitment-retract-row" "commitment-retracted"
    "commitment-retract-payment" "commitment-retract-jpy" 300
  expect
    (image? events [c] [row] (commitmentRevisions := [revision])).isNone
    "dependent current settlement evidence survived commitment retraction"

private def extinguishmentLifecycle : IO Unit := do
  let source ← requireSome
    (event? "ext-source" [
      keyedEffect "ext-origin" sourceLocus usd 1
    ])
    "extinguishment source Event failed"
  let events ← requireSome (memory? [source])
    "extinguishment EventMemory failed"

  let c := commitment
    "ext-target" "ext-source" "ext-origin"
    .household (.external broker) yen 1000

  let unknown := extinguishment "ext-unknown" "ext-target" 300
  let imageUnknown ← requireSome
    (image? events [c] (extinguishments := [unknown]))
    "unknown-time extinguishment was rejected"
  expect (imageUnknown.extinguishedQuanta ⟨"ext-target"⟩ == 300)
    "unknown-time extinguishment total changed"
  expectOutstanding imageUnknown "ext-target" 700
    "unknown-time extinguishment"

  let known := extinguishment
    "ext-known" "ext-target" 250 (some "2026-09-20")
  let imageKnown ← requireSome
    (image? events [c] (extinguishments := [known]))
    "known-time extinguishment was rejected"
  expectOutstanding imageKnown "ext-target" 750
    "known-time extinguishment"

  let invalid := extinguishment
    "ext-invalid" "ext-target" 100 (some "2026-02-29")
  expect (image? events [c] (extinguishments := [invalid])).isNone
    "invalid effective date was admitted"

  let old := extinguishment
    "ext-old" "ext-target" 400 (some "2026-02-29")
  let replacement := extinguishment
    "ext-new" "ext-target" 200 (some "2026-09-21")
  let correction := extinguishmentRevision "ext-old" (some "ext-new")
  let corrected ← requireSome
    (image? events [c]
      (extinguishments := [old, replacement])
      (extinguishmentRevisions := [correction]))
    "superseded malformed extinguishment poisoned current admission"
  expect (corrected.extinguishedQuanta ⟨"ext-target"⟩ == 200)
    "extinguishment correction did not select replacement quantity"
  expectOutstanding corrected "ext-target" 800
    "extinguishment correction"

  let retracted ← requireSome
    (image? events [c]
      (extinguishments := [unknown])
      (extinguishmentRevisions := [
        extinguishmentRevision "ext-unknown" none
      ]))
    "extinguishment retraction was rejected"
  expect (retracted.extinguishedQuanta ⟨"ext-target"⟩ == 0)
    "retracted extinguishment remained current"
  expectOutstanding retracted "ext-target" 1000
    "extinguishment retraction"

private def extinguishmentComposesWithSettlement : IO Unit := do
  let source ← requireSome
    (event? "ext-compose-source" [
      keyedEffect "ext-compose-origin" sourceLocus usd 1
    ])
    "extinguishment composition source Event failed"
  let payment ← requireSome
    (event? "ext-compose-payment" [
      keyedEffect "ext-compose-jpy" bank yen (-600)
    ])
    "extinguishment composition payment Event failed"
  let events ← requireSome (memory? [source, payment])
    "extinguishment composition EventMemory failed"

  let c := commitment
    "ext-compose-target" "ext-compose-source" "ext-compose-origin"
    .household (.external broker) yen 1000
  let paid := correspondence
    "ext-compose-row" "ext-compose-target"
    "ext-compose-payment" "ext-compose-jpy" 600
  let reduced := extinguishment
    "ext-compose-reduced" "ext-compose-target" 300

  let admitted ← requireSome
    (image? events [c] [paid] (extinguishments := [reduced]))
    "settlement plus extinguishment within commitment bound was rejected"
  expect (admitted.settledQuanta ⟨"ext-compose-target"⟩ == 600)
    "settled quantity changed under extinguishment"
  expect (admitted.extinguishedQuanta ⟨"ext-compose-target"⟩ == 300)
    "extinguished quantity changed under settlement"
  expectOutstanding admitted "ext-compose-target" 100
    "settlement plus extinguishment"

  let over := extinguishment
    "ext-compose-over" "ext-compose-target" 500
  expect (image? events [c] [paid] (extinguishments := [over])).isNone
    "settled 600 + extinguished 500 exceeded commitment 1000"

private def extinguishmentFollowsCommitmentCorrection : IO Unit := do
  let source ← requireSome
    (event? "ext-corr-source" [
      keyedEffect "ext-corr-origin" sourceLocus usd 1
    ])
    "extinguishment commitment correction source Event failed"
  let events ← requireSome (memory? [source])
    "extinguishment commitment correction EventMemory failed"

  let old := commitment
    "ext-corr-old" "ext-corr-source" "ext-corr-origin"
    .household (.external broker) yen 1000
  let current := commitment
    "ext-corr-current" "ext-corr-source" "ext-corr-origin"
    .household (.external broker) yen 700
  let commitmentCorrection :=
    commitmentRevision "ext-corr-old" (some "ext-corr-current")
  let reduced := extinguishment
    "ext-corr-row" "ext-corr-old" 200 (some "2026-09-22")

  let image ← requireSome
    (image? events [old, current]
      (commitmentRevisions := [commitmentCorrection])
      (extinguishments := [reduced]))
    "historical extinguishment target did not follow commitment correction"
  expect (image.extinguishedQuanta ⟨"ext-corr-current"⟩ == 200)
    "extinguishment did not resolve onto current commitment identity"
  expectOutstanding image "ext-corr-current" 500
    "extinguishment after commitment correction"

def runAll : IO Unit := do
  crossMeasureCard
  securityBuyAndSell
  partialMultiEventDirect
  oneEffectSeveralCommitments
  oppositeDirectionNetting
  zeroNet
  mixedDirectAndNet
  rejectsCrossModeTargetOveruse
  rejectsCrossModePhysicalReuse
  correspondenceCorrection
  memberCorrection
  replacementConflictsFailClosed
  commitmentCorrectionCarriesHistoricalTarget
  incompatibleCommitmentCorrectionFailsClosed
  commitmentRetractionBoundary

  IO.println "Settlement production Slice C qualification succeeded."

end Loam.Tests.SettlementFrontier

def main : IO Unit :=
  Loam.Tests.SettlementFrontier.runAll

import Loam.ExchangeAdmission
import Loam.Application.MovementAdmission

open Loam.Core

set_option autoImplicit false

namespace Loam.PtaMigration

/-!
# Read-only plaintext-accounting migration plan

This module is the small production-facing semantic boundary for one-shot
Ledger/hledger migration planning.

It deliberately does not parse Ledger syntax, write canonical authority, assign
AccountingRole, infer history completeness, allocate stable Event identity, or
publish anything. External adapters provide exact normalized transactions plus
retained source features. This module classifies them through the existing
Movement / Exchange admission drafts and builds a read-only migration preview.

Source order is preserved only for human review. It is not Event identity.
-/

inductive Disposition where
  | direct
  | normalize
  | review
  | refuse
  deriving Repr, DecidableEq, BEq

inductive SourceFeature where
  | inferredAmount
  | sourceComposition
  | unconfirmedMeasureScale
  | cost
  | status
  | metadata
  | postingDate
  | balanceAssertion
  | balanceAssignment
  | virtualPosting
  | automatedRule
  | periodicRule
  | priceOrLot
  deriving Repr, DecidableEq, BEq

structure Posting where
  account : LocusId
  measure : MeasureId
  quanta : Int
  deriving Repr, DecidableEq

structure Transaction where
  validOn : String
  description : Option String := none
  postings : List Posting
  sourceFeatures : List SourceFeature := []
  deriving Repr, DecidableEq

inductive Candidate where
  | movement (draft : Loam.MovementAdmission.Draft)
  | exchange (draft : Loam.ExchangeAdmission.Draft)

structure Decision where
  disposition : Disposition
  candidate : Option Candidate := none
  sourceFeatures : List SourceFeature := []
  explanation : String := ""

private def featureDisposition : SourceFeature → Disposition
  | .inferredAmount => .normalize
  | .sourceComposition => .normalize
  | .unconfirmedMeasureScale => .review
  | .cost => .review
  | .status => .review
  | .metadata => .review
  | .balanceAssertion => .review
  | .balanceAssignment => .review
  | .postingDate => .refuse
  | .virtualPosting => .refuse
  | .automatedRule => .refuse
  | .periodicRule => .refuse
  | .priceOrLot => .refuse

private def dispositionRank : Disposition → Nat
  | .direct => 0
  | .normalize => 1
  | .review => 2
  | .refuse => 3

private def stronger (left right : Disposition) : Disposition :=
  if dispositionRank left >= dispositionRank right then left else right

private def strongestFeatureDisposition
    (features : List SourceFeature) : Disposition :=
  features.foldl
    (fun current feature => stronger current (featureDisposition feature))
    .direct

private def postingEffect (posting : Posting) : Effect :=
  Effect.ofAnonymousQuantity
    posting.account posting.measure (Quantity.ofQuanta posting.quanta)

private def distinctMeasures (postings : List Posting) : List MeasureId :=
  postings.foldl
    (fun (kept : List MeasureId) posting =>
      if kept.any fun measure => decide (measure = posting.measure) then
        kept
      else
        kept ++ [posting.measure])
    []

private def blocked
    (disposition : Disposition)
    (tx : Transaction)
    (explanation : String) : Decision :=
  {
    disposition := disposition
    sourceFeatures := tx.sourceFeatures
    explanation := explanation
  }

private def movementDecision (tx : Transaction) : Decision :=
  let effects := tx.postings.map postingEffect
  let draft : Loam.MovementAdmission.Draft := {
    validOn := tx.validOn
    description := tx.description
    effects := effects
    relations := []
    discharges := []
    total := Effect.positiveQuantaTotal effects
  }
  match Loam.MovementAdmission.validateDraft draft with
  | .ok _ =>
      {
        disposition := .direct
        candidate := some (.movement draft)
        sourceFeatures := tx.sourceFeatures
      }
  | .error message =>
      blocked .refuse tx message

private def exchangeDecision
    (tx : Transaction)
    (source destination : Posting) : Decision :=
  let sourceKey : EffectKey := ⟨"pta-import-source"⟩
  let destinationKey : EffectKey := ⟨"pta-import-destination"⟩
  let draft : Loam.ExchangeAdmission.Draft := {
    validOn := tx.validOn
    description := tx.description
    effects := [
      Effect.ofQuantity
        sourceKey source.account source.measure (Quantity.ofQuanta source.quanta),
      Effect.ofQuantity
        destinationKey destination.account destination.measure
        (Quantity.ofQuanta destination.quanta)
    ]
    source := sourceKey
    destination := destinationKey
  }
  match Loam.ExchangeAdmission.validateDraft draft with
  | .ok _ =>
      {
        disposition := .direct
        candidate := some (.exchange draft)
        sourceFeatures := tx.sourceFeatures
      }
  | .error message =>
      blocked .refuse tx message

private def classifyShape (tx : Transaction) : Decision :=
  match distinctMeasures tx.postings with
  | [] =>
      blocked .refuse tx "transaction has no exact quantity postings"
  | [_] =>
      movementDecision tx
  | [_, _] =>
      match tx.postings with
      | [left, right] =>
          if left.measure = right.measure then
            movementDecision tx
          else if left.quanta < 0 then
            if right.quanta > 0 then
              exchangeDecision tx left right
            else
              blocked .refuse tx "two-Measure transaction has no positive exchange destination"
          else if right.quanta < 0 then
            if left.quanta > 0 then
              exchangeDecision tx right left
            else
              blocked .refuse tx "two-Measure transaction has no positive exchange destination"
          else
            blocked .refuse tx "two-Measure transaction has no negative exchange source"
      | _ =>
          blocked .review tx
            "multi-posting two-Measure transaction needs explicit exchange-side review"
  | _ =>
      blocked .refuse tx "transaction uses more than two Measures"

/--
Classify one already-normalized external transaction.

Only Direct may expose a publication candidate. Normalize, Review, and Refuse
remain blocked and therefore cannot accidentally leak into a writer path.
-/
def classify (tx : Transaction) : Decision :=
  match strongestFeatureDisposition tx.sourceFeatures with
  | .refuse =>
      blocked .refuse tx
        "source carries meaning outside the v1 migration boundary"
  | .review =>
      blocked .review tx
        "source carries a distinction that requires explicit migration review"
  | .normalize =>
      blocked .normalize tx
        "source-native normalization is required before admission"
  | .direct =>
      classifyShape tx

structure PlannedTransaction where
  transaction : Transaction
  decision : Decision

/--
A pure migration plan. The source string is descriptive provenance only and has
no authority or identity semantics.
-/
structure MigrationPlan where
  source : String
  transactions : List PlannedTransaction

structure ReasonSummary where
  disposition : Disposition
  explanation : String
  count : Nat
  deriving Repr, DecidableEq

structure FeatureSummary where
  feature : SourceFeature
  count : Nat
  deriving Repr, DecidableEq

/--
Read-only scan summary.

`ready` counts Direct only. `needsPreparation` remains separate because
Normalize currently has no admission candidate. A later explicit normalization
pass may turn those rows into Direct, but this preview never pretends that has
already happened.
-/
structure Preview where
  source : String
  transactionsFound : Nat
  ready : Nat
  needsPreparation : Nat
  needsDecision : Nat
  cannotImportYet : Nat
  loci : List LocusId
  measures : List MeasureId
  blockedReasons : List ReasonSummary
  blockedFeatures : List FeatureSummary

def plan (source : String) (transactions : List Transaction) : MigrationPlan := {
  source := source
  transactions := transactions.map fun transaction => {
    transaction := transaction
    decision := classify transaction
  }
}

private def countDisposition
    (transactions : List PlannedTransaction)
    (target : Disposition) : Nat :=
  transactions.foldl
    (fun count planned =>
      if planned.decision.disposition == target then count + 1 else count)
    0

private def collectLoci (transactions : List PlannedTransaction) : List LocusId :=
  transactions.foldl
    (fun kept planned =>
      planned.transaction.postings.foldl
        (fun kept posting =>
          if kept.any fun locus => decide (locus = posting.account) then
            kept
          else
            kept ++ [posting.account])
        kept)
    []

private def collectMeasures
    (transactions : List PlannedTransaction) : List MeasureId :=
  transactions.foldl
    (fun kept planned =>
      planned.transaction.postings.foldl
        (fun kept posting =>
          if kept.any fun measure => decide (measure = posting.measure) then
            kept
          else
            kept ++ [posting.measure])
        kept)
    []

private def bumpReason
    (summaries : List ReasonSummary)
    (disposition : Disposition)
    (explanation : String) : List ReasonSummary :=
  match summaries with
  | [] => [{ disposition := disposition, explanation := explanation, count := 1 }]
  | summary :: rest =>
      if summary.disposition == disposition && summary.explanation == explanation then
        { summary with count := summary.count + 1 } :: rest
      else
        summary :: bumpReason rest disposition explanation

private def collectReasons
    (transactions : List PlannedTransaction) : List ReasonSummary :=
  transactions.foldl
    (fun summaries planned =>
      if planned.decision.disposition == .direct then
        summaries
      else
        bumpReason summaries planned.decision.disposition planned.decision.explanation)
    []

private def bumpFeature
    (summaries : List FeatureSummary)
    (feature : SourceFeature) : List FeatureSummary :=
  match summaries with
  | [] => [{ feature := feature, count := 1 }]
  | summary :: rest =>
      if summary.feature == feature then
        { summary with count := summary.count + 1 } :: rest
      else
        summary :: bumpFeature rest feature

private def collectFeatures
    (transactions : List PlannedTransaction) : List FeatureSummary :=
  transactions.foldl
    (fun summaries planned =>
      if planned.decision.disposition == .direct then
        summaries
      else
        planned.decision.sourceFeatures.foldl bumpFeature summaries)
    []

def preview (migration : MigrationPlan) : Preview := {
  source := migration.source
  transactionsFound := migration.transactions.length
  ready := countDisposition migration.transactions .direct
  needsPreparation := countDisposition migration.transactions .normalize
  needsDecision := countDisposition migration.transactions .review
  cannotImportYet := countDisposition migration.transactions .refuse
  loci := collectLoci migration.transactions
  measures := collectMeasures migration.transactions
  blockedReasons := collectReasons migration.transactions
  blockedFeatures := collectFeatures migration.transactions
}

/--
Compact human-readable scan summary. This is presentation text only and performs
no IO or publication.
-/
def renderPreview (summary : Preview) : String :=
  String.intercalate "\n" [
    "Import preview",
    "",
    summary.source,
    "",
    "Transactions found       " ++ toString summary.transactionsFound,
    "Ready                    " ++ toString summary.ready,
    "Needs preparation        " ++ toString summary.needsPreparation,
    "Needs your decision      " ++ toString summary.needsDecision,
    "Cannot import yet        " ++ toString summary.cannotImportYet,
    "",
    "Loci                     " ++ toString summary.loci.length,
    "Measures                 " ++ toString summary.measures.length,
    "",
    "Nothing has been written."
  ]

end Loam.PtaMigration

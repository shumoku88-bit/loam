import Loam.Application.PtaMigration

open Loam.Core
open Loam.PtaMigration

set_option autoImplicit false

namespace Loam.Tests.PtaMigrationClassifier

/-!
# Executable PTA migration classifier gate

This research/test instrument exercises the production-facing read-only
`Loam.PtaMigration` boundary against the Observation-385 fixtures and current
Movement / Exchange admission.

The source adapter is assumed to have parsed the external journal and exposed
exact posting quantities plus any source features whose meaning must not
disappear during normalization.
-/

private def posting (account measure : String) (quanta : Int) : Posting := {
  account := ⟨account⟩
  measure := ⟨measure⟩
  quanta := quanta
}

private def ordinary
    (validOn description : String)
    (postings : List Posting)
    (features : List SourceFeature := []) : Transaction := {
  validOn := validOn
  description := some description
  postings := postings
  sourceFeatures := features
}

private structure Fixture where
  name : String
  tx : Transaction
  expected : Disposition

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

private def emptyHistory : ActualValidityHistory String := {
  facts := []
  factRefNodup := by simp
  corrections := []
  correctionIdNodup := by simp
}

private def uniqueLoci (effects : List Effect) : List LocusId :=
  effects.foldl
    (fun (kept : List LocusId) effect =>
      if kept.any fun locus => decide (locus = effect.locus) then
        kept
      else
        kept ++ [effect.locus])
    []

private def emptyEvents : IO EventMemory := do
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "could not construct empty EventMemory")
  pure events

private def vocabularyFor (effects : List Effect) : IO LocusAdmissionVocabulary := do
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? (uniqueLoci effects)
    | throw (IO.userError "could not construct migration Locus vocabulary")
  pure vocabulary

private def directCandidateAdmits
    (label : String)
    (candidate : Candidate) : IO Unit := do
  match candidate with
  | .movement draft =>
      let events ← emptyEvents
      let vocabulary ← vocabularyFor draft.effects
      let world : Loam.MovementAdmission.World := {
        events := events
        validity := emptyHistory
        descriptions := .empty
        relations := []
        discharges := []
        locusAdmission := vocabulary
      }
      match Loam.MovementAdmission.admit? world draft with
      | .ok _ => pure ()
      | .error message =>
          throw (IO.userError
            (label ++ ": Direct Movement did not reach production admission: " ++ message))
  | .exchange draft =>
      let events ← emptyEvents
      let vocabulary ← vocabularyFor draft.effects
      let corrections : EventCorrectionMemory := {
        corrections := []
        idNodup := by simp
      }
      let world : Loam.ExchangeAdmission.World := {
        events := events
        validity := emptyHistory
        descriptions := .empty
        exchanges := .empty
        corrections := corrections
        locusAdmission := vocabulary
      }
      match Loam.ExchangeAdmission.admit? world draft with
      | .ok _ => pure ()
      | .error message =>
          throw (IO.userError
            (label ++ ": Direct Exchange did not reach production admission: " ++ message))

private def fixtures : List Fixture := [
  {
    name := "01 basic expense"
    tx := ordinary "2026-09-01" "Coffee" [
      posting "Assets:Cash" "JPY" (-300),
      posting "Expenses:Coffee" "JPY" 300
    ]
    expected := .direct
  },
  {
    name := "02 split expense"
    tx := ordinary "2026-09-02" "Supermarket" [
      posting "Assets:Cash" "JPY" (-900),
      posting "Expenses:Food" "JPY" 600,
      posting "Expenses:Supplies" "JPY" 300
    ]
    expected := .direct
  },
  {
    name := "03 same-Measure transfer"
    tx := ordinary "2026-09-03" "Transfer" [
      posting "Assets:Bank" "JPY" (-5000),
      posting "Assets:Cash" "JPY" 5000
    ]
    expected := .direct
  },
  {
    name := "04 income"
    tx := ordinary "2026-09-04" "Pension" [
      posting "Assets:Bank" "JPY" 80000,
      posting "Income:Pension" "JPY" (-80000)
    ]
    expected := .direct
  },
  {
    name := "05 explicit opening transaction"
    tx := ordinary "2026-01-01" "Opening" [
      posting "Assets:Bank" "JPY" 120000,
      posting "Equity:Opening" "JPY" (-120000)
    ]
    expected := .direct
  },
  {
    name := "06 inferred balancing amount"
    tx := ordinary "2026-09-05" "Lunch" [
      posting "Expenses:Food" "JPY" 850,
      posting "Assets:Cash" "JPY" (-850)
    ] [.inferredAmount]
    expected := .normalize
  },
  {
    name := "07 include or alias composition"
    tx := ordinary "2026-09-05" "Composed source" [
      posting "Assets:Cash" "JPY" (-200),
      posting "Expenses:Food" "JPY" 200
    ] [.sourceComposition]
    expected := .normalize
  },
  {
    name := "08 decimal Measure setup"
    tx := ordinary "2026-09-06" "Snack" [
      posting "Assets:USD" "USD" (-1234),
      posting "Expenses:Food" "USD" 1234
    ] [.unconfirmedMeasureScale]
    expected := .review
  },
  {
    name := "09 exact two-commodity exchange"
    tx := ordinary "2026-09-07" "Exchange" [
      posting "Assets:JPY" "JPY" (-15000),
      posting "Assets:USD" "USD" 10000
    ]
    expected := .direct
  },
  {
    name := "10 explicit cost"
    tx := ordinary "2026-09-08" "Buy shares" [
      posting "Assets:Broker" "ABC" 2,
      posting "Assets:Bank" "JPY" (-1000)
    ] [.cost]
    expected := .review
  },
  {
    name := "11 cleared or pending status"
    tx := ordinary "2026-09-09" "Cleared purchase" [
      posting "Assets:Cash" "JPY" (-500),
      posting "Expenses:Food" "JPY" 500
    ] [.status]
    expected := .review
  },
  {
    name := "12 code tags or metadata"
    tx := ordinary "2026-09-11" "Hardware" [
      posting "Assets:Bank" "JPY" (-2000),
      posting "Expenses:Tools" "JPY" 2000
    ] [.metadata]
    expected := .review
  },
  {
    name := "13 posting-specific date"
    tx := ordinary "2026-09-12" "Posting date" [
      posting "Assets:Bank" "JPY" (-1000),
      posting "Expenses:Food" "JPY" 1000
    ] [.postingDate]
    expected := .refuse
  },
  {
    name := "14 balance assertion"
    tx := ordinary "2026-09-12" "ATM" [
      posting "Assets:Cash" "JPY" 1000,
      posting "Assets:Bank" "JPY" (-1000)
    ] [.balanceAssertion]
    expected := .review
  },
  {
    name := "15 balance assignment"
    tx := ordinary "2026-09-13" "Reconcile" [
      posting "Assets:Cash" "JPY" 300,
      posting "Equity:Adjustments" "JPY" (-300)
    ] [.balanceAssignment]
    expected := .review
  },
  {
    name := "16 unbalanced virtual posting"
    tx := ordinary "2026-09-14" "Dinner" [
      posting "Assets:Cash" "JPY" (-900),
      posting "Expenses:Food" "JPY" 900,
      posting "Budget:Food" "JPY" (-900)
    ] [.virtualPosting]
    expected := .refuse
  },
  {
    name := "17 balanced virtual posting"
    tx := ordinary "2026-09-15" "Dinner" [
      posting "Assets:Cash" "JPY" (-900),
      posting "Expenses:Food" "JPY" 900,
      posting "Budget:Food" "JPY" (-900),
      posting "Equity:Budget" "JPY" 900
    ] [.virtualPosting]
    expected := .refuse
  },
  {
    name := "18 automated transaction rule"
    tx := {
      validOn := "2026-09-16"
      description := some "Automated rule"
      postings := []
      sourceFeatures := [.automatedRule]
    }
    expected := .refuse
  },
  {
    name := "19 periodic transaction rule"
    tx := {
      validOn := "2026-09-16"
      description := some "Periodic rule"
      postings := []
      sourceFeatures := [.periodicRule]
    }
    expected := .refuse
  },
  {
    name := "20 price lot or investment identity"
    tx := {
      validOn := "2026-09-16"
      description := some "Price or lot"
      postings := []
      sourceFeatures := [.priceOrLot]
    }
    expected := .refuse
  }
]

private structure AdapterHeader where
  idx : String
  validOn : String
  features : List SourceFeature

private structure AdapterPosting where
  idx : String
  posting : Posting

private def sourceFeature? : String → Option SourceFeature
  | "inferredAmount" => some .inferredAmount
  | "sourceComposition" => some .sourceComposition
  | "unconfirmedMeasureScale" => some .unconfirmedMeasureScale
  | "cost" => some .cost
  | "status" => some .status
  | "metadata" => some .metadata
  | "postingDate" => some .postingDate
  | "balanceAssertion" => some .balanceAssertion
  | "balanceAssignment" => some .balanceAssignment
  | "virtualPosting" => some .virtualPosting
  | "automatedRule" => some .automatedRule
  | "periodicRule" => some .periodicRule
  | "priceOrLot" => some .priceOrLot
  | _ => none

private def disposition? : String → Option Disposition
  | "direct" => some .direct
  | "normalize" => some .normalize
  | "review" => some .review
  | "refuse" => some .refuse
  | _ => none

private def parseFeatures? (text : String) : Option (List SourceFeature) :=
  if text == "-" then
    some []
  else
    (text.splitOn ",").mapM sourceFeature?

private def parseAdapterHeader? (line : String) : Option AdapterHeader := do
  match line.splitOn "\t" with
  | ["T", idx, validOn, featuresText] =>
      let features ← parseFeatures? featuresText
      some { idx := idx, validOn := validOn, features := features }
  | _ => none

private def parseAdapterPosting? (line : String) : Option AdapterPosting := do
  match line.splitOn "\t" with
  | ["P", idx, account, measure, quantaText] =>
      let quanta ← quantaText.toInt?
      some {
        idx := idx
        posting := {
          account := ⟨account⟩
          measure := ⟨measure⟩
          quanta := quanta
        }
      }
  | _ => none

private def dataLines (input : String) : List String :=
  (input.splitOn "\n").filter fun line =>
    !line.isEmpty && !line.startsWith "#"

private def adapterTransactions?
    (input : String) : Option (List (String × Transaction)) := do
  let lines := dataLines input
  let headerLines := lines.filter fun line => line.startsWith "T\t"
  let postingLines := lines.filter fun line => line.startsWith "P\t"
  if headerLines.length + postingLines.length != lines.length then
    none
  else
    let headers ← headerLines.mapM parseAdapterHeader?
    let postings ← postingLines.mapM parseAdapterPosting?
    headers.mapM fun header => do
      let selected :=
        (postings.filter fun posting => posting.idx == header.idx).map
          (fun posting => posting.posting)
      some
        (header.idx, {
          validOn := header.validOn
          description := none
          postings := selected
          sourceFeatures := header.features
        })

private def adapterExpected?
    (input : String) : Option (List (String × Disposition)) := do
  (dataLines input).mapM fun line => do
    match line.splitOn "\t" with
    | [idx, token] =>
        let disposition ← disposition? token
        some (idx, disposition)
    | _ => none

private def runAdapter
    (normalizedPath expectedPath : String) : IO Unit := do
  let normalizedInput ← IO.FS.readFile (System.FilePath.mk normalizedPath)
  let expectedInput ← IO.FS.readFile (System.FilePath.mk expectedPath)
  let some transactions := adapterTransactions? normalizedInput
    | throw (IO.userError "PTA adapter wire is malformed")
  let some expected := adapterExpected? expectedInput
    | throw (IO.userError "PTA adapter expected-disposition fixture is malformed")

  expect (transactions.length == expected.length)
    "PTA adapter transaction count does not match expected-disposition fixture"

  for pair in transactions do
    let idx := pair.1
    let tx := pair.2
    let some expectedDisposition :=
        ((expected.find? fun row => row.1 == idx).map Prod.snd)
      | throw (IO.userError ("PTA adapter transaction " ++ idx ++ " has no expected disposition"))
    let decision := classify tx
    expect (decision.disposition == expectedDisposition)
      ("PTA adapter transaction " ++ idx ++ ": expected " ++
        reprStr expectedDisposition ++ ", got " ++ reprStr decision.disposition)

    let shouldHaveCandidate := expectedDisposition == .direct
    expect (decision.candidate.isSome == shouldHaveCandidate)
      ("PTA adapter transaction " ++ idx ++
        ": only Direct input may expose a publication candidate")

    match decision.candidate with
    | none => pure ()
    | some candidate =>
        directCandidateAdmits ("PTA adapter transaction " ++ idx) candidate

  let migration :=
    Loam.PtaMigration.plan normalizedPath (transactions.map fun pair => pair.2)
  let summary := Loam.PtaMigration.preview migration
  expect (summary.transactionsFound == 5)
    "PTA adapter preview transaction count changed"
  expect (summary.ready == 1)
    "PTA adapter preview Direct count changed"
  expect (summary.needsPreparation == 1)
    "PTA adapter preview Normalize count changed"
  expect (summary.needsDecision == 2)
    "PTA adapter preview Review count changed"
  expect (summary.cannotImportYet == 1)
    "PTA adapter preview Refuse count changed"

  IO.println (Loam.PtaMigration.renderPreview summary)

  IO.println
    ("PTA hledger adapter boundary: " ++ toString transactions.length ++
      " normalized transactions classified through the existing gate.")

def run : IO Unit := do
  expect (fixtures.length == 20)
    "PTA migration matrix stopped containing exactly 20 representative fixtures"

  for fixture in fixtures do
    let decision := classify fixture.tx
    expect (decision.disposition == fixture.expected)
      (fixture.name ++ ": expected " ++ reprStr fixture.expected ++
        ", got " ++ reprStr decision.disposition)

    let shouldHaveCandidate := fixture.expected == .direct
    expect (decision.candidate.isSome == shouldHaveCandidate)
      (fixture.name ++ ": only Direct fixtures may expose a publication candidate")

    match decision.candidate with
    | none => pure ()
    | some candidate =>
        directCandidateAdmits fixture.name candidate

  let migration :=
    Loam.PtaMigration.plan "fixture://pta-migration-matrix"
      (fixtures.map fun fixture => fixture.tx)
  let summary := Loam.PtaMigration.preview migration
  expect (summary.transactionsFound == 20)
    "PTA migration preview stopped seeing all 20 fixtures"
  expect (summary.ready == 6)
    "PTA migration preview Direct count changed"
  expect (summary.needsPreparation == 2)
    "PTA migration preview Normalize count changed"
  expect (summary.needsDecision == 6)
    "PTA migration preview Review count changed"
  expect (summary.cannotImportYet == 6)
    "PTA migration preview Refuse count changed"
  expect (summary.measures.length == 3)
    "PTA migration preview stopped collecting the three fixture Measures"
  expect (!summary.loci.isEmpty)
    "PTA migration preview stopped collecting source Locus candidates"
  expect
    (summary.blockedFeatures.any fun feature =>
      feature.feature == .virtualPosting && feature.count == 2)
    "PTA migration preview stopped grouping virtual-posting blockers"

  let reviewBeatsNormalize :=
    classify (ordinary "2026-09-20" "precedence" [
      posting "Assets:Cash" "JPY" (-100),
      posting "Expenses:Food" "JPY" 100
    ] [.inferredAmount, .status])
  expect (reviewBeatsNormalize.disposition == .review &&
      reviewBeatsNormalize.candidate.isNone)
    "Review did not block a simultaneously normalizable transaction"

  let refuseBeatsReview :=
    classify (ordinary "2026-09-21" "precedence" [
      posting "Assets:Cash" "JPY" (-100),
      posting "Expenses:Food" "JPY" 100
    ] [.status, .virtualPosting])
  expect (refuseBeatsReview.disposition == .refuse &&
      refuseBeatsReview.candidate.isNone)
    "Refuse did not dominate Review for a meaning-changing source feature"

  let feeBearingShape :=
    classify (ordinary "2026-09-22" "fee-bearing exchange" [
      posting "Assets:JPY" "JPY" (-15100),
      posting "Expenses:ExchangeFee" "JPY" 100,
      posting "Assets:USD" "USD" 10000
    ])
  expect (feeBearingShape.disposition == .review &&
      feeBearingShape.candidate.isNone)
    "ambiguous multi-posting Exchange reached publication without source/destination review"

  let some firstFixture := fixtures.head?
    | throw (IO.userError "PTA migration fixture list unexpectedly empty")
  let basic := classify firstFixture.tx
  match basic.candidate with
  | some (.movement draft) =>
      expect
        (draft.effects.any fun effect => effect.locus.token == "Assets:Cash")
        "PTA classifier rewrote the source account spelling instead of preserving it as opaque Locus input"
  | _ =>
      throw (IO.userError "basic expense did not produce a Movement candidate")

  IO.println
    "PTA migration classifier: 20 fixtures classified; Direct candidates reached production admission; blocked cases exposed no candidate."

def runArgs (args : List String) : IO Unit :=
  match args with
  | [] => run
  | ["adapter", normalizedPath, expectedPath] =>
      runAdapter normalizedPath expectedPath
  | _ =>
      throw (IO.userError
        "usage: PtaMigrationClassifier.lean [adapter <normalized.tsv> <expected.tsv>]")

end Loam.Tests.PtaMigrationClassifier

def main (args : List String) : IO Unit :=
  Loam.Tests.PtaMigrationClassifier.runArgs args

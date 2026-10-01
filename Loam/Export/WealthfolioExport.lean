import Loam.Review.ActualJournalProjection
import Loam.Review.OpeningPositionReview
import Loam.Core.AccountingRole
import Loam.Presentation.MeasurePresentation

namespace Loam.WealthfolioExport

open Loam.Core

set_option autoImplicit false

/-!
# Conservative Wealthfolio cash-activity export

This is a disposable target projection for Wealthfolio transaction-tracked Cash
accounts. LOAM remains authoritative.

The first boundary deliberately exports only coordinates whose explicit
`AccountingRole` is `.asset`. It does not infer securities, credit-card
semantics, valuation, fees, taxes, refunds, or investment activity types.

For each current Actual Event on or after the Accounting Epoch:

- one Asset effect is rendered as DEPOSIT / WITHDRAWAL by sign;
- multiple Asset effects are rendered as TRANSFER_IN / TRANSFER_OUT by sign;
- non-Asset effects are not emitted as Wealthfolio accounts, but every source
  Effect must still have an explicit AccountingRole so transfer classification
  is not guessed through unresolved evidence.

The derived Opening Position is rendered as a DEPOSIT for positive cash or a
WITHDRAWAL for negative cash. This is target scaffolding only. No opening Event
is added to LOAM.

Wealthfolio cash activities use positive `amount` values; direction comes from
the activity type. Currency text is accepted only for conservative three-letter
alphabetic Measure tokens and is rendered upper-case.
-/

inductive ActivityType where
  | deposit
  | withdrawal
  | transferIn
  | transferOut
deriving Repr, DecidableEq

private def activityTypeText : ActivityType → String
  | .deposit => "DEPOSIT"
  | .withdrawal => "WITHDRAWAL"
  | .transferIn => "TRANSFER_IN"
  | .transferOut => "TRANSFER_OUT"

structure Row where
  date : String
  activityType : ActivityType
  currency : String
  amount : String
  account : String
  comment : String
deriving Repr, DecidableEq

private def asciiLetters : List Char :=
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".toList

private def currencyText? (measure : MeasureId) : Option String := do
  if measure.token.length != 3 then
    none
  else if !measure.token.toList.all fun c => asciiLetters.contains c then
    none
  else
    some measure.token.toUpper

private def csvQuoted (text : String) : String :=
  let escaped :=
    text.foldl
      (fun acc c =>
        match c with
        | '"' => acc ++ """"
        | '\n' => acc.push ' '
        | '\r' => acc.push ' '
        | '\t' => acc.push ' '
        | other => acc.push other)
      ""
  """ ++ escaped ++ """

private def renderRow (row : Row) : String :=
  String.intercalate ","
    [ row.date
    , activityTypeText row.activityType
    , row.currency
    , row.amount
    , csvQuoted row.account
    , csvQuoted row.comment
    ]

private def absQuanta (quanta : Int) : Int :=
  Int.ofNat quanta.natAbs

private def amountText
    (presentation : List Loam.MeasurePresentation.Metadata)
    (measure : MeasureId)
    (quanta : Int) : String :=
  Loam.MeasurePresentation.formatQuanta presentation measure (absQuanta quanta)

private def coordinateLe
    (left right : EffectCoordinate) : Bool :=
  if left.locus.token < right.locus.token then
    true
  else if right.locus.token < left.locus.token then
    false
  else
    left.measure.token ≤ right.measure.token

private def effectLe (left right : Effect) : Bool :=
  coordinateLe
    ⟨left.locus, left.measure⟩
    ⟨right.locus, right.measure⟩

private def openingRows
    (presentation : List Loam.MeasurePresentation.Metadata)
    (roles : AccountingRoleMap)
    (opening : Loam.OpeningPositionReview.Snapshot) :
    Except String (List Row) := do
  let sorted := opening.rows.mergeSort fun left right =>
    coordinateLe left.coordinate right.coordinate
  let mut rows : List Row := []
  for row in sorted do
    match roles.roleOf? row.coordinate.locus with
    | some .asset =>
        if row.quantity.quanta != 0 then
          let currency ←
            match currencyText? row.coordinate.measure with
            | some currency => pure currency
            | none =>
                throw
                  ("Wealthfolio cash export requires a three-letter currency Measure for " ++
                    row.coordinate.locus.token ++ " / " ++ row.coordinate.measure.token)
          let activityType :=
            if row.quantity.quanta > 0 then .deposit else .withdrawal
          rows := rows ++ [{
            date := opening.accountingEpoch
            activityType := activityType
            currency := currency
            amount := amountText presentation row.coordinate.measure row.quantity.quanta
            account := row.coordinate.locus.token
            comment :=
              "LOAM opening position | loam_epoch=" ++ opening.accountingEpoch ++
              " | loam_locus=" ++ row.coordinate.locus.token ++
              " | loam_measure=" ++ row.coordinate.measure.token
          }]
    | some _ => pure ()
    | none =>
        throw
          ("Wealthfolio cash export requires explicit AccountingRole for opening Locus " ++
            row.coordinate.locus.token)
  return rows

private def eventComment
    (entry : Loam.ActualJournalProjection.Entry)
    (effect : Effect) : String :=
  let prefix :=
    match entry.description with
    | some description =>
        if description.isEmpty then "" else description ++ " | "
    | none => ""
  prefix ++
    "loam_event_id=" ++ entry.event.id.token ++
    " | loam_locus=" ++ effect.locus.token ++
    " | loam_measure=" ++ effect.measure.token

private def validateRoles
    (roles : AccountingRoleMap)
    (entry : Loam.ActualJournalProjection.Entry) : Except String Unit := do
  let missing :=
    (entry.event.effects.map (·.locus)).eraseDups.filter fun locus =>
      roles.roleOf? locus == none
  if !missing.isEmpty then
    throw
      ("Wealthfolio cash export requires explicit AccountingRole for Event " ++
        entry.event.id.token ++ " Loci: " ++
        String.intercalate ", " (missing.map (·.token)))

private def entryRows
    (presentation : List Loam.MeasurePresentation.Metadata)
    (roles : AccountingRoleMap)
    (entry : Loam.ActualJournalProjection.Entry) :
    Except String (List Row) := do
  validateRoles roles entry
  let assets :=
    (entry.event.effects.filter fun effect =>
      roles.roleOf? effect.locus == some .asset).mergeSort effectLe
  let isTransfer := assets.length > 1
  assets.mapM fun effect => do
    let currency ←
      match currencyText? effect.measure with
      | some currency => pure currency
      | none =>
          throw
            ("Wealthfolio cash export requires a three-letter currency Measure for " ++
              effect.locus.token ++ " / " ++ effect.measure.token)
    let activityType :=
      if isTransfer then
        if effect.quantity.quanta > 0 then
          ActivityType.transferIn
        else
          ActivityType.transferOut
      else if effect.quantity.quanta > 0 then
        ActivityType.deposit
      else
        ActivityType.withdrawal
    return {
      date := entry.validOn
      activityType := activityType
      currency := currency
      amount := amountText presentation effect.measure effect.quantity.quanta
      account := effect.locus.token
      comment := eventComment entry effect
    }

private def selectedEntries
    (accountingEpoch : String)
    (entries : List Loam.ActualJournalProjection.Entry) :
    List Loam.ActualJournalProjection.Entry :=
  entries.filter fun entry => decide (accountingEpoch ≤ entry.validOn)

/--
Render one deterministic Wealthfolio-native cash CSV.

The output columns are the current Wealthfolio importer field names needed for
cash activity plus LOAM provenance:

`date,activityType,currency,amount,account,comment`

Opening rows are emitted first, followed by correction-aware current Actual
entries on or after the Accounting Epoch.
-/
def renderWithPresentation?
    (presentation : List Loam.MeasurePresentation.Metadata)
    (roles : AccountingRoleMap)
    (opening : Loam.OpeningPositionReview.Snapshot)
    (entries : List Loam.ActualJournalProjection.Entry) :
    Except String String := do
  let opening ← openingRows presentation roles opening
  let selected := selectedEntries opening.accountingEpoch entries
  let activityRows ← selected.flatMapM fun entry =>
    entryRows presentation roles entry
  let lines :=
    ["date,activityType,currency,amount,account,comment"] ++
      (opening ++ activityRows).map renderRow
  return String.intercalate "\n" lines ++ "\n"

end Loam.WealthfolioExport

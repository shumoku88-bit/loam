import Loam.ActualJournalProjection
import Loam.Core.AccountingRole
import Loam.MeasurePresentation
import Loam.Persistence.TextEscape

namespace Loam.PlainTextAccountingExport

open Loam.Core

set_option autoImplicit false

/-!
# Conservative Plain Text Accounting export

This module renders the current LOAM Actual journal projection into the shared
core transaction syntax understood by hledger and Ledger.

It is a one-way read projection only. LOAM remains authoritative.

AccountingRole changes only the exported account prefix:

- Asset -> assets:
- Liability -> liabilities:
- Equity -> equity:
- Income -> income:
- Expense -> expenses:

An unresolved role is kept visible under `unclassified:`; no role is inferred.

The export refuses Events that cannot be represented faithfully as ordinary
balanced PTA transactions without inventing valuation or balancing evidence.
In particular, every exported Event must contain at least one Effect and must
sum to zero independently for each Measure.
-/

private def rolePrefix : AccountingRole → String
  | .asset => "assets"
  | .liability => "liabilities"
  | .equity => "equity"
  | .income => "income"
  | .expense => "expenses"

private def accountTokenSafe (token : String) : Bool :=
  !token.isEmpty &&
    !token.contains ' ' &&
    !token.contains '\t' &&
    !token.contains '\n' &&
    !token.contains '\r'

private def measureTokenSafe (token : String) : Bool :=
  accountTokenSafe token

private def accountName
    (roles : AccountingRoleMap) (locus : LocusId) : Except String String := do
  if !accountTokenSafe locus.token then
    throw ("PTA account export requires a whitespace-free Locus token: " ++ locus.token)
  match roles.roleOf? locus with
  | some role =>
      let accountPrefix := rolePrefix role
      let typedPrefix := accountPrefix ++ ":"
      if typedPrefix.isPrefixOf locus.token then
        pure locus.token
      else
        pure (typedPrefix ++ locus.token)
  | none =>
      pure ("unclassified:" ++ locus.token)

private def normalizedDescription (text : String) : String :=
  text.foldl (fun acc char =>
    match char with
    | '\n' => acc.push ' '
    | '\r' => acc.push ' '
    | '\t' => acc.push ' '
    | ';' => acc.push ','
    | other => acc.push other) ""

private def transactionDescription
    (entry : Loam.ActualJournalProjection.Entry) : String :=
  match entry.description with
  | some text =>
      let normalized := normalizedDescription text
      if normalized.isEmpty then
        "LOAM event " ++ normalizedDescription entry.event.id.token
      else
        normalized
  | none => "LOAM event " ++ normalizedDescription entry.event.id.token

private def validateEvent (event : Event) : Except String Unit := do
  if event.effects.isEmpty then
    throw ("PTA export cannot represent effect-free Event " ++ event.id.token)
  match Effect.firstNonzeroMeasureTotal? event.effects with
  | some (measure, total) =>
      throw
        ("PTA export requires per-Measure balance; Event " ++ event.id.token ++
          " sums to " ++ toString total ++ " " ++ measure.token)
  | none => pure ()

private def renderEffect
    (presentation : List Loam.MeasurePresentation.Metadata)
    (roles : AccountingRoleMap) (effect : Effect) : Except String String := do
  let account ← accountName roles effect.locus
  if !measureTokenSafe effect.measure.token then
    throw
      ("PTA amount export requires a whitespace-free Measure token: " ++
        effect.measure.token)
  pure
    ("    " ++ account ++ "  " ++
      Loam.MeasurePresentation.formatQuanta
        presentation effect.measure effect.quantity.quanta ++
      " " ++ effect.measure.token)

private def renderEntry
    (presentation : List Loam.MeasurePresentation.Metadata)
    (roles : AccountingRoleMap)
    (entry : Loam.ActualJournalProjection.Entry) : Except String String := do
  validateEvent entry.event
  let postings ← entry.event.effects.mapM (renderEffect presentation roles)
  let eventId := Loam.Persistence.escapeText entry.event.id.token
  pure <| String.intercalate "\n" <|
    [ entry.validOn ++ " " ++ transactionDescription entry
    , "    ; loam-event-id: " ++ eventId
    ] ++ postings

/--
Render deterministic current Actual entries using only the common hledger/Ledger
core transaction syntax. No directives, inferred amounts, costs, lots, virtual
postings, recurrence, Scheduled evidence, or Capacity evidence are emitted.
-/
def renderWithPresentation?
    (presentation : List Loam.MeasurePresentation.Metadata)
    (roles : AccountingRoleMap)
    (entries : List Loam.ActualJournalProjection.Entry) : Except String String := do
  let transactions ← entries.mapM (renderEntry presentation roles)
  let header :=
    [ "; Generated from LOAM current Actual projection."
    , "; LOAM remains authoritative; this file is a one-way accounting view."
    , "; Loci without explicit AccountingRole are emitted under unclassified:."
    ]
  let body :=
    if transactions.isEmpty then header
    else header ++ [""] ++ [String.intercalate "\n\n" transactions]
  pure (String.intercalate "\n" body ++ "\n")

/-- Scale-0 compatibility renderer. -/
def render?
    (roles : AccountingRoleMap)
    (entries : List Loam.ActualJournalProjection.Entry) : Except String String :=
  renderWithPresentation? [] roles entries

end Loam.PlainTextAccountingExport

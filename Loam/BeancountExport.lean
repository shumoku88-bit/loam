import Loam.ActualJournalProjection
import Loam.Core.AccountingRole

namespace Loam.BeancountExport

open Loam.Core

set_option autoImplicit false

/-!
# Conservative Beancount export

This module renders the correction-aware current LOAM Actual journal projection
as a disposable Beancount file suitable for validation and Fava viewing.

LOAM remains authoritative. The generated file is a one-way target projection.

The first production boundary is intentionally conservative:

- every exported Event must contain at least one Effect;
- every Event must balance independently in each Measure;
- every used Locus must have an explicit AccountingRole;
- one exported Beancount account may correspond to only one LOAM
  Locus/Measure coordinate;
- target account-name normalization must be collision-free;
- Measure tokens must admit a conservative Beancount commodity spelling.

No AccountingRole, valuation, balancing quantity, or historical account-open
fact is inferred.

Beancount requires Open directives before postings. The earliest current
occurrence date in the selected projection is therefore used only as target
scaffolding for generated Open directives. It is not a claim about the
historical creation date of the underlying household locus.
-/

private def roleRoot : AccountingRole → String
  | .asset => "Assets"
  | .liability => "Liabilities"
  | .equity => "Equity"
  | .income => "Income"
  | .expense => "Expenses"

private def asciiAlphaChars : List Char :=
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".toList

private def asciiTokenChars : List Char :=
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_:".toList

private def asciiCommodityChars : List Char :=
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_".toList

private def allCharsIn (allowed : List Char) (text : String) : Bool :=
  text.toList.all fun c => allowed.contains c

private def normalizeLocusComponent? (token : String) : Option String := do
  if token.isEmpty then
    none
  else if !allCharsIn asciiTokenChars token then
    none
  else
    let normalized :=
      String.ofList <| token.toList.map fun c =>
        if c = ':' || c = '_' then '-' else c
    some ("Loam-" ++ normalized)

private def commodityText? (measure : MeasureId) : Option String := do
  if measure.token.isEmpty then
    none
  else if !allCharsIn asciiCommodityChars measure.token then
    none
  else
    match measure.token.toList with
    | [] => none
    | first :: _ =>
        if !asciiAlphaChars.contains first then
          none
        else
          some measure.token.toUpper

private def escapeQuoted (text : String) : String :=
  text.foldl
    (fun acc c =>
      match c with
      | '\\' => acc ++ "\\\\"
      | '"' => acc ++ "\\\""
      | '\n' => acc.push ' '
      | '\r' => acc.push ' '
      | '\t' => acc.push ' '
      | other => acc.push other)
    ""

private def transactionDescription
    (entry : Loam.ActualJournalProjection.Entry) : String :=
  match entry.description with
  | some text =>
      let normalized := escapeQuoted text
      if normalized.isEmpty then
        "LOAM event " ++ escapeQuoted entry.event.id.token
      else
        normalized
  | none =>
      "LOAM event " ++ escapeQuoted entry.event.id.token

private def addMeasureTotal
    (totals : List (MeasureId × Int))
    (measure : MeasureId)
    (amount : Int) : List (MeasureId × Int) :=
  match totals with
  | [] => [(measure, amount)]
  | current :: rest =>
      if current.1 = measure then
        (current.1, current.2 + amount) :: rest
      else
        current :: addMeasureTotal rest measure amount

private def measureTotals (event : Event) : List (MeasureId × Int) :=
  event.effects.foldl
    (fun totals effect =>
      addMeasureTotal totals effect.measure effect.quantity.quanta)
    []

private def firstUnbalanced? (event : Event) : Option (MeasureId × Int) :=
  (measureTotals event).find? fun total => total.2 != 0

private def validateEvent (event : Event) : Except String Unit := do
  if event.effects.isEmpty then
    throw
      ("Beancount export cannot represent effect-free Event " ++
        event.id.token)
  match firstUnbalanced? event with
  | some (measure, total) =>
      throw
        ("Beancount export requires per-Measure balance; Event " ++
          event.id.token ++ " sums to " ++ toString total ++ " " ++
          measure.token)
  | none => pure ()

structure ResolvedCoordinate where
  locus : LocusId
  measure : MeasureId
  account : String
  commodity : String
deriving Repr, DecidableEq

private def accountName
    (roles : AccountingRoleMap)
    (locus : LocusId) : Except String String := do
  let role ←
    match roles.roleOf? locus with
    | some role => pure role
    | none =>
        throw
          ("Beancount export requires explicit AccountingRole for Locus " ++
            locus.token)
  let component ←
    match normalizeLocusComponent? locus.token with
    | some component => pure component
    | none =>
        throw
          ("Beancount export cannot safely encode Locus token " ++
            locus.token)
  pure (roleRoot role ++ ":" ++ component)

private def resolveCoordinate
    (roles : AccountingRoleMap)
    (locus : LocusId)
    (measure : MeasureId) : Except String ResolvedCoordinate := do
  let account ← accountName roles locus
  let commodity ←
    match commodityText? measure with
    | some commodity => pure commodity
    | none =>
        throw
          ("Beancount export cannot safely encode Measure token " ++
            measure.token)
  pure {
    locus := locus
    measure := measure
    account := account
    commodity := commodity
  }

private def usedCoordinates
    (entries : List Loam.ActualJournalProjection.Entry) :
    List (LocusId × MeasureId) :=
  (entries.flatMap fun entry =>
    entry.event.effects.map fun effect =>
      (effect.locus, effect.measure)).eraseDups

private def resolvedCoordinates
    (roles : AccountingRoleMap)
    (entries : List Loam.ActualJournalProjection.Entry) :
    Except String (List ResolvedCoordinate) :=
  (usedCoordinates entries).mapM fun coordinate =>
    resolveCoordinate roles coordinate.1 coordinate.2

private def firstDuplicate? {α : Type} [DecidableEq α] : List α → Option α
  | [] => none
  | item :: rest =>
      if rest.contains item then
        some item
      else
        firstDuplicate? rest

private def validateCoordinateNames
    (coordinates : List ResolvedCoordinate) : Except String Unit := do
  match firstDuplicate? (coordinates.map fun coordinate => coordinate.account) with
  | some account =>
      throw
        ("Beancount target account collision after LOAM normalization: " ++
          account)
  | none => pure ()

private def earliestDate?
    (entries : List Loam.ActualJournalProjection.Entry) : Option String :=
  match entries with
  | [] => none
  | first :: rest =>
      some <| rest.foldl
        (fun earliest entry =>
          if compare entry.validOn earliest = .lt then
            entry.validOn
          else
            earliest)
        first.validOn

private def renderOpen
    (openDate : String)
    (coordinate : ResolvedCoordinate) : String :=
  openDate ++ " open " ++ coordinate.account ++ " " ++ coordinate.commodity

private def renderEffect
    (roles : AccountingRoleMap)
    (effect : Effect) : Except String String := do
  let coordinate ← resolveCoordinate roles effect.locus effect.measure
  let locus := escapeQuoted effect.locus.token
  let measure := escapeQuoted effect.measure.token
  pure <| String.intercalate "\n"
    [ "  " ++ coordinate.account ++ "  " ++
        toString effect.quantity.quanta ++ " " ++ coordinate.commodity
    , "    loam_locus: \"" ++ locus ++ "\""
    , "    loam_measure: \"" ++ measure ++ "\""
    ]

private def renderEntry
    (roles : AccountingRoleMap)
    (entry : Loam.ActualJournalProjection.Entry) : Except String String := do
  validateEvent entry.event
  let postings ← entry.event.effects.mapM (renderEffect roles)
  let eventId := escapeQuoted entry.event.id.token
  let description := transactionDescription entry
  pure <| String.intercalate "\n" <|
    [ entry.validOn ++ " * \"" ++ description ++ "\""
    , "  loam_event_id: \"" ++ eventId ++ "\""
    ] ++ postings

/--
Render deterministic current Actual entries as one standalone disposable
Beancount file.

The generated Open directives use the earliest selected current occurrence date
only as target scaffolding. Source Event identity, Locus identity, and Measure
identity are retained as Beancount metadata for observation and debugging, but
they do not become LOAM authority in the target.
-/
def render?
    (roles : AccountingRoleMap)
    (entries : List Loam.ActualJournalProjection.Entry) :
    Except String String := do
  for entry in entries do
    validateEvent entry.event

  let coordinates ← resolvedCoordinates roles entries
  validateCoordinateNames coordinates

  let header :=
    [ "; Generated from LOAM current Actual projection."
    , "; LOAM remains authoritative; this Beancount file is disposable."
    , "; Open dates below are target scaffolding, not source account-open facts."
    ]

  match earliestDate? entries with
  | none =>
      pure (String.intercalate "\n" header ++ "\n")
  | some openDate =>
      let openings := coordinates.map (renderOpen openDate)
      let transactions ← entries.mapM (renderEntry roles)
      let body :=
        header ++ [""] ++ openings ++
          (if transactions.isEmpty then [] else [""] ++
            [String.intercalate "\n\n" transactions])
      pure (String.intercalate "\n" body ++ "\n")

end Loam.BeancountExport

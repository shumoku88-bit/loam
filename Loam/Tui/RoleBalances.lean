import Loam.RoleBalanceReview
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.RoleBalances

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Evidence-aware accounting balance presentation

This module is presentation only. It consumes the shared `RoleBalanceReview`
answer and derives Balance-Sheet-, Net-Worth-, and Trial-Balance-shaped views.
It does not load canonical evidence, calculate a second balance, infer a role,
or introduce a report-specific semantic engine.

The support domains follow Observation 242/243:

- Balance Sheet: Asset / Liability / Equity coordinates;
- Net Worth: Asset / Liability coordinates, per Measure;
- Trial Balance: every coordinate.

An unresolved AccountingRole is conservatively treated as a Balance Sheet and
Net Worth blocker because the presentation cannot prove that the coordinate is
outside those role domains. Distinct Measures are never valued or summed.

The Answerability Map is also presentation-only. It summarizes the evidence
frontiers already present in `RoleBalanceReview.Snapshot`; it does not infer
missing history or prescribe zero-origin evidence merely to turn an unknown
quantity into a number.
-/

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def signedQuanta (quantity : Quantity) : String :=
  if quantity.quanta > 0 then "+" ++ toString quantity.quanta else toString quantity.quanta

private def roleLabel : AccountingRole → String
  | .asset => "Asset"
  | .liability => "Liability"
  | .equity => "Equity"
  | .income => "Income"
  | .expense => "Expense"

private def isBalanceSheetRole : AccountingRole → Bool
  | .asset => true
  | .liability => true
  | .equity => true
  | .income => false
  | .expense => false

private def isNetWorthRole : AccountingRole → Bool
  | .asset => true
  | .liability => true
  | .equity => false
  | .income => false
  | .expense => false

private def isFlowRole : AccountingRole → Bool
  | .income => true
  | .expense => true
  | _ => false

private def addMeasureIfAbsent
    (measures : List MeasureId) (measure : MeasureId) : List MeasureId :=
  if measure ∈ measures then measures else measures ++ [measure]

/-- Presentation projection of every coordinate whose AccountingRole is unresolved. -/
private structure RoleGap where
  coordinate : EffectCoordinate
  quantity : Option Quantity

private def roleGaps (snapshot : Loam.RoleBalanceReview.Snapshot) : List RoleGap :=
  snapshot.unresolvedRoles.map (fun row =>
    { coordinate := row.coordinate, quantity := some row.quantity }) ++
  snapshot.knownPresentBalances.filterMap (fun row =>
    match row.role with
    | some _ => none
    | none => some { coordinate := row.coordinate, quantity := none }) ++
  snapshot.unsupportedBalances.filterMap fun row =>
    match row.role with
    | some _ => none
    | none => some { coordinate := row.coordinate, quantity := none }

private def balanceMeasures (snapshot : Loam.RoleBalanceReview.Snapshot) : List MeasureId :=
  let supported := snapshot.rows.foldl
    (fun measures row =>
      if isBalanceSheetRole row.role then
        addMeasureIfAbsent measures row.coordinate.measure
      else
        measures)
    []
  let presentUnknown := snapshot.knownPresentBalances.foldl
    (fun measures row =>
      match row.role with
      | some role =>
          if isBalanceSheetRole role then
            addMeasureIfAbsent measures row.coordinate.measure
          else
            measures
      | none => measures)
    supported
  let unsupported := snapshot.unsupportedBalances.foldl
    (fun measures row =>
      match row.role with
      | some role =>
          if isBalanceSheetRole role then
            addMeasureIfAbsent measures row.coordinate.measure
          else
            measures
      | none => measures)
    presentUnknown
  (roleGaps snapshot).foldl
    (fun measures row => addMeasureIfAbsent measures row.coordinate.measure)
    unsupported

private def rowLe
    (left right : Loam.RoleBalanceReview.Row) : Bool :=
  if left.coordinate.measure.token == right.coordinate.measure.token then
    left.coordinate.locus.token <= right.coordinate.locus.token
  else
    left.coordinate.measure.token <= right.coordinate.measure.token

private def rowsFor
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) (role : AccountingRole) : List Loam.RoleBalanceReview.Row :=
  (snapshot.rows.filter fun row =>
    decide (row.coordinate.measure = measure ∧ row.role = role)).mergeSort rowLe

private def knownRoleSubtotal
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) (role : AccountingRole) : Int :=
  (rowsFor snapshot measure role).foldl (fun total row => total + row.quantity.quanta) 0

private def balanceRowLine (row : Loam.RoleBalanceReview.Row) : Widget :=
  line
    ("  " ++ Loam.Tui.Layout.padRight 28 row.coordinate.locus.token ++
      Loam.Tui.Layout.padLeft 12 (signedQuanta row.quantity) ++
      " " ++ row.coordinate.measure.token)

private def roleSection
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) (role : AccountingRole) : List Widget :=
  let rows := rowsFor snapshot measure role
  [ muted (roleLabel role) ] ++
  (if rows.isEmpty then
    [muted "  (no supported rows)"]
   else
    rows.map balanceRowLine) ++
  [ muted
      ("  Known subtotal: " ++ toString (knownRoleSubtotal snapshot measure role) ++
        " " ++ measure.token) ]

private def stockUnsupportedFor
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) : List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row =>
    if decide (row.coordinate.measure = measure) then
      match row.role with
      | some role => isBalanceSheetRole role
      | none => false
    else
      false

private def stockKnownPresentFor
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) : List Loam.RoleBalanceReview.KnownPresentBalance :=
  snapshot.knownPresentBalances.filter fun row =>
    if decide (row.coordinate.measure = measure) then
      match row.role with
      | some role => isBalanceSheetRole role
      | none => false
    else
      false

private def netWorthKnownPresentFor
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) : List Loam.RoleBalanceReview.KnownPresentBalance :=
  snapshot.knownPresentBalances.filter fun row =>
    if decide (row.coordinate.measure = measure) then
      match row.role with
      | some role => isNetWorthRole role
      | none => false
    else
      false

private def netWorthUnsupportedFor
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) : List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row =>
    if decide (row.coordinate.measure = measure) then
      match row.role with
      | some role => isNetWorthRole role
      | none => false
    else
      false

private def unresolvedFor
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) : List RoleGap :=
  (roleGaps snapshot).filter fun row => decide (row.coordinate.measure = measure)

private def knownNetWorth
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (measure : MeasureId) : Int :=
  snapshot.rows.foldl
    (fun total row =>
      if decide (row.coordinate.measure = measure) && isNetWorthRole row.role then
        total + row.quantity.quanta
      else
        total)
    0

private def unsupportedLine
    (row : Loam.RoleBalanceReview.UnsupportedBalance) : Widget :=
  let role := match row.role with
    | some value => roleLabel value
    | none => "Unresolved role"
  line
    ("  ? " ++ Loam.Tui.Layout.padRight 28 row.coordinate.locus.token ++
      " balance unsupported  " ++ row.coordinate.measure.token ++ "  " ++ role)

private def knownPresentLine
    (row : Loam.RoleBalanceReview.KnownPresentBalance) : Widget :=
  let role := match row.role with
    | some value => roleLabel value
    | none => "Unresolved role"
  line
    ("  ? " ++ Loam.Tui.Layout.padRight 28 row.coordinate.locus.token ++
      " amount unknown, known present  " ++ row.coordinate.measure.token ++ "  " ++ role)

private def unresolvedLine (row : RoleGap) : Widget :=
  let quantity := match row.quantity with
    | some value => signedQuanta value
    | none => "?"
  line
    ("  ? " ++ Loam.Tui.Layout.padRight 28 row.coordinate.locus.token ++
      Loam.Tui.Layout.padLeft 12 quantity ++ " " ++ row.coordinate.measure.token ++
      "  role unresolved")

private def quantitySupportedCount
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  snapshot.rows.length + snapshot.unresolvedRoles.length

private def totalCoordinateCount
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  quantitySupportedCount snapshot +
    snapshot.knownPresentBalances.length +
    snapshot.unsupportedBalances.length

private def classifiedUnsupportedCount
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  (snapshot.unsupportedBalances.filter fun row => row.role.isSome).length

private def classifiedKnownPresentCount
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  (snapshot.knownPresentBalances.filter fun row => row.role.isSome).length

private def roleClassifiedCount
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  snapshot.rows.length + classifiedKnownPresentCount snapshot + classifiedUnsupportedCount snapshot

private def balanceSheetKnownPresent
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.KnownPresentBalance :=
  snapshot.knownPresentBalances.filter fun row =>
    match row.role with
    | some role => isBalanceSheetRole role
    | none => false

private def netWorthKnownPresent
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.KnownPresentBalance :=
  snapshot.knownPresentBalances.filter fun row =>
    match row.role with
    | some role => isNetWorthRole role
    | none => false

private def balanceSheetUnsupported
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row =>
    match row.role with
    | some role => isBalanceSheetRole role
    | none => false

private def netWorthUnsupported
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row =>
    match row.role with
    | some role => isNetWorthRole role
    | none => false

private def flowUnsupported
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row =>
    match row.role with
    | some role => isFlowRole role
    | none => false

private def answerabilityStatus
    (quantityBlockers roleBlockers : Nat) : String :=
  if quantityBlockers == 0 && roleBlockers == 0 then "ANSWERABLE" else "BLOCKED"

private def answerabilitySupportGapLine
    (row : Loam.RoleBalanceReview.UnsupportedBalance) : Widget :=
  let role := match row.role with
    | some value => roleLabel value
    | none => "Unresolved role"
  line
    ("  [quantity] " ++ row.coordinate.locus.token ++ " / " ++
      row.coordinate.measure.token ++ "  " ++ role)

private def answerabilityKnownPresentLine
    (row : Loam.RoleBalanceReview.KnownPresentBalance) : Widget :=
  let role := match row.role with
    | some value => roleLabel value
    | none => "Unresolved role"
  line
    ("  [amount] " ++ row.coordinate.locus.token ++ " / " ++
      row.coordinate.measure.token ++ "  " ++ role ++
      "  known present, exact amount unknown")

private def answerabilityRoleGapLine (row : RoleGap) : Widget :=
  let quantityState := if row.quantity.isSome then "quantity known" else "quantity also unsupported"
  line
    ("  [role] " ++ row.coordinate.locus.token ++ " / " ++
      row.coordinate.measure.token ++ "  " ++ quantityState)

private def answerabilityMapLines
    (snapshot : Loam.RoleBalanceReview.Snapshot) : List Widget :=
  let total := totalCoordinateCount snapshot
  let quantitySupported := quantitySupportedCount snapshot
  let roleClassified := roleClassifiedCount snapshot
  let stockKnownPresent := balanceSheetKnownPresent snapshot
  let netWorthKnownPresentRows := netWorthKnownPresent snapshot
  let stockBlockers := balanceSheetUnsupported snapshot
  let netWorthBlockers := netWorthUnsupported snapshot
  let unresolved := roleGaps snapshot
  let roleBlockers := unresolved.length
  let flowGaps := flowUnsupported snapshot
  [ line "Answerability Map"
  , muted "Which current accounting questions are justified by existing evidence?"
  , line
      ("  Current quantity support  " ++ toString quantitySupported ++ " / " ++
        toString total ++ " coordinates")
  , line
      ("  AccountingRole coverage  " ++ toString roleClassified ++ " / " ++
        toString total ++ " coordinates")
  , line
      ("  Balance Sheet            " ++
        answerabilityStatus (stockKnownPresent.length + stockBlockers.length) roleBlockers ++
        "  (" ++ toString stockKnownPresent.length ++ " amount-unknown, " ++
        toString stockBlockers.length ++ " unsupported, " ++
        toString roleBlockers ++ " role blockers)")
  , line
      ("  Net Worth                " ++
        answerabilityStatus (netWorthKnownPresentRows.length + netWorthBlockers.length) roleBlockers ++
        "  (" ++ toString netWorthKnownPresentRows.length ++ " amount-unknown, " ++
        toString netWorthBlockers.length ++ " unsupported, " ++
        toString roleBlockers ++ " role blockers)")
  , line
      ("  Trial Balance frontier   " ++ toString quantitySupported ++ " / " ++
        toString total ++ " current quantities supported")
  , line
      ("  Flow-role quantity gaps  " ++ toString flowGaps.length ++
        "  (Income / Expense; do not block Balance Sheet or Net Worth)")
  , blank
  , muted "Next evidence targets for Balance Sheet / Net Worth:"
  ] ++
  (if stockKnownPresent.isEmpty then [] else
    stockKnownPresent.map answerabilityKnownPresentLine) ++
  (if stockBlockers.isEmpty && stockKnownPresent.isEmpty then
    [muted "  No classified stock-role quantity blockers."]
   else
    stockBlockers.map answerabilitySupportGapLine) ++
  (if unresolved.isEmpty then
    [muted "  No unresolved AccountingRole blockers."]
   else
    unresolved.map answerabilityRoleGapLine) ++
  [ muted "Known-present evidence proves existence, not an arithmetic amount."
  , muted "For an unsupported quantity blocker, explicit support can be zero-origin, opening, or an exact current anchor."
  , muted "Add zero-origin only when retained history really begins at zero; never add it just to erase '?'."
  , muted "Flow-role gaps remain visible in the Trial Balance frontier but are lower priority for stock reports."
  ]

private def measureBalanceLines
    (snapshot : Loam.RoleBalanceReview.Snapshot) (measure : MeasureId) : List Widget :=
  let stockKnownPresent := stockKnownPresentFor snapshot measure
  let netWorthKnownPresent := netWorthKnownPresentFor snapshot measure
  let stockUnsupported := stockUnsupportedFor snapshot measure
  let netWorthUnsupported := netWorthUnsupportedFor snapshot measure
  let unresolved := unresolvedFor snapshot measure
  let balanceSheetComplete :=
    stockKnownPresent.isEmpty && stockUnsupported.isEmpty && unresolved.isEmpty
  let netWorthComplete :=
    netWorthKnownPresent.isEmpty && netWorthUnsupported.isEmpty && unresolved.isEmpty
  let netWorth := knownNetWorth snapshot measure
  [ line ("Measure: " ++ measure.token)
  , muted "Balance Sheet-shaped supported rows"
  ] ++
  roleSection snapshot measure .asset ++ [blank] ++
  roleSection snapshot measure .liability ++ [blank] ++
  roleSection snapshot measure .equity ++
  [ blank
  , line
      (if balanceSheetComplete then
        "Balance Sheet support: COMPLETE"
       else
        "Balance Sheet support: INCOMPLETE")
  ] ++
  (if stockKnownPresent.isEmpty then [] else
    [muted "Known stock-role balances whose exact amount is unknown:"] ++
      stockKnownPresent.map knownPresentLine) ++
  (if stockUnsupported.isEmpty then [] else
    [muted "Known stock-role coordinates without current balance support:"] ++
      stockUnsupported.map unsupportedLine) ++
  (if unresolved.isEmpty then [] else
    [muted "Coordinates whose AccountingRole is unresolved:"] ++
      unresolved.map unresolvedLine) ++
  [ blank
  , line ("Known Net Worth subtotal: " ++ toString netWorth ++ " " ++ measure.token)
  , line
      (if netWorthComplete then
        "Qualified Net Worth: " ++ toString netWorth ++ " " ++ measure.token
       else
        "Qualified Net Worth: UNKNOWN")
  , muted "Net Worth uses raw Asset + Liability quantity, exactly as the qualified projection model."
  , muted "No cross-Measure valuation or conversion is inferred."
  ]

private def trialSupportedLine (row : Loam.RoleBalanceReview.Row) : Widget :=
  line
    ("  " ++ Loam.Tui.Layout.padRight 28 row.coordinate.locus.token ++
      Loam.Tui.Layout.padLeft 12 (signedQuanta row.quantity) ++ " " ++
      Loam.Tui.Layout.padRight 10 row.coordinate.measure.token ++
      roleLabel row.role)

private def classifiedKnownPresent
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.KnownPresentBalance :=
  snapshot.knownPresentBalances.filter fun row => row.role.isSome

private def classifiedUnsupported
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row => row.role.isSome

private def trialBalanceLines (snapshot : Loam.RoleBalanceReview.Snapshot) : List Widget :=
  let supported := snapshot.rows.mergeSort rowLe
  let unresolved := roleGaps snapshot
  let knownPresent := classifiedKnownPresent snapshot
  let unsupported := classifiedUnsupported snapshot
  [ line "Trial Balance-shaped frontier"
  , muted "Every current coordinate belongs to this support question; role totals are not substituted for rows."
  , line
      (if snapshot.knownPresentBalances.isEmpty && snapshot.unsupportedBalances.isEmpty then
        "Exact quantity support: COMPLETE"
       else
        "Exact quantity support: INCOMPLETE")
  , line
      (if unresolved.isEmpty then
        "Role classification: COMPLETE"
       else
        "Role classification: INCOMPLETE")
  , blank
  ] ++
  (if supported.isEmpty then
    [muted "No classified supported rows."]
   else
    supported.map trialSupportedLine) ++
  (if unresolved.isEmpty then [] else
    [blank, muted "Unresolved role frontier:"] ++ unresolved.map unresolvedLine) ++
  (if knownPresent.isEmpty then [] else
    [blank, muted "Known-present balances with unknown exact amount:"] ++
      knownPresent.map knownPresentLine) ++
  (if unsupported.isEmpty then [] else
    [blank, muted "Classified coordinates without current balance support:"] ++
      unsupported.map unsupportedLine)

/--
Render the human-facing balance answer first, then progressively expose why it
is or is not qualified and finally the evidence-oriented accounting frontier.
Unsupported and unresolved frontiers remain visible instead of being coerced to
zero. The view deliberately makes no retained-earnings, closing, valuation,
recognition, or historical-as-of claim.
-/
def lines (snapshot : Loam.RoleBalanceReview.Snapshot) : List Widget :=
  let measures := balanceMeasures snapshot
  [ line "Current Balances"
  , muted "What do I have and owe now?"
  , blank
  ] ++
  (if measures.isEmpty then
    [muted "No Balance-Sheet-relevant or unresolved current coordinates are visible."]
   else
    measures.flatMap fun measure => measureBalanceLines snapshot measure ++ [blank]) ++
  [ line "Evidence details"
  , muted "Why these balance answers are or are not justified."
  , blank
  ] ++
  answerabilityMapLines snapshot ++
  [ blank ] ++
  trialBalanceLines snapshot ++
  [ blank
  , muted "One RoleBalance answer; three presentation projections."
  , muted "Supported current quantity is not the same claim as zero-origin history."
  , muted "No retained earnings, period closing, valuation, recognition, or historical as-of semantics are added here."
  ]

end Loam.Tui.RoleBalances

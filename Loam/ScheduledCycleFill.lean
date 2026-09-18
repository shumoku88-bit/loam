import Loam.ActualDate
import Loam.BoundaryPresetConfig

namespace Loam.ScheduledCycleFill

set_option autoImplicit false

/-!
# Current-cycle Scheduled generation

A generation cadence is explicit input intent used only while constructing
ordinary Scheduled occurrences. It is not retained recurrence evidence and does
not introduce a second Scheduled authority.

Generation is clipped to the explicit current boundary window and the current
observation date. The end boundary remains exclusive, matching Current Coverage
and Cycle Budget Scheduled pressure semantics.
-/

/-- User-selected construction cadence. No value of this type is persisted. -/
inductive GenerationCadence where
  | monthly
  | everyTwoMonths
  | yearly
  deriving Repr, DecidableEq

namespace GenerationCadence

/-- Whole Gregorian months between generated occurrences. -/
def months : GenerationCadence → Nat
  | .monthly => 1
  | .everyTwoMonths => 2
  | .yearly => 12

def label : GenerationCadence → String
  | .monthly => "Monthly"
  | .everyTwoMonths => "Every 2 months"
  | .yearly => "Yearly"

end GenerationCadence

/--
Construction request anchored by one explicit Scheduled due date.

The anchor is evidence supplied by the caller. The cadence expresses only how
this one creation action should propose later explicit dates.
-/
structure Request where
  anchor : String
  cadence : GenerationCadence
  deriving Repr, DecidableEq

private def parseDateParts? (text : String) : Option (Nat × Nat × Nat) := do
  if !Loam.ActualDate.validIsoDate text then none else do
    let [yearText, monthText, dayText] := text.splitOn "-" | none
    let year ← yearText.toNat?
    let month ← monthText.toNat?
    let day ← dayText.toNat?
    pure (year, month, day)

private def monthIndex? (text : String) : Option Nat := do
  let (year, month, _) ← parseDateParts? text
  pure (year * 12 + (month - 1))

private def shiftedNominalParts?
    (text : String) (months : Nat) : Option (Nat × Nat × Nat) := do
  let (year, month, day) ← parseDateParts? text
  let zeroBased := (month - 1) + months
  let targetYear := year + zeroBased / 12
  let targetMonth := zeroBased % 12 + 1
  if targetYear > 9999 then none
  else pure (targetYear, targetMonth, day)

/--
One construction-time candidate.

`dated` carries an ordinary generated calendar date. `needsDate` preserves a
nominal cadence slot whose calendar day does not exist, such as February 29 in a
non-leap year or day 31 in a shorter month. The latter is deliberately unresolved
until a human chooses an explicit real date.
-/
inductive Candidate where
  | dated (date : String)
  | needsDate (year month nominalDay : Nat)
  deriving Repr, DecidableEq

/-- Whether one human-resolved date remains inside one explicit construction horizon. -/
def validResolvedDateThrough
    (horizon : Loam.BoundaryPresetConfig.ExplicitHorizon)
    (observedAt date : String) : Bool :=
  Loam.ActualDate.validIsoDate date &&
    decide (horizon.start <= date ∧ observedAt <= date ∧ date < horizon.endExclusive)

/-- Backward-compatible single-window validation. -/
def validResolvedDate
    (window : Loam.BoundaryPresetConfig.CurrentWindow)
    (observedAt date : String) : Bool :=
  validResolvedDateThrough
    { source := window.source
      start := window.start
      endExclusive := window.endExclusive }
    observedAt date

/--
Generate construction candidates through one explicitly configured horizon.

The source anchor may precede the current boundary. The horizon itself is
derived from boundaries already present in configuration, so extending the
construction farther into the future never invents a new cycle or recurrence.

The cadence remains one-shot input. Missing nominal calendar days stay
`needsDate` until a human supplies an explicit date.
-/
def planCandidatesThrough
    (horizon : Loam.BoundaryPresetConfig.ExplicitHorizon)
    (observedAt : String)
    (request : Request) : Except String (List Candidate) := do
  if !Loam.ActualDate.validIsoDate horizon.start ||
      !Loam.ActualDate.validIsoDate horizon.endExclusive ||
      !Loam.ActualDate.validIsoDate observedAt ||
      !Loam.ActualDate.validIsoDate request.anchor then
    throw "loam: Scheduled cycle fill requires valid ISO calendar dates"
  if !(decide (horizon.start < horizon.endExclusive)) then
    throw "loam: Scheduled cycle fill horizon is invalid"
  if !(decide (observedAt < horizon.endExclusive)) then
    throw "loam: Scheduled cycle fill observation is not before the selected horizon"
  if !(decide (request.anchor < horizon.endExclusive)) then
    throw "loam: Scheduled cycle fill anchor is not before the selected horizon"

  let some anchorMonth := monthIndex? request.anchor
    | throw "loam: Scheduled cycle fill anchor is invalid"
  let some observedMonth := monthIndex? observedAt
    | throw "loam: Scheduled cycle fill observation is invalid"
  let some startMonth := monthIndex? horizon.start
    | throw "loam: Scheduled cycle fill start boundary is invalid"
  let some endMonth := monthIndex? horizon.endExclusive
    | throw "loam: Scheduled cycle fill end boundary is invalid"

  let stepMonths := request.cadence.months
  let steps :=
    if endMonth < anchorMonth then 0
    else (endMonth - anchorMonth) / stepMonths

  let mut candidates : List Candidate := []
  for index in List.range steps do
    let offset := (index + 1) * stepMonths
    let some (year, month, nominalDay) := shiftedNominalParts? request.anchor offset
      | throw "loam: Scheduled cycle fill exceeds the supported calendar range"
    let targetMonth := year * 12 + (month - 1)
    if startMonth <= targetMonth && observedMonth <= targetMonth then
      match Loam.ActualDate.shiftMonthsSameDay? request.anchor offset with
      | some date =>
          if validResolvedDateThrough horizon observedAt date then
            candidates := candidates ++ [.dated date]
      | none =>
          candidates := candidates ++ [.needsDate year month nominalDay]
  return candidates

/--
Generate construction candidates for one explicit target boundary window.

This remains as the narrower compatibility entrance introduced before the
fill-through-horizon generalization.
-/
def planCandidatesForWindow
    (window : Loam.BoundaryPresetConfig.CurrentWindow)
    (observedAt : String)
    (request : Request) : Except String (List Candidate) :=
  planCandidatesThrough
    { source := window.source
      start := window.start
      endExclusive := window.endExclusive }
    observedAt request

/--
Backward-compatible current-window entrance.

Current-cycle callers keep the original stricter admission rule: observation and
anchor must both be inside the current window. Cross-cycle construction should
use `planCandidatesForWindow` explicitly.
-/
def planCandidatesAfter
    (window : Loam.BoundaryPresetConfig.CurrentWindow)
    (observedAt : String)
    (request : Request) : Except String (List Candidate) := do
  if !(decide (window.start <= observedAt ∧ observedAt < window.endExclusive)) then
    throw "loam: Scheduled cycle fill observation must lie inside the current window"
  if !(decide (window.start <= request.anchor ∧ request.anchor < window.endExclusive)) then
    throw "loam: Scheduled cycle fill anchor must lie inside the current window"
  planCandidatesForWindow window observedAt request

/--
Generate only already-resolved explicit due dates.

Headless callers that cannot ask a human to resolve a missing nominal calendar
day still fail closed. Interactive callers should use `planCandidatesAfter`
and collect an explicit date for every `needsDate` candidate before publication.
-/
def planThrough
    (horizon : Loam.BoundaryPresetConfig.ExplicitHorizon)
    (observedAt : String)
    (request : Request) : Except String (List String) := do
  let candidates ← planCandidatesThrough horizon observedAt request
  candidates.mapM fun
    | .dated date => pure date
    | .needsDate _ _ _ =>
        throw
          ("loam: " ++ request.cadence.label ++
           " cycle fill reaches a month without the anchor day; choose an explicit date policy")

def planForWindow
    (window : Loam.BoundaryPresetConfig.CurrentWindow)
    (observedAt : String)
    (request : Request) : Except String (List String) := do
  let candidates ← planCandidatesForWindow window observedAt request
  candidates.mapM fun
    | .dated date => pure date
    | .needsDate _ _ _ =>
        throw
          ("loam: " ++ request.cadence.label ++
           " cycle fill reaches a month without the anchor day; choose an explicit date policy")

def planAfter
    (window : Loam.BoundaryPresetConfig.CurrentWindow)
    (observedAt : String)
    (request : Request) : Except String (List String) := do
  let candidates ← planCandidatesAfter window observedAt request
  candidates.mapM fun
    | .dated date => pure date
    | .needsDate _ _ _ =>
        throw
          ("loam: " ++ request.cadence.label ++
           " cycle fill reaches a month without the anchor day; choose an explicit date policy")

end Loam.ScheduledCycleFill

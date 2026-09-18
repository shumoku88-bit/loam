import Loam.ActualDate

namespace Loam.ScheduledCycleFill

set_option autoImplicit false

/-!
# Scheduled generation

This module is a pure construction kernel for proposing later explicit Scheduled
dates. It knows nothing about household cycles, boundary presets, report windows,
or persistence.

A cadence and fill limit are one-shot construction input only. The retained
result, after review and publication elsewhere, is still a set of ordinary
Scheduled occurrences with explicit dates.
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

The anchor is retained Scheduled evidence supplied by the caller. The cadence
expresses only how this one construction action should propose later dates.
-/
structure Request where
  anchor : String
  cadence : GenerationCadence
  deriving Repr, DecidableEq

/--
Exclusive upper bound for one Scheduled generation action.

This is construction input, not retained Scheduled evidence. Its origin is
deliberately absent: a UI may obtain it from a boundary suggestion, direct user
input, or another presentation-specific source without changing the generator.
-/
structure FillLimit where
  endExclusive : String
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
non-leap year or day 31 in a shorter month. The latter stays unresolved until a
human supplies an explicit real date.
-/
inductive Candidate where
  | dated (date : String)
  | needsDate (year month nominalDay : Nat)
  deriving Repr, DecidableEq

/-- Whether one reviewed date remains within this construction action. -/
def validResolvedDate
    (limit : FillLimit)
    (observedAt date : String) : Bool :=
  Loam.ActualDate.validIsoDate limit.endExclusive &&
    Loam.ActualDate.validIsoDate observedAt &&
    Loam.ActualDate.validIsoDate date &&
    decide (observedAt <= date ∧ date < limit.endExclusive)

/--
Generate later construction candidates before one exclusive fill limit.

No cycle coordinate participates. The selected anchor may be arbitrarily old;
already-past generated dates are simply omitted relative to `observedAt`.

The cadence remains one-shot input. Missing nominal calendar days stay
`needsDate` until a human supplies an explicit date.
-/
def planCandidates
    (limit : FillLimit)
    (observedAt : String)
    (request : Request) : Except String (List Candidate) := do
  if !Loam.ActualDate.validIsoDate limit.endExclusive ||
      !Loam.ActualDate.validIsoDate observedAt ||
      !Loam.ActualDate.validIsoDate request.anchor then
    throw "loam: Scheduled generation requires valid ISO calendar dates"
  if !(decide (observedAt < limit.endExclusive)) then
    throw "loam: Scheduled generation observation must precede the fill limit"
  if !(decide (request.anchor < limit.endExclusive)) then
    throw "loam: Scheduled generation anchor must precede the fill limit"

  let some anchorMonth := monthIndex? request.anchor
    | throw "loam: Scheduled generation anchor is invalid"
  let some observedMonth := monthIndex? observedAt
    | throw "loam: Scheduled generation observation is invalid"
  let some endMonth := monthIndex? limit.endExclusive
    | throw "loam: Scheduled generation fill limit is invalid"

  let stepMonths := request.cadence.months
  let steps :=
    if endMonth < anchorMonth then 0
    else (endMonth - anchorMonth) / stepMonths

  let mut candidates : List Candidate := []
  for index in List.range steps do
    let offset := (index + 1) * stepMonths
    let some (year, month, nominalDay) := shiftedNominalParts? request.anchor offset
      | throw "loam: Scheduled generation exceeds the supported calendar range"
    let targetMonth := year * 12 + (month - 1)
    if observedMonth <= targetMonth then
      match Loam.ActualDate.shiftMonthsSameDay? request.anchor offset with
      | some date =>
          if validResolvedDate limit observedAt date then
            candidates := candidates ++ [.dated date]
      | none =>
          if targetMonth <= endMonth then
            candidates := candidates ++ [.needsDate year month nominalDay]
  return candidates

/-- Compatibility name for callers that phrase the action as filling through a limit. -/
def planCandidatesThrough := planCandidates

/--
Generate only already-resolved explicit due dates.

Headless callers that cannot ask a human to resolve a missing nominal calendar
day fail closed. Interactive callers should use `planCandidates` and collect an
explicit date for every `needsDate` candidate before publication.
-/
def plan
    (limit : FillLimit)
    (observedAt : String)
    (request : Request) : Except String (List String) := do
  let candidates ← planCandidates limit observedAt request
  candidates.mapM fun
    | .dated date => pure date
    | .needsDate _ _ _ =>
        throw
          ("loam: " ++ request.cadence.label ++
           " generation reaches a month without the anchor day; choose an explicit date")

/-- Compatibility name paired with `planCandidatesThrough`. -/
def planThrough := plan

end Loam.ScheduledCycleFill

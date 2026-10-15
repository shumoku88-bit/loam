import Loam.Review.CycleSpendingPaceReview

namespace Loam.DailyPaceChangeReview

set_option autoImplicit false

/-!
# Explain an adjacent-day change in discretionary money per remaining day

The source of truth remains CycleSpendingPaceReview.Snapshot. This review
separates the change caused by one fewer calendar day from the change
caused by eligible pool balance and protected Scheduled commitments.

These quantities are arithmetic explanations, not inferred causal labels.
For example, a pool decrease could be a purchase, an inter-account
transfer or a recorded correction. The caller determines whether the
snapshots represent as-known history or restated current truth; this
module must not invent a knowledge-time coordinate or savings reserves.
-/

/-- Exact signed integer-quanta/day decomposition for adjacent days in one cycle. -/
structure Breakdown where
  previousPace : Int
  currentPace : Int
  changePerDay : Int
  timePassageEffect : Int
  freeMoneyEffect : Int
  poolBalanceChange : Int
  protectionRelease : Int
  freeThroughEndChange : Int
  deriving Repr, DecidableEq

/--
For F=eligiblePool-protectedScheduled and R=remaining calendar days:

  P_today - P_yesterday
    = (F_yesterday / R_today - F_yesterday / R_yesterday)
    + (F_today / R_today - F_yesterday / R_today)

This telescopes exactly under LOAM's signed integer division, including
negative balances and truncated fractions. It cannot be used across
different Measures, cycles, skipped dates or inconsistent admitted facts.
-/
def compare
    (previous current : Loam.CycleSpendingPaceReview.Snapshot) :
    Except String Breakdown := do
  if previous.measure != current.measure then
    throw "Daily Pace change requires one Measure"
  if previous.endExclusive != current.endExclusive then
    throw "Daily Pace change crosses a cycle boundary"
  let some nextDay := Loam.ActualDate.shiftDays? previous.observedAt 1
    | throw "Daily Pace change requires valid consecutive days"
  if nextDay != current.observedAt then
    throw "Daily Pace change requires consecutive calendar days"
  if previous.remainingDays != current.remainingDays + 1 ||
      current.remainingDays == 0 then
    throw "Daily Pace change requires a one-day shorter positive horizon"
  if previous.automaticDeductions.quanta < 0 ||
      current.automaticDeductions.quanta < 0 then
    throw "Daily Pace change requires nonnegative protected Scheduled outflows"
  if previous.eligiblePool.quanta - previous.automaticDeductions.quanta !=
      previous.availableThroughEnd.quanta ||
      current.eligiblePool.quanta - current.automaticDeductions.quanta !=
        current.availableThroughEnd.quanta then
    throw "Daily Pace change has inconsistent available-through-end evidence"
  let some previousPace := previous.dailyPaceQuanta?
    | throw "Daily Pace change previous day unavailable"
  let some currentPace := current.dailyPaceQuanta?
    | throw "Daily Pace change current day unavailable"
  let oldFreeOnNewHorizon :=
    previous.availableThroughEnd.quanta / Int.ofNat current.remainingDays
  let timePassageEffect := oldFreeOnNewHorizon - previousPace
  let freeMoneyEffect := currentPace - oldFreeOnNewHorizon
  let poolBalanceChange :=
    current.eligiblePool.quanta - previous.eligiblePool.quanta
  let protectionRelease :=
    previous.automaticDeductions.quanta - current.automaticDeductions.quanta
  return {
    previousPace
    currentPace
    changePerDay := currentPace - previousPace
    timePassageEffect
    freeMoneyEffect
    poolBalanceChange
    protectionRelease
    freeThroughEndChange := poolBalanceChange + protectionRelease
  }

end Loam.DailyPaceChangeReview

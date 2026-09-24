import Loam.Presentation.HouseholdSnapshot

namespace Loam.Presentation.Home

open Loam.Core

set_option autoImplicit false

/-!
# Surface-neutral Home presentation model

Home is derived entirely from the shared read-side household snapshot. It does
not load files, publish facts, infer classifications, or retain UI state.

Renderers may turn this model into terminal text, HTML, native widgets, or other
presentation without becoming a second household semantics engine.
-/

structure Funding where
  budgetableBacking : Quantity
  remainingAssigned : Quantity
  residualBeforeUnresolved : Quantity
  deriving Repr, DecidableEq

structure DailyPace where
  quantaPerDay : Int
  availableThroughEnd : Quantity
  remainingDays : Nat
  endExclusive : String
  deriving Repr, DecidableEq

structure Model where
  observedAt : String
  recentActualCount : Loam.Presentation.ReadState Nat
  nextScheduled : Loam.Presentation.ReadState (Option Loam.ScheduledReview.Record)
  attentionOpenCount : Loam.Presentation.ReadState Nat
  dailyPace : Loam.Presentation.ReadState (Option DailyPace)
  funding : Loam.Presentation.ReadState Funding

private def scheduledBefore
    (left right : Loam.ScheduledReview.Record) : Bool :=
  if left.scheduledOn = right.scheduledOn then
    left.id.token <= right.id.token
  else
    left.scheduledOn <= right.scheduledOn

private def nextScheduledFrom
    (records : List Loam.ScheduledReview.Record) : Option Loam.ScheduledReview.Record :=
  (records.mergeSort scheduledBefore).head?

/--
Derive the Home presentation from already-qualified shared Review answers.

A missing Attention count means that Attention authority is not configured. A
configured-but-empty Attention source is represented as some 0, preserving the
existing Review distinction.
-/
def fromSnapshot (snapshot : Loam.Presentation.HouseholdSnapshot) : Model :=
  let recentActualCount :=
    Loam.Presentation.ReadState.map snapshot.actual fun records =>
      (Loam.ActualReview.select records (.week snapshot.observedAt)).length
  let nextScheduled :=
    Loam.Presentation.ReadState.map snapshot.scheduled nextScheduledFrom
  let attentionOpenCount :=
    Loam.Presentation.ReadState.map snapshot.attention fun attention =>
      attention.openItems.length
  let dailyPace :=
    Loam.Presentation.ReadState.map snapshot.pace fun pace =>
      match pace.dailyPaceQuanta? with
      | none => none
      | some quanta =>
          some {
            quantaPerDay := quanta
            availableThroughEnd := pace.availableThroughEnd
            remainingDays := pace.remainingDays
            endExclusive := pace.endExclusive
          }
  let funding :=
    Loam.Presentation.ReadState.map
      (Loam.Presentation.ReadState.fromExcept snapshot.budget.funding)
      fun summary =>
        {
          budgetableBacking := summary.budgetableBacking
          remainingAssigned := summary.remainingAssigned
          residualBeforeUnresolved := summary.residualBeforeUnresolved
        }
  {
    observedAt := snapshot.observedAt
    recentActualCount := recentActualCount
    nextScheduled := nextScheduled
    attentionOpenCount := attentionOpenCount
    dailyPace := dailyPace
    funding := funding
  }

end Loam.Presentation.Home

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
  recentActualCount : Except String Nat
  nextScheduled : Except String (Option Loam.ScheduledReview.Record)
  attentionOpenCount : Except String (Option Nat)
  dailyPace : Except String (Option DailyPace)
  funding : Except String Funding

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
    match snapshot.actual with
    | .error message => .error message
    | .ok records =>
        .ok (Loam.ActualReview.select records (.week snapshot.observedAt)).length
  let nextScheduled :=
    match snapshot.scheduled with
    | .error message => .error message
    | .ok records => .ok (nextScheduledFrom records)
  let attentionOpenCount :=
    match snapshot.attention with
    | .error message => .error message
    | .ok availability =>
        match availability with
        | .unavailable => .ok none
        | .available attention => .ok (some attention.openItems.length)
  let dailyPace :=
    match snapshot.pace with
    | .error message => .error message
    | .ok pace =>
        match pace.dailyPaceQuanta? with
        | none => .ok none
        | some quanta =>
            .ok (some {
              quantaPerDay := quanta
              availableThroughEnd := pace.availableThroughEnd
              remainingDays := pace.remainingDays
              endExclusive := pace.endExclusive
            })
  let funding :=
    match snapshot.budget.funding with
    | .error message => .error message
    | .ok summary =>
        .ok {
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

import Loam.ActualDate
import Loam.Core.Event

namespace Loam.BoundedHistorySupport

open Loam.Core

set_option autoImplicit false

/-!
# Bounded historical quantity support

This is the narrow production evidence earned by Observations 345/346.

One row states only:

> for this `Locus × Measure` coordinate, every real quantity change from the
> start of this calendar day onward is represented by dated, correction-aware
> Actual evidence.

The row does not store an opening quantity, current quantity, reconciliation id,
anchor id, correction graph, or report state. A later exact
`CurrentQuantityAnchor` supplies the terminal quantity used by historical
reconstruction.

The claim is never inferred from endpoint equality. It is explicit household
evidence and can be changed or removed through its publisher.
-/

structure Support where
  coordinate : EffectCoordinate
  startDay : String
deriving Repr, DecidableEq

structure Evidence where
  supports : List Support
  coordinateNodup : (supports.map Support.coordinate).Nodup
  validStartDays : supports.all (fun support => Loam.ActualDate.validIsoDate support.startDay) = true
deriving Repr, DecidableEq

namespace Evidence

def ofSupports? (supports : List Support) : Option Evidence :=
  if hCoordinates : (supports.map Support.coordinate).Nodup then
    if hDates : supports.all (fun support => Loam.ActualDate.validIsoDate support.startDay) = true then
      some {
        supports := supports
        coordinateNodup := hCoordinates
        validStartDays := hDates
      }
    else
      none
  else
    none

def empty : Evidence := {
  supports := []
  coordinateNodup := by simp
  validStartDays := by simp
}

def supportFor? (evidence : Evidence) (coordinate : EffectCoordinate) : Option Support :=
  evidence.supports.find? fun support => decide (support.coordinate = coordinate)

def coordinates (evidence : Evidence) : List EffectCoordinate :=
  evidence.supports.map Support.coordinate

def withSupport? (evidence : Evidence) (support : Support) : Option Evidence :=
  let retained := evidence.supports.filter fun current =>
    decide (current.coordinate != support.coordinate)
  ofSupports? (retained ++ [support])

def withoutCoordinate?
    (evidence : Evidence)
    (coordinate : EffectCoordinate) : Option Evidence :=
  ofSupports? <| evidence.supports.filter fun support =>
    decide (support.coordinate != coordinate)

end Evidence

end Loam.BoundedHistorySupport

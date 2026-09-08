import Loam.Core.EventMemory

namespace Loam.Core

set_option autoImplicit false

/--
One explicit claim that a retained Actual Event is reversed by another retained
Event whose physical Effects are its exact inverse.

This relation is not a correction. Both endpoints remain historical facts and
both remain part of physical quantity accumulation. It preserves the answer
"which Actual does this inverse movement reverse?" without deriving that answer
from signs, descriptions, dates, endpoint shape, or temporal ordering.
-/
structure ActualReversal where
  target : EventId
  reversal : EventId
deriving Repr, DecidableEq

/--
Complete retained Actual-reversal relation evidence.

List order is representation only. One target may be reversed at most once and
one reversal Event may explain at most one target. Referential closure and exact
inverse-Effect validation remain publisher/read admission obligations because
relation-first interrupted publication may temporarily name an absent reversal
Event.
-/
structure ActualReversalMemory where
  reversals : List ActualReversal
  targetNodup : (reversals.map ActualReversal.target).Nodup
  reversalNodup : (reversals.map ActualReversal.reversal).Nodup

namespace ActualReversalMemory

/-- Admit only endpoint-functional raw reversal evidence. -/
def ofReversals? (reversals : List ActualReversal) : Option ActualReversalMemory :=
  if hTarget : (reversals.map ActualReversal.target).Nodup then
    if hReversal : (reversals.map ActualReversal.reversal).Nodup then
      some { reversals := reversals, targetNodup := hTarget, reversalNodup := hReversal }
    else
      none
  else
    none

/-- Empty reversal authority is valid explicit evidence. -/
def empty : ActualReversalMemory :=
  { reversals := [], targetNodup := by simp, reversalNodup := by simp }

/-- Find the unique retained relation for one target Actual. -/
def findByTarget? (memory : ActualReversalMemory) (target : EventId) : Option ActualReversal :=
  memory.reversals.find? fun relation => decide (relation.target = target)

/-- Find the unique retained relation explained by one reversal Event. -/
def findByReversal? (memory : ActualReversalMemory) (reversal : EventId) : Option ActualReversal :=
  memory.reversals.find? fun relation => decide (relation.reversal = reversal)

/-- Append one relation only when both endpoint-functional invariants remain true. -/
def add? (memory : ActualReversalMemory) (relation : ActualReversal) : Option ActualReversalMemory :=
  ofReversals? (memory.reversals ++ [relation])

end ActualReversalMemory

end Loam.Core

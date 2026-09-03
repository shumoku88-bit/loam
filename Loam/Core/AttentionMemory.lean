import Loam.Core.Attention

namespace Loam.Core

set_option autoImplicit false

/-!
# Attention memory

Storage order is representation only. It is not priority, chronology, closure,
or winner authority.
-/

/-- Append-oriented memory for retained Attention items. -/
structure AttentionMemory (Time : Type) where
  items : List (Attention Time)
  idNodup : (items.map Attention.id).Nodup

namespace AttentionMemory

/-- Admit runtime Attention values only when stable identity is unique. -/
def ofItems? {Time : Type}
    (items : List (Attention Time)) : Option (AttentionMemory Time) :=
  if h : (items.map Attention.id).Nodup then
    some { items := items, idNodup := h }
  else
    none

/-- Append one Attention item, rejecting repeated identity. -/
def add? {Time : Type}
    (memory : AttentionMemory Time)
    (item : Attention Time) : Option (AttentionMemory Time) :=
  ofItems? (memory.items ++ [item])

private def findItemById? {Time : Type} :
    List (Attention Time) → AttentionId → Option (Attention Time)
  | [], _ => none
  | item :: rest, id =>
      if item.id = id then some item else findItemById? rest id

/-- Find one retained Attention item by stable identity. -/
def findById? {Time : Type}
    (memory : AttentionMemory Time)
    (id : AttentionId) : Option (Attention Time) :=
  findItemById? memory.items id

end AttentionMemory

/--
Current retained closure evidence.

The first practical slice permits at most one closure fact per Attention
identity. Correction/edit semantics for mistaken closure evidence are not yet
claimed; a future slice must earn them rather than hiding a winner rule here.
-/
structure AttentionClosureMemory (Time : Type) where
  closures : List (AttentionClosure Time)
  attentionNodup : (closures.map AttentionClosure.attention).Nodup

namespace AttentionClosureMemory

/-- Admit closure evidence only when one source Attention has at most one close. -/
def ofClosures? {Time : Type}
    (closures : List (AttentionClosure Time)) : Option (AttentionClosureMemory Time) :=
  if h : (closures.map AttentionClosure.attention).Nodup then
    some { closures := closures, attentionNodup := h }
  else
    none

/-- Append one closure fact, rejecting a second closure for the same Attention. -/
def add? {Time : Type}
    (memory : AttentionClosureMemory Time)
    (closure : AttentionClosure Time) : Option (AttentionClosureMemory Time) :=
  ofClosures? (memory.closures ++ [closure])

private def findClosureByAttention? {Time : Type} :
    List (AttentionClosure Time) → AttentionId → Option (AttentionClosure Time)
  | [], _ => none
  | closure :: rest, id =>
      if closure.attention = id then
        some closure
      else
        findClosureByAttention? rest id

/-- Find current retained closure evidence for one Attention identity. -/
def findByAttention? {Time : Type}
    (memory : AttentionClosureMemory Time)
    (id : AttentionId) : Option (AttentionClosure Time) :=
  findClosureByAttention? memory.closures id

end AttentionClosureMemory

end Loam.Core

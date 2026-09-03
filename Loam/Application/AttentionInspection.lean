import Loam.Core.AttentionMemory

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Current Attention inspection

This is the first current-only household-facing projection for the semantic
family behind "Issues". Relation provenance is intentionally absent from the
lifecycle calculation: Observation 109 established that a relation to an Event
or later Attention identity does not itself close the source item.
-/

/-- Current lifecycle answer while preserving closure disposition and evidence time. -/
inductive AttentionLifecycle (Time : Type) where
  | open
  | resolved (knownOn : Time)
  | dropped (knownOn : Time)
deriving Repr, DecidableEq

/-- One current Attention answer with its retained human/due evidence. -/
structure AttentionInspection (Time : Type) where
  item : Attention Time
  lifecycle : AttentionLifecycle Time
deriving Repr, DecidableEq

/-- Every retained closure must refer to an Attention identity we actually know. -/
def closureReferencesKnown {Time : Type}
    (items : AttentionMemory Time)
    (closures : AttentionClosureMemory Time) : Bool :=
  closures.closures.all fun closure =>
    (AttentionMemory.findById? items closure.attention).isSome

private def lifecycleFor {Time : Type}
    (closures : AttentionClosureMemory Time)
    (item : Attention Time) : AttentionLifecycle Time :=
  match AttentionClosureMemory.findByAttention? closures item.id with
  | none => .open
  | some closure =>
      match closure.kind with
      | .resolved => .resolved closure.knownOn
      | .dropped => .dropped closure.knownOn

/--
Inspect one current Attention item.

A dangling closure invalidates the whole current view rather than being ignored.
No relation record participates in this decision.
-/
def inspectAttention? {Time : Type}
    (items : AttentionMemory Time)
    (closures : AttentionClosureMemory Time)
    (id : AttentionId) : Option (AttentionInspection Time) :=
  if closureReferencesKnown items closures then
    match AttentionMemory.findById? items id with
    | none => none
    | some item => some { item := item, lifecycle := lifecycleFor closures item }
  else
    none

/--
Project every currently open Attention item.

Storage order is retained representation order only. Due-date ordering and
historical `knownThrough` visibility belong to later query-specific projections.
-/
def openAttentions? {Time : Type}
    (items : AttentionMemory Time)
    (closures : AttentionClosureMemory Time) : Option (List (Attention Time)) :=
  if closureReferencesKnown items closures then
    some <| items.items.filter fun item =>
      match AttentionClosureMemory.findByAttention? closures item.id with
      | none => true
      | some _ => false
  else
    none

end Loam.Application
